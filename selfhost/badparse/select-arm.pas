{ AP 6.9.3.15: an arm's head is an operation and then a colon. }
program selectarm(output);
type ints = channel [2] of integer;
var c: ints; n: integer;
begin
  select
    receive(c, n) writeln(n)
  end
end.
