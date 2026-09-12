{ A second module giving `Shape` an implementation of its own. Each component
  conforms to AP 6.7.10's "at most one inherent-implementation in a
  program-component" on its own; what no program can have is both, because
  6.7.10.2 would then select from the type and find two candidates with
  nothing to choose between them. }
module ShapeEdge;

export ShapeEdge = (EdgeName);

import ShapeOwner;

const EdgeName = 'edge';

end;

impl Shape;

  function Perimeter(s: Shape): integer;
  begin
    Perimeter := s.side * 4
  end;

end;

end.
