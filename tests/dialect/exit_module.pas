{ AP 6.7.5.9 where an activation is not a procedure's: a module's
  initialization, a module's finalization, and the main-program-block.

  The last is the one that distinguishes an exit from 6.7.5.7's halt. Both end
  the program; only this one ends it the ordinary way, so 6.2.3.6's
  finalizations run and the module's own lines are what say so.

  The order of the last two lines is the whole of what a module adds. An exit
  leaves a statement-sequence without completing it, so what that sequence
  armed waits for 6.9.3.11.2 b) -- and a module-block's activation does not
  terminate when its initialization does: 6.2.3.6 keeps it live until after
  the main-program-block, so the armed statement runs at the end of the
  finalization, which is where that block's epilogue is. Compare
  defer_module.pas, where the sequence completes and the same statement runs
  immediately. }
program exit_module(output);

import exit_counter;

var i: integer;

begin
  writeln('program: Count = ', Count:1);
  for i := 1 to 3 do begin
    writeln('program: iteration ', i:1);
    if i = 2 then exit
  end;
  writeln('program: not reached')
end.
