{ ADR-0123 costs the lexis nothing: `?` is a character neither standard admits
  anywhere at all, so the dialect can take it without reserving a word and
  without changing what either conformance mode accepts. Outside the dialect
  it is refused by the path every other stray character takes, which is also
  why the reference front end needed no teaching for it -- unlike ADR-0121's
  `external`, whose spelling is a perfectly good identifier. }
program optional_refused(output);
type oi = ?integer;
var a: oi;
begin
  a := 1
end.
