{ ISO/IEC 10206:1991 §6.8.2's constant-expression, where the value is real.

  §6.3.2's own example of a constant-definition-part opens with

      unity = 1.0;
      third = unity/3.0;                    -- and cites 6.8.2 for it

  and this compiler refused the second line until ADR-0227: a real constant is
  carried as the text that was written (ADR-0025), so folding one needed a
  decimal-to-binary conversion and a way to write the result back. Both are
  §6.10.4's `readstr` and `writestr`, which this compiler already implements
  and may use, being an Extended Pascal program itself.

  What is pinned here is of two kinds, and the split is deliberate. An
  operation whose result IEEE 754 fixes exactly — the four arithmetic
  operators, `abs`, `sqr`, the comparisons, the two conversions — has its value
  written out, because that value is the same on every conforming processor.
  A *mathematical* function's accuracy is implementation-defined (§6.4.2.2),
  so writing `arctan(1)` to twenty digits would pin this machine's libm and
  not the language. What is asserted of those instead is the property §6.8.2
  NOTE 2 asks an implementation to state: the folded value and the value the
  emitted code computes are the same one. }
program ConstExprReals(output);

const
  unity = 1.0;
  third = unity / 3.0;
  { the four arithmetic operators, exact in binary64 }
  sum   = 1.25 + 2.5;
  diff  = 1.25 - 2.5;
  prod  = 1.25 * 2.5;
  { §6.8.3.2 table 3 note (3): `/` makes a real of two integers }
  half  = 7 / 2;
  { note (4): an integer operand stands for a real approximation to its value }
  mixed = 2 * 1.5;
  { §6.7.6.1 gives abs and sqr the type of the operand }
  sq    = sqr(2.5);
  ab    = abs(-2.5);
  { §6.8.3.2's two exponentiating operators. `**` yields a real whatever its
    operands are; `pow` yields the type of its left one, so this is the real
    arm and `2 pow 3` elsewhere is still the integer 8. }
  pw    = 2.0 ** 10;
  pwi   = 2.0 pow 10;
  { §6.6.6.3's conversions, whose results are integers -- so what they needed
    was the conversion alone and never a formatter }
  cut   = trunc(3.7);
  ncut  = trunc(-3.7);
  near  = round(3.5);
  nnear = round(-3.5);
  { §6.6.6.3 defines round(x) as trunc(x+0.5), and the addition is where the
    two part company: for this value the sum is exactly 1.0. }
  edge  = round(0.49999999999999994);
  { §6.8.3.5 over reals }
  lt    = 1.5 < 2.5;
  eq    = 1.5 = 1.5;
  ge    = 2.5 >= 2.5;
  { a folded real is an operand of the next fold, which is what makes the
    round trip through the pool worth pinning }
  twice = 2 * third;
  { §6.4.2.2's required real constants are constants like any other }
  tiny  = minreal * 1.0;
  { §6.7.6.2's six, whose values are not written out here }
  pi    = 4 * arctan(1);
  e     = exp(1.0);
  rt2   = sqrt(2.0);
  lg    = ln(2.0);
  sn    = sin(1.0);
  cs    = cos(1.0);

var v: real;

begin
  writeln('third ', third:22);
  writeln('sum   ', sum:22, diff:22);
  writeln('prod  ', prod:22, half:22);
  writeln('mixed ', mixed:22, sq:22);
  writeln('ab    ', ab:22, pw:22);
  writeln('pwi   ', pwi:22, twice:22);
  writeln('trunc ', cut:1, ' ', ncut:1, '  round ', near:1, ' ', nnear:1,
          '  edge ', edge:1);
  writeln('rel   ', lt, ' ', eq, ' ', ge);
  writeln('tiny  ', tiny = minreal);

  { The accuracy claim, one function at a time: the constant the folder
    computed and the value the emitted code computes are one value. }
  v := 4 * arctan(1.0); writeln('pi  ', v = pi);
  v := exp(1.0);        writeln('e   ', v = e);
  v := sqrt(2.0);       writeln('rt2 ', v = rt2);
  v := ln(2.0);         writeln('lg  ', v = lg);
  v := sin(1.0);        writeln('sn  ', v = sn);
  v := cos(1.0);        writeln('cs  ', v = cs)
end.
