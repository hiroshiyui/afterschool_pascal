{ --dump-predicates (ADR-0194): what every type-classifying predicate in this
  compiler answers about a type of every kind.

  The program is irrelevant and that is the point -- the subject is the
  compiler, and this flag reports after a whole run only for consistency with
  the two dumps beside it. A one-line program keeps the golden to the table.

  This case exists because ADR-0103 found four documented --dump flags that no
  case in the tree had ever passed: a walker nothing enters is a walker nothing
  checks does not crash. `predicate-kinds` reads the same output for a
  different question -- whether the answers are the ones affirmed -- and the
  two are not the same reader. }
program predicates(output);
begin
end.
