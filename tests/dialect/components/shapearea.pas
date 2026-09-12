{ One module giving `Shape` a routine of its own (AP 6.7.10.5). It compiles,
  and a client importing this and not `ShapeEdge` compiles too. }
module ShapeArea;

export ShapeArea = (AreaName);

import ShapeOwner;

const AreaName = 'area';

end;

impl Shape;

  function Area(s: Shape): integer;
  begin
    Area := s.side * s.side
  end;

end;

end.
