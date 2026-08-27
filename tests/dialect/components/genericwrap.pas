{ A module that *imports* a generic and instantiates it (ADR-0216).

  AP 6.7.3.10 makes an instantiation belong to the translation that named the
  types, and ADR-0212 established that across ISO/IEC 10206:1991 §6.13 for a
  program importing a generic. A module is such a translation too, and was the
  arm that emitted the frame type and the call and not the body — so the
  component assembled and the *link* failed, one component later, with a
  reference to a function nobody defined.

  Nothing about this module is unusual, which is the point: it names `integer`
  where `GenericMod` named `T`, exactly as `generic_import.pas` does, and the
  only difference is that it has no main-program-declaration. }
module GenericWrap;

export GenericWrap = (SwapInts, PairSum);

import GenericMod;

{ A generic procedure instantiated inside a module's own body. }
procedure SwapInts(var a, b: integer);

{ And a generic that yields a type — `Pair(integer)` is a local variable here
  and never crosses the interface, so a caller needs to know nothing of it. }
function PairSum(x, y: integer): integer;

end;

procedure SwapInts;
begin
  Swap(integer, a, b)
end;

function PairSum;
var p: Pair(integer);
begin
  MakePair(integer, p, x, y);
  PairSum := p.a + p.b
end;

end.
