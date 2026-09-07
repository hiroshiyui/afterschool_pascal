{ A task-declaration in a module-block (AP 6.7.8, ADR-0365): the same
  two-token spelling the block's declaration-part takes, in the position
  6.11.1 gives a procedure-and-function-declaration-part. It is not exported
  -- a module-heading holds no task -- and the routine the module exports
  spawns it. }
module taskmod interface;
export taskmod = (SumTo);
procedure SumTo(n: integer; var total: integer);
end.

module taskmod implementation;
type ch = channel [4] of integer;

task Count(out: ch; n: integer);
var i, k: integer;
begin
  for i := 1 to n do send(out, i);
  k := release(out)
end;

procedure SumTo;
var c: ch; v: integer;
begin
  total := 0;
  spawn Count(c, n);
  while receive(c, v) do total := total + v
end;
end.
