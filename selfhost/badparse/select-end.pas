{ AP 6.9.3.15: arms are separated by ';', as a case-statement's are, so an arm
  that follows one without a separator is where the closing `end` was due. }
program selectend(output);
type ints = channel [2] of integer;
var c, d: ints; n: integer;
begin
  select
    receive(c, n): writeln(n)
    receive(d, n): writeln(n)
  end
end.
