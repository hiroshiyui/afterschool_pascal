{ AP 6.7.3.10 across §6.13, with a *module* as the importer (ADR-0216).

  `tests/dialect/generic_import.pas` is the same clause with a program as the
  importer, and it passed while this did not compile at all: the two arms of
  RunCodeGen are one translation unit with a main-program-declaration and one
  without, and only the first emitted the instantiation bodies. The frame types
  were emitted either way — that loop is above the branch — so a module
  translated on its own succeeded and the failure surfaced as an undefined
  symbol at link time, in a different command, about a name no source spells.

  This program does nothing a generic needs; it calls two ordinary routines.
  What makes it the case is the component behind them. }
program generic_module(output);

import GenericWrap;

var i, j: integer;
begin
  i := 3; j := 7;
  SwapInts(i, j);
  writeln(i:1, ' ', j:1, ' ', PairSum(4, 5):1)
end.
