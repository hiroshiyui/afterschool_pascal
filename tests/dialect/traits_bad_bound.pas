{ A bound is refused where it is written and where it is not satisfied
  (ADR-0338), and there are three places: the type-parameter slot of a routine
  heading, a schema's formal discriminant list, and each of the two sites a
  type-valued discriminant is bound -- a pointer domain and a plain
  application. }
program traits_bad_bound(output);

type
  Point = record x: integer end;
  Line = record a: integer end;

trait Sortable;
  function Rank(p: Self; q: Self): integer;
end;

impl Sortable for Point;
  function Rank;
  begin Rank := p.x - q.x end;
end;

{ A bound that names a type, and one that names nothing. }
function ByType(T: Point type; a: T): integer;
begin ByType := 1 end;

function ByNothing(T: NoSuchTrait type; a: T): integer;
begin ByNothing := 1 end;

function Bigger(T: Sortable type; a, b: T): T;
begin if Rank(a, b) >= 0 then Bigger := a else Bigger := b end;

type
  Box(K: Sortable; cap: integer) = record items: array [1..cap] of K end;
  { the pointer-domain site }
  BadPtr = ^Box(Line);

var
  ln, lm, lr: Line;
  { the plain-application site }
  bad: Box(Line, 2);

begin
  { an unsatisfied bound at an activation, written and inferred }
  lr := Bigger(Line, ln, lm);
  lr := Bigger(ln, lm)
end.
