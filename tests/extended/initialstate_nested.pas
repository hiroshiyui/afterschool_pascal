{ §6.4.3.2: "The type-denoter of a component-type shall not closest-contain an
  initial-state-specifier." The parser is what makes that reading possible —
  a component stops before the word, so the specifier attaches to the array —
  which leaves exactly one position where the word is genuinely misplaced: a
  denoter that is not a variable's, a type definition's or a field's. A
  function's result type is the readiest one, and the parser stops there. }
program InitialStateNested(output);
function f: integer value 1;
begin
  f := 2
end;
begin
  writeln(f:1)
end.
