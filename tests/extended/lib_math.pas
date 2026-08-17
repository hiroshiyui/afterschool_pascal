{ PasMath. The values chosen here are mostly about *overflow*: this compiler
  traps on integer overflow rather than wrapping (ADR-0014), so a library
  formula that forms an intermediate outside -maxint..maxint stops the program
  instead of returning a wrong answer. Every case below at the top of the range
  is one the obvious formula would have failed -- ISqrt(maxint) by Newton's
  first step, Lcm by multiplying before dividing, NextRandom by forming
  16807 * state -- and each would fail loudly, which is why they are worth
  pinning. }
program lib_math(output);

import PasMath;

var
  i, n, r, lo, hi: integer;
  sum: integer;
  counts: array [0..4] of integer;

begin
  writeln('IMin/IMax');
  writeln(IMin(3, 7):1, ' ', IMax(3, 7):1);
  writeln(IMin(-3, -7):1, ' ', IMax(-3, -7):1);
  writeln(IMin(4, 4):1, ' ', IMax(4, 4):1);
  writeln(IMin(-maxint, maxint):1, ' ', IMax(-maxint, maxint):1);

  writeln('Gcd');
  writeln(Gcd(12, 18):1);
  writeln(Gcd(18, 12):1);
  writeln(Gcd(17, 5):1);
  writeln(Gcd(0, 5):1);
  writeln(Gcd(5, 0):1);
  writeln(Gcd(0, 0):1);
  { Negative arguments go through abs, which is total here: -maxint is a value
    of the type and maxint is its negation, so there is no INT_MIN to trip on. }
  writeln(Gcd(-12, 18):1);
  writeln(Gcd(-12, -18):1);
  writeln(Gcd(maxint, maxint):1);

  writeln('Lcm');
  writeln(Lcm(4, 6):1);
  writeln(Lcm(0, 5):1);
  writeln(Lcm(5, 0):1);
  writeln(Lcm(-4, 6):1);
  writeln(Lcm(17, 5):1);
  { maxint is 2147483647 = 2^31 - 1, which is prime, so its lcm with itself is
    itself -- and `abs(x) * abs(y) div g` would have formed maxint * maxint
    first and trapped. Dividing first is what makes this line printable. }
  writeln(Lcm(maxint, maxint):1);

  writeln('ISqrt');
  writeln(ISqrt(0):1);
  writeln(ISqrt(1):1);
  writeln(ISqrt(2):1);
  writeln(ISqrt(3):1);
  writeln(ISqrt(4):1);
  writeln(ISqrt(-9):1);
  writeln(ISqrt(99):1);
  writeln(ISqrt(100):1);
  writeln(ISqrt(101):1);
  { 46340^2 = 2147395600 <= maxint and 46341^2 = 2147488281 > maxint, so this is
    the exact boundary the type allows and the answer must be 46340. Newton's
    iteration cannot reach it: its first step forms maxint + maxint div maxint. }
  writeln(ISqrt(maxint):1);
  writeln(ISqrt(2147395600):1);
  writeln(ISqrt(2147395599):1);

  { Exact for every perfect square and its two neighbours, checked rather than
    sampled at a few points. A single wrong answer prints its own line, so the
    golden stays short while the sweep is wide. }
  write('exact over 0..3000: ');
  n := 0;
  for i := 0 to 3000 do begin
    r := ISqrt(i * i);
    if r <> i then begin writeln('ISqrt(', i * i:1, ') = ', r:1); n := n + 1 end;
    if i > 0 then begin
      if ISqrt(i * i - 1) <> i - 1 then
        begin writeln('below ', i:1, ' wrong'); n := n + 1 end;
      if ISqrt(i * i + 1) <> i then
        begin writeln('above ', i:1, ' wrong'); n := n + 1 end
    end
  end;
  writeln(n:1, ' wrong');

  writeln('NextRandom');
  { A fixed seed is a fixed sequence, which is the promise SeedRandom makes. }
  SeedRandom(1);
  for i := 1 to 5 do write(NextRandom:12);
  writeln;
  { The same seed again gives the same five, so the generator carries no hidden
    state beyond what SeedRandom sets. }
  SeedRandom(1);
  for i := 1 to 5 do write(NextRandom:12);
  writeln;
  { A different seed gives a different sequence. }
  SeedRandom(2);
  for i := 1 to 5 do write(NextRandom:12);
  writeln;
  { Seed 0 is the one state the recurrence cannot leave, and SeedRandom maps it
    away rather than accepting it: a generator stuck at 0 would print five
    zeros here. }
  SeedRandom(0);
  for i := 1 to 5 do write(NextRandom:12);
  writeln;

  { Every value stays inside 1..RandomLimit - 1 over a long run, which is what
    Schrage's factoring is for: a single trap would end the program instead of
    printing this line. }
  SeedRandom(12345);
  lo := maxint;
  hi := 0;
  for i := 1 to 200000 do begin
    r := NextRandom;
    if r < lo then lo := r;
    if r > hi then hi := r
  end;
  writeln('200000 draws stayed in range: ', (lo >= 1) and (hi <= RandomLimit - 1));

  writeln('RandomBelow');
  writeln(RandomBelow(0):1);
  writeln(RandomBelow(-5):1);
  writeln(RandomBelow(1):1);
  { Every value below n appears and none outside it. The counts are printed as a
    total rather than individually, so the case does not depend on the
    generator's exact stream -- only on its range being covered. }
  SeedRandom(7);
  for i := 0 to 4 do counts[i] := 0;
  for i := 1 to 50000 do begin
    r := RandomBelow(5);
    if (r < 0) or (r > 4) then writeln('out of range: ', r:1)
    else counts[r] := counts[r] + 1
  end;
  sum := 0;
  for i := 0 to 4 do sum := sum + counts[i];
  writeln('50000 draws below 5, all in range: ', sum = 50000);
  n := 0;
  for i := 0 to 4 do if counts[i] > 0 then n := n + 1;
  writeln('distinct values seen: ', n:1)
end.
