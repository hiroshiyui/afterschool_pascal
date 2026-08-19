{ ADR-0128's run-time errors, and there is nothing new in any of them: the
  integer type's own checks (ADR-0014) at one width up.

  -maxint64..maxint64 is the type, as -maxint..maxint is integer's, so a result
  whose bit pattern is the machine word's least value is out of range even
  though it fits -- which is why the checked add tests for it as well as for
  the overflow flag.

  Only the first fires. The others are here so that the file says which checks
  exist, and each has been run on its own; a golden holds one trap because a
  trap stops the program. }
program TrapInt64(output);
var a: int64;
    n: integer;
begin
  a := maxint64;
  writeln('before');
  a := a + 1;
  writeln('unreached ', a);
  a := maxint64;
  n := trunc(a);
  writeln(n div 0, a mod 0)
end.
