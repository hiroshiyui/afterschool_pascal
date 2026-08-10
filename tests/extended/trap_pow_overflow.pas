{ `pow` is repeated multiplication (ISO/IEC 10206:1991 6.8.3.2), so it is
  checked exactly as `*` is: the integer type is -maxint..maxint, and a power
  that leaves it stops the program rather than wrapping.

  The exponent is chosen so that the wrapped value would be *in range and
  positive* -- 3 pow 21 is 10460353203, and the low 32 bits of that are
  1870185139, a perfectly plausible answer. An accumulator no wider than the
  type would produce it and report nothing, which is the failure this program
  exists to see; 2 pow 31 would not show it, because the wrap lands on a value
  the check happens to catch anyway. }
program TrapPowOverflow(output);
var i, n: integer;
begin
  n := 21;
  writeln('before');
  i := 3 pow n;
  writeln('unreachable ', i:1)
end.
