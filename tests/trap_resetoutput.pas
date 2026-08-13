{ The other direction: §6.6.5.2's `reset(f)` puts a file into the inspection
  mode and positions it at the first component, which the standard output has
  none of. E.33 in `doc/implementation-defined.md` is the answer this pins.

  `rewrite(output)` and `extend(output)` are *not* errors — there is nothing to
  discard and nothing to append past, so both are permitted to do nothing, and
  `tests/rewriteoutput.pas` is what says they do exactly nothing rather than
  losing the line state `page` consults. }
program TrapResetOutput(input, output);
begin
  writeln('before');
  reset(output);
  writeln('unreachable')
end.
