{ 6.8.3.2 defines x ** y as an approximation to exp(y*ln(x)), and a negative
  base has no logarithm -- so `**` is an error there, and the standard's answer
  is `pow`, whose exponent is a whole number. The check is on the value and not
  on the type: this program is well-formed, and only the sign of what reaches
  the operator makes it stop. }
program TrapPowNegative(output);
var r, b: real;
begin
  b := -2.0;
  writeln('before');
  r := b ** 2.0;
  writeln('unreachable ', r:1:1)
end.
