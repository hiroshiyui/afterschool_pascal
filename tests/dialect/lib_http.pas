{ PasHttp: an HTTP/1.1 exchange, over the loopback interface, in one program.

  **This is its own server, and it has to be.** `tests/dialect/lib_net.pas`
  gives the reason and it is stronger here: a test that reached a web site
  would be a test of that site, of the network, and of whatever proxy sat
  between -- and it would fail on a machine with no route out. So the program
  listens on whatever port is free, connects to itself, and writes the canned
  responses by hand with `PasNet.WriteText`. Every response below is therefore
  a **literal**, byte for byte what the client is asked to read, which is the
  only way a golden can say what was parsed.

  **Which is why `Send` and `Receive` are two routines.** One thread of
  control cannot be both ends of a request-and-response unless the two halves
  can be interleaved: the client writes, the server reads and answers, the
  client reads. Where the canned answer needs no request -- the malformed ones
  below, and the chunked one -- the server writes first and `Exchange` does
  both halves in one call, which a socket permits and a person would find
  odd. Both shapes are exercised on purpose.

  **What each block is for.** A 200 framed by `Content-Length`; a POST
  carrying a body, answered 404, which is where the field lookup is shown to
  ignore case and to keep a duplicate and an empty value apart; a 200 framed
  by `Transfer-Encoding: chunked`, with a chunk-extension and a chunk whose
  data runs to two lines; a 302, reported and not followed; a HEAD, whose
  response states a length it does not send; a body with no framing field at
  all, which ends at the close. Then the failures, which are the half that
  matters: a status-line that is not one, a field-line with no colon, a
  response framed both ways at once, a far end that closes without answering,
  and a body line longer than the module's own bound -- `errFull`, reported,
  rather than a truncation nobody hears about.

  No port number appears in the output, for `lib_net.pas`'s reason: the
  program asks for service `'0'` and a test that named a port would fail on a
  machine where something else held it. }
program lib_http(output);

import PasError;
       PasNet;
       PasHttp;

const
  { RFC 9112 §2.1's line terminator, which the canned responses below are
    written with. Built by `chr` because §6.1.7 gives a character-string no
    escape. }
  CRLF = chr(13) + chr(10);

var
  srv, cli, conn: Socket;
  port: ServiceName;
  q: Request;
  r: Response;
  e, e2: ErrorCode;
  line, long: NetLine;
  v: OptHeaderValue;
  joined: string(200);
  small: string(4);
  i: integer;

{ A fresh connection, both of whose ends this program holds. `srv` goes on
  listening: accepting does not consume the socket that accepted. }
procedure Pair;
begin
  e := Connect(cli, 'localhost', port);
  if Failed(e) then writeln('connect: ', ErrorText(e));
  e := Accept(srv, conn);
  if Failed(e) then writeln('accept: ', ErrorText(e))
end;

