program Arrays(output);

{ Static arrays: index bases other than one, char and boolean subscripts, the
  multi-dimensional abbreviation, whole-array assignment, and the copy that a
  value parameter makes. }

const
  size = 5;

type
  vector = array [1..size] of integer;
  grid   = array [1..2, 1..3] of integer;
  counts = array ['a'..'e'] of integer;
  flags  = array [false..true] of integer;

var
  a, b: vector;
  g: grid;
  c: counts;
  f: flags;
  i, j: integer;
  ch: char;

{ A value parameter is a copy, so writing to it cannot be seen by the caller. }
procedure Clobber(v: vector);
var
  k: integer;
begin
  for k := 1 to size do
    v[k] := 0;
  write('inside Clobber:');
  for k := 1 to size do
    write(v[k]:3);
  writeln
end;

{ A var parameter is the caller's array itself. }
procedure Double(var v: vector);
var
  k: integer;
begin
  for k := 1 to size do
    v[k] := v[k] * 2
end;

function SumOf(v: vector): integer;
var
  k, total: integer;
begin
  total := 0;
  for k := 1 to size do
    total := total + v[k];
  SumOf := total
end;

begin
  for i := 1 to size do
    a[i] := i * i;

  write('a =');
  for i := 1 to size do
    write(a[i]:3);
  writeln;

  { Whole-array assignment copies every component. }
  b := a;
  a[1] := 999;
  write('b =');
  for i := 1 to size do
    write(b[i]:3);
  writeln;
  a[1] := 1;

  writeln('sum = ', SumOf(a));

  Clobber(a);
  write('after Clobber:');
  for i := 1 to size do
    write(a[i]:3);
  writeln;

  Double(a);
  write('after Double:');
  for i := 1 to size do
    write(a[i]:3);
  writeln;

  { array [1..2, 1..3] means array [1..2] of array [1..3]. }
  for i := 1 to 2 do
    for j := 1 to 3 do
      g[i, j] := i * 10 + j;
  write('g =');
  for i := 1 to 2 do
    for j := 1 to 3 do
      write(g[i][j]:4);
  writeln;

  { A char-indexed array starts at 'a', not at zero. }
  for ch := 'a' to 'e' do
    c[ch] := ord(ch) - ord('a');
  write('c =');
  for ch := 'a' to 'e' do
    write(c[ch]:2);
  writeln;

  f[false] := 10;
  f[true] := 20;
  writeln('f = ', f[false], ' ', f[true])
end.
