{ And the other end of the range. The integer type is -maxint..maxint, which
  is symmetric, so -2147483648 is not a value of it even though it fits the
  i32 behind it -- the same rule that makes `-2147483648` an out-of-range
  literal (ISO 7185 6.4.2.2).

  (-2) pow 31 is exactly that value, and it is the only direction the check
  can be wrong in without any test noticing: every power that overflows
  upwards is caught by the other half of the same test. }
program TrapPowOverflowNegative(output);
var i, b, n: integer;
begin
  b := -2;
  n := 31;
  writeln('before');
  i := b pow n;
  writeln('unreachable ', i:1)
end.
