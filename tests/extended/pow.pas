{ ISO/IEC 10206:1991 6.8.1 adds a precedence level between `not` and the
  multiplying operators, and 6.8.3.1 puts two operators in it:

    factor                  = primary [ exponentiating-operator primary ]
    exponentiating-operator = '**' | 'pow'

  Table 3 of 6.8.3.2 is what makes them two operators rather than one spelling
  of the same thing:

    **   exponentiation to a real power.  An integer operand stands for a real
         approximation to its value, so the result is *always* real.
    pow  exponentiation to an integer power.  The right operand must be an
         integer, and the result has the type of the LEFT operand.

  So `2 pow 3` is the integer 8 and `2 ** 3` is the real 8.0, and only the
  first of them may be assigned to an integer.

  Not a valid ISO 7185 program: that language has neither operator. }
{ `pow` is a word-symbol here, so it cannot also be this program's name --
  which is exactly why the two standards are not nested (ADR-0033). }
program Powers(output);
const
  { an exponentiating-operator is not a constant-expression in ISO 7185 terms,
    so these are ordinary constants the expressions below build on }
  two = 2;
  half = 0.5;
var
  i, j: integer;
  r: real;
  n: 0..1000;

begin
  { `pow` on integers is integer arithmetic, exact and closed }
  writeln(2 pow 10:1, ' ', 10 pow 3:1, ' ', 7 pow 0:1, ' ', 0 pow 5:1);

  { and it may go straight into an integer variable, which is the whole point
    of the standard having it }
  i := 3 pow 4;
  writeln(i:1);

  { `**` yields a real however it is written, so this one needs a real }
  r := 2 ** 10;
  writeln(r:1:1, ' ', 2 ** 10:1:1, ' ', 2.0 ** 10:1:1);

  { a real exponent is what ** is for }
  writeln(9 ** half:1:4, ' ', 2 ** half:1:4);

  { a real base with an integer exponent is `pow` again, and its result is
    real because its left operand is }
  writeln(1.5 pow 2:1:4, ' ', 2.0 pow 10:1:1);

  { a negative base is fine for `pow`, where the exponent is a whole number }
  writeln((0 - 2) pow 3:1, ' ', (0 - 2) pow 4:1, ' ', (0 - 1.5) pow 3:1:3);

  { 6.8.3.2 defines x pow y for negative y as (1 div x) pow (-y) -- integer
    division, so every base but 1 and -1 gives zero }
  writeln(2 pow (0 - 3):1, ' ', 1 pow (0 - 3):1, ' ', (0 - 1) pow (0 - 3):1);

  { the real form of the same rule is a real reciprocal, and is not zero }
  writeln(2.0 pow (0 - 3):1:5, ' ', 2 ** (0 - 3):1:5);

  { A sign binds to the whole factor, so this is -(2 pow 2) and not 4 -- the
    rule that already makes -7 mod 3 be -(7 mod 3). }
  writeln(-2 pow 2:1, ' ', -2 ** 2:1:1);

  { The same question one level down. ISO 7185's grammar has no sign inside a
    factor at all -- a sign belongs to a simple-expression -- but this parser
    accepts one, and where it does the sign takes the whole factor, exactly as
    the standard's own sign takes the whole term. So this is 3 * -(2 pow 2). }
  writeln(3 * -2 pow 2:1);

  { `not` binds tighter than an exponentiating operator (6.8.1 gives it the
    highest precedence of all), so the left operand here is `not false` }
  writeln(ord(not false) pow 3:1);

  { exponentiation binds tighter than the multiplying operators, so no
    parentheses are needed to say "twice 2 to the third" }
  writeln(3 * two pow 3:1, ' ', 3 * two ** 3:1:1);

  { and tighter than the adding operators }
  writeln(1 + two pow 3:1);

  { it is an ordinary operand everywhere an expression may go }
  n := 2 pow 5;
  for j := 1 to 3 do
    if j pow 2 > 4 then
      writeln('j = ', j:1, ', n = ', n:1);

  { both operands may be arbitrary expressions, evaluated once each }
  i := 2;
  j := 3;
  { and one operator is all a factor may have, so a chain has to say which
    grouping it means }
  writeln((i + 1) pow (j - 1):1, ' ', (i pow j) pow 1:1)
end.
