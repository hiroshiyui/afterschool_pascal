{ PasMath -- integer arithmetic that does not trap, and a random source.

  Everything here is written against one property of this compiler: integer
  `+ - *` and `sqr` go through a checked path and *stop the program* on overflow
  rather than wrapping (ADR-0014), and the integer type is -maxint..maxint,
  narrower than the i32 behind it. A library routine may therefore not compute a
  quantity it is about to divide back down -- the intermediate has to fit. Each
  function below says where that changed the obvious formula.

  There is no random source in either standard, and nothing here can ask the
  operating system for one: `runtime/pasrt.c` is the only door to the outside
  and this library adds nothing to it (ADR-0109 puts a foreign-function
  interface ahead of that). So the generator is arithmetic, seeded by the caller
  or by the clock through the required `GetTimeStamp`, and it is reproducible on
  purpose -- which is what a test wants and what a simulation wants. It is not
  suitable for anything requiring unpredictability, and the interface says so
  where a caller will read it. }

module PasMath;

export PasMath = (
  IMin, IMax, Gcd, Lcm, ISqrt,
  RandomLimit, SeedRandom, SeedRandomFromClock, NextRandom, RandomBelow);

{ Not spelled `MinInt`/`MaxInt`: 6.1.3 case-folds identifiers, so `MaxInt` and
  the required `maxint` are one name, and exporting it would shadow the constant
  in every importer's block. }
function IMin(x, y: integer): integer;
function IMax(x, y: integer): integer;

{ The greatest common divisor of |x| and |y|; Gcd(0, 0) is 0. }
function Gcd(x, y: integer): integer;

{ The least common multiple of |x| and |y|; Lcm(x, 0) is 0. The result can leave
  the integer type where the arguments did not, and this reports that by
  trapping rather than by returning a wrong answer. }
function Lcm(x, y: integer): integer;

{ The largest r with r * r <= n, for n >= 0; 0 for n < 0. Exact for every value
  of the type, maxint included -- there is no real arithmetic anywhere in it, so
  there is no rounding to be wrong about near the top of the range. }
function ISqrt(n: integer): integer;

{ One more than the largest value NextRandom returns, so a caller can scale
  without knowing the generator. }
const RandomLimit = 2147483647;

{ Fix the sequence. Any seed is accepted; the generator's state is kept away
  from 0, which is the one value its recurrence cannot leave. }
procedure SeedRandom(s: integer);

{ Seed from the clock, via 6.7.6.9's GetTimeStamp. Reproducibility is what this
  gives up, and it is the only thing here that does. }
procedure SeedRandomFromClock;

{ The next value in 1..RandomLimit - 1. Uniform over that range and nothing
  more: this is a Lehmer generator, adequate for tests, sampling and
  simulation, and **not** for anything that must be unpredictable. }
function NextRandom: integer;

{ A value in 0..n - 1, or 0 for n <= 0. The modulo bias is removed by rejecting
  the short tail of the generator's range rather than ignored, so every value
  below n is equally likely. }
function RandomBelow(n: integer): integer;

end;

{ The generator's state. A module has exactly one activation (6.2.3.6), so this
  is a global in the emitted IR (ADR-0053) and every importer shares the one
  sequence -- which is what makes SeedRandom's promise meaningful. }
var
  state: integer;

function IMin;
begin
  if x < y then IMin := x else IMin := y
end;

function IMax;
begin
  if x > y then IMax := x else IMax := y
end;

function Gcd;
var a, b, t: integer;
begin
  { abs is safe here where it would not be in C: -maxint is a value of the type
    and maxint is its negation, there being no INT_MIN in this language. }
  a := abs(x);
  b := abs(y);
  while b <> 0 do begin
    t := b;
    b := a mod b;
    a := t
  end;
  Gcd := a
end;

function Lcm;
var g: integer;
begin
  if (x = 0) or (y = 0) then
    Lcm := 0
  else begin
    g := Gcd(x, y);
    { Divide *before* multiplying. `abs(x) * abs(y) div g` is the same number
      and forms a product that overflows for arguments whose lcm fits, which
      here is a trap rather than a wrong answer. }
    Lcm := (abs(x) div g) * abs(y)
  end
end;

function ISqrt;
var r, b, t: integer;
begin
  if n < 0 then
    ISqrt := 0
  else begin
    { The digit-by-digit binary method: r is built one bit at a time, and the
      only products formed are by 2 and by 4 on quantities already known to be
      small enough. Newton's iteration is the obvious alternative and cannot be
      used -- its first step forms `x + n div x`, which for n = maxint is
      maxint + 1 and traps before the loop can converge. }
    r := 0;
    b := 1;
    { The largest power of four not exceeding n. Guarded as `b <= n div 4` so
      the multiplication below cannot leave the type. }
    while b <= n div 4 do
      b := b * 4;
    while b > 0 do begin
      t := r + b;
      r := r div 2;
      if t <= n then begin
        n := n - t;
        r := r + b
      end;
      b := b div 4
    end;
    ISqrt := r
  end
end;

procedure SeedRandom;
begin
  { The recurrence has 0 as a fixed point, so it is the one state to refuse.
    Everything else is mapped into 1..RandomLimit - 1. }
  state := abs(s) mod (RandomLimit - 1) + 1
end;

procedure SeedRandomFromClock;
var t: TimeStamp; s: integer;
begin
  GetTimeStamp(t);
  { 6.7.6.9 leaves a TimeStamp's fields to the implementation beyond the six
    subranges of 6.4.3.4, so this mixes the three time-of-day fields rather
    than assuming any one of them is fine-grained. }
  s := 0;
  if t.DateValid then
    s := ((t.year * 12 + t.month) * 31 + t.day);
  if t.TimeValid then
    s := ((s * 24 + t.hour) * 60 + t.minute) mod (RandomLimit - 1)
        + t.second;
  SeedRandom(s)
end;

function NextRandom;
var hi, lo, t: integer;
begin
  { Lehmer: state := 16807 * state mod 2147483647, by Schrage's factoring so
    that no intermediate leaves the type. 16807 * state would need 46 bits;
    with q = m div a and r = m mod a, both products below are bounded --
    16807 * lo < 16807 * 127773 and 2836 * hi <= 2836 * 16807 -- and each fits
    with room to spare. This is the reason the obvious one-line form is not
    written here: it would trap on nearly every call. }
  hi := state div 127773;
  lo := state mod 127773;
  t := 16807 * lo - 2836 * hi;
  if t > 0 then state := t else state := t + RandomLimit;
  NextRandom := state
end;

function RandomBelow;
var limit, v: integer;
begin
  if n <= 0 then
    RandomBelow := 0
  else begin
    { Reject the tail that would make the low residues more likely: the
      generator yields 1..RandomLimit - 1, so `limit` is the largest multiple of
      n within that range and anything above it is drawn again. The loop
      terminates with probability 1 and in practice at once, the rejected band
      being narrower than n. }
    limit := (RandomLimit - 1) div n * n;
    repeat
      v := NextRandom
    until v <= limit;
    RandomBelow := (v - 1) mod n
  end
end;

{ 6.2.3.6: a module's activation commences before the main-program-block, so a
  caller that never seeds still gets a defined sequence rather than state 0 --
  which the recurrence could not leave. Fixed, not from the clock: a library
  whose output changed run to run without being asked would be the wrong
  default, and SeedRandomFromClock is one call away. }
to begin do
  SeedRandom(1);

end.
