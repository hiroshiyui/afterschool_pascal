{ AP 6.4.7's type-valued discriminant: `T: type` names a *type* where every
  other discriminant names a value, so one schema produces a container for
  every element type instead of one per element type being written out.

  6.4.8's interning is what carries it: the tuple component for a type
  discriminant is that type's own identity, so two productions naming one type
  ARE one type -- which is what lets `Fill` below take both `p` and `q`, and
  what makes `p := q` an assignment between equals rather than between two
  records that merely look alike (ADR-0017, ADR-0209).

  The mixed case is the one worth reading: a schema may take a type and a
  value together, and the value goes on being what it was -- `array [1..cap]`
  reaches the ordinary subrange code, and `of T` reaches the ordinary array
  code, with nothing added to either. }
program schema_type_disc(output);
type
  Vec(T: type; cap: integer) = record
    n: integer;
    a: array [1..cap] of T
  end;
  Point = record x, y: integer end;
  Colour = (red, green, blue);

var p, q: Vec(integer, 4);
    long: Vec(integer, 8);
    pts: Vec(Point, 2);
    cs: Vec(Colour, 3);
    chs: Vec(char, 5);
    k: integer;
    c: Colour;

{ one tuple, one type -- so this is a procedure over Vec(integer, 4) and takes
  either of the two variables of it }
procedure Fill(var v: Vec(integer, 4); base: integer);
var i: integer;
begin
  v.n := 4;
  for i := 1 to 4 do v.a[i] := base + i
end;

begin
  Fill(p, 100);
  Fill(q, 200);
  writeln('p ', p.a[1]:1, ' ', p.a[4]:1);
  { the same type, so the whole-variable assignment is admitted }
  p := q;
  writeln('p ', p.a[1]:1, ' ', p.a[4]:1);

  { a different tuple is a different type, with its own layout }
  long.n := 8;
  for k := 1 to 8 do long.a[k] := k * k;
  writeln('long ', long.n:1, ' ', long.a[8]:1);

  { a record element -- which no schema could hold before, the discriminant
    being a value }
  pts.n := 2;
  pts.a[1].x := 3; pts.a[1].y := 4;
  pts.a[2].x := 5; pts.a[2].y := 6;
  writeln('pts ', pts.a[1].x:1, ',', pts.a[1].y:1, ' ',
                  pts.a[2].x:1, ',', pts.a[2].y:1);

  { an enumeration, and a char, to show the component is an ordinary component }
  cs.n := 3;
  cs.a[1] := red; cs.a[2] := green; cs.a[3] := blue;
  write('cs');
  for c := red to blue do write(' ', ord(cs.a[ord(c) + 1]):1);
  writeln;

  chs.n := 5;
  chs.a[1] := 'h'; chs.a[2] := 'e'; chs.a[3] := 'l';
  chs.a[4] := 'l'; chs.a[5] := 'o';
  write('chs ');
  for k := 1 to 5 do write(chs.a[k]);
  writeln
end.
