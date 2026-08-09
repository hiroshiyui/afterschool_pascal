program FilesExt(output, work, copy);

{ External files. ISO 7185 §6.10 makes a program parameter the only connection
  to a file outside the program and leaves the binding to the implementation;
  this one binds them to the command line, in the order they are written here.
  So `work` is the first argument and `copy` the second. }

type
  line = packed array [1..12] of char;

var
  work, copy: text;
  i, n: integer;
  c: char;

procedure WriteLine(var f: text; s: line);
var k: integer;
begin
  for k := 1 to 12 do
    write(f, s[k]);
  writeln(f)
end;

begin
  { Write three lines, then read the same file back. reset after rewrite is
    what makes this a round trip rather than two unrelated files. }
  rewrite(work);
  WriteLine(work, 'first line  ');
  WriteLine(work, 'second line ');
  WriteLine(work, 'third line  ');

  reset(work);
  n := 0;
  while not eof(work) do begin
    readln(work);
    n := n + 1
  end;
  writeln('lines written and read back: ', n:1);

  { Copy one file to another, character by character, preserving lines. }
  reset(work);
  rewrite(copy);
  n := 0;
  while not eof(work) do begin
    while not eoln(work) do begin
      read(work, c);
      write(copy, c);
      n := n + 1
    end;
    readln(work);
    writeln(copy)
  end;

  { And read the copy back to prove it arrived. Closing is what flushed it:
    the copy was never closed explicitly, because ISO has no way to say so —
    a file is closed when the block that declares it exits, and reset closes
    what it reopens. }
  reset(copy);
  i := 0;
  while not eof(copy) do begin
    read(copy, c);
    if c = 'e' then i := i + 1;
    if eoln(copy) then readln(copy)
  end;
  writeln('copied ', n:1, ' characters, of which ', i:1, ' are the letter e')
end.
