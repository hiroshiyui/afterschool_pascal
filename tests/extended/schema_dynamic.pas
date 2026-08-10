{ ISO/IEC 10206:1991 §6.2.3.2: an actual-discriminant-part is evaluated when
  the block is entered, so a discriminant may be a variable — and a variable
  whose type it decides has a size that is not known until then. It holds the
  descriptor a schematic formal parameter holds, and differs only in where the
  tuple comes from: computed on entry rather than brought by a caller. }
program SchemaDynamic(output);
type
  vector(n: integer) = array [1..n] of integer;
  grid(w, h: integer) = array [1..w, 1..h] of integer;
  letters(n: integer) = packed array [1..n] of char;
var
  k: integer;

{ the plain case: one variable sized by a parameter -- and one sized by an
  *expression*, because a discriminant-value is an expression evaluated on
  entry. That is the opposite of a bound inside the schema's own body, which
  must be a constant or a discriminant: the body is resolved once, and this is
  computed every time the block is entered. }
procedure sized(m: integer);
var v: vector(m); w: vector(m * 2 - 1); i: integer;
begin
  for i := 1 to v.n do
    v[i] := i * i;
  for i := 1 to w.n do
    w[i] := i;
  writeln('vector(', v.n:1, ') ends at ', v[v.n]:1, ', and vector(',
          w.n:1, ') at ', w[w.n]:1)
end;

{ two names, one actual-discriminant-part: each gets its own descriptor, and
  the expressions are evaluated once for each }
procedure pair(m: integer);
var a, b: vector(m); i: integer;
begin
  for i := 1 to a.n do
  begin
    a[i] := i;
    b[i] := 100 * i
  end;
  writeln('a and b hold ', a.n:1, ' and ', b.n:1, ', last ', a[a.n]:1, ' and ',
          b[b.n]:1)
end;

{ two dimensions, both decided on entry }
procedure table(w, h: integer);
var g: grid(w, h); i, j: integer;
begin
  for i := 1 to g.w do
    for j := 1 to g.h do
      g[i, j] := i * 10 + j;
  write('grid ', g.w:1, 'x', g.h:1, ':');
  for i := 1 to g.w do
    for j := 1 to g.h do
      write(g[i, j]:4);
  writeln
end;

{ what makes the storage per-activation: each invocation computes its own
  tuple, and the one deeper in does not disturb the one that called it }
procedure recur(d: integer);
var v: vector(d); i: integer;
begin
  for i := 1 to v.n do v[i] := d;
  if d > 1 then recur(d - 1);
  writeln('  depth ', d:1, ' still holds ', v.n:1, ' of ', v[v.n]:1)
end;

{ a dynamically sized variable is an ordinary variable of its type, so it goes
  to a schematic formal parameter exactly as a `vector(3)` does — and the
  descriptor is what travels, so the callee never learns which it was }
procedure fill(var v: vector);
var i: integer;
begin
  for i := 1 to v.n do v[i] := v.n - i
end;

procedure handOn(m: integer);
var v: vector(m);
begin
  fill(v);
  writeln('filled ', v.n:1, ' from ', v[1]:1, ' down to ', v[v.n]:1)
end;

{ a discriminant may be any ordinal expression that is a variable, and the
  bound it decides is checked on entry against the discriminant's own type }
procedure text(m: integer);
var s: letters(m); i: integer;
begin
  for i := 1 to s.n do s[i] := chr(ord('a') + i - 1);
  write('letters(', s.n:1, ') = ');
  for i := 1 to s.n do write(s[i]);
  writeln
end;

begin
  sized(3);
  sized(6);
  pair(4);
  table(2, 3);
  recur(3);
  handOn(5);
  for k := 1 to 3 do text(k)
end.
