{ Two tasks and a channel: a producer, a filter, and the program reading
  the end of the line.

  A `task` is a procedure only `spawn` may start; a `channel [n] of T` is a
  bounded queue and a handle (ADR-0268). A task is given copies of its
  value arguments and references to its channels, and can reach nothing
  else -- there is no shared variable to race on, which is what makes the
  output below the same on every run. Every task a block spawned is joined
  before the block ends.

  Each stage ends by closing the channel it writes to: `release(c)` closes
  a channel wherever it is written, so the stage downstream sees the queue
  drain and then end (ADR-0302). The first draft of this program used a
  sentinel value instead, because a task's release used to drop its own
  reference and leave the channel open -- which made a pipeline hang with
  nothing reported anywhere. Nothing is imported. }
program pipeline_tasks(output);

type Ints = channel [8] of integer;

task Producer(out: Ints; n: integer);
var i, k: integer;
begin
  for i := 1 to n do send(out, i * i);
  k := release(out)
end;

task OddOnly(src, dst: Ints);
var v, k: integer;
begin
  while receive(src, v) do
    if odd(v) then send(dst, v);
  k := release(dst)
end;

var squares, odds: Ints; v: integer;

begin
  spawn Producer(squares, 10);
  spawn OddOnly(squares, odds);
  while receive(odds, v) do writeln(v:1);
  writeln('done')
end.
