{ AP 6.7.3.10.5's refusal (ADR-0266) reached through each of the three shapes
  AP 6.7.3.10.4 infers from, rather than only through a type-identifier.

  The point of the file is the *position* each refusal names. A written type
  argument is pointed at directly; an inferred one has no type written
  anywhere, so what the message points at is the actual-parameter that
  determined the parameter -- and the three ways an actual can determine one
  are a type-identifier, a schema production read against its tuple, and a
  slice read through its component type. Each is a different walk in
  `Determine`, and each has to arrive at the same answer about where the type
  came from.

  Sema accumulates (ADR-0024), so all of these are reported in one run. }
program p(output);

type
  Code = (bad, worse);
  Fallible(T: type) = T ! Code;
  Point = record x, y: integer end;
  PointResult = Fallible(Point);

{ a) the parameter-form is the type parameter itself }
function Twice(Elem: numeric type; a: Elem): Elem;
begin Twice := a + a end;

{ b) the parameter-form is a schema production, and the tuple carries the
     type: `res` says what `Elem` is without `Elem` being written at the call
     or standing alone in any parameter-form. }
function Unwrap(Elem: ordered type; res: Fallible(Elem); whenBad: Elem): Elem;
begin
  if res.ok then Unwrap := res.val else Unwrap := whenBad
end;

{ c) the parameter-form is AP 6.7.3.9's slice, read through its component }
function FirstOf(Elem: equatable type; protected var a: array of Elem): Elem;
begin FirstOf := a[1] end;

var
  p, q: Point;
  r: PointResult;
  row: array [1..2] of Point;

begin
  p.x := 0;
  q.x := 0;
  r := p;
  row[1] := p;

  { The written form: the argument that names the type is the position. }
  q := Twice(Point, p);

  { a) inferred from a bare type parameter. }
  q := Twice(p);

  { b) inferred from a schema production -- argument 1 is the Fallible, and
       the type it yields is the record inside it. }
  q := Unwrap(r, p);

  { c) inferred from a slice -- argument 1 is the slice, and the type it
       yields is its component. A whole array does not determine here and a
       slice does: `Determine` reads the actual's type through AP 6.7.3.9's
       slice and an array is not one, so `FirstOf(row)` would say that
       nothing in the call determines the parameter (ADR-0254). }
  q := FirstOf(row[1..2]);

  writeln(q.x:1)
end.
