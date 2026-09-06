{ AP 6.7 (ADR-0338): the type an implementation is for is a name, and a
  semicolon closes the line -- what follows is the first routine. }
program p;
type Point = record x: integer end;
trait Ord;
  function Compare(a: Self; b: Self): integer;
end;
impl Ord for Point
  function Compare;
  begin Compare := 0 end;
end;
begin end.
