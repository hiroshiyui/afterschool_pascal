{ §6.6.6.2, and D.34 in Annex A's list of errors: "for sqrt(x), it is an error
  if x is negative."

  Without the check the answer is a NaN, which is not a value of the real-type
  — the same reason `trunc` and `round` are checked (ADR-0015), and the reason
  the comparison is *ordered*: an argument that is already a NaN is not less
  than zero and passes, which is right, because §6.7.1 makes using an undefined
  value the error there.

  Zero is not negative, so `sqrt(0.0)` is 0.0 and only `ln` refuses it. }
program TrapSqrt(output);
var x: real;
begin
  x := 0.0;
  writeln('sqrt(0) is ', sqrt(x):1:1);
  x := -1.0;
  writeln(sqrt(x):1:4)
end.
