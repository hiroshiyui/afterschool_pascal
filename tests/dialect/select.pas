{ AP 6.9.3.15: waiting for whichever channel comes first (ADR-0313).

  ADR-0268's table of what two threads of control left open ends here. A
  program could wait for one channel and, since ADR-0312, for one task; what
  it could not do was wait for *whichever* of several things happened, or give
  up waiting. A worker that must service a job queue and a shutdown signal had
  to fold both into one channel.

  **Every answer below is deterministic**, which a test of concurrency has to
  be. Nothing here depends on the order two threads ran in: the sends all
  happen before the selects, the timeout arm is reached only when no channel
  can proceed at all, and the one place the *choice* between two ready arms is
  observable is the fairness paragraph, whose rule is stated rather than
  guessed -- the arm tried first rotates, so over n executions each arm is
  looked at first once, and a counter that did not rotate would print a
  different answer. }
program select_(output);

type Ints = channel [4] of integer;
     Small = channel [2] of integer;

var jobs, quit, left, right, feed, spare: Ints;
    tight: Small;
    v, q, k, hits: integer;
    ok, live, done: boolean;

{ AP 6.7.3.10 (ADR-0254): a generic routine holding a select. Its body is
  checked once per instantiation, so every name in the select is resolved and
  forgotten again -- which is the one path through the resolver a select
  reaches and no ordinary routine does. }
procedure TookOne(T: type; var sink: T; whenNone: T);
var got: integer; had: boolean;
begin
  select
    had := receive(spare, got): if had then sink := whenNone else sink := whenNone
  otherwise sink := whenNone
  end
end;

{ A producer that closes what it filled, which is the only way an activation
  sees a close: AP 6.4.16.4's three spellings all empty the variable that
  performs them, so the close a select reports is always another activation's
  (ADR-0313). }
task Produce(c: Ints; n: integer);
var i, r: integer;
begin
  for i := 1 to n do send(c, i * 11);
  r := release(c)
end;

begin
  { A deferred select, which is the one place a select's arms are walked by
    something other than the checker of a statement: AP 6.9.3.11 arms the
    statement here and runs it where this sequence completes, so a spawn or
    an exit written in an arm is refused exactly as it is anywhere else in a
    deferred statement. `otherwise` is what keeps it from waiting for a
    channel nobody will fill after the program has ended. }
  defer
    select
      receive(quit, q): writeln('deferred      : ', q:1);
    otherwise writeln('deferred      : nothing left')
    end;

  { `otherwise` is a deadline of zero: it looks once and does not wait. }
  select
    receive(jobs, v): writeln('unreachable');
  otherwise writeln('nothing ready : TRUE')
  end;

  { `after` gives up. The channels are empty and nobody is going to fill
    them, so the deadline is what ends the wait. }
  select
    receive(jobs, v): writeln('unreachable');
    after 30: writeln('timed out     : TRUE')
  end;

  { A send arm proceeds while there is room, and the third send finds none --
    which is a select being used to *not* block rather than to wait. }
  for k := 1 to 3 do
    select
      send(tight, k): writeln('sent          : ', k:1);
      otherwise writeln('full at       : ', k:1)
    end;

  { Two arms, both always ready, four executions. The arm tried first
    rotates, so each is chosen twice; trying them in written order would
    choose `left` four times and `right` never.

    What is printed is the *count* and not the order. Which of the two goes
    first depends on how many selects this thread has already executed, which
    is a fact about the program above rather than about this loop -- and
    printing it would make this case fail the day a select is added earlier.
    tests/dialect/concurrency.pas set that rule and it applies here. }
  { Both channels hold *more* values than the loop takes, which is what makes
    this discriminate: with the arms tried in written order `left` can supply
    every one of the four and `right` is never looked at. }
  for k := 1 to 4 do begin
    send(left, 1);
    send(right, 2)
  end;
  hits := 0;
  for k := 1 to 4 do
    select
      receive(left, v):  hits := hits + 1;
      receive(right, v): hits := hits + 0
    end;
  writeln('left won twice: ', hits = 2);

  { The shutdown shape this construct exists for: a job queue and a signal,
    and the program leaves on the signal rather than on the queue running
    out. How many jobs it handled first is the rotation's business and is not
    printed; that every job is either handled or still queued is the property,
    and it holds whichever arm went first. }
  send(jobs, 7);
  send(jobs, 8);
  send(quit, 99);
  done := false;
  hits := 0;
  k := 0;
  while not done and (k < 6) do begin
    k := k + 1;
    select
      receive(jobs, v): hits := hits + v;
      receive(quit, q): begin
        writeln('quit          : ', q:1);
        done := true
      end
    end
  end;
  { Whatever the loop left behind, taken without waiting. }
  done := false;
  while not done do
    select
      receive(jobs, v): hits := hits + v;
    otherwise done := true
    end;
  writeln('every job seen: ', hits = 15);

  { `ok := receive(c, v)` is how a drain loop ends: false is the close of a
    drained channel, which is `receive`'s own second outcome and is the one
    thing a select could not otherwise report. }
  spawn Produce(feed, 3);
  live := true;
  while live do
    select
      ok := receive(feed, v):
        if ok then writeln('drained       : ', v:1) else live := false
    end;
  writeln('closed        : TRUE');

  { The generic instantiated, which is what makes its select's names be
    resolved and forgotten again. }
  send(spare, 5);
  TookOne(integer, k, 41);
  writeln('generic       : ', k:1)
end.
