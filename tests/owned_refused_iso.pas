{ AP Annex B: what a conformance mode says about a dialect construct. `owned`
  is no word-symbol, so what each conformance mode sees is a type-name followed by
  `^` -- a type-denoter is complete after the name, so the caret is where the
  parser stops (ADR-0140, ADR-0181).

  The refusal is a *conformance* answer and so belongs to both front ends
  (ADR-0121): src/ must say what this says, or difftest disagrees. }
program owned_refused_iso(output);
type
  Node = record key: integer end;
var p: owned ^Node;
begin
  writeln('unreachable')
end.
