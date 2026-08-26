{ A module declaring a generic routine and a schema parameterised by a type,
  for tests/dialect/generic_import.pas to instantiate. It exists to be
  *imported*: AP 6.7.3.10's instantiation re-parses the generic's body from a
  saved token position, and until ADR-0212 the import loop cleared the token
  array between components -- so this file is the case that could not be
  written before. }
module GenericMod;

export GenericMod = (Swap, Largest, Pair, MakePair);

{ AP 6.4.7.1: the container written once (ADR-0209). }
type Pair(T: type) = record a, b: T end;

procedure Swap(T: type; var x, y: T);

procedure MakePair(T: type; var p: Pair(T); x, y: T);

{ A generic function, whose own name inside its body must reach the
  instantiation's result and not the generic's. }
function Largest(T: type; var p: Pair(T); function bigger(i, j: integer): boolean): integer;

end;

procedure Swap;
var q: T;
begin q := x; x := y; y := q end;

procedure MakePair;
begin p.a := x; p.b := y end;

function Largest;
begin
  if bigger(1, 2) then Largest := 1 else Largest := 2
end;

end.
