{ What the exponentiating operators refuse. Sema accumulates, so one run
  reports all of them; the refusal of `**` under --std=iso7185 is lexical and
  lives in selfhost/torture.pas, and the non-associativity is a parse error and
  lives in selfhost/badparse/. }
program PowErrors(output);
type
  colour = (red, green);
var
  i: integer;
  r: real;
  c: colour;
  b: boolean;
  s: set of 1..9;

begin
  { both operands of either operator have to be numbers -- an enumeration is
    an ordinal type but not a numeric one }
  i := c pow 2;
  i := 2 pow c;
  r := b ** 2;
  r := 2 ** s;

  { the right operand of `pow` is an integer by table 3: exponentiation to an
    *integer* power is what distinguishes it from `**` }
  r := 2.0 pow 1.5;
  r := 2 pow r;

  { `not` binds tighter than an exponentiating operator (6.8.1 gives it the
    highest precedence of all), so the left operand of `pow` here is `not b`
    and the one complaint is about that. Reading it as not (b pow 2) would
    complain twice, which is how the two groupings are told apart -- neither
    is a legal expression, so only a diagnostic can show which was parsed. }
  i := ord(not b pow 2);

  { `**` yields a real however it is written, so an integer cannot hold it --
    this is the one place the two operators are told apart by a diagnostic
    rather than by a value }
  i := 2 ** 3;

  { and `pow` yields the type of its left operand, so a real base does too }
  i := 2.0 pow 3;

  writeln(i:1, r:1:1)
end.
