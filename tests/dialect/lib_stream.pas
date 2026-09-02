{ PasStream. Every release is observed by reading the file back, because
  fputs is buffered until the stream is closed: a line that comes back says
  the close ran. The names are built from `fresh`, the harness's own
  per-run path, and the file that must not exist is under a directory that
  does not. }
program lib_stream(output, fresh);

import PasError;
       PasFS;
       PasStream;

var
  fresh: bindable text;
  base, p, q: PathName;
  s, t: Stream;
  line: string(80);
  short: string(5);
  n: integer;
  e: ErrorCode;

procedure dump(path: PathName; what: string);
var r: Stream;
begin
  if StreamOpenRead(r, path) = errNone then begin
    writeln(what, ':');
    while StreamReadLine(r, line) do
      writeln('  [', line, ']')
  end
  else
    writeln(what, ': ', ErrorText(errIO))
end;

{ closed at the block's end, with nothing said }
procedure writer(path: PathName);
var w: Stream;
begin
  e := StreamOpenWrite(w, path);
  e := StreamWriteLine(w, 'from writer');
  e := StreamWriteText(w, 'no newline at the end')
end;

begin
  base := binding(fresh).name;
  p := base + '.stream.p';
  q := base + '.stream.q';

  writer(p);
  dump(p, 'after the block');

  { explicit StreamClose, then the file is complete while the block goes on }
  e := StreamOpenWrite(s, q);
  writeln('open for writing: ', ErrorText(e));
  e := StreamWriteLine(s, 'one');
  e := StreamWriteLine(s, '');
  e := StreamWriteLine(s, 'three');
  StreamClose(s);
  writeln('closed, empty: ', s = nil);
  dump(q, 'after Close');

  { append keeps what was there }
  e := StreamOpenAppend(s, q);
  e := StreamWriteLine(s, 'four, and the rest of a long line');
  StreamClose(s);
  dump(q, 'after append');

  { a line longer than the string loses its tail and only its tail }
  e := StreamOpenRead(t, q);
  n := 0;
  while StreamReadLine(t, short) do begin
    n := n + 1;
    writeln('short ', n:1, ': [', short, ']')
  end;
  writeln('lines: ', n:1);
  StreamClose(t);

  { StreamFlush makes a write visible to a second reader of the same file }
  e := StreamOpenWrite(s, p);
  e := StreamWriteLine(s, 'flushed');
  e := StreamFlush(s);
  dump(p, 'while still open');

  { a missing file, and a directory that cannot be created in }
  e := StreamOpenRead(t, '/nonexistent-apascal/x');
  writeln('missing: ', ErrorText(e), ', empty: ', t = nil);
  e := StreamOpenWrite(t, '/nonexistent-apascal/x');
  writeln('uncreatable: ', ErrorText(e));
  StreamClose(t);
  writeln('close of empty: ', t = nil)
end.
