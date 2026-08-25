{ Annex B of doc/afterschool-pascal-spec.md: AP 6.7.5.11's continue is a required
  procedure-identifier of the dialect and of nothing else, so under either
  conformance mode the name is nobody's and the program names a procedure that
  does not exist. A program of either standard that declares its own `continue`
  keeps it -- 6.1.3's shadowing, and the whole of why the dialect reserves no
  word for either of these two (ADR-0140, ADR-0208). }
program continue_refused_iso(output);
var i: integer;
begin
  for i := 1 to 3 do
    if i = 2 then continue;
  writeln('not reached')
end.
