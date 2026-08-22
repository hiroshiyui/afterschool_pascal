{ ISO 7185 6.9.3.4.2 -- and ISO/IEC 10206:1991 6.10.3.4.2 in the same words --
  do not say a real is "rounded" to FracDigits places. They prescribe an
  algorithm:

    eWritten := abs(e);
    eWritten := eWritten + 0.5 * 10.0 pow(-FracDigits);
    eWritten := Truncate(eWritten, FracDigits)

  That is round-half-away-from-zero. C's printf rounds half to *even*, and this
  compiler was handing the job to it -- so every exact halfway value came out
  one unit low half the time. 0.125 at two places is the shortest example: the
  clause says 0.13 and printf says 0.12.

  Every value written here is exactly representable as a double, so each really
  is a halfway case rather than something that merely looks like one in decimal.
  The expected output was produced from the clause, by an implementation of it
  written separately from the compiler, and not by running the compiler -- the
  same one that swept 5022 cases past it.
  0.135 is *not* such a value -- its double is a shade above 0.135 -- so it
  rounds up under either rule, and it is here to show the test is not simply
  asserting "always round up".

  The floating-point form carries the same algorithm (6.9.3.4.1 / 6.10.3.4.1)
  and is pinned in the same way. }
program write_real_round(output);
begin
  { Halfway at two places: x.xx5 exactly. }
  writeln(0.125:6:2);
  writeln(0.375:6:2);
  writeln(0.625:6:2);
  writeln(0.875:6:2);
  writeln(-0.125:7:2);
  writeln(-0.875:7:2);

  { Halfway at one place: x.x5 exactly. These are the ones that decide how the
    clause's arithmetic is read. Executed literally in real arithmetic,
    `0.5 * 10.0 pow(-1)` is 0.05, which no binary format holds exactly, so
    0.25 + 0.05 lands a hair under 0.3 and truncates to 0.2. Done on the exact
    value it is 0.3. This compiler answers 0.3, and 6.10.3.4's opening
    sentence is why: "a decimal representation of the value of e, *rounded* to
    the specified number of ... decimal places". The sub-clauses fix which
    rounding; they do not license losing the value (ADR-0169). }
  writeln(0.25:6:1);
  writeln(0.75:6:1);
  writeln(2.25:6:1);
  writeln(-2.75:7:1);

  { Not a halfway value -- rounds up under both rules. }
  writeln(0.135:6:2);
  { Not a halfway value -- rounds down under both rules. }
  writeln(0.1234:6:2);

  { The floating-point form. 1.25 at TotalWidth 8 leaves DecPlaces 1, so this
    is the halfway case there. }
  writeln(1.25:8);
  writeln(1.75:8);
  writeln(-1.25:9)
end.
