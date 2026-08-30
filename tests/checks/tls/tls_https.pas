{ `PasHttps`: `PasHttp`'s grammar over `PasTls`'s transport, against a real
  server.

  **This is the whole of what the split had to prove.** `lib_http_grammar.pas`
  shows the grammar has no transport under it, and `lib_http.pas` shows the
  socket transport still works; what neither can show is that a *second*
  transport needs nothing of the parser. Here one does: `PasHttps.Exchange` is
  twelve lines over `PasHttp.BeginRequest`, `NextPiece`, `BeginResponse`,
  `WantsLine`, `FeedLine` and `FeedEnd`, and the response below was parsed by
  the same routines `lib_http.pas` drives over a plain socket (ADR-0265).

  **Nothing OpenSSL wrote is printed**, as in `tls_probe.pas`: `s_server`'s
  status page lists the ciphers it was built with and its reason-phrase is its
  own. What is printed is the status code, the framing this module worked out,
  and whether a body arrived at all. }
program tls_https(input, output);

import PasError;
       PasTls;
       PasHttp;
       PasHttps qualified;

var
  c: Connection;
  q: Request;
  r: Response;
  port: TlsService;
  cert: TrustPath;
  e: ErrorCode;
  ct: OptHeaderValue;

begin
  readln(port);
  readln(cert);

  e := ConnectTrusting(c, 'localhost', port, cert);
  writeln('connected     : ', ErrorText(e));
  if Failed(e) then exit;

  e := NewRequest(q, 'GET', '/');
  e := AddHeader(q, 'Host', 'localhost');
  e := PasHttps.Exchange(c, q, r);
  writeln('exchanged     : ', ErrorText(e));
  if Failed(e) then exit;

  { `s_server -www` answers HTTP/1.0 with no Content-Length, so RFC 9112
    §6.3's rule 6 frames the body: it ends where the connection does. That is
    the shape only `FeedEnd` completes, and it is the one a client that
    assumed a length would hang on. }
  writeln('  status      : ', r.status:1);
  writeln('  stated      : ', r.stated:1);
  writeln('  chunked     : ', r.chunked);
  writeln('  by close    : ', r.byClose);
  writeln('  body arrived: ', r.bodyLines > 0);
  ct := Header(r, 'CONTENT-TYPE');
  writeln('  content-type: ', ct <> nil);

  { A second exchange on the same connection is refused by the *server*,
    which sent `Connection: close` behaviour by closing -- so what this shows
    is that a spent connection reports rather than hanging. }
  e := NewRequest(q, 'GET', '/again');
  e := AddHeader(q, 'Host', 'localhost');
  e := PasHttps.Exchange(c, q, r);
  writeln('second exchange: ', ErrorText(e));

  Close(c);

  { And a request the grammar refuses costs no connection at all: nothing was
    written, so there is nothing on the wire to take back. }
  e := NewRequest(q, 'GET', '/');
  e := PasHttps.Send(c, q);
  writeln('no Host field : ', ErrorText(e))
end.
