{ An ordinary ISO/IEC 10206:1991 module, and the point of it is that nothing
  here is a dialect feature: no `external`, no `?T`, no `array of`, no `int64`,
  and — the thing ADR-0137 turns on — no variant-part with a tag-field.

  It is translated under --std=extended, by the second field of
  lib_conforming.components, while the program that imports it is the dialect.
  That mixture is what ADR-0119 refused wholesale and ADR-0137 admits when the
  interface says the two modes cannot differ. }
module Conforming;

export Conforming = (Pair, Nearer, Total);

type
  { A record with no variant part. It is exported deliberately: a module that
    exported no structured type at all would pass a much weaker test, since
    the walk would never have to look inside anything. }
  Pair = record lo, hi: integer end;

{ The one nearer to zero, ties going to `lo`. }
function Nearer(p: Pair): integer;

{ Both of them added, which traps on overflow exactly as it does anywhere. }
function Total(p: Pair): integer;

end;

function Nearer;
begin
  if abs(p.lo) <= abs(p.hi) then Nearer := p.lo else Nearer := p.hi
end;

function Total;
begin Total := p.lo + p.hi end;

end.
