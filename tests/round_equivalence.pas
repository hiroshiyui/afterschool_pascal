{ ISO 7185 6.6.6.3 (and ISO/IEC 10206:1991 6.7.6.3) define round by
  *equivalence* rather than by a rounding mode:

    "If x is positive or zero, round(x) shall be equivalent to trunc(x+0.5);
     otherwise, round(x) shall be equivalent to trunc(x-0.5)."

  That is a stronger statement than "round half away from zero", and the two
  are different functions. They agree at every halfway point -- which is what
  the clause's own examples exercise, and what let `llvm.round` stand here for
  a long time -- and they disagree wherever x +- 0.5 is inexact, because the
  addition itself rounds.

  0.49999999999999994 is the smallest double below one half. Adding 0.5 to it
  gives a sum that is not representable, and the nearest double to that sum is
  exactly 1.0 -- so the clause's trunc(x+0.5) is 1, while the value nearest x
  is 0. A processor emitting a round-half-away-from-zero instruction answers 0
  and contradicts the clause.

  The last two lines are the check that costs nothing to state and would have
  caught this the moment it was written: the program computes the clause's
  right-hand side itself, so the two columns must agree for every row. }
program round_equivalence(output);

var x: real;

procedure both(label_: char; v: real);
begin
  write(label_, ': round=', round(v):3, '  trunc(v+-0.5)=');
  if v >= 0.0 then writeln(trunc(v + 0.5):3)
  else writeln(trunc(v - 0.5):3)
end;

begin
  { The clause's own examples: these hold under either reading. }
  both('a', 3.5);
  both('b', -3.5);
  both('c', 3.4);
  both('d', -3.4);

  { 2.5 is where "round to even" would answer 2. The clause asks for
    trunc(3.0), so a processor doing banker's rounding is wrong here too. }
  both('e', 2.5);

  { The rows that separate the two readings. }
  x := 0.49999999999999994;
  both('f', x);
  both('g', -x);

  { The range check now applies to the shifted value rather than to the
    rounded one, which is what the clause's own trunc(x+0.5) asks for. This row
    rounds to maxint and must not trap. }
  both('h', 2147483646.7);

  writeln('done')
end.
