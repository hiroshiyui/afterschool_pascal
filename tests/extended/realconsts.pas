{ ISO/IEC 10206:1991 §6.4.2.2 b)'s three required real constants. A real here
  is an IEEE-754 binary64, so they are its largest finite value, its smallest
  positive normal one, and its epsilon — and each is spelled as the decimal
  text both compilers carry, because the Pascal-hosted one has no
  floating-point type to convert with (ADR-0025). }
program realconsts(output);
var x: real;
begin
  writeln(maxreal);
  writeln(minreal);
  writeln(epsreal);

  { §6.4.2.2 b): "the value of epsreal shall be the result of subtracting 1.0
    from the smallest value of real-type that is greater than 1.0" — so this
    is the property that defines it, and the half of it is not. }
  x := 1.0 + epsreal;
  writeln(x > 1.0);
  x := 1.0 + epsreal / 2.0;
  writeln(x > 1.0);

  { All three are positive, and maxreal is the top of the usable range. }
  writeln(maxreal > 0.0, minreal > 0.0, epsreal > 0.0);
  writeln(minreal < 1.0, maxreal > 1.0);

  { The three lines above assert the property that *defines* epsreal, which is
    what ADR-0062 said a test of these had to do: the default output rounds to
    thirteen significant digits, so any value within 10^-12 of the right one
    prints the same characters and passes. That leaves `maxreal` and `minreal`
    with no such property to assert — the clause defines them as the largest
    and smallest values of the real-type, and Pascal offers no way to ask for
    the next one.

    A field width does instead. §6.10.3.4.1 derives the number of decimal
    places from the width (ADR-0064), so asking for 26 characters asks for
    nineteen significant digits — past binary64's seventeen, and so past any
    truncation of the decimal text the two compilers carry. Nothing else here
    could see one: a constant short by its last four digits satisfies every
    inequality below and prints identically at the default width, in both
    compilers, so `difftest` and `irtest` would agree as readily as the
    goldens. }
  writeln(maxreal:26);
  writeln(minreal:26);

  { They are constants, so they may be written with a field width and used
    where any other real constant is. }
  writeln(epsreal:12:10);
  x := maxreal / 2.0;
  writeln(x < maxreal)
end.
