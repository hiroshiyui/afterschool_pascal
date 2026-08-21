{ ISO 7185 §6.6.3.7's conformant array parameters, which with §6.6.3.6 e) and
  §6.6.3.8 are the whole of the difference between level 0 and level 1
  (§5.1 a)). One body serves every extent an array-type can have, and the
  bounds travel with the actual as two more arguments -- ADR-0040's descriptor,
  which was built for a schematic formal and needed nothing added.

  §6.6.3.7's own worked example is the abbreviated form, and this pins both:
  `array [u..v: T1; j..k: T2] of T3` and the full `array [u..v: T1] of
  array [j..k: T2] of T3` are equivalent, so the parser writes the full one. }
program conformant(output);

type
  small  = array [1..3] of integer;
  big    = array [5..9] of integer;
  matrix = array [1..2] of array [3..5] of integer;
  colour = (red, green, blue);
  wheel  = array [red..blue] of integer;
  packed3 = packed array [1..5] of char;

var
  s: small;
  b: big;
  m: matrix;
  w: wheel;
  p: packed3;
  loose: array [1..5] of char;
  yes: array [boolean] of integer;
  t1, t2: small;
  i, j: integer;
  c: colour;

{ §6.6.3.7.1: the bound-identifiers denote the smallest and largest values of
  the index-type the *actual* possesses, and are neither constants nor
  variables -- neither assignable nor passable as a var actual. }
function total(var a: array [u..v: integer] of integer): integer;
var i, n: integer;
begin
  n := 0;
  for i := u to v do n := n + a[i];
  total := n
end;

{ One conformant array handed on to another. §6.6.3.8 makes two schemas
  correspond, and the bounds come from this activation's own descriptor. }
procedure onward(var a: array [lo..hi: integer] of integer);
begin
  writeln('onward ', lo:1, '..', hi:1, ' = ', total(a):1)
end;

{ Two dimensions, written the abbreviated way. A row is itself a conformant
  array and may be passed as one, and assigned as a whole. }
procedure rows(var a: array [p..q: integer; s..t: integer] of integer);
var i: integer;
begin
  writeln('rows ', p:1, '..', q:1, ' cols ', s:1, '..', t:1);
  for i := p to q do writeln('  row ', i:1, ' total ', total(a[i]):1);
  a[p] := a[q];
  writeln('  after a[', p:1, '] := a[', q:1, ']: ', total(a[p]):1)
end;

{ An enumerated index type, and a §6.6.3.7.2 value conformant array whose
  actual is a literal: the value form takes an *expression*, and the copy is
  the callee's own. }
procedure paint(var a: array [lo..hi: colour] of integer);
var c: colour;
begin
  write('paint');
  for c := lo to hi do write(' ', a[c]:1);
  writeln
end;

procedure spell(a: packed array [u..v: integer] of char);
var i: integer;
begin
  write('spell ', u:1, '..', v:1, ' ');
  for i := u to v do write(a[i]);
  a[u] := '!';
  write(' then ');
  for i := u to v do write(a[i]);
  writeln
end;

{ §6.6.3.7.1 gives the formal-parameters of one specification *an* array-type,
  singular for a plural -- so `a` and `b` here possess the same type and the
  assignment between them is conforming. Two types would be two by §6.4.1
  however alike, and ADR-0017's name equivalence would refuse it. }
procedure swapfirst(var a, b: array [lo..hi: integer] of integer);
begin
  a := b;
  writeln('swapped ', total(a):1, ' ', total(b):1)
end;

{ An index type narrower than the word the bounds travel in. §6.6.3.7 puts no
  restriction on the ordinal-type-identifier, so `boolean` and `char` are index
  types like any other -- and the descriptor field then has their width, which
  is what the bounds are converted to on the way in. }
procedure flags(var a: array [lo..hi: boolean] of integer);
var b: boolean;
begin
  write('flags');
  for b := lo to hi do write(' ', a[b]:1);
  writeln
end;

{ §6.6.5.4's transfer procedures over a conformant array. Their bounds are
  read where the arrays' are, so `pack` and `unpack` work through a schema in
  either position -- and until this feature reached them they did not work
  through a *schematic formal* either, ADR-0040 having left that unexercised. }
procedure squeeze(var loose: array [lu..hu: integer] of char;
                  var tight: packed array [lp..hp: integer] of char);
var i: integer;
begin
  pack(loose, lu, tight);
  write('packed');
  for i := lp to hp do write(' ', tight[i]);
  writeln;
  unpack(tight, loose, lu);
  write('unpacked');
  for i := lu to hu do write(' ', loose[i]);
  writeln
end;

{ §6.6.3.6 e): a procedural parameter whose own list contains a conformant
  array specification is congruous with one whose schema is equivalent. }
procedure apply(procedure f(var a: array [u..v: integer] of integer);
                var g: small);
begin
  f(g)
end;

begin
  for i := 1 to 3 do s[i] := i;
  for i := 5 to 9 do b[i] := i;
  writeln('totals ', total(s):1, ' ', total(b):1);
  onward(s);
  onward(b);

  for i := 1 to 2 do
    for j := 3 to 5 do m[i][j] := i * 10 + j;
  rows(m);

  for c := red to blue do w[c] := ord(c) + 1;
  paint(w);

  p := 'hello';
  spell(p);
  spell('bye  ');
  writeln('p is still ', p);

  apply(onward, s);

  for i := 1 to 3 do t1[i] := i;
  for i := 1 to 3 do t2[i] := i * 10;
  swapfirst(t1, t2);

  yes[false] := 10;
  yes[true] := 20;
  flags(yes);

  for i := 1 to 5 do loose[i] := chr(ord('a') + i - 1);
  squeeze(loose, p)
end.
