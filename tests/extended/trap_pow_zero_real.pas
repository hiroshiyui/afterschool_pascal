{ And once more for a real base with an integer exponent, which is the third
  of the three lowerings: `**` converts both operands, integer `pow` is
  repeated multiplication, and this one is neither. Each carries its own copy
  of the zero-base condition, so each needs its own program to show it. }
program TrapPowZeroReal(output);
var r, b: real; e: integer;
begin
  b := 0.0;
  e := -1;
  writeln('before');
  r := b pow e;
  writeln('unreachable ', r:1:1)
end.
