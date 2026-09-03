{ AP 6.9.3.12.1: every activation a block commenced is complete before that
  block's activation ends -- and this is the case that can see it.

  `doc/sop.md` §7 carried a row saying a missing join was caught by nothing:
  removing the join entirely left tests/dialect/concurrency.pas green, every
  task in it finishing before its block ended, so nothing observed the
  difference. What was needed was a task still running when its block ends
  *and* whose continued running is observable.

  This is that program. The spawn is inside `Detach`, so the join is at `Detach`'s
  end and nothing here writes it. The task sleeps a whole second and then
  writes to a stream it owns, which is flushed and closed where its block
  ends -- so if `Detach` returns without joining, the program reads a file that
  has been created and not yet written to.

  It is the companion of tests/dialect/task_wait.pas: there a program waits
  for one named activation, here it waits for all of them by leaving a block,
  and the two are the same join reached two ways (ADR-0312). }
program task_join(output);

import PasError; PasFS; PasStream; PasProcess;

task Writer(s: Stream; note: StreamLine);
var e: ErrorCode; slept: integer;
begin
  slept := Sleep(1);
  e := StreamWriteLine(s, note)
end;

{ Nothing in this block joins anything: the join is what its `end` performs,
  before the block releases any variable of its own. }
procedure Detach(path: PathName);
var s: Stream; e: ErrorCode;
begin
  e := StreamOpenWrite(s, path);
  spawn Writer(take(s), 'written before the block ended')
end;

var back: Stream;
    e: ErrorCode;
    line: StreamLine;
    path: PathName;
    r: PathResult;

begin
  { A name of its own: see the note in tests/dialect/task_wait.pas. }
  r := TemporaryPath('.', 'task_join');
  path := ValueOr(r, '');
  Detach(path);
  writeln('block left    : TRUE');
  e := StreamOpenRead(back, path);
  writeln('reopened      : ', e = errNone);
  if StreamReadLine(back, line) then
    writeln('read back     : ', line);
  StreamClose(back);
  e := Remove(path)
end.
