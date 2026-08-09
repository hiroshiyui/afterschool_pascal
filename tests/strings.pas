program Strings(output);

{ ISO 7185 gives a string literal the type `packed array [1..n] of char`, so a
  literal, a variable of that type, and a field of one are all the same kind of
  thing: they assign to each other, they compare, and they can be written. }

type
  word8 = packed array [1..8] of char;

var
  a, b: word8;
  keyword: array [1..4] of word8;
  i: integer;

function Rank(w: word8): integer;
var
  k: integer;
begin
  Rank := 0;
  for k := 1 to 4 do
    if keyword[k] = w then
      Rank := k
end;

procedure Report(w: word8);
begin
  write('[', w, ']')
end;

begin
  keyword[1] := 'begin   ';
  keyword[2] := 'end     ';
  keyword[3] := 'program ';
  keyword[4] := 'var     ';

  for i := 1 to 4 do
    Report(keyword[i]);
  writeln;

  a := 'begin   ';
  b := a;
  writeln('a = ', a, ' rank ', Rank(a));
  writeln('b = a: ', b = a);

  { The relational operators compare character by character (§6.7.2.5). }
  writeln('begin < end: ', keyword[1] < keyword[2]);
  writeln('end < begin: ', keyword[2] < keyword[1]);
  writeln('var = var:   ', keyword[4] = 'var     ');
  writeln('unknown:     ', Rank('while   '));

  { A single character in quotes is a char, not a string of length one. }
  writeln('char: ', a[1], a[2], a[3]);

  a[1] := 'B';
  writeln('modified: ', a, ' still equal: ', a = b)
end.
