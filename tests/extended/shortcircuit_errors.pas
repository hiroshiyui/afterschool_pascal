{ What the short-circuit operators refuse. §6.8.3.3 gives them Boolean
  operands and a Boolean result, exactly as for `and` and `or` -- the four
  differ only in whether the right operand is evaluated, which is not a
  question about types. Sema accumulates, so one run reports all of these. }
program ShortCircuitErrors(output);
var
  i: integer;
  b: boolean;
  s: set of 1..9;

begin
  b := 1 and then b;
  b := b and then 1;
  b := i or else b;
  b := b or else s;

  { the result is boolean however true the operands look }
  i := b and then b;

  { `not` binds tighter than either (§6.8.1 gives it the highest precedence of
    all), so this is (not i) and then b and the one complaint is about `not`.
    Read as not (i and then b) it would complain twice, which is how the two
    groupings are told apart -- neither is a legal expression, so only a
    diagnostic can show which was parsed. }
  b := not i and then b;

  writeln(i:1, b)
end.
