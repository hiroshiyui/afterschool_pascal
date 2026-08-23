{ Annex B of doc/afterschool-pascal-spec.md: AP 6.9.3.11's defer-statement is
  an identifier followed by a token that begins a statement, which no program
  of either standard can write -- a statement beginning with an identifier
  continues as a designator, as a call, or not at all. `defer` itself is
  nobody's word, and a program that declares one keeps it. }
program defer_refused(output);
var p: ^integer;
begin
  new(p);
  defer dispose(p);
  writeln('not reached')
end.
