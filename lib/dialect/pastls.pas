{ PasTls -- a TLS connection, as a handshake that is verified and a line at a
  time.

  **This is the row `doc/roadmap.md` said could not be reached.** That entry
  gave two grounds and both were wrong. It said a TLS library's interface
  needs a foreign struct, which ADR-0185 refuses a library: OpenSSL's is
  opaque pointers throughout -- `SSL_CTX *`, `SSL *` -- which is AP 6.4.12's
  handle exactly, and nothing below declares a struct of any kind. And it said
  the runtime would have to link a cryptography library: the runtime links
  nothing, and adds nothing here. It is the **program** that links, through
  `AFTERSCHOOL_PASCAL_CFLAGS`, so a program using no TLS pays no OpenSSL. That
  is why this module is 6.7.7's `external` and not a `pasx_` in
  `runtime/pasrt_posix.c` (ADR-0264).

  **A caller cannot turn verification off.** There is no flag, no mode and no
  second entry point that skips it: every connection this module makes checks
  the chain to a trust anchor and checks that the certificate is for the host
  that was asked for, and answers `errIO` when either fails. A TLS client that
  verifies wrongly is worse than one that does not verify at all, because it
  reports a security property it has not got -- and the commonest way to get
  one is a flag someone set while debugging. What a caller may choose is
  *which anchors*: `Connect` uses the system's, `ConnectTrusting` uses one PEM
  file and nothing else. A self-signed certificate is its own anchor, so the
  self-signed case is `ConnectTrusting` with that certificate and not a hole
  in the rule.

  **What is checked, and what is therefore promised.** The peer must present a
  chain that verifies to an anchor; the chain must be valid *now*; and the
  identity must match `host` -- against the certificate's subjectAltName,
  which OpenSSL's `SSL_set1_host` does and which works for a name and for an
  address literal alike. TLS 1.2 is the floor. Nothing here checks revocation:
  neither CRLs nor OCSP, and a caller for whom that matters wants more than
  this module.

  **The name goes out twice and for two reasons.** `host` is the server-name
  indication, so a server holding many names knows which certificate to send
  (RFC 6066), *and* it is what the certificate is checked against. Only the
  first is skipped for an address literal, RFC 6066 §3 forbidding one there;
  the check is made either way.

  **A line at a time**, as `PasNet` is, and for the same reason -- but the
  buffer is Pascal here rather than C, because `SSL_read` is the read and this
  module may not add C. A slice of an ordinary `array [1..n] of char` is what
  crosses (6.7.7.7), so the buffering is thirty lines of this language and no
  translation unit.

  **The connection owns everything under it.** A `Connection` holds the TCP
  socket, the configuration and the session, all three handles, so the block
  that declared it closes all three when it ends (AP 6.4.12 NOTE 3) and
  neither can outlive the other. That is also why `Connect` takes the variable
  that will own the result rather than answering one: lib/dialect/README.md's
  third rule, and the only shape an affine type admits.

  **`reason` and `protocol` are for a caller to read.** An ErrorCode says
  which of six categories; OpenSSL says which of hundreds, and throwing that
  away would make every handshake failure the same sentence. Every other field
  belongs to this module and a caller assigns none of them.

  **What it is not.** There is no server side, no client certificate, no
  session resumption, no renegotiation and no `Wait` over several connections
  -- `PasNet.Wait` reads a descriptor and this module does not hand one out.
  `PasHttp` speaks to a `PasNet.Socket` and so still speaks plain HTTP only;
  making it speak both means splitting its grammar from its transport, which
  is a change to that module and not to this one.

  **This module is a binding** in lib/dialect/README.md's sense, and the only
  one whose far side is not the C library or this project's runtime. OpenSSL
  3.0 is the floor: `SSL_CTX_load_verify_file` is that release's, and the two
  `_ctrl` calls below are what this language can spell where the header offers
  a macro. }

module PasTls;

export PasTls = (TlsHostMax, TlsServiceMax, TlsLineMax, TlsReasonMax,
                 TlsProtocolMax, TlsTrustMax, TlsBufMax,
                 TlsHost, TlsService, TlsLine, TlsReason, TlsProtocol,
                 TrustPath, Connection,
                 Connect, ConnectTrusting, Close,
                 WriteText, WriteLine, ReadLine);

