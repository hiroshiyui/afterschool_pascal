{ §6.7.2.2, D.44: "a term of the form x/y is an error if y is zero."

  `div` and `mod` by zero have trapped since ADR-0014; real division had not,
  and the difference was never a decision — IEEE simply answers ∞ and nothing
  looked. No program in the corpus divided by a zero it did not write as a
  literal, so every oracle agreed. }
program TrapRealDiv(output);
var x, y: real;
begin
  x := 1.0;
  y := 4.0;
  writeln('1/4 is ', (x / y):1:2);
  y := 0.0;
  writeln((x / y):1:4)
end.
