{ A module whose interface tries to hold an implementation-declaration. An
  impl has routine *bodies*, and a module-heading holds headings only (6.11.2),
  so it belongs to the module-block -- which is where ADR-0341 puts every
  implementation, a trait crossing a component and an implementation not
  needing to. }
module traitheadmod;

export traitheadmod = (Point);

type Point = record x: integer end;

trait Ord;
  function Compare(a: Self; b: Self): integer;
end;

impl Ord for Point;
  function Compare;
  begin Compare := a.x - b.x end;
end;

end;

end.
