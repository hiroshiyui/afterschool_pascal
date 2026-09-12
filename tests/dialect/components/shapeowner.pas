{ The type, in the component that owns it. Neither implementing module
  declares it; each only imports it, which is the shape a library is in when
  it wants to give a type it did not write some routines. }
module ShapeOwner;

export ShapeOwner = (Shape, NewShape);

type Shape = record side: integer end;

{ A value to have. It is here and not in either implementer for the same
  reason the type is: a constructor belongs to the component that knows the
  representation. }
function NewShape(n: integer): Shape;

end;

function NewShape;
var s: Shape;
begin
  s.side := n;
  NewShape := s
end;

end.
