{ Two tasks and a channel: a producer, a filter, and the program reading
  the end of the line.

  A `task` is a procedure only `spawn` may start; a `channel [n] of T` is a
  bounded queue and a handle (ADR-0268). A task is given copies of its
  value arguments and references to its channels, and can reach nothing
  else -- there is no shared variable to race on, which is what makes the
  output below the same on every run. Every task a block spawned is joined
  before the block ends.

  The stages end on a sentinel. `release(c)` on a channel a task was
  *handed* drops only that task's reference -- a worker must not close a
  channel its colleagues still read -- so a stage cannot close the channel
  downstream of it, and a value the data can never take does the job.
  Nothing is imported. }
program pipeline_tasks(output);

type Ints = channel [8] of integer;

task Producer(out: Ints; n: integer);
var i: integer;
begin
  for i := 1 to n do send(out, i * i);
  send(out, 0)                     { the sentinel: no square of 1..n is 0 }
end;

task OddOnly(src, dst: Ints);
var v: integer;
begin
  v := -1;
  while v <> 0 do
    if receive(src, v) then
      if odd(v) or (v = 0) then send(dst, v)
end;

var squares, odds: Ints; v: integer;

begin
  spawn Producer(squares, 10);
  spawn OddOnly(squares, odds);
  v := -1;
  while v <> 0 do
    if receive(odds, v) then
      if v <> 0 then writeln(v:1);
  writeln('done')
end.
