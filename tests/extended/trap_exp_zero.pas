{ The same error condition as trap_pow_zero, on the other operator: 6.8.3.2
  says x ** y is an error if x is zero and y <= 0. It is a separate program
  because a trap ends the run, and a separate *check* because `**` and `pow`
  reach the runtime by different calls -- there is no shared "exponentiation"
  entry point that could carry one test for both. }
program TrapExpZero(output);
var r, b, e: real;
begin
  b := 0.0;
  e := 0.0;
  writeln('before');
  r := b ** e;
  writeln('unreachable ', r:1:1)
end.
