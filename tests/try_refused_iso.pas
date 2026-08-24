{ Annex B of doc/afterschool-pascal-spec.md: AP 6.8.9's try is a required
  function-identifier of the dialect and of nothing else, so under either
  conformance mode the name is nobody's and the program calls a function that
  does not exist. A program of either standard that declares its own `try`
  keeps it -- 6.1.3's shadowing, which is why the dialect reserves no word for
  this either (ADR-0140, ADR-0178). }
program try_refused_iso(output);
var k: integer;
begin
  k := try(1);
  writeln(k:1)
end.
