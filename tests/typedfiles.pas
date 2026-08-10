{ Non-text files: `file of T` (ISO 7185 6.4.3.5).

  A `text` is not one of these, however alike `file of char` looks. A text has
  a line structure and an external representation of numbers; a `file of T` has
  neither. A component is written and read back exactly as it stands, and
  `read` and `write` on one mean what 6.6.5.2 says they mean:

      read(f, v)   is   v := f^; get(f)
      write(f, e)  is   f^ := e; put(f)

  which is why they take a component of the file's own type and no width. }
program typedfiles(output, data);
type
  colour = (red, green, blue);
  point = record
    x, y: integer;
    hue: colour
  end;
  triple = array [1..3] of integer;
  { 6.6.3.1 makes a parameter's type a type *identifier*, so a file parameter
    needs a name for its type -- `var f: file of point` cannot be written. }
  pointfile = file of point;
var
  { A program parameter, so an external file. Its type is the *named* one:
    ADR-0017's name equivalence makes a second `file of point` written out
    longhand a different type, which a var parameter would then refuse. }
  data: pointfile;
  nums: file of integer; { not a parameter: a scratch file }
  chars: file of char;   { a sequence of characters with no lines in it }
  arrs: file of triple;
  p: point;
  t: triple;
  i, n: integer;
  c: char;

{ A file always travels by reference (6.6.3.3), and the file a `var` parameter
  binds to belongs to the block that declared it -- so this one is not
  re-initialised on the way in, and keeps the component type it was given. }
procedure Refill(var f: pointfile; upto: integer);
var i: integer; q: point;
begin
  rewrite(f);
  for i := 1 to upto do begin
    q.x := i * 100;
    q.y := i;
    q.hue := red;
    write(f, q)
  end
end;

begin
  { A scratch file, written and read back. `write` here is not formatting
    anything -- each component is the integer's own representation. }
  rewrite(nums);
  for i := 1 to 5 do
    write(nums, i * i);
  reset(nums);
  n := 0;
  while not eof(nums) do begin
    read(nums, i);
    n := n + i;
    write(i:3)
  end;
  writeln('  sum', n:4);

  { get/put and the buffer variable, which read and write are derived from.
    A record component makes f^ a designator with fields rather than a value
    in a register -- the same designator machinery an ordinary record has. }
  rewrite(data);
  for i := 1 to 3 do begin
    data^.x := i;
    data^.y := i * 10;
    data^.hue := blue;
    put(data)
  end;
  reset(data);
  while not eof(data) do begin
    writeln('x', data^.x:2, ' y', data^.y:3, ' hue', ord(data^.hue):2);
    get(data)
  end;

  { Reading a whole record copies it and then advances: `read(data, p)` is
    `p := data^; get(data)`, so p is the first component, assigning to p does
    not touch the file, and the buffer variable is already the second one. }
  reset(data);
  read(data, p);
  p.x := 99;
  writeln('read ', p.x:1, ', buffer now ', data^.x:1);

  { A file of char is not a text: no lines, and no way to ask for one. }
  rewrite(chars);
  write(chars, 'a', 'b', 'c');
  reset(chars);
  while not eof(chars) do begin
    read(chars, c);
    write(c)
  end;
  writeln;

  { An array component travels exactly as a record one does. }
  rewrite(arrs);
  t[1] := 7; t[2] := 8; t[3] := 9;
  write(arrs, t);
  reset(arrs);
  t[1] := 0; t[2] := 0; t[3] := 0;
  read(arrs, t);
  writeln(t[1]:2, t[2]:2, t[3]:2);

  { Two variables in one read take two successive components: `get` between
    them invalidates the buffer variable, so it has to be fetched again. }
  reset(nums);
  read(nums, i, n);
  writeln(i:2, n:3);

  { The same external file, refilled through a var parameter. }
  Refill(data, 2);
  reset(data);
  while not eof(data) do begin
    write(' (', data^.x:1, ',', data^.y:1, ')');
    get(data)
  end;
  writeln
end.
