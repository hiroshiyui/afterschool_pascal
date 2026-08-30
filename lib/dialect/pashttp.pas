{ PasHttp -- an HTTP/1.1 client, as a request written and a response read.

  `doc/roadmap.md` said of this row that **HTTP is a module over what exists**,
  and that is the whole of the claim being made here: nothing below binds a C
  function, declares a foreign struct or asks the runtime for anything. It is
  Pascal over `PasNet`'s socket, and the reason that is possible at all is that
  RFC 9112 framed HTTP/1.1 as lines -- a start-line, then fields one to a line,
  then an empty line -- which is exactly the shape `PasNet.ReadLine` answers
  in. The other half of that row, TLS, is not a module over anything and is not
  here.

  **The transport is a line and so is the body, and that is the limit to know
  before using this.** `PasNet` delivers a line at a time and strips the
  terminator, so a carriage return immediately before a line feed does not
  survive -- and this module may add no C to get the octets back. What follows
  is stated rather than hidden: a response body arrives as its **lines**, in
  `r.body[1..r.bodyLines]`, and `BodyInto` joins them with a single line feed.
  A body that is not text does not survive this module. A body that is text
  does, and that is what an API answering JSON or a status page sends.

  **Content-Length is a bound and the close is the backstop.** RFC 9112 §6.3
  gives six ways to know where a body ends; this client uses two of them at
  once. It sends `Connection: close` unless the caller wrote a `Connection`
  field of its own, so rule 6 -- the body ends where the connection does --
  always applies and is exact; and it counts a line as its characters plus one
  octet for the terminator, stopping early when that reaches the stated length.
  Where a body's lines end CRLF the count runs one octet short per line, and
  the close is then what ends the body -- at the same place, which is why the
  two together are right where either alone would not be. `r.stated` is the
  length the server claimed and `r.byClose` says which of the two ended the
  read, so a caller can compare them and decide.

  **Chunked has no such backstop and says so** (RFC 9112 §7.1). A chunk-size
  is a count of octets and nothing else can find the end of a chunk, so the
  same one-octet-per-line accounting is load-bearing there: a chunk whose data
  runs to three or more CRLF-terminated lines is counted short, the line after
  it is read as a chunk-size, and that is `errSyntax`. A reported failure and
  not a wrong body, which is the property worth keeping. Closing it means a
  byte-level read in `runtime/pasrt_posix.c`, which is C this module is not.

  **A 404 is not a failure.** `Receive` answers `errNone` for every response it
  could read, whatever the status-code says, because the status-code is the
  server's answer and the ErrorCode is this module's. The five codes mean:
  `errAbsent`, no response arrived -- the far end closed without one;
  `errSyntax`, what arrived was not an HTTP/1.1 response; `errFull`, it did not
  fit a bound this module states below; `errIO`, the transport refused;
  `errNone`, there is a response in `r`. On any answer but `errNone` the fields
  of `r` hold whatever had been read and are not to be relied on.

  **Redirects are not followed, and that is a decision.** A 3xx arrives as an
  ordinary response with its `Location` field in it, and what to do about one
  is the caller's: RFC 9110 §15.4 leaves automatic redirection to the user
  agent, and the choices it hides -- how many hops, whether a POST becomes a
  GET, whether a redirect off the origin still carries the `Authorization`
  field -- are a policy this module has no way to be right about. It would also
  need a second connection, and this module is handed one and opens none.

  **One request per connection.** Framing a body exactly needs octets and this
  counts lines, so a connection whose body ended one octet from where this
  thinks it did would desynchronise the next response on it. `Connection:
  close` is what makes that unreachable rather than merely unlikely.

  **It blocks, and the caller is what bounds it.** Every read here is
  `PasNet.ReadLine`, which waits. A caller that must not wait forever keeps its
  socket in a `SocketList` -- `Connect(list[1], ...)` -- and calls `PasNet.Wait`
  before `Receive`; a handle cannot be copied (AP 6.4.12.2), so this module
  cannot build such a list out of the socket it was handed and cannot do it for
  the caller.

  **Field names are folded and the first one wins.** RFC 9110 §5.1 makes a
  field name case-insensitive, so every name is kept twice -- as it was written
  and folded to lower case -- and `Header` compares the folded spelling. A name
  that appears twice keeps both entries in `r.field[1..r.count]` and `Header`
  answers the first: RFC 9110 §5.3 permits combining repeated fields into one
  comma-separated value only for a field whose value *is* a list, and nothing
  here knows which those are. `Set-Cookie` is the field that makes that more
  than a technicality.

  RFC 9110 §5 calls these **fields**; the names below say *header*, which is
  what a caller looking for one will type.

  **This module is dialect-only** in lib/dialect/README.md's sense, although it
  binds nothing itself: it is built on `PasNet`, which does, and on AP 6.4.11's
  optional for a field that is not there. }

