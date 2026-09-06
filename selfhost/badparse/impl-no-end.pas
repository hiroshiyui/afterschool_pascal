{ AP 6.7 (ADR-0338): an implementation-declaration is closed by `end`, and its
  routines are procedure- and function-declarations and nothing else -- a
  declaration part met where the next routine or the `end` should be is
  reported against the `end` that was expected. }
program p;
type Point = record x: integer end;
trait Ord;
  function Compare(a: Self; b: Self): integer;
end;
impl Ord for Point;
  function Compare;
  begin Compare := 0 end;
  var n: integer;
end;
begin end.
