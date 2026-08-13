{ sin, cos and arctan — three required functions of ISO 7185 §6.6.6.2 that no
  program in this corpus had ever called.

  `tests/builtins.pas` covers `sqrt`, `exp` and `ln`; the only occurrences of
  the other three anywhere were in `tests/extended/complex.pas`, on values of
  `complex`, which is a different overload in a different standard (ADR-0049).
  So the real-valued versions had never been compiled, let alone run — the
  fourth time a count of what the corpus reaches has turned something up
  (ADR-0067), and the first where what was missing is a *required function*
  rather than a rule about one.

  §6.7.2.2 makes the accuracy of these approximations implementation-defined,
  so this program asserts identities rather than digits wherever it can: the
  Pythagorean identity, arctan's relation to pi, and the values at zero, which
  are exact in binary64. Where it does print digits it prints few, because a
  golden file that pins the last bit of a libm result is a test of libm.

  §6.6.6.2 also makes the argument `integer or real` for all six, so each is
  called both ways — the integer form widens, and is the one a reader is most
  likely to assume does not exist. }
program transcendental(output);

var
  x, y: real;
  i: integer;

begin
  { Exact at zero, in any implementation that is approximating at all. }
  x := 0.0;
  writeln('zero    ', sin(x):5:2, cos(x):5:2, arctan(x):5:2);

  { The identity that says sin and cos are what they claim to be, at a value
    where neither is exact. }
  x := 1.0;
  y := sqr(sin(x)) + sqr(cos(x));
  writeln('pythag  ', y:6:4);

  { arctan(1) is pi/4, so this is pi to as many places as a golden file should
    ever hold. }
  writeln('pi      ', (4.0 * arctan(1.0)):8:5);

  { §6.6.6.2's other argument type. `sin(i)` is `sin` of the real i denotes,
    so the two lines below must agree. }
  i := 1;
  writeln('real    ', sin(x):8:5, ' ', cos(x):8:5, ' ', arctan(x):8:5);
  writeln('integer ', sin(i):8:5, ' ', cos(i):8:5, ' ', arctan(i):8:5);

  { And the three that were already covered, called the way that was not:
    §6.6.6.2 admits an integer argument to each of these too. }
  i := 4;
  writeln('roots   ', sqrt(i):6:3, ' ', exp(i):9:4, ' ', ln(i):6:4);

  { sqr is defined for both and yields the argument's own type (table 2), so
    this pair is an integer and a real, not two reals. }
  writeln('sqr     ', sqr(i):1, ' ', sqr(2.0):5:2);

  { arctan is odd and cos is even: two more identities that hold whatever the
    approximation is. }
  x := 0.75;
  writeln('odd     ', (arctan(x) + arctan(-x)):5:2);
  writeln('even    ', (cos(x) - cos(-x)):5:2)
end.
