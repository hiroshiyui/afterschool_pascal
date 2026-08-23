{ ADR-0121's first library user, exercised as a program: PasMathX exports
  Pascal and keeps `external` to itself, so nothing here names a foreign
  routine and nothing here could -- the interface has no way to say one.

  What the wrappers add over the C functions is the part C cannot: a routine
  that can fail answers ADR-0120's result shape instead of a NaN, and a caller
  that reads the payload without asking traps. `-inf` and `nan` are exactly
  the values the standards' own `write` has no defined text for, which is a
  second reason not to hand one back. }
program lib_mathx(output);

import PasError; PasMathX;

var
  r: RealResult;

begin
  { Total, so a plain function: every real has a cube root, negative ones too. }
  writeln('cbrt   27    = ', Cbrt(27.0):0:1);
  writeln('cbrt  -8     = ', Cbrt(-8.0):0:1);

  r := Log10(1000.0);
  writeln('log10  1000  = ', r.val:0:1, '  ok=', r.ok);

  r := Log2(1024.0);
  writeln('log2   1024  = ', r.val:0:1, '  ok=', r.ok);

  { Not positive: errRange, because 6.7.2.2 makes `ln` of one an error and a
    library may not halt (ADR-0116). The tag went false when `code` was
    written -- no line in PasMathX assigns it. }
  r := Log10(-1.0);
  writeln('log10 -1     = ', ErrorText(r.cause), '  ok=', r.ok);

  r := FMod(7.0, 3.0);
  writeln('fmod   7 3   = ', r.val:0:1);

  r := FMod(7.0, 0.0);
  writeln('fmod   7 0   = ', ErrorText(r.cause), '  failed=', Failed(r.cause));

  { The alternative to branching, for a caller with a default in hand. }
  writeln('or 0 of bad  = ', RealOr(FMod(1.0, 0.0), 0.0):0:1);
  writeln('or 0 of good = ', RealOr(FMod(9.0, 4.0), 0.0):0:1)
end.
