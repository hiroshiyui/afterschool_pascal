{ A non-local goto abandons the activations between here and the target, and
  the files those blocks declared are closed on the way out -- the work their
  epilogues would have done had they run (ADR-0021, ADR-0032).

  There is no way to look at a closed file from inside Pascal, so this observes
  the descriptor table instead, exactly as files_scratch.pas does: three
  thousand scratch files opened in blocks that are then jumped out of. If the
  jump did not close them the table runs out long before the end. The test
  harness runs the program with a small one on purpose.

  Three different questions, and each half of the program answers one:

  * `Deep` is on the static chain of the goto that abandons it.
  * `Holder` is not -- it calls a procedural parameter and is abandoned by a
    jump inside it that names a block Holder knows nothing about. Only this
    one distinguishes finding the abandoned frames dynamically from walking
    the static chain, which would miss it.
  * `log` belongs to the block the jump lands *in*, so it must survive every
    one of those jumps. A cleanup that closed one file too many, or that noted
    which files were open one step too early, would take it. }
program GotoFiles(output);
label 1, 2;
var onchain, offchain, lines: integer;
    log: text;

procedure Deep;
var scratch: text;
begin
  rewrite(scratch);
  writeln(scratch, 'x');
  goto 1
end;

procedure Holder(procedure p);
var scratch: text;
begin
  rewrite(scratch);
  writeln(scratch, 'y');
  p;
  writeln('Holder is not resumed')
end;

procedure Owner;
  procedure Jump;
  begin
    goto 2
  end;
begin
  Holder(Jump)
end;

begin
  rewrite(log);
  writeln(log, 'opened before any jump');

  { The loop is the goto: a label a non-local goto may reach has to be at the
    top level of the block, so it cannot be inside a `for`. }
  onchain := 0;
1:
  onchain := onchain + 1;
  if onchain <= 1500 then Deep;

  offchain := 0;
2:
  offchain := offchain + 1;
  if offchain <= 1500 then Owner;

  { Three thousand jumps landed here, and this file was open through all of
    them. Writing to it is what says so -- a closed one is a runtime error. }
  writeln(log, 'still open after every jump');
  reset(log);
  lines := 0;
  while not eof(log) do begin
    readln(log);
    lines := lines + 1
  end;

  writeln('jumps out of a block that owns a file:  ', onchain - 1:1);
  writeln('jumps out of a block off the chain:     ', offchain - 1:1);
  writeln('lines in the landing block''s own file:  ', lines:1)
end.