module PasHttp;

export PasHttp = (MethodMax, TargetMax, HeaderNameMax, HeaderValueMax,
                  ReasonMax, BodyLineMax, MaxHeaders, MaxBodyLines,
                  RequestBodyMax, PieceMax,
                  MethodName, RequestTarget, HeaderName, HeaderValue,
                  ReasonPhrase, BodyLine, RequestBody, OptHeaderValue,
                  HeaderField, Request, Response, HttpPiece, RequestCursor,
                  NewRequest, AddHeader, SetBody,
                  BeginRequest, NextPiece,
                  BeginResponse, WantsLine, FeedLine, FeedEnd,
                  Send, Receive, Exchange,
                  Header, HeaderOr, BodyInto);

import PasError; PasNet;

const
  { RFC 9110 §9 makes a method a token and registers eight; the longest of
    them is six characters and an extension is not much longer. }
  MethodMax = 15;
  { RFC 9112 §3 sets no limit on a request-target and recommends a *server*
    support at least 8000 octets. A client has to choose one, and this is the
    bound past which `NewRequest` refuses rather than a length anything
    truncates to. }
  TargetMax = 2047;
  { A field name is a token and they are short; a value is not, `Set-Cookie`
    and `Location` being the ones that run long. Past either is `errFull`. }
  HeaderNameMax = 63;
  HeaderValueMax = 1023;
  { RFC 9112 §4 makes the reason-phrase optional and advisory. }
  ReasonMax = 127;
  { The fixed buffers ADR-0012 asks for, and each of them is a bound a caller
    can read: a message with more fields than this, a body with more lines, or
    a line longer than this is `errFull` and never a truncation nobody hears
    about. A caller needing more than a page of body wants a file, and this
    module has nowhere to put one. }
  MaxHeaders = 32;
  MaxBodyLines = 64;
  BodyLineMax = 1023;
  { A request body is one string, so it can be handed to `SetBody` whole. }
  RequestBodyMax = 4095;
  { The longest single piece a request is made of, which is the start-line:
    `MethodMax` + a space + `TargetMax` + ` HTTP/1.1` + CRLF is 2074, a field
    line is at most 1090, and the body is at most `RequestBodyMax`. A caller's
    write buffer may be **shorter** than this -- `NextPiece` spans a piece
    across calls -- so this is not a bound on anything a caller must provide. }
  PieceMax = 4096;

  { RFC 9112 §2.1 terminates every line of a message with CRLF. Built by `chr`
    because §6.1.7 gives a character-string no escape and neither character
    can be written in one. }
  CRLF = chr(13) + chr(10);
  HT = chr(9);

type
  MethodName = string(MethodMax);
  RequestTarget = string(TargetMax);
  HeaderName = string(HeaderNameMax);
  HeaderValue = string(HeaderValueMax);
  ReasonPhrase = string(ReasonMax);
  BodyLine = string(BodyLineMax);
  RequestBody = string(RequestBodyMax);

  { AP 6.4.11's absence, for the field that was not sent. A field sent with an
    empty value and a field not sent at all are different facts and RFC 9110
    §5.5 admits the first, so `nil` and `''` are both answers `Header` gives
    and they do not mean the same thing. }
  OptHeaderValue = ?HeaderValue;

  { A field, kept twice: `name` as it was written, because that is what goes
    back on the wire and what a caller prints, and `fold` in lower case,
    because RFC 9110 §5.1 makes the comparison case-insensitive and §6.7.2.5's
    `=` is not. }
  HeaderField = record
    name: HeaderName;
    fold: HeaderName;
    val: HeaderValue
  end;

  { One piece of a request as it goes out, and the buffer `NextPiece` fills.
    A caller may pass a shorter string; this is the capacity that never makes
    a piece span a call. }
  HttpPiece = string(PieceMax);

  { Where a response has got to. **Not exported**: it is the reader's own
    business and a caller drives it through `WantsLine` and `FeedLine`. The
    six phases are RFC 9112's message shape read in order -- the status-line,
    the field lines, then whichever of the three body framings §6.3 selected,
    with the chunked one alternating between a size and its data. }
  ReadPhase = (rpStatus, rpFields, rpCounted, rpChunkSize, rpChunkData,
               rpTrailer, rpDone);

  { Where a request has got to on its way out. A caller declares one, hands
    it to `BeginRequest` and then to `NextPiece` until `done`.

    It is a record of its own rather than state inside the `Request` because
    the request is being **read**: `Send` takes it `protected` and a cursor
    living in it would take that away. The response's state is in the
    `Response` for the mirror-image reason -- that record is being built. }
  RequestCursor = record
    { Which piece, and how far into it. }
    at, off: integer;
    { Whether this module supplies a `Connection` and a `Content-Length`,
      decided once by `BeginRequest` from what the caller wrote. }
    addConn, addLength: boolean;
    { Nothing is left. }
    done: boolean
  end;

  { A request being built. Declared by the caller and filled by the three
    routines below -- there is no allocation here and nothing to release. }
  Request = record
    method: MethodName;
    target: RequestTarget;
    count: integer;
    field: array [1..MaxHeaders] of HeaderField;
    hasBody: boolean;
    body: RequestBody
  end;

  { A response that was read. `status` is RFC 9112 §4's three-digit code and
    `reason` the phrase after it, which may be empty. `stated` is the
    `Content-Length` the server sent, or -1 where it sent none; `chunked` says
    the body was framed by RFC 9112 §7.1's chunks; `byClose` says the body
    ended because the far end closed rather than because its stated length was
    reached. }
  Response = record
    status: integer;
    reason: ReasonPhrase;
    count: integer;
    field: array [1..MaxHeaders] of HeaderField;
    bodyLines: integer;
    body: array [1..MaxBodyLines] of BodyLine;
    stated: integer;
    chunked: boolean;
    byClose: boolean;
    { The reader's own state, and no caller's business. `isHead` is kept from
      `BeginResponse` because RFC 9112 §6.3 rule 1 needs the method and the
      status together, and the status is not known until the first line has
      been fed. }
    phase: ReadPhase;
    isHead: boolean;
    got, chunkSize, chunkGot: integer
  end;

