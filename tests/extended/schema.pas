{ ISO/IEC 10206:1991 §6.4.7 and §6.4.8: a schema is a mapping from
  discriminant tuples to types, and a discriminated-schema selects one of
  them. `vector(3)` is a type; `vector` on its own is not.

  §6.4.8 makes a type produced with one tuple distinct from a type produced
  with any other, and — the other half of the same sentence — makes one tuple
  denote one type however many times it is written. Both halves are pinned
  below, because an implementation that got only the first right would look
  correct until two variables had to be assignment-compatible. }
program Schemata(output);
type
  vector(n: integer) = array [1..n] of real;
  grid(w, h: integer) = array [1..w, 1..h] of integer;
  bounded(lo, hi: integer) = lo..hi;
  buffer(cap: integer) = record
    len: integer;
    data: array [1..cap] of char
  end;
  { a discriminant is an ordinal, so it need not be an integer }
  suit = (clubs, diamonds, hearts, spades);
  hand(s: suit) = array [1..3] of integer;
  { and a production may be given a name of its own, which names the same
    type rather than a new one }
  triple = vector(3);

var
  a, b: vector(3);
  named: triple;
  wide: vector(5);
  g: grid(2, 3);
  r: bounded(1, 9);
  buf: buffer(8);
  red, black: hand(hearts);
  i, j: integer;

{ a discriminated schema is an ordinary type, so it is an ordinary parameter }
procedure ShowThree(v: vector(3));
var k: integer;
begin
  for k := 1 to v.n do write(v[k]:1:1, ' ');
  writeln
end;

begin
  { §6.8.4's schema-discriminant: `v.n` is the value the type was produced
    with, so it is a constant and not a field }
  for i := 1 to a.n do a[i] := i / 2;
  ShowThree(a);

  { the same tuple, written twice, is the same type -- so this is a whole
    array assignment and not a type error }
  b := a;
  named := b;
  writeln('same tuple, same type: ', named[3]:1:1);

  { a wider production of the same schema is a different type, and knows it }
  for i := 1 to wide.n do wide[i] := i;
  writeln('vector(', wide.n:1, ') ends at ', wide[wide.n]:1:1);

  { two discriminants, and an array of two dimensions built from both }
  for i := 1 to g.w do
    for j := 1 to g.h do g[i, j] := i * 10 + j;
  writeln('grid ', g.w:1, ' by ', g.h:1, ': ', g[2, 3]:1);

  { the body need not be structured at all -- this one is a subrange, and it
    is range-checked like any other }
  r := 9;
  writeln('bounded(', r.lo:1, ',', r.hi:1, ') holds ', r:1);

  { a record whose field is sized by the discriminant }
  buf.len := 5;
  for i := 1 to buf.len do buf.data[i] := chr(ord('a') + i - 1);
  write('buffer(', buf.cap:1, ') holds ');
  for i := 1 to buf.len do write(buf.data[i]);
  writeln;

  { a discriminant that appears nowhere in the body still tells two types
    apart -- NOTE 1 of §6.4.7 says that is what it is for }
  for i := 1 to 3 do red[i] := i;
  black := red;
  writeln('hand(', ord(black.s):1, ') is ', black[2]:1)
end.
