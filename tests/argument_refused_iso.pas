{ Annex B of doc/afterschool-pascal-spec.md: AP 6.7.6.10's argument and
  argcount are required identifiers of the dialect alone, so under ISO 7185
  they are nobody's names -- the int64 row. }
program argument_refused_iso(output);
begin
  writeln(argument(1))
end.
