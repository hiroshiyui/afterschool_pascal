{ --dump-symbols over a source declaring a task (ADR-0357).

  ADR-0349's case made the outline survive a trait and left one question
  open in as many words: a task was reported as `procedure`, the word the
  walker writes for every nkProcDecl that is not a function, and whether the
  outline should say `task` was not decided there. It is decided here. A
  task is declared by a task-declaration (AP 6.7.8) and started by `spawn`
  and by nothing else -- CheckStmt refuses to *call* one -- so a reader who
  jumps to `procedure Worker` from an outline and writes `Worker(c)` has
  been sent to the wrong construct by the tool that named it. The word is
  the language's own, as every word this dump writes is (ADR-0239), and a
  client that does not know it maps it beside `procedure`, as pasls does.

  What is pinned: the row says `task`, its extent runs to the block's end
  as a procedure's does, and its parameters and locals nest under it. }
program symbols_task(output);

type IntChan = channel [4] of integer;

var c: IntChan; t: task;

task Worker(ch: IntChan; rounds: integer);
var k, got: integer;
begin
  for k := 1 to rounds do
    if receive(ch, got) then got := got + 1
end;

procedure Plain;
begin
end;

begin
  spawn t := Worker(c, 1);
  send(c, 7);
  wait(t);
  Plain;
  writeln('done')
end.
