{ A task declared at the top of a module-block, spawned by the routine the
  module exports (AP 6.7.8, ADR-0365). Before the audit that found it, the
  parser stopped at the word: the block's declaration-part knew the spelling
  and the module-block's did not. }
program task_in_module(output);
import taskmod;
var t: integer;
begin
  SumTo(10, t);
  writeln(t:1)
end.
