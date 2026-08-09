program Files(input, output);

{ Reading the standard input. ISO 7185 §6.9.1 defines read in terms of the
  buffer variable and get, and this exercises both the derived form and the
  primitives it is derived from. }

var
  count, total, n: integer;
  x: real;
  c: char;
  lines: integer;

begin
  { A line of integers, read one at a time until the line ends. eoln is what
    says the line has ended; eof would not, because there is more after it. }
  count := 0;
  total := 0;
  while not eoln do begin
    read(n);
    count := count + 1;
    total := total + n
  end;
  readln;
  writeln('integers ', count:1, ' total ', total:1);

  { A real, then the rest of that line character by character. }
  read(x);
  writeln('real ', x:8:3);
  write('rest [');
  while not eoln do begin
    read(c);
    write(c)
  end;
  readln;
  writeln(']');

  { The buffer variable is one character of lookahead: inspecting input^ does
    not consume it, so the same character is still there for read to return.
    That is the property a lexer needs, and the reason get and put exist here
    rather than only the derived operations. }
  writeln('peek ', input^, input^, input^);
  read(c);
  writeln('read ', c);

  { get advances without yielding a value, so this skips a character. }
  get(input);
  read(c);
  writeln('after get ', c);
  readln;

  { Counting the remaining lines: eof is only true once the last one is
    consumed, so a well-formed file gives the number of lines in it. }
  lines := 0;
  while not eof do begin
    readln;
    lines := lines + 1
  end;
  writeln('remaining lines ', lines:1)
end.
