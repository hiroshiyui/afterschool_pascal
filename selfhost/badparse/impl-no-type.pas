{ AP 6.7 (ADR-0338): after `for` comes the name of a type or a schema, and
  nothing else -- a denoter written out would give the implementation a type
  no client could name (6.4.1 makes each denoter its own type), so the parser
  admits a name only. }
program p;
type Point = record x: integer end;
trait Ord;
  function Compare(a: Self; b: Self): integer;
end;
impl Ord for record x: integer end;
  function Compare;
  begin Compare := 0 end;
end;
begin end.
