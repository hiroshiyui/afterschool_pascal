{ An HTTP GET, and what comes back.

  PasHttp is an HTTP/1.1 client over PasNet: build a Request, `Send` it
  down a Socket, `Receive` the Response, then ask it for a header by name
  and for its body. A Socket is a handle -- it closes itself when the
  variable dies, or when assigned `nil`.

  There is no web server in a test, so this program is both ends: it
  listens on whatever port is free (`'0'`), connects to itself, and the
  "server" half reads the request and writes a canned reply. To fetch from
  a real host, delete the server half and give `NetConnect` a host and `'80'`.
  Uses PasError, PasNet and PasHttp. }
program fetch_http(output);

import PasError; PasNet; PasHttp;

const CRLF = chr(13) + chr(10);

var
  server, client, conn: Socket;
  port: ServiceName;
  q: Request;
  r: Response;
  e: ErrorCode;
  line: NetLine;
  body: string(1024);

begin
  e := NetListen(server, 'localhost', '0');
  e := NetService(server, port);            { which port we were given }
  e := NetConnect(client, 'localhost', port);
  e := NetAccept(server, conn);

  { --- the client sends --- }
  e := NewRequest(q, 'GET', '/hello');
  e := AddHeader(q, 'Host', 'localhost');
  e := AddHeader(q, 'Accept', 'text/plain');
  e := Send(client, q);
  writeln('send: ', ErrorText(e));

  { --- the server reads the request head and answers --- }
  e := NetReadLine(conn, line);
  while (e = errNone) and (line <> '') do begin
    writeln('  > ', line);
    e := NetReadLine(conn, line)
  end;
  e := NetWriteText(conn,
       'HTTP/1.1 200 OK' + CRLF +
       'Content-Type: text/plain' + CRLF +
       'Content-Length: 12' + CRLF + CRLF +
       'hello' + chr(10) + 'world' + chr(10));
  conn := nil;

  { --- the client reads the response --- }
  e := Receive(client, 'GET', r);
  writeln('receive: ', ErrorText(e));
  writeln('status ', r.status:1, ' ', r.reason);
  writeln('content-type: ', HeaderOr(r, 'content-type', '(none)'));
  e := BodyInto(r, body);
  writeln('body: [', body, ']')
end.