{ `PasNet` is imported **qualified** because five of its exported names are
  five of this module's: a TLS connection is read and written with the words
  a socket is, which is the property worth keeping and the reason the two
  cannot share a scope (ISO/IEC 10206:1991 §6.11.2). }
import PasError; PasNet qualified;

const
  { The bounds, each prefixed as `PasLsp`'s are and for the reason this
    module found: a program speaking HTTPS imports `PasHttp` too, and both
    modules have something they would call a `ReasonMax`. The types below are
    `Tls`-prefixed already; a constant that is not is a name a client cannot
    have back (ADR-0265).

    `PasNet`'s two, restated rather than imported: POSIX's
    HOST_NAME_MAX is 255 and a service is a name or a number written out.
    They are separate types so that a program using this module needs no
    name of `PasNet`'s, the socket underneath being none of its business. }
  TlsHostMax = 255;
  TlsServiceMax = 63;
  { What a line may be, and it is `PasNet.LineMax` deliberately: a program
    that reads a socket and a program that reads a TLS connection meet the
    same bound, so moving between them is not a rewrite. }
  TlsLineMax = 4096;
  { What the read buffer holds. A line longer than this is `errFull` and its
    characters are discarded, there being nowhere to keep them -- the same
    answer `PasNet` gives, from the same shape of buffer. }
  TlsBufMax = 4096;
  { OpenSSL's `ERR_error_string_n` writes a diagnostic of about this length;
    120 is the number its own documentation names as sufficient, and this is
    room for that and a sentence of this module's. }
  TlsReasonMax = 255;
  { `SSL_get_version` answers `TLSv1.3` and its siblings. }
  TlsProtocolMax = 15;
  { A path to a PEM file of trust anchors. }
  TlsTrustMax = 1023;

  { The two characters a line is terminated by, built with `chr` because
    §6.1.7 gives a character-string no escape (RFC 9112 §2.1's CRLF). }
  CR = chr(13);
  LF = chr(10);

type
  TlsHost = string(TlsHostMax);
  TlsService = string(TlsServiceMax);
  TlsLine = string(TlsLineMax);
  TlsReason = string(TlsReasonMax);
  TlsProtocol = string(TlsProtocolMax);
  TrustPath = string(TlsTrustMax);

  { The two opaque pointers OpenSSL's client interface is made of, each with
    the function that releases it (AP 6.4.12). Declared here rather than in
    the module-block because `Connection` below has a field of each; **not
    exported**, there being nothing a caller can do with one that this module
    has not already done.

    `SSL_free` before or after `SSL_CTX_free` is immaterial: `SSL_new` takes a
    reference on the context, so the context outlives the session whichever
    field the block releases first. Neither closes the descriptor --
    `SSL_set_fd` builds its BIO with BIO_NOCLOSE -- so `pasx_socket_close` is
    what closes it, and the order of those two does not matter either. }
  Context = handle external 'SSL_CTX_free';
  Session = handle external 'SSL_free';

  { `SSL_get_version` answers storage it owns; ADR-0123's optional is what
    copies it at the call site. Not exported for the same reason. }
  OptProtocol = ?TlsProtocol;


  { An open TLS connection.

    The first two fields are answers and a caller reads them: `reason` is what
    OpenSSL said about the last failure, the null-string when nothing has
    failed, and `protocol` is the version that was negotiated. Everything
    after them is this module's, and a caller assigns none of it -- there is
    nothing to be gained by it and a handle set to `nil` early closes a
    connection the next call will then report as refused. }
  Connection = record
    reason: TlsReason;
    protocol: TlsProtocol;
    sock: PasNet.Socket;
    ctx: Context;
    ss: Session;
    { What has arrived and not been handed out: `buf[head..tail - 1]`. Empty
      when the two are equal, and both are 1 on a fresh connection. }
    head, tail: integer;
    buf: array [1..TlsBufMax] of char
  end;

{ Connect to `host` at `service` and complete a TLS handshake, verifying the
  peer against the anchors this system is configured with.

  `service` is `PasNet`'s: a name (`https`) or a number written out (`443`).

  `errAbsent` where neither `host` nor `service` resolved, `errIO` where the
  system refused the connection **or where verification did** -- and `reason`
  is what separates those two, which is why it is a field and not a sentence
  this module invents. What `c` held before is released first, whichever way
  this answers. }
function Connect(var c: Connection; host: TlsHost;
                 service: TlsService): ErrorCode;

{ The same, verifying against the certificates in `trust` and nothing else --
  not the system's anchors, which are not consulted at all.

  It is how a program reaches a service behind a private certificate
  authority, and how it reaches one presenting a self-signed certificate: such
  a certificate is its own anchor, so `trust` is that certificate's own PEM
  file. The host is still checked, so the certificate must name the host being
  asked for.

  `errAbsent` where `trust` could not be read -- a path that is not there is
  the commonest mistake here and it must not look like a rejection by the
  peer. }
function ConnectTrusting(var c: Connection; host: TlsHost;
                         service: TlsService;
                         trust: TrustPath): ErrorCode;

{ Close now rather than at the block's end, and leave `c` empty.

  A close-notify alert is sent first, which is what tells the far end that the
  data stream ended where this program meant it to. Letting the block end
  instead closes the three handles without one: the connection is released
  either way and no storage is lost, but the far end cannot then distinguish
  the end of the data from a connection that was cut. Harmless on a
  `Connection` that is already empty, and the variable may be connected
  again. }
procedure Close(var c: Connection);

{ The characters of `text`, nothing appended. `errIO` on a refusal, which
  includes the far end having closed. }
function WriteText(var c: Connection; text: TlsLine): ErrorCode;

{ The characters and then CRLF, which is the terminator every line-oriented
  protocol over TLS uses -- unlike `PasNet.WriteLine`, whose newline is a
  Pascal one. }
function WriteLine(var c: Connection; text: TlsLine): ErrorCode;

{ The next line into `line`, without its terminator, and with a carriage
  return immediately before the newline removed.

  `errNone` and `line` holds it; `errAbsent` when the far end closed and
  nothing was left, which is the ordinary end of a loop; `errFull` for a line
  longer than `line` can hold or longer than `TlsBufMax`, whose characters are
  discarded; `errIO` for a refusal. A final line the far end sent without a
  terminator **is** a line.

  `line` is the null-string on every answer but `errNone`. }
function ReadLine(var c: Connection; var line: string): ErrorCode;

end;

{ ------------------------------------------------------------------------
  The directive, kept to this module.

  These are OpenSSL's, and OpenSSL is not linked into anything this repository
  builds: a program that imports this module is linked with `-lssl -lcrypto`
  and every other program is not. 6.7.7.10 reserves nothing here -- the
  reserved names are this processor's own, and `pasx_socket_fd` below is the
  runtime's, which 6.7.7.11 lets this component declare although `PasNet`
  declares it too (ADR-0263). }

const
  { The header constants this language cannot reach, because each is a macro
    over `SSL_ctrl` or a bare `#define`. `tests/checks/tls.sh` compiles a C
    program including OpenSSL's own headers and compares every one of these
    against what the header says, so a value transcribed wrongly -- or a
    value OpenSSL changes -- fails a gate rather than a handshake. }
  CtrlSetHostName = 55;    { SSL_CTRL_SET_TLSEXT_HOSTNAME }
  NameTypeHost = 0;        { TLSEXT_NAMETYPE_host_name }
  CtrlSetMinProto = 123;   { SSL_CTRL_SET_MIN_PROTO_VERSION }
  VersionTls12 = 771;      { TLS1_2_VERSION, 0x0303 }
  VerifyPeer = 1;          { SSL_VERIFY_PEER }
  VerifyOk = 0;            { X509_V_OK }
  ErrorZeroReturn = 6;     { SSL_ERROR_ZERO_RETURN -- a clean close }
  ErrorSyscall = 5;        { SSL_ERROR_SYSCALL -- one of which is also one }

{ The descriptor, for `SSL_set_fd`. `PasNet` keeps this to itself for
  ADR-0203's reason -- a program holding a descriptor could close it twice --
  and the reason holds here: it lives inside one statement and is never a
  value of anything exported. }
function ExtFd(s: PasNet.Socket): integer; external 'pasx_socket_fd';

{ The client's half of OpenSSL. `TLS_client_method` answers a pointer to
  static storage which is only ever handed straight back to `SSL_CTX_new`, so
  6.7.7.9 c)'s `int64` is what it crosses as and nothing keeps it. }
function ClientMethod: int64; external 'TLS_client_method';
function CtxNew(method: int64): Context; external 'SSL_CTX_new';

{ Verification. `SSL_CTX_set_verify` takes a callback and this language has
  none to give (6.7.7.9 b), so the null pointer crosses as `int64` 0 -- which
  is the value that asks OpenSSL for its own, and the one a C program writes
  as well. With SSL_VERIFY_PEER set the handshake itself fails on a bad
  chain, which is what makes the check impossible to forget rather than
  something the caller must remember to ask about afterwards. }
procedure CtxSetVerify(c: Context; mode: integer; callback: int64);
  external 'SSL_CTX_set_verify';
function CtxDefaultAnchors(c: Context): integer;
  external 'SSL_CTX_set_default_verify_paths';
function CtxTrustFile(c: Context; path: string): integer;
  external 'SSL_CTX_load_verify_file';

{ The protocol floor. `SSL_CTX_set_min_proto_version` is a macro over this,
  and `parg` is not read by that command -- the null-string is what this
  language can put in a `void *` position, 6.7.7.5 making it the address of a
  NUL-terminated copy. }
function CtxCtrl(c: Context; cmd: integer; larg: int64; parg: string): int64;
  external 'SSL_CTX_ctrl';

function SslNew(c: Context): Session; external 'SSL_new';

{ Server-name indication. `SSL_set_tlsext_host_name` is a macro over this, and
  here `parg` *is* read: it is the name, and 6.7.7.5's NUL-terminated copy is
  exactly what the far side wants. }
function SslCtrl(s: Session; cmd: integer; larg: int64; parg: string): int64;
  external 'SSL_ctrl';

{ The identity to check the certificate against. Answers 1 when it was set,
  and a name it cannot use is a refusal here rather than a check that quietly
  passes later. }
function SslSetHost(s: Session; name: string): integer;
  external 'SSL_set1_host';

function SslSetFd(s: Session; fd: integer): integer; external 'SSL_set_fd';
function SslConnect(s: Session): integer; external 'SSL_connect';
function SslShutdown(s: Session): integer; external 'SSL_shutdown';
function SslVerifyResult(s: Session): int64;
  external 'SSL_get_verify_result';
function SslVersion(s: Session): OptProtocol; external 'SSL_get_version';

{ `SSL_write` is handed the NUL-terminated copy 6.7.7.5 makes and a count of
  its characters, so no buffer of this module's is involved; `SSL_read` is
  handed a slice of the buffer below, which crosses as an address and a length
  the compiler computed and checked (6.7.7.7). }
function SslWrite(s: Session; text: string; n: integer): integer;
  external 'SSL_write';
function SslRead(s: Session; var b: array of char; n: integer): integer;
  external 'SSL_read';

{ Which kind of failure a non-positive result was. }
function SslError(s: Session; ret: integer): integer; external 'SSL_get_error';

{ What OpenSSL has to say, one entry at a time. `ERR_error_string_n` takes a
  buffer and a length, which is 6.7.7.7's order exactly, so a slice is what
  crosses and the length is one this compiler computed. }
function ErrTake: int64; external 'ERR_get_error';
procedure ErrString(e: int64; var b: array of char);
  external 'ERR_error_string_n';

{ ------------------------------------------------------------------------ }

{ Whatever OpenSSL last complained about, as a sentence, and the queue drained
  behind it -- an entry left there would be reported against the next failure,
  which is how a diagnostic comes to name something that did not happen.

  `whenQuiet` is what to say when the queue is empty, which it is whenever the
  refusal was the system's rather than the library's. }
function Complaint(whenQuiet: TlsReason): TlsReason;
var
  b: array [1..TlsReasonMax + 1] of char;
  e, last: int64;
  i: integer;
  t: TlsReason;
begin
  last := 0;
  repeat
    e := ErrTake;
    if e <> 0 then last := e
  until e = 0;
  if last = 0 then exit(whenQuiet);
  for i := 1 to TlsReasonMax + 1 do b[i] := chr(0);
  ErrString(last, b);
  t := '';
  i := 1;
  while (i <= TlsReasonMax) and (b[i] <> chr(0)) do begin
    t := t + b[i];
    i := i + 1
  end;
  if t = '' then Complaint := whenQuiet else Complaint := t
end;

{ Is `host` an address literal rather than a name? RFC 6066 §3 forbids one in
  the server-name indication, so this is what decides whether the extension is
  sent -- and nothing else, the certificate being checked against `host`
  either way. A colon makes it IPv6; otherwise it is IPv4 exactly when every
  character is a digit or a point. }
function IsAddressLiteral(host: TlsHost): boolean;
var i: integer; onlyDigits: boolean;
begin
  if host = '' then exit(false);
  onlyDigits := true;
  for i := 1 to length(host) do begin
    if host[i] = ':' then exit(true);
    if not (((host[i] >= '0') and (host[i] <= '9')) or (host[i] = '.')) then
      onlyDigits := false
  end;
  IsAddressLiteral := onlyDigits
end;

procedure Close;
var k: integer;
begin
  if c.ss <> nil then begin
    { The first call sends close-notify and answers 0 when the far end's has
      not arrived; a second would wait for it. One is what the protocol
      requires of this end, and waiting is what a caller did not ask for --
      so the result is read into a variable and dropped, there being nothing
      a close can do about a refusal to close. }
    k := SslShutdown(c.ss);
    if k < 0 then c.reason := Complaint('the shutdown was refused');
    c.ss := nil
  end;
  c.ctx := nil;
  PasNet.Close(c.sock);
  c.head := 1;
  c.tail := 1;
  c.protocol := ''
end;

{ The two entry points differ in one call, so the work is here and `trust` of
  the null-string means the system's anchors. It is a private routine rather
  than a parameter of an exported one because a caller that may pass `''`
  is a caller that may pass it by accident, and the whole of this module's
  claim is that there is no way to ask for less. }
function Establish(var c: Connection; host: TlsHost; service: TlsService;
                   trust: TrustPath): ErrorCode;
var e: ErrorCode; k: integer; got: OptProtocol;
begin
  Close(c);
  c.reason := '';
  c.protocol := '';
  c.head := 1;
  c.tail := 1;

  e := PasNet.Connect(c.sock, host, service);
  if Failed(e) then begin
    c.reason := 'the connection could not be made';
    exit(e)
  end;

  c.ctx := CtxNew(ClientMethod);
  if c.ctx = nil then begin
    c.reason := Complaint('no TLS context could be made');
    PasNet.Close(c.sock);
    exit(errIO)
  end;
  CtxSetVerify(c.ctx, VerifyPeer, 0);
  if CtxCtrl(c.ctx, CtrlSetMinProto, VersionTls12, '') <> 1 then begin
    c.reason := Complaint('TLS 1.2 could not be set as the floor');
    Close(c);
    exit(errIO)
  end;

  if trust = '' then k := CtxDefaultAnchors(c.ctx)
  else k := CtxTrustFile(c.ctx, trust);
  if k <> 1 then begin
    if trust = '' then begin
      c.reason := Complaint('this system has no trust anchors configured');
      Close(c);
      exit(errIO)
    end;
    { A named file that cannot be read is `errAbsent` and not `errIO`: it is
      this program's own mistake and not the peer's, and the two must not
      arrive as one code. }
    c.reason := Complaint('the trust file could not be read');
    Close(c);
    exit(errAbsent)
  end;

  c.ss := SslNew(c.ctx);
  if c.ss = nil then begin
    c.reason := Complaint('no TLS session could be made');
    Close(c);
    exit(errIO)
  end;
  if not IsAddressLiteral(host) then
    if SslCtrl(c.ss, CtrlSetHostName, NameTypeHost, host) <> 1 then begin
      c.reason := Complaint('the server name could not be indicated');
      Close(c);
      exit(errIO)
    end;
  if SslSetHost(c.ss, host) <> 1 then begin
    c.reason := Complaint('the host could not be checked for');
    Close(c);
    exit(errIO)
  end;
  if SslSetFd(c.ss, ExtFd(c.sock)) <> 1 then begin
    c.reason := Complaint('the connection could not carry TLS');
    Close(c);
    exit(errIO)
  end;

  if SslConnect(c.ss) <> 1 then begin
    c.reason := Complaint('the handshake was refused');
    Close(c);
    exit(errIO)
  end;
  { SSL_VERIFY_PEER has already failed the handshake on a bad chain, so
    **nothing reaches this arm** and no case in this repository covers it.
    That is said here rather than argued away: it costs one call, the property
    it states is the one this module exists for, and the two together are what
    keep the guarantee from resting on a single call to a library this
    processor does not translate (ADR-0264). }
  if SslVerifyResult(c.ss) <> VerifyOk then begin
    c.reason := Complaint('the certificate was not accepted');
    Close(c);
    exit(errIO)
  end;

  got := SslVersion(c.ss);
  if got <> nil then c.protocol := got^;
  Establish := errNone
end;

function Connect;
begin
  Connect := Establish(c, host, service, '')
end;

function ConnectTrusting;
begin
  ConnectTrusting := Establish(c, host, service, trust)
end;

function WriteText;
var n: integer;
begin
  if c.ss = nil then begin
    c.reason := 'the connection is not open';
    exit(errIO)
  end;
  n := length(text);
  if n = 0 then exit(errNone);
  { `SSL_write` writes all of it or fails: OpenSSL's default is
    SSL_MODE_ENABLE_PARTIAL_WRITE off, so a positive result is the whole
    length and there is no loop to write here. }
  if SslWrite(c.ss, text, n) <> n then begin
    c.reason := Complaint('the write was refused');
    exit(errIO)
  end;
  WriteText := errNone
end;

function WriteLine;
begin
  WriteLine := WriteText(c, text + CR + LF)
end;

{ Move what is held down to the front, so a read can use the whole buffer. }
procedure Compact(var c: Connection);
var i, n: integer;
begin
  if c.head = 1 then exit;
  n := c.tail - c.head;
  for i := 1 to n do c.buf[i] := c.buf[c.head + i - 1];
  c.head := 1;
  c.tail := n + 1
end;

{ `buf[from..to]` as a line, once the terminator has been accounted for. }
function Take(var c: Connection; var line: string; count: integer): boolean;
var i: integer;
begin
  if count > line.capacity then exit(false);
  line := '';
  for i := 1 to count do line := line + c.buf[c.head + i - 1];
  Take := true
end;

function ReadLine;
var p, count, n, k: integer;
begin
  line := '';
  if c.ss = nil then begin
    c.reason := 'the connection is not open';
    exit(errIO)
  end;
  repeat
    { A newline in what is held? }
    p := c.head;
    while (p < c.tail) and (c.buf[p] <> LF) do p := p + 1;
    if p < c.tail then begin
      count := p - c.head;
      if (count > 0) and (c.buf[c.head + count - 1] = CR) then
        count := count - 1;
      if not Take(c, line, count) then begin
        c.head := p + 1;
        c.reason := 'the line did not fit';
        exit(errFull)
      end;
      c.head := p + 1;
      exit(errNone)
    end;

    Compact(c);
    if c.tail > TlsBufMax then begin
      { Nothing was found in a full buffer, so the line is longer than
        anything this can hold and its characters are gone. }
      c.head := 1;
      c.tail := 1;
      c.reason := 'the line was longer than the buffer';
      exit(errFull)
    end;

    n := SslRead(c.ss, c.buf[c.tail..TlsBufMax], TlsBufMax - c.tail + 1);
    if n <= 0 then begin
      count := c.tail - c.head;
      if count > 0 then begin
        { A last line with no terminator is a line. }
        if not Take(c, line, count) then begin
          c.head := c.tail;
          c.reason := 'the line did not fit';
          exit(errFull)
        end;
        c.head := c.tail;
        exit(errNone)
      end;
      k := SslError(c.ss, n);
      if (k = ErrorZeroReturn) or (k = ErrorSyscall) then begin
        { A close-notify, or a connection the far end simply dropped. Both
          are the end of the data and neither is a failure a caller acts on;
          `reason` is what separates them for a caller that cares. }
        if k = ErrorZeroReturn then c.reason := ''
        else c.reason := Complaint('the far end closed without a shutdown');
        exit(errAbsent)
      end;
      c.reason := Complaint('the read was refused');
      exit(errIO)
    end;
    c.tail := c.tail + n
  until false
end;

end.
