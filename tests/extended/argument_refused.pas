{ Annex B of doc/afterschool-pascal-spec.md: AP 6.7.6.10's argument and
  argcount are required identifiers of the dialect alone, so under Extended
  Pascal they are nobody's names -- the int64 row. A bare argcount is a
  variable here, and an undeclared one. }
program argument_refused(output);
begin
  writeln(argument(1));
  writeln(argcount)
end.
