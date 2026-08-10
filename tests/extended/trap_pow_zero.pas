{ 6.8.3.2: x pow y is an error if x is zero and y is not positive. Zero to a
  positive power is zero and zero to the power zero would have to be one, so
  the standard makes the whole non-positive half an error rather than choosing
  a value for it. }
program TrapPowZero(output);
var i, n, e: integer;
begin
  n := 0;
  e := 0;
  writeln('before');
  i := n pow e;
  writeln('unreachable ', i:1)
end.
