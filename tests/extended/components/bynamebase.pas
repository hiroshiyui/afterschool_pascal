{ The deeper of two components a case reaches **without being told where they
  are** (ADR-0244). Nothing names this file: `tests/extended/import_by_name.pas`
  writes `import bynamemid`, the middle one writes `import bynamebase`, and
  the search path is a directory.

  So this is the transitive half. A search that resolved only what the source
  itself imports would leave the middle component's own import unmet, and the
  order matters as much as the finding does: 6.2.3.6 commences a supplying
  module before the one importing it, and the golden below is written by the
  two `to begin do` parts in the order the resolution decided.

  The file is named after the **interface** and not the module, which is the
  convention a search can be built on -- an import writes an interface name
  and nothing else. Here the two words are the same, as they are for every
  module in lib/; components/counter.pas is the case where they differ, and it
  is reachable by --import and not by a path. }
module bynamebase;

export bynamebase = (baseTally, baseBump);

import StandardOutput;

var
  baseTally: integer;
procedure baseBump(n: integer);
end;

procedure baseBump;
begin
  baseTally := baseTally + n
end;

to begin do
  begin
    writeln('base activated');
    baseTally := 1
  end;

end.
