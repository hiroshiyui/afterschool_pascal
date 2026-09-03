{ AP 6.9.3.15 under contention (ADR-0313), which is the case the construct's
  one real correctness claim needs.

  Everything else about a select can be tested with one thread. What cannot is
  the lock invariant the runtime rests on -- *no thread ever holds a channel's
  mutex and the activity mutex at the same time* -- and the wakeup it makes
  impossible to lose. Four workers select over the same two channels while the
  program sends on both and every one of them sends on a third, so a
  selector's poll runs against another selector's transfer, which is exactly
  the interleaving the invariant is about.

  **The answer is deterministic and the schedule is not.** Twelve values are
  sent, each is received by exactly one worker and forwarded once, so the
  total is twelve however the four workers divided them. Which worker got
  which is not printed, and neither is the order -- tests/dialect/concurrency.pas
  set that rule.

  The deadlines are long on purpose. They are not part of what is being
  measured: they are there so that a defect which loses a wakeup ends the
  program with a wrong total instead of hanging until the harness kills it,
  and 2000 ms is far past any scheduling delay a loaded machine imposes. A
  timeout that fires sends nothing, so the total falls short and the case
  fails. **ThreadSanitizer is the other half of this case and is not a gate**
  (`doc/sop.md` §7): run it by hand over this program when a channel or a
  select changes. }
program select_contended(output);

type Ints = channel [4] of integer;
     Wide = channel [32] of integer;

var a, b: Ints;
    results: Wide;
    i, v, total: integer;

task Worker(x, y: Ints; out: Wide; rounds: integer);
var k, got: integer;
begin
  for k := 1 to rounds do
    select
      receive(x, got): send(out, got);
      receive(y, got): send(out, got);
      after 2000: writeln('a worker gave up waiting')
    end
end;

begin
  spawn Worker(a, b, results, 3);
  spawn Worker(a, b, results, 3);
  spawn Worker(a, b, results, 3);
  spawn Worker(a, b, results, 3);

  { Whichever of the two has room. A send arm is what lets the program feed
    four consumers without choosing which channel to block on. }
  for i := 1 to 12 do
    select
      send(a, 1): ;
      send(b, 1): ;
      after 2000: writeln('the program gave up sending')
    end;

  total := 0;
  for i := 1 to 12 do
    if receive(results, v) then total := total + v;
  writeln('total         : ', total:1)
end.