{ --- building a request --------------------------------------------------- }

{ Begin a request. `errSyntax` where the method is not RFC 9110 §9.1's token
  or the target holds a space or a control character -- either would put a
  second line, or a second request, into the one being sent.

  Any method is admitted, GET and POST included: RFC 9110 §9.1 makes the set
  extensible and a client that knew only the eight registered ones would be
  wrong the day a ninth is. }
function NewRequest(var q: Request; method: MethodName;
                    target: RequestTarget): ErrorCode;

{ Add a field. `errSyntax` for a name that is not a token or a value holding a
  control character -- the second is what stops a caller composing a value out
  of something it read and thereby sending fields it did not write. `errFull`
  past `MaxHeaders`.

  A `Host` field is required and is the caller's to add: RFC 9112 §3.2 makes
  it the authority the request is for, which this module cannot know, having
  been handed an open socket rather than a name. }
function AddHeader(var q: Request; name: HeaderName;
                   val: HeaderValue): ErrorCode;

{ Give the request a body, whose length `Send` states. `errSyntax` for a body
  holding a null character: what crosses to the runtime is a C string, so a
  null would end it early and send a shorter body than the length said -- the
  one place this module's own boundary can lose data, refused rather than
  risked. }
function SetBody(var q: Request; body: RequestBody): ErrorCode;

{ --- the grammar, without a transport ------------------------------------- }

{ **This is the half of this module that touches nothing.** RFC 9112 framed
  HTTP/1.1 as lines, and the four routines below turn a `Request` into the
  octets to write and a sequence of lines back into a `Response` -- without
  reading or writing anything themselves. `Send` and `Receive` below are
  written over them and are all this module does with a `PasNet.Socket`, so a
  second transport is a second pair of routines and not a second parser.

  `lib/dialect/pashttps.pas` is that second pair, over `PasTls.Connection`.
  The alternative was a transport this module chose between, which would have
  meant importing `PasTls` here -- and then every program using HTTP would
  link a cryptography library it never asked for (ADR-0265). }

{ Begin writing `q`. `errSyntax` where no `Host` field was added (RFC 9112
  §3.2) or the request was never begun -- refused before an octet is written,
  so a refused request puts nothing on a connection the caller may still want.

  `Connection: close` and `Content-Length` are decided here unless the caller
  wrote one of its own, which is how the framing this module states stays true
  without taking the choice away from a caller who knows better. }
function BeginRequest(protected var q: Request; var w: RequestCursor):
  ErrorCode;

{ The next octets of the request, as many as `piece` holds. `w.done` when
  there are none left, which is the loop's condition.

  It cannot fail. A piece longer than `piece` spans calls, so a caller with a
  one-character buffer sends the same request in more writes -- which is why
  `PieceMax` is a fact about a request and not a demand on a caller. }
procedure NextPiece(protected var q: Request; var w: RequestCursor;
                    var piece: string);

{ Begin reading a response into `r`. The method is a parameter because
  RFC 9112 §6.3 makes the framing a property of the exchange and not of the
  response alone: a response to HEAD carries the header fields of a body it
  does not send, and reading one as though it had a body would block until the
  far end closed. }
procedure BeginResponse(var r: Response; method: MethodName);

