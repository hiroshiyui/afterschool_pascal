{ What `PasTls` promises, asked of a real TLS server.

  **The reason this is a check and not a case under `tests/dialect/`.** It
  needs OpenSSL -- the library to link against and the `openssl` program to be
  the far end -- and neither is a documented dependency of this repository, so
  the harness has to be able to skip. A `.pas` case cannot: `run_test.sh`
  compiles and compares, and a machine without libssl would see a compilation
  failure and call it a defect. `tests/checks/tls.sh` is what decides, and it
  refuses to pass by skipping when `TLS_REQUIRE` is set.

  **Nothing printed here comes from OpenSSL.** A reason string is that
  library's wording and moves between releases, and so does the list of
  ciphers on the status page; a golden holding either would fail on an
  upgrade and say nothing about this module. So what is printed is what this
  module decided -- the code, whether a reason was recorded, and the shape of
  the protocol name -- and never the sentence itself.

  Two servers, because the two halves of verification need different
  certificates: one presents a certificate for `localhost`, the other a
  certificate for a name nobody asked for. Connecting to the second **by**
  `localhost` and trusting its own certificate is the case where the chain is
  perfect and the identity is wrong, which is the half a client that checks
  only the chain gets wrong. }
program tls_probe(input, output);

import PasError;
       PasTls;

var
  c: Connection;
  goodPort, badPort: TlsService;
  goodCert, badCert, missing: TrustPath;
  e: ErrorCode;
  line: TlsLine;
  short: string(8);
  n: integer;

{ `errNone`, or the name of the code -- never the sentence behind it. }
procedure Say(what: TlsLine; e: ErrorCode; reasonWanted: boolean);
begin
  write(what, ': ', ErrorText(e));
  if reasonWanted then
    if c.reason = '' then write(', with no reason recorded')
    else write(', with a reason')
  else if c.reason <> '' then write(', and a reason nobody asked for');
  writeln
end;

begin
  readln(goodPort);
  readln(badPort);
  readln(goodCert);
  readln(badCert);
  missing := goodCert + '.no-such-file';

  { 1. The system's anchors do not know a certificate made for this test, so
       the handshake must fail -- and it must fail with something to say. A
       client that accepted this would accept anything. }
  e := Connect(c, 'localhost', goodPort);
  Say('unknown anchor       ', e, true);

  { 2. The certificate itself as the anchor: the chain verifies and the name
       matches, so this is the connection. }
  e := ConnectTrusting(c, 'localhost', goodPort, goodCert);
  Say('own certificate      ', e, false);
  writeln('  protocol negotiated : ',
          (length(c.protocol) >= 7) and (c.protocol[1..6] = 'TLSv1.'));

  { 3. And it carries data. `s_server -WWW` answers a small file the harness
       wrote, so the body is this repository's and not OpenSSL's -- which is
       what lets the two cases below name what they expect. }
  e := WriteLine(c, 'GET /hello HTTP/1.0');
  Say('  request written    ', e, false);
  e := WriteLine(c, '');
  Say('  request ended      ', e, false);
  e := ReadLine(c, line);
  Say('  response read      ', e, false);
  writeln('  status line        : ', line[1..12]);

  { 4. A line longer than the caller's variable is `errFull` and not a
       truncation. The next line is `Content-type: text/plain`, longer than
       eight characters, and its characters are gone rather than
       half-delivered. }
  e := ReadLine(c, short);
  Say('  a line that is long', e, true);

  { 5. The far end closes when the page ends, which is the ordinary end of a
       loop and not a failure. }
  n := 0;
  repeat
    e := ReadLine(c, line);
    if e = errNone then n := n + 1
  until e <> errNone;
  writeln('  loop ended on      : ', ErrorText(e));
  writeln('  more lines followed: ', n > 0);

  { 6. Closing twice is harmless, and the variable may be connected again. }
  Close(c);
  Close(c);
  writeln('closed twice         : ok');

  { 7. The chain is perfect and the name is wrong: this is the case a client
       checking only the chain accepts, and it must be refused. }
  e := ConnectTrusting(c, 'localhost', badPort, badCert);
  Say('right chain, wrong name', e, true);

  { 8. A trust file that is not there is this program's own mistake and must
       not arrive as a rejection by the peer. }
  e := ConnectTrusting(c, 'localhost', goodPort, missing);
  Say('trust file absent    ', e, true);

  { 9. Nothing is listening on the service `1`, which is reserved and needs
       privilege even to bind. }
  e := ConnectTrusting(c, 'localhost', '1', goodCert);
  Say('nobody listening     ', e, true);

  { 10. A host that resolves to nothing. }
  e := ConnectTrusting(c, 'no-such-host.invalid', goodPort, goodCert);
  Say('host does not resolve', e, true);

  { 11. Reading or writing a connection that is not open is refused rather
        than being undefined. }
  e := WriteText(c, 'x');
  Say('write when closed    ', e, true);
  e := ReadLine(c, line);
  Say('read when closed     ', e, true);
  writeln('  line left empty    : ', line = '')
end.
