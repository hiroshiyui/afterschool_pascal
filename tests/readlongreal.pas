{ ISO 7185 §6.9.1 c) and d): reading a number reads the *longest* sequence of
  characters that forms one, and the value read is the number those characters
  denote. Both halves, and this is about a number long enough that the runtime
  ran out of room for it.

  `pas_read_real` accumulated the characters into a fixed `char buf[64]` and
  every one of its loops carried `&& n + 1 < sizeof buf`. That guard stopped
  the *loop* and not the *read*: the digits past the sixty-third stayed in the
  file, so a seventy-digit number was read as its first sixty-three digits --
  wrong by seven orders of magnitude -- and the seven left over became the next
  value the program read. Two wrong answers, no diagnostic, and nothing in the
  corpus long enough to notice. `pas_read_int` had always reported its own
  overflow (§6.4.2.2's -maxint..maxint); the real path silently truncated.

  `tests/readlongest.pas` is the companion that pins how much of the input a
  read consumes when the number *ends*; this one pins it when the number does
  not fit. The two together are §6.9.1 d)'s "s shall, and s ~ S(t.first) shall
  not, form a signed-number".

  Each line reads a real and then an integer, so what the read left behind is
  as visible as the value it produced -- the two are only separable in a
  program that reads something afterwards. A value is written back with a
  precision that shows the exponent rather than the digits, because what was
  wrong was the magnitude and a double has no seventy digits to compare. }
program readlongreal(input, output);
var r: real; n: integer;
begin
  { Seventy integer digits and then a separate integer. Truncating at the
    buffer gave 1.11...E+62 and then read 1111111 as n. }
  read(r, n);
  writeln('1: ', r:24, ' ', n:1);

  { The same length in the fractional part. Those digits are far below what a
    double can hold, so the *value* is unaffected -- but they still have to be
    consumed, or they are read as the next number. }
  read(r, n);
  writeln('2: ', r:24, ' ', n:1);

  { And with a scale factor after a long mantissa, which is the case where a
    dropped digit moves the exponent as well as the fraction. }
  read(r, n);
  writeln('3: ', r:24, ' ', n:1);

  { A long run of leading zeros is still one number, and it is the one shape
    where the digits that overflow the buffer are the *significant* ones. }
  read(r, n);
  writeln('4: ', r:24, ' ', n:1)
end.
