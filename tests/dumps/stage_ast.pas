{ --dump-ast, which runs *before* Sema.

  So this golden shows only what the parser decided: no types, no resolved
  symbols, and `@line:col` only where the tree really records a position. That
  is the distinction the two AST-shaped dumps exist to make, and comparing this
  golden with stage_sema.dump is the cheapest way to see it. }
program shapes(output);
var a, b: integer;
begin
  a := 1;
  b := a * (a + 2) - 3;
  if b > a then writeln('gt') else writeln('le')
end.
