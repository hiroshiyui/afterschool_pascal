{ Annex B of doc/afterschool-pascal-spec.md: AP 6.4.13's fallible-type is
  written with `!`, a character neither standard admits in any position --
  so both conformance modes refuse it in the lexis, exactly as they refuse
  the optional's `?`, and neither says anything about the dialect. }
program fallible_refused_iso(output);
type Code = (none_, syntax);
     IntResult = integer ! Code;
var r: IntResult;
begin
  r := 1;
  writeln('not reached')
end.
