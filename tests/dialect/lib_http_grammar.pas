{ PasHttp's grammar, with no transport under it at all.

  **This is the case the split exists for.** `lib_http.pas` drives `Send` and
  `Receive` over a loopback socket and would pass just as well if the parser
  and the socket were still one thing; what it cannot show is that the grammar
  *has* no transport. Here there is none: a request is rendered into a string
  and printed, and a response is fed to the reader a line at a time from an
  array in this program. Nothing is opened.

  It is also the only case that reaches the grammar at all on a machine
  without OpenSSL, `tests/checks/tls.sh` being where the second transport is
  exercised and that check skipping without libssl (ADR-0265).

  **The write buffer is deliberately tiny.** `NextPiece` fills whatever it is
  given and spans a longer piece across calls, so a `string(7)` proves the
  spanning that a `string(4096)` would hide -- the start-line alone is longer
  than the buffer, and so is every field line here.

  CRLF is printed as `<` and `>` so a golden can hold it: RFC 9112 §2.1 ends
  every line with both characters, and a golden with real ones in it would be
  a golden nobody could read a diff of. }
program lib_http_grammar(output);

import PasError;
       PasHttp;

var
  q: Request;
  r: Response;
  w: RequestCursor;
  small: string(7);
  e: ErrorCode;
  n: integer;
  body: BodyLine;

{ The octets, with the two terminator characters made visible. }
function Shown(s: string): BodyLine;
var i: integer; t: BodyLine;
begin
  t := '';
  for i := 1 to length(s) do
    if s[i] = chr(13) then t := t + '<'
    else if s[i] = chr(10) then t := t + '>'
    else t := t + s[i];
  Shown := t
end;

{ Render `q` through a seven-character buffer and print every piece as it
  comes out, so the spanning is in the golden and not merely in the total. }
procedure Render;
var pieces: integer;
begin
  e := BeginRequest(q, w);
  if Failed(e) then begin
    writeln('  refused: ', ErrorText(e));
    exit
  end;
  pieces := 0;
  while not w.done do begin
    NextPiece(q, w, small);
    if length(small) > 0 then begin
      pieces := pieces + 1;
      writeln('  ', pieces:2, ' |', Shown(small), '|')
    end
  end;
  writeln('  ', pieces, ' writes of at most ', small.capacity)
end;

{ Feed a response one line at a time, stopping when the reader stops asking.
  `lines` is what the far end sent; after them the connection closes, which is
  `FeedEnd`. }
procedure Feed(protected var lines: array of BodyLine; closes: boolean);
var i: integer;
begin
  BeginResponse(r, q.method);
  i := 0;
  e := errNone;
  while WantsLine(r) and (not Failed(e)) do
    if i < length(lines) then begin
      i := i + 1;
      e := FeedLine(r, lines[i])
    end
    else if closes then e := FeedEnd(r)
    else begin
      writeln('  the reader wanted a line nobody sent');
      e := errIO
    end;
  write('  ', ErrorText(e));
  if not Failed(e) then begin
    write(': ', r.status:1, ' stated=', r.stated:1,
          ' chunked=', r.chunked, ' byClose=', r.byClose,
          ' lines=', r.bodyLines:1);
    if BodyInto(r, body) = errNone then write(' body=|', Shown(body), '|')
  end;
  writeln
end;

var counted, chunked, headless, cut, bad: array [1..8] of BodyLine;

begin
  { --- the request side ------------------------------------------------- }
  writeln('a GET with one field:');
  e := NewRequest(q, 'GET', '/things?id=7');
  e := AddHeader(q, 'Host', 'example.test');
  Render;

  writeln('a POST with a body, and a Connection the caller chose:');
  e := NewRequest(q, 'POST', '/things');
  e := AddHeader(q, 'Host', 'example.test');
  e := AddHeader(q, 'Connection', 'keep-alive');
  e := SetBody(q, 'x=1');
  Render;

  { A request with no Host is refused before an octet is produced, which is
    the property `BeginRequest` moved out of `Send`: nothing is written, so
    nothing has to be taken back. }
  writeln('no Host field:');
  e := NewRequest(q, 'GET', '/');
  Render;

  { --- the response side ------------------------------------------------ }
  e := NewRequest(q, 'GET', '/');
  e := AddHeader(q, 'Host', 'example.test');

  writeln('framed by Content-Length:');
  counted[1] := 'HTTP/1.1 200 OK';
  counted[2] := 'Content-Type: text/plain';
  counted[3] := 'Content-Length: 12';
  counted[4] := '';
  counted[5] := 'hello';
  counted[6] := 'world';
  Feed(counted[1..6], true);

  writeln('framed by chunks:');
  chunked[1] := 'HTTP/1.1 200 OK';
  chunked[2] := 'Transfer-Encoding: chunked';
  chunked[3] := '';
  chunked[4] := '6;ext=1';
  chunked[5] := 'first';
  chunked[6] := '0';
  chunked[7] := '';
  Feed(chunked[1..7], true);

  { RFC 9112 §6.3 rule 6: no framing field at all, so the body ends where the
    connection does -- which is the one shape only `FeedEnd` can complete. }
  writeln('framed by the close:');
  headless[1] := 'HTTP/1.1 200 OK';
  headless[2] := 'Content-Type: text/plain';
  headless[3] := '';
  headless[4] := 'to the end';
  Feed(headless[1..4], true);

  { A close inside the header section is a message that stopped in the middle
    of itself, and a close in a chunked body is a message that was not what it
    said it was. Two different answers from the same routine, which is why it
    is a routine. }
  writeln('cut off in the header section:');
  cut[1] := 'HTTP/1.1 200 OK';
  cut[2] := 'Content-Type: text/plain';
  Feed(cut[1..2], true);

  writeln('nothing at all:');
  Feed(cut[1..0], true);

  writeln('a status-line that is not one:');
  bad[1] := 'this is not HTTP';
  Feed(bad[1..1], true);

  { The reader stops asking the moment the message is complete, so the lines
    after it are never read -- which is what lets one connection carry a
    second response even though this module does not use one. }
  writeln('a complete message with more behind it:');
  n := 0;
  BeginResponse(r, 'GET');
  counted[1] := 'HTTP/1.1 204 No Content';
  counted[2] := '';
  counted[3] := 'HTTP/1.1 200 OK';
  while WantsLine(r) and (n < 3) do begin
    n := n + 1;
    e := FeedLine(r, counted[n])
  end;
  writeln('  ', ErrorText(e), ': ', r.status:1, ' after ', n:1,
          ' of 3 lines')
end.
