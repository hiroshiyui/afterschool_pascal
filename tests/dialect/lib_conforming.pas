{ ADR-0137: a dialect program linking a module translated under --std=extended.
  Before it, this did not link at all -- ADR-0119 spelled the mode into a
  module's activation names, so `m.conforming.extended.init` was defined and
  `m.conforming.afterschool.init` was what the program called.

  The reason that mattered is not this file: it is `lib/`, six modules of
  ordinary Extended Pascal that the language *containing* Extended Pascal could
  not use. lib_conforming.components is what makes the two modes differ, and
  without ADR-0137 the link fails with

      module 'conforming' was translated under a different --std

  The program is dialect and says so by using a dialect feature -- the optional
  -- so that it could not accidentally be a conforming program that happens to
  compile under --std=afterschool. }
program LibConforming(output);

import Conforming;

type
  OptInt = ?integer;

var
  p: Pair;
  best: OptInt;

begin
  p.lo := -3;
  p.hi := 7;
  writeln(Nearer(p), ' ', Total(p));

  { the dialect feature, so the mixture is genuinely two languages }
  best := nil;
  if best = nil then best := Nearer(p);
  writeln(best^)
end.
