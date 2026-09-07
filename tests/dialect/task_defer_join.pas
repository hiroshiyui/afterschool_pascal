{ AP 6.9.3.12.1: "Every activation a block commenced shall be complete before
  that block's activation ends, and before any variable of that block is
  released", and NOTE 2 names the block's deferred statements among the things
  that must happen after the join.

  A deferred statement of the block's own statement-part runs at 6.9.3.11.2
  a)'s completion of that sequence, and the join stood in the exit path
  *after* it -- so `defer c := nil` closed a channel a spawned task was still
  sending on, and the program died with "send on a channel that has been
  closed" and exit 1 (ADR-0365, an audit's finding).

  The loop is what makes the task outlast the block's body without a sleep.
  Only the main block writes: two activations writing one text file is a race
  ThreadSanitizer reports, and the ordering claim needs no second writer --
  the deferred release either found the task finished or killed it. }
program task_defer_join(output);
type ch = channel [4] of integer;
var c: ch;

task Slow(o: ch);
var i, s, k, r: integer;
begin
  for k := 1 to 3 do begin
    s := 0;
    for i := 1 to 3000000 do s := (s + i) mod 7;
    send(o, s)
  end;
  r := release(o)
end;

begin
  defer writeln('deferred');
  defer c := nil;
  spawn Slow(c);
  writeln('body done')
end.
