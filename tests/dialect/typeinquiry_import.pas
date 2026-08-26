{ AP 6.4.9's object is a variable-access, and §6.5.1's variable-name — the one
  form ISO/IEC 10206:1991 §6.4.9 already had — carries an optional qualifier
  before an imported-interface-identifier. Under the dialect that period and a
  field-designator's are one production, so the two readings must both work and
  must not be told apart by the syntax (ADR-0215).

  `type of TqMod.Seed` is the qualified name; `type of TqMod.Origin.x` is the
  qualified name and then a field, which is the only way to write both periods
  in one object. }
program typeinquiry_import(output);

import TqMod;

var a: type of TqMod.Seed;
    b: type of TqMod.Origin.x;
    c: type of TqMod.Origin;
begin
  a := Seed + 1;
  b := Origin.x + 1;
  c := Origin;
  writeln(a:1, ' ', b:1, ' ', c.x + c.y:1)
end.
