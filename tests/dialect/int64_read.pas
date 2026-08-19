{ 6.9.1's read of an integer, at the width ADR-0128 added. It was the one
  asymmetry the type had -- `write` took an int64 from the day it landed,
  because 6.10.3.1's decimal representation is the same at both widths and the
  runtime's call had taken an i64 since it was written, and `read` did not.

  What closed it is that the clause is the same sentence for both: c) and d)
  take the longest prefix that *is* a number, the sign is the sign, and the
  give-back is the two characters `struct pas_file` already carries. Only the
  bound differs, so the runtime selects it rather than carrying a second copy
  of the loop (ADR-0134).

  The overflow is caught during the accumulation and not after it, which is
  what makes the check mean anything at the wider width -- `value * 10` would
  already have wrapped. `int64_read_toobig.pas` is the value one over. }
program Int64Read(input, output);
var a, b: int64; k: integer;
begin
  read(a);
  read(k);
  read(b);
  writeln(a);
  writeln(k:1);
  writeln(b);
  { a mixed line, to show the give-back is the same one: `12x` leaves the x }
  readln;
  read(a);
  writeln(a);
  writeln(a + 1)
end.
