{ ISO/IEC 10206:1991 §6.10.3.4.1, and ISO 7185 §6.9.3.4.1 before it: a real
  written in the floating-point form occupies *exactly* TotalWidth characters.
  The representation is a sign, a digit, a point, DecPlaces digits, the letter
  'E', a sign and ExpDigits digits -- and DecPlaces is derived from TotalWidth
  so that the total comes out right. ExpDigits is implementation-defined
  (E.24 / E.11); here it is what the exponent needs, two digits or three.

  So the width is a property the program can check without knowing a single
  digit of the answer, and that is what this does: `writestr` puts the
  representation into a string and `length` measures it.

  It was not always right. The runtime chose ExpDigits from
  `fabs(log10(fabs(val)))` -- the *magnitude* of the exponent rather than the
  exponent that is actually written. For a value in [1e-100, 1e-99) those
  differ: log10(9.99e-100) is -99.0004, so the magnitude is under 100 and two
  digits were budgeted, while the printed exponent is E-100 and needs three.
  The representation came out one character wider than TotalWidth, which is the
  one thing this clause fixes.

  The band is narrow and one-sided -- only negative exponents, and only where
  the mantissa is not exactly 1.0 -- which is why no corpus program had met it.
  There is no over-estimate to match it: a log10 at or past 100 in magnitude
  always means a three-digit exponent.

  Asserting the width rather than the characters is deliberate. A golden of the
  digits would agree with whatever libm rounds to and would say nothing about
  the clause; the width is what §6.10.3.4.1 requires, and it is checkable by
  the program itself. }
program writereal_width(output);
var s: string(64);
begin
  { The band that was wrong: a three-digit negative exponent whose log10 is
    just short of 100 in magnitude. }
  writestr(s, 9.99e-100:20);
  writeln('9.99e-100:20  ', length(s):3, '  ok=', length(s) = 20);
  writestr(s, 5.0e-100:20);
  writeln('5.0e-100:20   ', length(s):3, '  ok=', length(s) = 20);
  writestr(s, 1.5e-100:25);
  writeln('1.5e-100:25   ', length(s):3, '  ok=', length(s) = 25);

  { The boundary itself, where log10 is exactly -100 and was already right. }
  writestr(s, 1.0e-100:20);
  writeln('1.0e-100:20   ', length(s):3, '  ok=', length(s) = 20);

  { Just outside the band, where the exponent really is two digits. }
  writestr(s, 9.99e-99:20);
  writeln('9.99e-99:20   ', length(s):3, '  ok=', length(s) = 20);

  { The positive side, which never had the fault: the floor and the magnitude
    agree once the exponent is not negative. }
  writestr(s, 9.99e99:20);
  writeln('9.99e99:20    ', length(s):3, '  ok=', length(s) = 20);
  writestr(s, 1.0e100:20);
  writeln('1.0e100:20    ', length(s):3, '  ok=', length(s) = 20);

  { And the ordinary values, so a fix in the wrong direction fails too. }
  writestr(s, 1.0:20);
  writeln('1.0:20        ', length(s):3, '  ok=', length(s) = 20);
  writestr(s, -1.0:20);
  writeln('-1.0:20       ', length(s):3, '  ok=', length(s) = 20);
  writestr(s, 0.0:20);
  writeln('0.0:20        ', length(s):3, '  ok=', length(s) = 20);

  { A width below what the representation needs is widened to fit rather than
    truncated -- the exponent's own digits cannot be dropped. Three-digit and
    two-digit exponents therefore have different least widths, which is the
    same computation this test is about, read from the other end. }
  writestr(s, 1.5e-100:1);
  writeln('1.5e-100:1    ', length(s):3, '  ok=', length(s) = 9);
  writestr(s, 1.5e-10:1);
  writeln('1.5e-10:1     ', length(s):3, '  ok=', length(s) = 8)
end.