{ Does the reader want another line? False once the message is complete, by
  whichever of RFC 9112 §6.3's rules framed it. }
function WantsLine(protected var r: Response): boolean;

{ Give it the next line, without its terminator. The codes are `Receive`'s and
  mean what they mean there; a line fed after the message is complete is
  ignored. }
function FeedLine(var r: Response; line: HttpPiece): ErrorCode;

{ Tell it the far end closed and there are no more lines.

  Which of RFC 9112 §6.3's rules was in force decides what that means, and the
  three answers are the point of this being a routine of its own: before a
  status-line it is `errAbsent`, there being no response rather than a bad
  one; inside the header section or a chunked body it is `errSyntax`, a
  message that stopped in the middle of itself; and in an uncounted body it is
  rule 6 working exactly as intended, `errNone` with `byClose` set. }
function FeedEnd(var r: Response): ErrorCode;

{ --- the exchange --------------------------------------------------------- }

{ Write the request over a plain socket: `BeginRequest` and then `NextPiece`
  until it is done. `errSyntax` for what `BeginRequest` refuses, `errIO` where
  the socket did. }
function Send(var s: Socket; protected var q: Request): ErrorCode;

{ Read a response from a plain socket into `r`: `BeginResponse`, then a line
  at a time through `FeedLine` while `WantsLine`, and `FeedEnd` when the far
  end closes. The method is `BeginResponse`'s and is a parameter for the
  reason given there. }
function Receive(var s: Socket; method: MethodName;
                 var r: Response): ErrorCode;

{ `Send` and then `Receive`, for the caller that has both halves to hand.

  It is two routines and not one because a program that is both ends of the
  connection -- which is the only way to test this without a network -- has to
  put the server's answer between them. }
function Exchange(var s: Socket; protected var q: Request;
                  var r: Response): ErrorCode;

{ --- reading a response --------------------------------------------------- }

{ The value of the first field of this name, matched without regard to case,
  or nil where there is none. }
function Header(protected var r: Response;
                name: HeaderName): OptHeaderValue;

{ The same, with the caller's own answer where the field is absent -- the
  `XOr` shape lib/dialect/README.md fixes the name of. }
function HeaderOr(protected var r: Response; name: HeaderName;
                  whenAbsent: HeaderValue): HeaderValue;

{ The body's lines joined with one line feed between each pair, into `dest`,
  which may be a string of any capacity. `errFull` where the whole does not
  fit, and `dest` is then untouched: a caller that got half a body and no word
  about it is the outcome this module exists to avoid. }
function BodyInto(protected var r: Response; var dest: string): ErrorCode;

end;

{ --- text, none of it exported -------------------------------------------- }

{ Lower case, over the ASCII letters and nothing else. RFC 9110 §5.1's
  case-insensitivity is defined over a field name, which §5.6.2 makes a token,
  which is ASCII -- so there is no locale here and no call on PasUnicode. }
function Fold(s: NetLine): NetLine;
var t: NetLine; i: integer;
begin
  t := '';
  for i := 1 to length(s) do
    if (s[i] >= 'A') and then (s[i] <= 'Z') then
      t := t + chr(ord(s[i]) - ord('A') + ord('a'))
    else
      t := t + s[i];
  Fold := t
end;

{ RFC 9110 §5.6.2's tchar. }
function IsTokenChar(c: char): boolean;
begin
  IsTokenChar := ((c >= 'a') and (c <= 'z')) or ((c >= 'A') and (c <= 'Z'))
                 or ((c >= '0') and (c <= '9'))
                 or (c = '!') or (c = '#') or (c = '$') or (c = '%')
                 or (c = '&') or (c = '''') or (c = '*') or (c = '+')
                 or (c = '-') or (c = '.') or (c = '^') or (c = '_')
                 or (c = '`') or (c = '|') or (c = '~')
end;

{ A token: one or more tchar and nothing else. }
function IsToken(s: NetLine): boolean;
var i: integer; ok: boolean;
begin
  ok := length(s) > 0;
  for i := 1 to length(s) do
    if not IsTokenChar(s[i]) then ok := false;
  IsToken := ok
end;

{ A field value: RFC 9110 §5.5 admits printable characters and horizontal tab
  and nothing else. The characters this refuses are the ones that would end
  the line and begin another, which is what makes it a check and not a
  nicety. }
function IsFieldText(s: NetLine): boolean;
var i: integer; ok: boolean;
begin
  ok := true;
  for i := 1 to length(s) do
    if (ord(s[i]) < 32) and (s[i] <> HT) then ok := false
    else if ord(s[i]) = 127 then ok := false;
  IsFieldText := ok
end;

{ A request-target: RFC 9112 §3 puts it between two spaces on the request
  line, so a space in it would make a different request and a control
  character a different message. }
function IsTarget(s: NetLine): boolean;
var i: integer; ok: boolean;
begin
  ok := length(s) > 0;
  for i := 1 to length(s) do
    if (ord(s[i]) <= 32) or (ord(s[i]) = 127) then ok := false;
  IsTarget := ok
end;

{ RFC 9112 §5's OWS -- the spaces and tabs around a field value, which are not
  part of it. }
function TrimOWS(s: NetLine): NetLine;
var a, b: integer; t: NetLine;
begin
  a := 1;
  b := length(s);
  while (a <= b) and then ((s[a] = ' ') or (s[a] = HT)) do a := a + 1;
  while (b >= a) and then ((s[b] = ' ') or (s[b] = HT)) do b := b - 1;
  if a > b then t := '' else t := substr(s, a, b - a + 1);
  TrimOWS := t
end;

function IsDigit(c: char): boolean;
begin
  IsDigit := (c >= '0') and (c <= '9')
end;

{ A non-negative decimal number, and whether the whole string was one. The
  overflow test comes before the multiply and not after it: integer `*` is
  checked here (ADR-0014) and stops the program, so a `Content-Length` of
  forty digits has to be refused rather than detected. }
function ParseDigits(s: NetLine; var v: integer): boolean;
var i, d, n: integer; ok: boolean;
begin
  n := 0;
  ok := length(s) > 0;
  for i := 1 to length(s) do begin
    if not IsDigit(s[i]) then ok := false;
    if ok then begin
      d := ord(s[i]) - ord('0');
      if n > (maxint - d) div 10 then ok := false else n := n * 10 + d
    end
  end;
  if not ok then n := 0;
  v := n;
  ParseDigits := ok
end;

{ The same for RFC 9112 §7.1's chunk-size, which is hexadecimal. }
function ParseHex(s: NetLine; var v: integer): boolean;
var i, d, n: integer; ok: boolean; c: char;
begin
  n := 0;
  ok := length(s) > 0;
  for i := 1 to length(s) do begin
    c := s[i];
    d := -1;
    if IsDigit(c) then d := ord(c) - ord('0')
    else if (c >= 'a') and then (c <= 'f') then d := ord(c) - ord('a') + 10
    else if (c >= 'A') and then (c <= 'F') then d := ord(c) - ord('A') + 10;
    if d < 0 then ok := false;
    if ok then
      if n > (maxint - d) div 16 then ok := false else n := n * 16 + d
  end;
  if not ok then n := 0;
  v := n;
  ParseHex := ok
end;

{ --- building a request --------------------------------------------------- }

function NewRequest;
begin
  q.method := '';
  q.target := '';
  q.count := 0;
  q.hasBody := false;
  q.body := '';
  if not IsToken(method) then NewRequest := errSyntax
  else if not IsTarget(target) then NewRequest := errSyntax
  else begin
    q.method := method;
    q.target := target;
    NewRequest := errNone
  end
end;

function AddHeader;
var k: integer;
begin
  if not IsToken(name) then AddHeader := errSyntax
  else if not IsFieldText(val) then AddHeader := errSyntax
  else if q.count = MaxHeaders then AddHeader := errFull
  else begin
    k := q.count + 1;
    q.field[k].name := name;
    q.field[k].fold := Fold(name);
    q.field[k].val := val;
    q.count := k;
    AddHeader := errNone
  end
end;

function SetBody;
var i: integer; ok: boolean;
begin
  ok := true;
  for i := 1 to length(body) do
    if body[i] = chr(0) then ok := false;
  if not ok then SetBody := errSyntax
  else begin
    q.body := body;
    q.hasBody := true;
    SetBody := errNone
  end
end;

{ --- writing: the grammar ------------------------------------------------- }

{ Piece `i` of the request, and false where there is none.

  The pieces are the start-line, one per field the caller added, then whichever
  of `Connection` and `Content-Length` this module supplies, then the empty
  line RFC 9112 §2.1 ends the header section with, then the body -- which
  carries no terminator of its own and is why the last piece is not a line.

  `w` is read and not written: which of the two optional pieces are there was
  decided once, by `BeginRequest`, so this is a pure function of the request
  and the index. }
function PieceText(protected var q: Request; protected var w: RequestCursor;
                   i: integer; var s: HttpPiece): boolean;
var num: string(12); j: integer;
begin
  PieceText := true;
  if i = 1 then s := q.method + ' ' + q.target + ' HTTP/1.1' + CRLF
  else if i <= 1 + q.count then begin
    j := i - 1;
    s := q.field[j].name + ': ' + q.field[j].val + CRLF
  end
  else begin
    { The trailing pieces, numbered from 1 with the absent ones skipped
      rather than left as holes -- a hole would make `NextPiece`'s "advance
      until something comes out" loop the place this knowledge lived. }
    j := i - 1 - q.count;
    if w.addConn then
      if j = 1 then begin
        s := 'Connection: close' + CRLF;
        exit(true)
      end
      else j := j - 1;
    if w.addLength then
      if j = 1 then begin
        writestr(num, length(q.body):1);
        s := 'Content-Length: ' + num + CRLF;
        exit(true)
      end
      else j := j - 1;
    if j = 1 then s := CRLF
    else if (j = 2) and q.hasBody then s := q.body
    else PieceText := false
  end
end;

function BeginRequest;
var k: integer; haveHost, haveLength, haveConn: boolean;
begin
  haveHost := false;
  haveLength := false;
  haveConn := false;
  for k := 1 to q.count do begin
    if q.field[k].fold = 'host' then haveHost := true;
    if q.field[k].fold = 'content-length' then haveLength := true;
    if q.field[k].fold = 'connection' then haveConn := true
  end;
  w.at := 1;
  w.off := 0;
  w.addConn := not haveConn;
  w.addLength := q.hasBody and (not haveLength);
  w.done := false;
  { A request nobody began, and a request with no authority (RFC 9112 §3.2).
    Refused here, which is before an octet has been produced. }
  if q.method = '' then begin
    w.done := true;
    exit(errSyntax)
  end;
  if not haveHost then begin
    w.done := true;
    exit(errSyntax)
  end;
  BeginRequest := errNone
end;

procedure NextPiece;
var cur: HttpPiece; room, n: integer;
begin
  piece := '';
  while (not w.done) and then (length(piece) < piece.capacity) do begin
    if not PieceText(q, w, w.at, cur) then w.done := true
    else begin
      room := piece.capacity - length(piece);
      n := length(cur) - w.off;
      if n > room then n := room;
      if n > 0 then piece := piece + substr(cur, w.off + 1, n);
      w.off := w.off + n;
      { A piece is finished when the cursor has passed its last character,
        which for an empty body is true at once -- so no piece can hold this
        loop up. }
      if w.off >= length(cur) then begin
        w.at := w.at + 1;
        w.off := 0
      end
    end
  end
end;

{ --- writing: over a socket ----------------------------------------------- }

function Send;
var
  { One write per bufferful rather than one per line: a request head arriving
    in eight packets is eight packets the far end reassembles for nothing, and
    `PasNet.WriteLine`'s comment gives the same reason for its own single
    call. The bufferful is what `NextPiece` fills, so the decision is the
    capacity of this variable and nothing else. }
  buf: NetLine;
  w: RequestCursor;
  e: ErrorCode;
begin
  e := BeginRequest(q, w);
  if Failed(e) then exit(e);
  while not w.done do begin
    NextPiece(q, w, buf);
    if length(buf) > 0 then begin
      e := WriteText(s, buf);
      if Failed(e) then exit(e)
    end
  end;
  Send := errNone
end;

{ --- reading -------------------------------------------------------------- }

{ RFC 9112 §4's status-line: the version, a space, three digits, and a
  reason-phrase which may be absent and may be empty. }
function ParseStatus(raw: NetLine; var r: Response): ErrorCode;
var ans: ErrorCode; rest: NetLine;
begin
  ans := errSyntax;
  if (length(raw) >= 12)
     and then (substr(raw, 1, 5) = 'HTTP/')
     and then IsDigit(raw[6]) and then (raw[7] = '.') and then IsDigit(raw[8])
     and then (raw[9] = ' ')
     and then IsDigit(raw[10]) and then IsDigit(raw[11])
     and then IsDigit(raw[12])
     and then ((length(raw) = 12) or else (raw[13] = ' ')) then begin
    r.status := (ord(raw[10]) - ord('0')) * 100
                + (ord(raw[11]) - ord('0')) * 10
                + (ord(raw[12]) - ord('0'));
    ans := errNone;
    if length(raw) > 13 then begin
      rest := substr(raw, 14, length(raw) - 13);
      if length(rest) > ReasonMax then ans := errFull else r.reason := rest
    end
  end;
  ParseStatus := ans
end;

{ RFC 9112 §5's field-line: a name, a colon with no space before it, and a
  value with its surrounding whitespace removed.

  A line beginning with a space or a tab is RFC 9112 §5.2's obs-fold, which a
  recipient of a response may either replace with a space or reject. This
  rejects: a folded value is a construct no HTTP/1.1 sender is allowed to
  produce, and accepting one would mean this module and the server disagreeing
  about where a field ends. It falls out of the rule above rather than needing
  a test of its own -- a space is not a tchar, so a folded line has no name. }
function ParseField(raw: NetLine; var r: Response): ErrorCode;
var ans: ErrorCode; i, colon, k: integer; nm: HeaderName; vl: NetLine;
begin
  colon := 0;
  for i := 1 to length(raw) do
    if (colon = 0) and (raw[i] = ':') then colon := i;
  ans := errNone;
  if colon < 2 then ans := errSyntax
  else if colon - 1 > HeaderNameMax then ans := errFull
  else begin
    nm := substr(raw, 1, colon - 1);
    if not IsToken(nm) then ans := errSyntax
    else begin
      if colon = length(raw) then vl := ''
      else vl := TrimOWS(substr(raw, colon + 1, length(raw) - colon));
      if length(vl) > HeaderValueMax then ans := errFull
      else if not IsFieldText(vl) then ans := errSyntax
      else if r.count = MaxHeaders then ans := errFull
      else begin
        k := r.count + 1;
        r.field[k].name := nm;
        r.field[k].fold := Fold(nm);
        r.field[k].val := vl;
        r.count := k
      end
    end
  end;
  ParseField := ans
end;

{ One more line of body, against the two bounds this module states. }
function AddBodyLine(var r: Response; raw: NetLine): ErrorCode;
begin
  if length(raw) > BodyLineMax then AddBodyLine := errFull
  else if r.bodyLines = MaxBodyLines then AddBodyLine := errFull
  else begin
    r.bodyLines := r.bodyLines + 1;
    r.body[r.bodyLines] := raw;
    AddBodyLine := errNone
  end
end;

{ Whether the last transfer coding is `chunked`, which is the only one this
  can decode (RFC 9112 §6.1). }
function LastIsChunked(v: HeaderValue): boolean;
var i, at: integer; t: NetLine;
begin
  at := 0;
  for i := 1 to length(v) do
    if v[i] = ',' then at := i;
  if at = 0 then t := v else t := substr(v, at + 1, length(v) - at);
  t := Fold(TrimOWS(t));
  LastIsChunked := t = 'chunked'
end;

{ --- reading: the grammar ------------------------------------------------- }

procedure BeginResponse;
begin
  r.status := 0;
  r.reason := '';
  r.count := 0;
  r.bodyLines := 0;
  r.stated := -1;
  r.chunked := false;
  r.byClose := false;
  r.phase := rpStatus;
  r.isHead := Fold(method) = 'head';
  r.got := 0;
  r.chunkSize := 0;
  r.chunkGot := 0
end;

function WantsLine;
begin
  WantsLine := r.phase <> rpDone
end;

{ The header section has ended: RFC 9112 §6.3 decides which framing is in
  force, and this is the one place in the reader where more than one clause is
  in play at once. Everything it can refuse, it refuses here -- before a single
  octet of body has been counted as anything. }
function StartBody(var r: Response): ErrorCode;
var te: OptHeaderValue; i, n: integer; seenLength, hasBody: boolean;
begin
  { RFC 9112 §6.1: a response whose final transfer coding is not `chunked` is
    one this client cannot frame or decode, and guessing is what that clause's
    note about request smuggling is written against. }
  te := Header(r, 'transfer-encoding');
  if te <> nil then
    if LastIsChunked(te^) then r.chunked := true
    else exit(errSyntax);

  seenLength := false;
  for i := 1 to r.count do
    if r.field[i].fold = 'content-length' then begin
      if not ParseDigits(r.field[i].val, n) then exit(errSyntax);
      { RFC 9112 §6.3 rule 4: two values that disagree is a message no
        recipient may guess at. }
      if seenLength and (n <> r.stated) then exit(errSyntax);
      seenLength := true;
      r.stated := n
    end;
  { RFC 9112 §6.1: a sender must not send both, and a recipient that picks one
    is the half of a request-smuggling pair that reads it the other way. }
  if r.chunked and seenLength then exit(errSyntax);

  { RFC 9112 §6.3 rule 1: a response to HEAD, and any 1xx, 204 or 304, has no
    body whatever its fields say -- and the fields do say, which is the point
    of asking the method at all. }
  hasBody := not (r.isHead or (r.status < 200)
                  or (r.status = 204) or (r.status = 304));
  if not hasBody then r.phase := rpDone
  else if r.chunked then r.phase := rpChunkSize
  else if r.stated = 0 then r.phase := rpDone
  else r.phase := rpCounted;
  StartBody := errNone
end;

{ A chunk-size line: RFC 9112 §7.1.1's chunk-ext is read past and not kept, no
  extension being registered and a recipient being free to ignore them. }
function TakeChunkSize(var r: Response; line: HttpPiece): ErrorCode;
var head: NetLine; i, at, size: integer;
begin
  { **An empty line before a chunk-size is skipped**, and it is not laxity.
    Each chunk ends with a CRLF of its own, which the line reading either
    consumed as the terminator of the chunk's last line or did not, depending
    on how that line itself ended -- and the two cases are not distinguishable
    from this side of a line-oriented transport. Skipping absorbs exactly that
    difference. }
  if length(line) = 0 then exit(errNone);
  at := 0;
  for i := 1 to length(line) do
    if (at = 0) and (line[i] = ';') then at := i;
  if at = 0 then head := line else head := substr(line, 1, at - 1);
  head := TrimOWS(head);
  if not ParseHex(head, size) then exit(errSyntax);
  if size = 0 then
    { RFC 9112 §7.1.2's trailer section, read to its empty line and discarded:
      a trailer field is one the sender could not know until the body was
      written, and this module has no place to put one that a caller could
      tell apart from a header field. }
    r.phase := rpTrailer
  else begin
    r.chunkSize := size;
    r.chunkGot := 0;
    r.phase := rpChunkData
  end;
  TakeChunkSize := errNone
end;

function FeedLine;
var e: ErrorCode;
begin
  FeedLine := errNone;
  case r.phase of
    rpStatus: begin
      e := ParseStatus(line, r);
      if Failed(e) then begin
        r.phase := rpDone;
        exit(e)
      end;
      r.phase := rpFields
    end;
    rpFields:
      { RFC 9112 §2.1: fields, one to a line, until an empty one. }
      if length(line) = 0 then begin
        e := StartBody(r);
        if Failed(e) then begin
          r.phase := rpDone;
          exit(e)
        end
      end
      else begin
        e := ParseField(line, r);
        if Failed(e) then begin
          r.phase := rpDone;
          exit(e)
        end
      end;
    rpCounted: begin
      { A line is counted as its characters plus one for the terminator, which
        is the module heading's accounting and its stated limit. }
      e := AddBodyLine(r, line);
      if Failed(e) then begin
        r.phase := rpDone;
        exit(e)
      end;
      r.got := r.got + length(line) + 1;
      if (r.stated >= 0) and (r.got >= r.stated) then r.phase := rpDone
    end;
    rpChunkSize: begin
      e := TakeChunkSize(r, line);
      if Failed(e) then begin
        r.phase := rpDone;
        exit(e)
      end
    end;
    rpChunkData: begin
      e := AddBodyLine(r, line);
      if Failed(e) then begin
        r.phase := rpDone;
        exit(e)
      end;
      r.chunkGot := r.chunkGot + length(line) + 1;
      if r.chunkGot >= r.chunkSize then r.phase := rpChunkSize
    end;
    rpTrailer:
      if length(line) = 0 then r.phase := rpDone;
    { A line fed after the message is complete is ignored rather than
      refused: a caller driving this from a loop it also uses for the next
      response has nothing wrong with it to report. }
    rpDone:
  end
end;

function FeedEnd;
var was: ReadPhase;
begin
  was := r.phase;
  r.phase := rpDone;
  case was of
    { There is no response. It is not a malformed one. }
    rpStatus: FeedEnd := errAbsent;
    { The header section has to end with an empty line; a connection that
      closed inside it is a message that stopped in the middle of itself. }
    rpFields: FeedEnd := errSyntax;
    { RFC 9112 §6.3 rule 6: the body ends where the connection does, which is
      exact and is what `Connection: close` was sent to make true. }
    rpCounted: begin
      r.byClose := true;
      FeedEnd := errNone
    end;
    { Chunked framing says where the body ends, so a connection closing before
      it does is a message that was not what it said it was. }
    rpChunkSize, rpChunkData: begin
      r.byClose := true;
      FeedEnd := errSyntax
    end;
    rpTrailer: begin
      r.byClose := true;
      FeedEnd := errNone
    end;
    rpDone: FeedEnd := errNone
  end
end;

{ --- reading: over a socket ----------------------------------------------- }

function Receive;
var raw: NetLine; e: ErrorCode;
begin
  BeginResponse(r, method);
  while WantsLine(r) do begin
    e := ReadLine(s, raw);
    if e = errAbsent then e := FeedEnd(r)
    else if Failed(e) then exit(e)
    else e := FeedLine(r, raw);
    if Failed(e) then exit(e)
  end;
  Receive := errNone
end;

function Exchange;
var e: ErrorCode;
begin
  e := Send(s, q);
  if Failed(e) then exit(e);
  Exchange := Receive(s, q.method, r)
end;

{ --- reading a response --------------------------------------------------- }

function Header;
var i: integer; want: HeaderName; ans: OptHeaderValue;
begin
  ans := nil;
  want := Fold(name);
  for i := 1 to r.count do
    if (ans = nil) and (r.field[i].fold = want) then ans := r.field[i].val;
  Header := ans
end;

function HeaderOr;
var v: OptHeaderValue;
begin
  v := Header(r, name);
  if v = nil then HeaderOr := whenAbsent else HeaderOr := v^
end;

function BodyInto;
var i, total: integer; ans: ErrorCode;
begin
  total := 0;
  for i := 1 to r.bodyLines do begin
    if i > 1 then total := total + 1;
    total := total + length(r.body[i])
  end;
  if total > dest.capacity then ans := errFull
  else begin
    dest := '';
    for i := 1 to r.bodyLines do begin
      if i > 1 then dest := dest + chr(10);
      dest := dest + r.body[i]
    end;
    ans := errNone
  end;
  BodyInto := ans
end;

end.
