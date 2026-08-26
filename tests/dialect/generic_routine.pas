{ AP 6.7.3.5: a routine may take a type parameter, and is then translated once
  per distinct type it is called with (ADR-0211).

  `T: type` is spelled where 6.7.3.1 admits `type` only as the first word of
  6.4.8's type-inquiry, `type of v` -- so `type` followed by anything but `of`
  is a juxtaposition no conforming program can write, and the dialect reserves
  nothing for it. The same spelling AP 6.4.7.1 uses for a type-valued
  discriminant, in the other place a type can be a parameter. }
program generic_routine(output);

type Point = record x, y: integer end;

{ One body, and the instantiations must not share a type: the heading's
  denoters are re-resolved per tuple, so `var a, b: T` is integer in one
  translation and Point in the other. }
procedure Swap(T: type; var a, b: T);
var q: T;
begin q := a; a := b; b := q end;

{ A generic *function*, which needs its own name inside its own body to reach
  the instantiation's result and not the generic's -- and a recursive call,
  which must find the instantiation already in the cache rather than starting
  another one. Without the cache this does not terminate. }
function Depth(T: type; var a: T; n: integer): integer;
begin
  if n <= 0 then Depth := 0
  else Depth := 1 + Depth(T, a, n - 1)
end;

{ AP 6.4.7.1 and 6.7.3.5 together: the container is written once and so is the
  routine over it. This is the pair the four monomorphic modules in lib/ were
  four for. }
type Vec(T: type; cap: integer) = record n: integer; a: array [1..cap] of T end;

procedure Push(T: type; var v: Vec(T, 4); x: T);
begin v.n := v.n + 1; v.a[v.n] := x end;

function Total(var v: Vec(integer, 4)): integer;
var i, s: integer;
begin
  s := 0;
  for i := 1 to v.n do s := s + v.a[i];
  Total := s
end;

var i, j: integer;
    p, r: Point;
    vi: Vec(integer, 4);
    vp: Vec(Point, 4);
begin
  i := 3; j := 7;
  Swap(integer, i, j);
  writeln('ints    ', i:1, ' ', j:1);

  p.x := 1; p.y := 2; r.x := 8; r.y := 9;
  Swap(Point, p, r);
  writeln('records ', p.x:1, ',', p.y:1, ' ', r.x:1, ',', r.y:1);

  { The same T a second time reaches the same translation, so this is not a
    third instantiation of Swap. Nothing in the output can show that; the
    dumped IR can, and the mutation is what pins it. }
  Swap(integer, i, j);
  writeln('again   ', i:1, ' ', j:1);

  writeln('fn int  ', Depth(integer, i, 3):1);
  writeln('fn rec  ', Depth(Point, p, 5):1);

  vi.n := 0;
  Push(integer, vi, 10);
  Push(integer, vi, 32);
  writeln('vec int ', Total(vi):1);

  vp.n := 0;
  p.x := 7; p.y := 6;
  Push(Point, vp, p);
  writeln('vec rec ', vp.a[1].x:1, ',', vp.a[1].y:1)
end.
