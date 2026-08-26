{ AP 6.4.7's type-valued discriminant: what it refuses. Sema accumulates, so
  one file.

  The two mistakes a tuple can make are each here twice over, because the
  parser cannot tell them apart: an actual-discriminant is an expression in
  the source whether it names a value or a type, so which of the two was meant
  is decided by *the symbol* and not by the syntax -- this compiler's recurring
  answer (ADR-0044, ADR-0053, ADR-0066, ADR-0071, ADR-0087, ADR-0209).

  The last one is the boundary of the increment and is written out rather than
  left to whatever an unbound name happens to say. A schematic formal takes
  its discriminants from the actual and reads them from a descriptor at run
  time (ADR-0040), which is what lets one compiled body serve every tuple --
  and a *type* is not something a descriptor can carry, the body's layout
  being different for each. So `var v: Vec` is refused in as many words, and
  a routine has to name the types it is over. }
program schema_type_errors(output);
type
  Vec(T: type; cap: integer) = record a: array [1..cap] of T end;
  Plain(cap: integer) = record a: array [1..cap] of integer end;
  Point = record x, y: integer end;
const four = 4;
var ok: Vec(integer, 4);
    { a value where a type belongs }
    bad1: Vec(four, 4);
    bad2: Vec(2 + 2, 4);
    { a type where a value belongs -- 6.4.7's own rule, reached the ordinary
      way, because a type-name is not an ordinal constant }
    bad3: Vec(integer, Point);
    { and a plain schema is unchanged: its discriminant is still a value }
    bad4: Plain(Point);
    { two productions of one schema over different types are different types }
    other: Vec(Point, 4);

{ a schematic formal over a schema with a type discriminant }
procedure Generic(var g: Vec);
begin end;

begin
  ok := other;
  Generic(ok)
end.
