{ An implementation written in the component that declared the *trait*, for a
  type another component declared (ADR-0338's orphan rule, the half that is
  reachable). The rule's other half -- an impl in the component that declared
  the type -- cannot be written yet, a trait being exportable from nothing. }
program traits_component(output);

import pointmod;

trait Sortable;
  function Rank(p: Self; q: Self): integer;
end;

impl Sortable for Point;
  function Rank;
  begin Rank := p.x - q.x end;
end;

var a, b: Point;
begin
  SetPoint(9, 1, a);
  SetPoint(4, 1, b);
  writeln(Rank(a, b):1)
end.
