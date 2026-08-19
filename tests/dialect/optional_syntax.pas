{ `?` where no type-denoter is expected. The parser stops at its first error,
  so this is a file of its own -- and it is here because the token has to have
  a *name* in a diagnostic: "found '?'" is written by the same routine that
  writes every other token's spelling, and nothing else in the corpus reaches
  the arm for this one. }
program optional_syntax(output);
var a: integer;
begin
  a := ?
end.
