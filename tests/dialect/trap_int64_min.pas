{ The check the overflow flag does not make (ADR-0014, ADR-0128).

  int64 is -maxint64..maxint64, as integer is -maxint..maxint, so the machine
  word's least value is *not* a value of the type -- and it is reachable
  without the intrinsic's overflow bit ever being set, because it is
  representable. -maxint64 - 1 is exactly it.

  So the checked arithmetic tests the result against the least word as well as
  reading the flag, and this is the program that tells the two apart: with the
  test emitted at the narrow width it compares an i64 against -2147483648,
  never matches, and a value outside the type is stored. }
program TrapInt64Min(output);
var a: int64;
begin
  a := -maxint64;
  writeln('before ', a);
  a := a - 1;
  writeln('unreached ', a)
end.
