{ AP Annex B: `take` is a required identifier and so is nobody's under a
  conformance mode -- the third of the dialect's two spelling shapes
  (ADR-0140, ADR-0177, ADR-0182). A program of that standard may declare its
  own `take` and keep it; this one does not, so the name resolves to nothing. }
program take_refused(output);
type Node = record key: integer end;
var p: ^Node; k: integer;
begin
  new(p);
  { the name resolves to nothing, and that is the whole of the refusal }
  k := take(p);
  writeln(k)
end.
