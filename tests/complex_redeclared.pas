{ ...and the other half of that: `complex` and `re` are required identifiers
  and not word-symbols, so §6.1.3 lets a program declare them and this one
  does. It is the evidence that the feature reserves nothing.

  A companion case carried the same evidence for `otherwise`, and could not
  survive ADR-0232: `otherwise` *is* a word-symbol of ISO/IEC 10206:1991
  §6.1.2, and with one language all 45 are reserved for every source. That is
  the cost the decision was taken with, and this case is the half of the pair
  that a required identifier lets stand. }
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
