{ ADR-0137, and what is left of it. It was a dialect program linking a module
  translated under `--std=extended`, which before that record did not link at
  all: ADR-0119 spelled the mode into a module's activation names, so
  `m.conforming.extended.init` was defined and `m.conforming.afterschool.init`
  was what the program called, and the link failed with

      module 'conforming' was translated under a different --std

  What made it matter was never this file. It was `lib/`, modules of ordinary
  Extended Pascal that the language *containing* Extended Pascal could not use
  -- and ADR-0232 dissolved the problem rather than solving it again: there is
  one language, every translation writes the same tag, and no two components
  here can disagree about which language they are in.

  So what this case still witnesses is the ordinary half: a program using a
  dialect feature -- the optional -- importing a separately translated
  component that exports a structured type. Kept rather than deleted because
  that is a §6.13 path worth a case, and this one already had it. }
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
