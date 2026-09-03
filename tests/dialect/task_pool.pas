{ AP 6.4.17 and AP 6.9.3.12: a pool of named tasks (ADR-0312).

  This is the shape that made the task-type a *variable-access* rather than a
  name. A task-type is a handle-type, an array of handles was already
  admissible, and `spawn ws[i] := Worker(...)` is therefore what a program
  spawning n workers writes -- so waiting for one of them is a subscript and
  not a new construct.

  Every answer here is deterministic, which a test of concurrency has to be:
  the total does not depend on the order the workers ran in, and no worker's
  identity is printed. What the waits buy is the *phase* -- every worker has
  ended before the channel is drained -- and the join at the end of the block
  would have given the same guarantee one statement later. }
program task_pool(output);

type Ints = channel [16] of integer;
     { A task-variable is a handle-variable, so a record may hold one and a
       pointer may identify one. Both spellings of the target are pinned
       below, because the statement takes a variable-access and each selector
       is a place it could have been got wrong. }
     Pair = record t: task; label_: integer end;

var
  jobs: Ints;
  ws: array [1..3] of task;
  r: Pair;
  p: ^task;
  i, v, total: integer;

task Worker(out: Ints; base: integer);
var j: integer;
begin
  for j := 1 to 3 do send(out, base * 10 + j)
end;

begin
  for i := 1 to 3 do
    spawn ws[i] := Worker(jobs, i);
  writeln('spawned       : ', ws[1] <> nil);

  { Waiting for each in turn. A subscript is a variable-access, so the
    statement that names one task names any of them. }
  for i := 1 to 3 do
    wait(ws[i]);
  writeln('all joined    : TRUE');

  { Every worker has ended, so the channel holds exactly nine values -- and
    knowing that is what the waits bought. The count is read rather than the
    close, because AP 6.4.16.4's three spellings all empty the variable as
    well as closing the channel, so the activation that owns a channel cannot
    close it and then drain it; a task can, holding a reference of its own,
    and that is what examples/pipeline_tasks.pas does. }
  total := 0;
  for i := 1 to 9 do
    if receive(jobs, v) then total := total + v;
  writeln('total         : ', total:1);

  { A field and a dereference, which are the other two selectors a
    variable-access is made of. }
  spawn r.t := Worker(jobs, 4);
  wait(r.t);
  new(p);
  spawn p^ := Worker(jobs, 5);
  wait(p^);
  total := 0;
  for i := 1 to 6 do
    if receive(jobs, v) then total := total + v;
  writeln('field and ptr : ', total:1);
  dispose(p)
end.
