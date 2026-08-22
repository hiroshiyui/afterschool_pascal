{ ISO/IEC 10206:1991 6.10.3.4.2, the two halves ISO 7185 cannot express.

  FracDigits of zero: 6.10.3.1 requires a fraction length "greater than or
  equal to zero" where ISO 7185 6.9.3.1 required at least one. The
  representation still ends with "the character '.', the next FracDigits
  digit-characters", and FracDigits is nought of them -- so a trailing point
  and no fraction, which C's "%.0f" does not write.

  And the sign, which is the half that surprises: the character '-' is written
  "if (e < 0.0) and (eWritten > 0.0)", and eWritten is the value *after*
  rounding. A negative number small enough to round away to nothing is
  therefore written without a minus. -0.000001 at two places is `0.00`, not
  `-0.00` -- and MinNumChars is not incremented for a sign that is not there,
  so the field is four characters and not five.

  The expected output was produced from the clause by a separate
  implementation of it, not by running this compiler (ADR-0169). }
program write_real_round_zero(output);
begin
  { Halfway with no fraction digits. }
  writeln('[', 0.5:4:0, ']');
  writeln('[', 1.5:4:0, ']');
  writeln('[', 2.5:4:0, ']');
  writeln('[', 3.5:4:0, ']');
  writeln('[', -0.5:5:0, ']');
  writeln('[', -2.5:5:0, ']');

  { Rounds away to nothing, so no sign and no space for one. }
  writeln('[', -0.000001:0:2, ']');
  writeln('[', -0.004:0:2, ']');
  writeln('[', -0.4:0:0, ']');
  { Rounds to one, so the sign is there. }
  writeln('[', -0.5:0:0, ']');
  writeln('[', -0.005:0:2, ']');

  { Positive zero is unaffected either way. }
  writeln('[', 0.0:0:2, ']')
end.
