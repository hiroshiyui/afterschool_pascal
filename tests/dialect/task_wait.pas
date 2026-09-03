{ AP 6.4.17 and AP 6.9.3.14: a task is named, and waited for (ADR-0312).

  ADR-0268's list of what two threads of control left open kept this row
  after ADR-0302 and ADR-0303 closed the two beside it: a block joined every
  activation it commenced and a program could not name one. `spawn t := P(...)`
  gives the activation a name and `wait(t)` joins that one.

  **A join is hard to observe, and this is what the difficulty is.** A channel
  already synchronises -- a `receive` blocks until a value arrives, so a
  program that reads what a task sent cannot tell whether the task has ended.
  What distinguishes a join is an effect the task has *outside* any channel,
  and the one available is a handle it owns: a stream moved into the task is
  released when the task's block ends, and releasing it is what flushes and
  closes the file. So the program waits, and then reads the file by name.

  The task sleeps a whole second before it writes. That is not decoration: it
  is what makes the case fail rather than race when the wait is removed, the
  program then opening a file the task has not written to yet and reading
  nothing from it. A construction that could not race at all would be better
  and there is not one -- `doc/sop.md` §7 carries the same difficulty for the
  join at the end of a block. }
program task_wait(output);

import PasError; PasFS; PasStream; PasProcess;

{ The task owns the stream: nothing here closes it, because the value is
  released where this block's activation ends, which is the ordinary rule for
  a handle-variable (AP 6.4.12). That release is the observable event. }
task Writer(s: Stream; note: StreamLine);
var e: ErrorCode; slept: integer;
begin
  slept := Sleep(1);
  e := StreamWriteLine(s, note)
end;

var s, back: Stream;
    t, idle: task;
    e: ErrorCode;
    line: StreamLine;
    path: PathName;
    r: PathResult;

begin
  { A name of its own, because the harnesses do not all run a case in a
    directory of its own -- the coverage sweep and heap-balance run one with
    the checkout as the working directory, so a fixed name would be a file
    left in the tree and two runs at once would be two programs writing it. }
  r := TemporaryPath('.', 'task_wait');
  path := ValueOr(r, '');
  e := StreamOpenWrite(s, path);
  writeln('opened        : ', e = errNone);

  { The stream is moved in and the task-variable named. Both halves of the
    statement are visible in it: `take(s)` says `s` is empty from here, and
    `t :=` says which activation `wait` below is about. }
  spawn t := Writer(take(s), 'written by the task');
  writeln('source emptied: ', s = nil);

  wait(t);
  writeln('joined        : ', t <> nil);

  { Waiting again is a statement with no effect. It is not an error for the
    reason releasing an empty handle is not one: a program that has already
    got what it asked for has nothing to be told. }
  wait(t);

  e := StreamOpenRead(back, path);
  writeln('reopened      : ', e = errNone);
  if StreamReadLine(back, line) then
    writeln('read back     : ', line);
  StreamClose(back);

  { A task-variable is a handle-variable in every other respect too: it may be
    released early, and it is empty afterwards. The activation it named is
    still the block's to join, which is why releasing it is safe. }
  t := nil;
  writeln('released      : ', t = nil);
  writeln('never spawned : ', idle = nil);
  e := Remove(path)
end.
