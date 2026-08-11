{ ...and the other half of that: under ISO 7185 `complex` and `re` are ordinary
  identifiers, so a program may declare them and this one does. It is the
  evidence that the feature reserves nothing — the same evidence
  `tests/iso_identifiers.pas` carries for `otherwise`. }
program ComplexRedeclared(output);
type complex = record x, y: integer end;
var c: complex;
function re(v: complex): integer;
begin
  re := v.x
end;
begin
  c.x := 3; c.y := 4;
  writeln(re(c):1)
end.
