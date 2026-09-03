{ AP 6.4.16.4: a task closes the channel downstream of it (ADR-0302).

  ADR-0295 found this by writing a program. The first draft of
  `examples/pipeline_tasks.pas` was a producer, a filter and a reader, each
  stage closing the channel it writes to as `concurrency.pas`'s main program
  closes its job channel -- and it hung at once, with nothing said by the
  compiler, the runtime or the linker. The reason was a rule that is right
  about one thing and was being asked about another: a task's channel
  parameter is released by a closer that *drops the reference and does not
  close*, because a worker of a pool that has run out of work must not close
  the channel its colleagues are still draining.

  That is the answer to *this activation has finished with the channel*. It is
  not the answer to *close it*, which is what a program writing `release(c)`
  says -- so the two are now two things: the release a **program** writes
  closes the channel wherever it stands, and the release the end of a block
  performs goes on meaning what it meant.

  It cannot destroy the channel out from under anybody. The block that spawned
  a task joins it before releasing any of its own variables (AP 6.9.3.12.1),
  so a variable of that block holds the channel the whole time a task is
  running.

  Every line below is deterministic, which a test of concurrency has to be:
  the pipeline is a chain and each stage writes nothing until it has read. }
program task_close(output);

type
  Ints = channel [4] of integer;
  Words = channel [4] of string(16);

{ Three stages, and each ends by closing what it writes to. Without
  AP 6.4.16.4 the two `release` calls below drop a reference and nothing
  more, and this program never reaches its last line. }
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

{ The other spelling. AP 6.4.12.2's assignment of `nil` is the same release
  as AP 6.4.12.5's function, so it closes the same way -- a rule that
  separated them would be a rule about syntax. }
task Naming(out: Words);
var s: string(16);
begin
  s := 'alpha';
  send(out, s);
  send(out, 'be' + 'ta');
  out := nil
end;

{ For the third spelling below: this drains a channel and reports, through a
  second channel, that the first one was closed. The report is what makes the
  output deterministic -- a writeln from a task could land anywhere. }
task Watcher(src, report: Ints);
var v: integer;
begin
  while receive(src, v) do ;
  send(report, 1)
end;

var squares, odds: Ints; names: Words; v: integer; s: string(16);
    watched, spare, report: Ints;

begin
  { A pipeline: the producer closes for the filter, the filter closes for the
    program, and neither channel is closed by the block that declared it. }
  spawn Producer(squares, 6);
  spawn OddOnly(squares, odds);
  while receive(odds, v) do writeln('odd square    : ', v:1);
  writeln('pipeline ended: TRUE');

  { And a channel of strings, which `Transferable` had admitted all along
    with no case to say so: a `string(n)` is a length beside a buffer, both in
    the value, so what the reader gets shares nothing with what was sent. The
    second send is a concatenation, whose value is shorter than the element
    type and is padded into it where it crosses. }
  spawn Naming(names);
  while receive(names, s) do writeln('word          : ', length(s):1, ' ', s);

  { The third spelling. AP 6.4.12.7's move releases what the target held
    before it takes, so the channel `watched` held is closed here and the
    task draining it is told there will be no more. }
  spawn Watcher(watched, report);
  watched := take(spare);
  if receive(report, v) then writeln('closed by move: TRUE');
  writeln('done')
end.
