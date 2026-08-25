{ AP Annex B: `release` is a required identifier and so is nobody's under a
  conformance mode -- the third of the dialect's two spelling shapes
  (ADR-0140, ADR-0177, ADR-0206). A program of that standard may declare its
  own `release` and keep it; this one does not, so the name resolves to
  nothing. }
program release_refused(output);
var f: text; k: integer;
begin
  rewrite(f);
  { the name resolves to nothing, and that is the whole of the refusal }
  k := release(f);
  writeln(k)
end.