{ Both ends closed (AP 6.4.12.2's second form, ADR-0202). }
procedure Drop;
begin
  cli := nil;
  conn := nil
end;

{ The server reading the request head, to the empty line that ends it. This is
  what shows that `Send` wrote a request and what it put in it -- the request
  line, the caller's fields, and the `Connection: close` and `Content-Length`
  the module adds. }
procedure ShowRequest;
var l: NetLine; more: boolean;
begin
  more := true;
  while more do begin
    e := ReadLine(conn, l);
    if Failed(e) then begin
      writeln('  request: ', ErrorText(e));
      more := false
    end
    else if length(l) = 0 then
      more := false
    else
      writeln('  > ', l)
  end
end;

{ Everything the client made of the response. }
procedure Report;
var k: integer;
begin
  writeln('receive: ', ErrorText(e));
  if not Failed(e) then begin
    writeln('  status ', r.status:1, ' [', r.reason, ']');
    writeln('  fields ', r.count:1, ', stated ', r.stated:1,
            ', chunked ', r.chunked, ', byClose ', r.byClose);
    for k := 1 to r.count do
      writeln('    ', r.field[k].name, ' = [', r.field[k].val, ']');
    for k := 1 to r.bodyLines do
      writeln('    body ', k:1, ': [', r.body[k], ']')
  end
end;

begin
  { --- what a request refuses, which needs no socket -------------------- }

  writeln('--- forming a request');
  { RFC 9110 §9.1 makes a method a token: a space in one would put a second
    word on the request line. }
  e := NewRequest(q, 'GET SNEAKY', '/x');
  writeln('method with a space:  ', ErrorText(e));
  e := NewRequest(q, 'GET', '/a b');
  writeln('target with a space:  ', ErrorText(e));
  e := NewRequest(q, 'GET', '/ok');
  writeln('a GET of /ok:         ', ErrorText(e));
  e := AddHeader(q, 'Bad Name', 'v');
  writeln('field name with a space: ', ErrorText(e));
  { The one that is a security property and not a tidiness one: a value
    carrying CRLF would end the field and begin another. }
  e := AddHeader(q, 'X-Note', 'ok' + CRLF + 'Injected: yes');
  writeln('value carrying CRLF:  ', ErrorText(e));
  e := SetBody(q, 'a' + chr(0) + 'b');
  writeln('body carrying a null: ', ErrorText(e));
  e := AddHeader(q, 'Host', 'localhost');
  for i := 1 to MaxHeaders do
    e := AddHeader(q, 'X-Pad', 'v');
  writeln('past MaxHeaders:      ', ErrorText(e));
  { RFC 9112 §3.2 requires a Host field, so a request without one is refused
    before a byte of it is written. }
  e := NewRequest(q, 'GET', '/nohost');
  e := Send(cli, q);
  writeln('sending without Host: ', ErrorText(e));
  writeln;

  e := Listen(srv, 'localhost', '0');
  writeln('listen:  ', ErrorText(e));
  e := Service(srv, port);
  writeln('service: ', ErrorText(e), ', a port was given: ', port <> '');
  writeln;

  { --- a GET, answered 200 with Content-Length -------------------------- }

  writeln('--- GET, 200, Content-Length');
  Pair;
  e := NewRequest(q, 'GET', '/hello');
  e := AddHeader(q, 'Host', 'localhost');
  e := AddHeader(q, 'Accept', 'text/plain');
  e := Send(cli, q);
  writeln('send:    ', ErrorText(e));
  ShowRequest;
  e := WriteText(conn,
       'HTTP/1.1 200 OK' + CRLF +
       'Content-Type: text/plain' + CRLF +
       'Content-Length: 12' + CRLF + CRLF +
       'hello' + chr(10) + 'world' + chr(10));
  conn := nil;
  e := Receive(cli, 'GET', r);
  Report;
  { The count reached 12 before the close did, which is what `byClose` above
    reports as false. }
  cli := nil;
  writeln;

  { --- a POST with a body, answered 404 --------------------------------- }

  writeln('--- POST with a body, 404, and the field lookup');
  Pair;
  e := NewRequest(q, 'POST', '/submit');
  e := AddHeader(q, 'Host', 'localhost');
  e := AddHeader(q, 'Content-Type', 'application/x-www-form-urlencoded');
  e := SetBody(q, 'a=1&b=2' + chr(10));
  e := Send(cli, q);
  writeln('send:    ', ErrorText(e));
  ShowRequest;
  e := ReadLine(conn, line);
  writeln('  > (body) ', line);
  e := WriteText(conn,
       'HTTP/1.1 404 Not Found' + CRLF +
       'X-Empty:' + CRLF +
       'Set-Cookie: a=1' + CRLF +
       'Set-Cookie: b=2' + CRLF +
       'Content-Length: 0' + CRLF + CRLF);
  e := Receive(cli, 'POST', r);
  Report;
  { The status-code is the server's answer and the ErrorCode is the module's:
    a 404 arrived intact and nothing failed. }
  writeln('  a 404 is not a failure: ', not Failed(e));
  { RFC 9110 §5.1: a field name is case-insensitive. }
  writeln('  set-COOKIE = [', HeaderOr(r, 'set-COOKIE', '?'), '] (the first)');
  v := Header(r, 'x-empty');
  if v <> nil then
    writeln('  x-empty was sent, and its value is [', v^, ']');
  v := Header(r, 'X-Missing');
  writeln('  x-missing absent: ', v = nil, ', or [',
          HeaderOr(r, 'X-Missing', 'a default'), ']');
  Drop;
  writeln;

  { --- chunked, through Exchange ---------------------------------------- }

  writeln('--- chunked, and Exchange');
  Pair;
  { The answer goes out before the question, which is what lets one thread run
    both halves of `Exchange`. The middle chunk carries an extension RFC 9112
    §7.1.1 lets a recipient ignore, and data that is two lines. }
  e := WriteText(conn,
       'HTTP/1.1 200 OK' + CRLF +
       'Transfer-Encoding: chunked' + CRLF + CRLF +
       '6' + CRLF + 'hello ' + CRLF +
       '3;ext=1' + CRLF + 'a' + chr(10) + 'b' + CRLF +
       '5' + CRLF + 'world' + CRLF +
       '0' + CRLF + 'X-Trailer: ignored' + CRLF + CRLF);
  e := NewRequest(q, 'GET', '/chunked');
  e := AddHeader(q, 'Host', 'localhost');
  e := Exchange(cli, q, r);
  Report;
  e2 := BodyInto(r, joined);
  writeln('  joined: ', ErrorText(e2), ' [', joined, ']');
  { The destination is left as it was, so a caller that got `errFull` cannot
    mistake half a body for the whole of one. }
  small := 'keep';
  e2 := BodyInto(r, small);
  writeln('  into four characters: ', ErrorText(e2), ', still [', small, ']');
  Drop;
  writeln;

  { --- a 302, reported and not followed --------------------------------- }

  writeln('--- 302, not followed');
  Pair;
  e := WriteText(conn,
       'HTTP/1.1 302 Found' + CRLF +
       'Location: /elsewhere' + CRLF +
       'Content-Length: 0' + CRLF + CRLF);
  e := NewRequest(q, 'GET', '/old');
  e := AddHeader(q, 'Host', 'localhost');
  e := Exchange(cli, q, r);
  writeln('receive: ', ErrorText(e));
  writeln('  status ', r.status:1, ', Location [',
          HeaderOr(r, 'location', ''), '] -- the caller decides');
  Drop;
  writeln;

  { --- HEAD: a stated length and no body -------------------------------- }

  writeln('--- HEAD, whose response states a length it does not send');
  Pair;
  e := WriteText(conn,
       'HTTP/1.1 200 OK' + CRLF +
       'Content-Length: 42' + CRLF + CRLF);
  e := NewRequest(q, 'HEAD', '/thing');
  e := AddHeader(q, 'Host', 'localhost');
  e := Exchange(cli, q, r);
  Report;
  Drop;
  writeln;

  { --- no framing field at all: the body ends at the close -------------- }

  writeln('--- no Content-Length and no Transfer-Encoding');
  Pair;
  e := WriteText(conn,
       'HTTP/1.1 200 OK' + CRLF + CRLF +
       'read until the far end closes' + chr(10));
  conn := nil;
  e := Receive(cli, 'GET', r);
  Report;
  cli := nil;
  writeln;

  { --- the failures ----------------------------------------------------- }

  writeln('--- what is reported rather than guessed at');

  Pair;
  e := WriteText(conn, 'HTTP/1.1 twohundred OK' + CRLF + CRLF);
  conn := nil;
  e := Receive(cli, 'GET', r);
  writeln('status-line with no code:   ', ErrorText(e));
  cli := nil;

  Pair;
  e := WriteText(conn,
       'HTTP/1.1 200 OK' + CRLF + 'no-colon-here' + CRLF + CRLF);
  conn := nil;
  e := Receive(cli, 'GET', r);
  writeln('field-line with no colon:   ', ErrorText(e));
  cli := nil;

  { RFC 9112 §6.1: a sender must not send both, and a recipient that picks one
    is half of a request-smuggling pair. }
  Pair;
  e := WriteText(conn,
       'HTTP/1.1 200 OK' + CRLF +
       'Content-Length: 5' + CRLF +
       'Transfer-Encoding: chunked' + CRLF + CRLF);
  conn := nil;
  e := Receive(cli, 'GET', r);
  writeln('framed both ways at once:   ', ErrorText(e));
  cli := nil;

  Pair;
  conn := nil;
  e := Receive(cli, 'GET', r);
  writeln('closed without answering:   ', ErrorText(e));
  cli := nil;

  { A body line past the module's own bound. Reported, and the response is not
    to be read -- which is the whole of what a fixed buffer owes a caller. }
  long := '';
  for i := 1 to BodyLineMax + 10 do
    long := long + 'x';
  Pair;
  e := WriteText(conn,
       'HTTP/1.1 200 OK' + CRLF + 'Content-Length: 1034' + CRLF + CRLF);
  e := WriteText(conn, long + chr(10));
  conn := nil;
  e := Receive(cli, 'GET', r);
  writeln('a body line too long:       ', ErrorText(e));
  cli := nil;

  srv := nil
end.
