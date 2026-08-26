{ AP 6.4.9: the type-inquiry-object is §6.5.1's whole variable-access, where
  ISO/IEC 10206:1991 §6.4.9's is a name (ADR-0215).

  It reserves nothing and adds no spelling. `type of` is a position the dialect
  already holds, so widening what may follow `of` is a rule about that position
  and not a construct — ADR-0184's shape, the second feature to take it.

  The reason it exists is AP 6.7.3.5's type parameter. A routine parameterised
  by a type had to be handed the container and then handed the element type
  again, because nothing could read the second off the first. }
program typeinquiry_access(output);

type Point = record x, y: integer end;
     Grid  = array [1..3] of Point;
     Inner = record n: integer end;
     Outer = record a: array [1..2] of Inner end;

var g: Grid;
    q: ^Outer;

    { One selector, and the type is the component's. §6.4.5's name equivalence
      does the rest: `e` *is* a Point, not a type alike one, so the assignment
      below is an ordinary whole-variable copy (ADR-0047). }
    e: type of g[1];
    { A field of a component. }
    f: type of g[1].x;

{ A chain through a pointer, an array and a field at once, which is the shape
  a generic container wants. }
procedure chain;
var b: type of q^.a[1].n;
begin
  q^.a[1].n := 41;
  b := q^.a[1].n + 1;
  writeln(b:1)
end;

{ §6.4.9 already let a later parameter name an earlier one; the object being a
  variable-access changes nothing about that, the scope answering as it always
  did (ADR-0047). Here the earlier parameter is a *slice*, whose own type may be
  written only as a formal's denoter (AP 6.7.3.9.2) — so `type of s` is refused
  and `type of s[1]` is `integer`. The asymmetry is the extension working: the
  second names a type that exists. }
procedure add(var s: array of integer; x: type of s[1]);
begin
  writeln(s[1] + x:1)
end;

{ The object is not evaluated, which is §6.4.9's own requirement carried to what
  the selectors contain: the type of `a[i]` does not depend on i. `bump` is
  declared, named in a type-denoter and never called. }
var calls: integer;

function bump: integer;
begin
  calls := calls + 1;
  bump := 1
end;

procedure unevaluated;
var a: array [1..3] of integer;
    b: type of a[bump];
begin
  b := 7;
  writeln(calls:1, ' ', b:1)
end;

{ The caller the feature was built for. Two instantiations of one body, each
  reading its own element type off the pointer it was given -- which is the
  argument that used to be written out at every call site. }
type Box(T: type; cap: integer) = record
       n: integer;
       a: array [1..cap] of T
     end;
     IntBox = ^Box(integer);
     PtBox  = ^Box(Point);

procedure Push(Ptr: type; var b: Ptr; x: type of b^.a[1]);
begin
  b^.n := b^.n + 1;
  b^.a[b^.n] := x
end;

var ib: IntBox;
    pb: PtBox;
    p: Point;
    t: array [1..4] of integer;

begin
  calls := 0;
  g[1].x := 3; g[1].y := 4;
  e := g[1];
  f := g[1].x;
  writeln(e.x + e.y:1, ' ', f:1);

  new(q);
  chain;

  t[1] := 40;
  add(t, 2);

  unevaluated;

  new(ib, 4); ib^.n := 0;
  Push(IntBox, ib, 11);
  Push(IntBox, ib, 22);
  new(pb, 4); pb^.n := 0;
  p.x := 100; p.y := 7;
  Push(PtBox, pb, p);
  writeln(ib^.a[1]:1, ' ', ib^.a[2]:1, ' ', pb^.a[1].x + pb^.a[1].y:1);

  { Given back, so `heap-balance` has nothing to catalogue about this case. }
  dispose(ib);
  dispose(pb);
  dispose(q)
end.
