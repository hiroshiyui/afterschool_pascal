{ AP 6.4.16 and AP 6.9.3.12-13: tasks and channels.

  ADR-0201 decided the shape of this construct and declined to build it, and
  the shape is what is here: **share-nothing**. A task is given a copy of every
  value it is passed and a reference to every channel, and there is no third
  way for it to reach anything -- Pascal has no address-of and `new` is the
  only producer of a pointer, so a task's body cannot name a variable of the
  activation that spawned it except through a formal.

  **Every answer below is deterministic**, which a test of concurrency has to
  be: the sums do not depend on the order the workers ran in, and the counts
  are of values sent rather than of who sent them. What is *not* deterministic
  is deliberately not printed.

  The join at the end of a block is what makes the lending safe, and it is why
  a program can hand a task a channel it declared: ADR-0201's sentence -- a
  borrow cannot outlive the call, because the caller is not running during
  it -- is false for two threads of control, and the join is what makes it
  true again. }
program concurrency(output);

type
  Ints = channel [32] of integer;
  Point = record x, y: integer end;
  Points = channel [8] of Point;

var
  jobs, results: Ints;
  shapes: Points;
  k, v, total, count: integer;
  p: Point;

{ A worker: reads until the channel is closed and drained, and answers on
  another. Four of these run over one job channel, which is the whole of what
  a worker pool is. }
task Worker(jobs, results: Ints);
var n: integer;
begin
  while receive(jobs, n) do send(results, n * n)
end;

{ A task given a *copy* of a value. Every one of the four gets its own `base`,
  and nothing it does to it is visible anywhere else. }
task Counter(out: Ints; base, times: integer);
var i: integer;
begin
  for i := 1 to times do send(out, base)
end;

{ A structured value crosses by being copied into the argument block, which
  the task owns and frees -- so the record outlives the statement that
  spawned it, where a frame slot of the spawning activation would not. }
task Shaper(out: Points; seed: Point);
begin
  send(out, seed)
end;

begin
  { --- a worker pool ---------------------------------------------------- }
  for k := 1 to 4 do spawn Worker(jobs, results);
  for k := 1 to 20 do send(jobs, k);
  { Closing the job channel is how the workers are told there is no more
    work: each drains what is left and then `receive` answers false. }
  k := release(jobs);
  total := 0;
  for k := 1 to 20 do
    if receive(results, v) then total := total + v;
  writeln('sum of squares 1..20 : ', total:1);

  { --- a value crosses by copy ------------------------------------------ }
  for k := 1 to 4 do spawn Counter(results, k, 3);
  total := 0;
  count := 0;
  for k := 1 to 12 do
    if receive(results, v) then begin
      total := total + v;
      count := count + 1
    end;
  writeln('12 values, sum       : ', count:1, ' ', total:1);

  { --- a record crosses the same way ------------------------------------ }
  p.x := 3;
  p.y := 4;
  spawn Shaper(shapes, p);
  { The spawning activation may change its own copy at once: the task has
    one of its own. }
  p.x := 0;
  p.y := 0;
  if receive(shapes, p) then writeln('the record arrived  : ', p.x:1, ' ',
                                     p.y:1);

  { --- and a block may spawn again ------------------------------------- }
  { The join happens when the *block* ends, so the four workers above are
    still running here -- they are not, in fact: `release(jobs)` closed their
    channel and each returned. What this shows is that the task set grows and
    the second round is joined with the first. }
  for k := 1 to 2 do spawn Counter(results, 100, 1);
  total := 0;
  for k := 1 to 2 do
    if receive(results, v) then total := total + v;
  writeln('spawned again, sum  : ', total:1)
end.
