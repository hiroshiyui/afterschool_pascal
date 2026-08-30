{ PasHttps -- HTTP/1.1 over TLS, which is `PasHttp`'s grammar and `PasTls`'s
  transport and nothing else.

  **Why this is a module and not two more routines in `PasHttp`.** A module
  that chose between transports would have to import `PasTls`, and a module's
  activation is commenced before the program-block whether the program calls
  into it or not (ISO/IEC 10206:1991 §6.2.3.6) -- so every program using plain
  HTTP would link OpenSSL. Splitting the parser from the socket instead cost
  `PasHttp` four exported routines and cost this module twenty-four lines
  (ADR-0265).

  **Those twenty-four lines are duplicated on purpose.** `Send` and `Receive`
  below are the same loops `PasHttp.Send` and `PasHttp.Receive` are, over a
  different pair of primitives. ADR-0116's rule is that two sites are a
  demand, and this is the case where the demand is refused with a reason: what
  the two share is a *loop shape*, and factoring it out needs a transport this
  language cannot express -- §6.7.3.4's procedural parameter cannot carry a
  handle, and a variant record over the two transports is the import this
  module exists to avoid. What is **not** duplicated is the thing worth not
  duplicating: RFC 9112's grammar, the framing rules of §6.3, and every
  refusal in them. There is one parser.

  **Everything else is `PasHttp`'s and is read there.** The bounds, the
  `Request` a caller builds, the `Response` it reads, `Header`, `HeaderOr`,
  `BodyInto`, and what each ErrorCode means -- none of it changes because the
  octets went through a TLS session. A program moving from one to the other
  changes the type of one variable and the qualifier on three calls.

  **What TLS adds to the failures is nothing new.** A refused handshake, an
  unverified certificate and a connection the far end dropped all arrive as
  `errIO` from `PasTls`, and `c.reason` is where the sentence is; this module
  passes both through without inventing a code. `PasTls.Connect` is the
  caller's to make, as `PasNet.Connect` is for the plain form -- a client that
  is handed an open connection can be pointed at a proxy, a test server or a
  socket somebody else opened, and this module has no business deciding.

  A program using this links `-lssl -lcrypto`, which is `PasTls`'s cost and
  not this module's. }

module PasHttps;

export PasHttps = (Send, Receive, Exchange);

{ `PasHttp` is imported **qualified** because three of its exported names are
  three of this module's, which is the property worth keeping: a program
  changes the qualifier on a call and not the name of what it is doing. }
import PasError; PasTls; PasHttp qualified;

{ Write the request over `c`. The codes are `PasHttp.BeginRequest`'s, with
  `errIO` where the TLS connection refused rather than where a socket did. }
function Send(var c: Connection; protected var q: PasHttp.Request): ErrorCode;

{ Read a response into `r`. The method is `PasHttp.BeginResponse`'s and is a
  parameter for the reason given there: RFC 9112 §6.3 makes the framing a
  property of the exchange. }
function Receive(var c: Connection; method: PasHttp.MethodName;
                 var r: PasHttp.Response): ErrorCode;

{ `Send` and then `Receive`. Two routines as well as one, for `PasHttp`'s
  reason: a program that is both ends of a connection has to put the server's
  answer between them. }
function Exchange(var c: Connection; protected var q: PasHttp.Request;
                  var r: PasHttp.Response): ErrorCode;

end;

function Send;
var
  { What one write carries, and the only decision this module makes about the
    shape of what goes out: `NextPiece` fills it and spans a longer piece
    across calls, so this is a buffer size and never a bound on a request. }
  buf: TlsLine;
  w: PasHttp.RequestCursor;
  e: ErrorCode;
begin
  e := PasHttp.BeginRequest(q, w);
  if Failed(e) then exit(e);
  while not w.done do begin
    PasHttp.NextPiece(q, w, buf);
    if length(buf) > 0 then begin
      e := WriteText(c, buf);
      if Failed(e) then exit(e)
    end
  end;
  Send := errNone
end;

function Receive;
var raw: TlsLine; e: ErrorCode;
begin
  PasHttp.BeginResponse(r, method);
  while PasHttp.WantsLine(r) do begin
    e := ReadLine(c, raw);
    { A closed connection is not a failure here; which of RFC 9112 §6.3's
      rules was in force decides what it means, and `FeedEnd` is what knows
      that. `errFull` and `errIO` are the transport's own and are final. }
    if e = errAbsent then e := PasHttp.FeedEnd(r)
    else if Failed(e) then exit(e)
    else e := PasHttp.FeedLine(r, raw);
    if Failed(e) then exit(e)
  end;
  Receive := errNone
end;

function Exchange;
var e: ErrorCode;
begin
  e := Send(c, q);
  if Failed(e) then exit(e);
  Exchange := Receive(c, q.method, r)
end;

end.
