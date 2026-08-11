{ ISO/IEC 10206:1991 §6.4.3.6: "file-type = 'file' [ '[' index-type ']' ] 'of'
  component-type. If there is an index-type in a file-type, then that file-type
  shall be designated a **direct-access file-type**."

  The brackets are the whole of the syntax, and the index-type is the whole of
  the difference: a direct-access file is the sequential machine with one
  number added, the component the next operation acts on. Everything is counted
  in *components* rather than bytes, because that is the unit the index-type
  gives — and positions reach the runtime already relative to the index type's
  smallest value, the same fold an array subscript makes.

  `text` is never direct-access: §6.4.3.6 says so, and it has no index-type to
  give it one. }
program DirectFile(output, f, g);
type slot = 1..100;
     { the index type's *smallest* value is position zero in the file, so a
       subrange starting at 'a' is what makes 'a' the first component —
       `file [char] of ...` would start counting at chr(0) }
     letter = 'a'..'z';
var f: file [slot] of integer;
    g: file [letter] of integer;
    i, n: integer;
    c: char;

begin
  { §6.7.5.2's rewrite leaves the file in Generation mode at the start, and put
    appends as it always has — a direct-access file is a sequential one until
    something seeks in it. }
  rewrite(f);
  for i := 1 to 5 do begin
    f^ := i * 10;
    put(f)
  end;

  { §6.7.6.5 and §6.7.6.6. `LastPosition` is `succ(a, length-1)`, so on a file
    indexed from 1 with five components it is 5 — not 4, and not the byte
    count. It is an *error* on an empty file, there being no last component to
    name. }
  writeln('empty ', empty(f), '  last ', lastposition(f):1);

  { SeekRead leaves the file in Inspection mode with the buffer variable
    holding the component sought to, so `f^` is that component and no `get` is
    needed first. }
  seekread(f, 3);
  writeln('at ', position(f):1, ' = ', f^:1);

  { §6.7.5.2's `update(f)`: write the buffer variable back over the component
    the file is positioned at and *do not advance*. `f.L = f0.L` is the whole
    difference from `put`, and it is what makes read-modify-write possible. }
  seekupdate(f, 3);
  n := f^;
  f^ := n + 1000;
  update(f);

  { ...and the position does not move, which is the whole difference from
    `put`: the very next read without seeking sees the component just written.
    ADR-0021's lookahead is what makes this delicate — after a fill the stream
    is one component ahead of the program. }
  writeln('back ', position(f):1, ' = ', f^:1);

  { `get` advances by one component, and `position` says so — the lookahead
    already fetched belongs to the component the program has not consumed. }
  get(f);
  writeln('next ', position(f):1, ' = ', f^:1);

  { Asking the position *after* the buffer variable has been fetched is the
    case ADR-0021's lookahead makes delicate: `f^` reads a component, so the
    stream is one ahead of the program and `position` has to say where the
    program is rather than where the stream is. `eof` fills too, so an ordinary
    read loop is already in this state. }
  seekread(f, 2);
  n := f^;
  writeln('held ', position(f):1, ' = ', n:1);

  seekread(f, 1);
  write('all  ');
  while not eof(f) do begin
    write(f^:1, ' ');
    get(f)
  end;
  writeln;

  { SeekWrite positions for writing, and put then overwrites a component in the
    middle — which §6.7.5.2 permits only for a direct-access file. }
  seekwrite(f, 5);
  f^ := 999;
  put(f);
  seekread(f, 1);
  write('then ');
  while not eof(f) do begin
    write(f^:1, ' ');
    get(f)
  end;
  writeln;

  { ...and seeking one past the last component is legal: that is the append
    position, and refusing it would leave SeekWrite unable to add anything. }
  seekwrite(f, 6);
  f^ := 60;
  put(f);
  writeln('grew ', lastposition(f):1);

  { §6.7.6.6 returns "a result of type T" — the *index* type, not an integer.
    On a `file [char] of integer` the positions are characters, so `position`
    yields a char and the arithmetic is the index type's. }
  rewrite(g);
  for c := 'a' to 'e' do begin
    g^ := ord(c);
    put(g)
  end;
  seekread(g, 'c');
  writeln('char ', position(g), ' = ', g^:1, ' last ', lastposition(g));

  { An `extend` keeps what is there and appends — the one of the five
    procedures that asks nothing of the file-type, because appending is a
    sequential operation. }
  extend(g);
  g^ := 999;
  put(g);
  seekread(g, 'a');
  write('gs   ');
  while not eof(g) do begin
    write(g^:1, ' ');
    get(g)
  end;
  writeln;
  writeln('glast ', lastposition(g))
end.
