{ A module exporting a *variable*, for tests/dialect/typeinquiry_import.pas.

  It exists for one production: §6.5.1's variable-name is
  `[ imported-interface-identifier '.' ] variable-identifier`, so a qualified
  name is the one period ISO/IEC 10206:1991 §6.4.9 already admits — and under
  AP 6.4.9 that same spelling is also a field-designator. The parser has one
  production for both and Sema asks the symbol, which is the branch nothing
  else here reaches. }
module TqMod;

export TqMod = (Seed, Origin, Point);

type Point = record x, y: integer end;

var Seed: integer;
    Origin: Point;

end;

{ §6.11.4's activation block, which is how a module gives its variables values
  before the program's own block runs. }
to begin do begin
  Seed := 7;
  Origin.x := 20;
  Origin.y := 22
end;

end.
