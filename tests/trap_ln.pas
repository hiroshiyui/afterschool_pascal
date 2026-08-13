{ §6.6.6.2, D.33: "for ln(x), it is an error if x is not greater than zero."

  Not "if x is negative" — zero is refused too, where `sqrt` admits it, and
  that one value is the whole difference between the two checks. IEEE would
  answer −∞ here, which is not a value of the real-type. }
program TrapLn(output);
var x: real;
begin
  x := 1.0;
  writeln('ln(1) is ', ln(x):1:1);
  x := 0.0;
  writeln(ln(x):1:4)
end.
