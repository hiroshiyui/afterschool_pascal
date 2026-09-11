{ **Which traits can have a trait object, and why the rest cannot**
  (AP 6.7.11.1, ADR-0409).

  A routine is reachable through a trait object when `Self` occurs exactly
  once, as the type of a `var` or `protected var` **first** parameter. The
  rule was measured and not reasoned about: with that spelling an
  implementation for a record and one for an integer compile to the same LLVM
  signature, so a table can hold the routine itself; with `p: Self` by value
  they differ, a record travelling by address and an integer not (ADR-0017),
  and every call through the table would need an adapter emitted per
  implementation.

  The other two refusals are not about the calling convention at all. `Self`
  as a *result* type is a value whose size the caller cannot know, and `Self`
  in a second parameter would need two trait objects to agree about a type
  neither of them carries.

  **It is reported at the type-definition**, which is where the program asks
  for the facility -- once, and naming every heading that is in the way,
  because a reader who fixed one would otherwise be told about the next on the
  next run. }
program dyn_object_safety(output);

type Point = record x, y: integer end;

{ every heading here is in the way, and each for a different reason }
trait Awkward;
  { a value receiver }
  procedure ByValue(p: Self);
  { `Self` as the result type }
  function Clone(protected var p: Self): Self;
  { `Self` in a second parameter }
  function Rank(protected var p: Self; q: Self): integer;
  { a formal-parameter-section naming two, which is two receivers (6.7.3.1) }
  procedure Pair(var p, q: Self);
  { no parameters at all, so nothing to dispatch on }
  procedure Bare;
  { and one that is fine, to show the report is per heading }
  procedure Draw(protected var p: Self);
end;

{ a trait every heading of which is reachable }
trait Fine;
  procedure Show(protected var p: Self);
end;

impl Fine for Point;
  procedure Show;
  begin writeln(p.x:1) end;
end;

type
  { refused, with one message per heading that is in the way }
  Bad = dyn Awkward;
  { accepted }
  Good = dyn Fine;
  Other = record z: integer end;

procedure Run;
var g: owned ^Good; o: owned ^Other;
begin
  new(o);
  { `Other` implements nothing, so there is no table to attach }
  g := take(o)
end;

begin
  Run
end.
