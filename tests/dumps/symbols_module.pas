{ --dump-symbols over a source that is not one program (ADR-0239).

  Two things this pins that tests/dumps/symbols.pas cannot. A module's
  heading and its block are one scope reported at one depth --
  ISO/IEC 10206:1991 6.2.2.12 makes every defining-point of the heading one of
  the block's too -- so an exported routine's heading in the module-heading
  (6.11.1) and the block that completes it are one name and are reported once,
  the way a forward declaration and its completion are. And 6.13 lets a file
  hold a module and then a main-program-block, which is the shape
  selfhost/compiler.pas has: both are reported, in the order they were
  written, each rooted at depth 0.

  What is *not* here is an --import, and that is the design rather than an
  omission: this flag stops after the parse, so a source's outline never
  depends on another file being found. }
module counters;

export counters = (tally, Bump, Reset);

type tally = record
  hits: integer;
  misses: integer
end;

{ A heading in a module-heading is the same routine as the block that
  completes it. Reported once, at the completion. }
procedure Bump(var t: tally);
procedure Reset(var t: tally);

end;

const step = 1;

procedure Bump;
begin
  t.hits := t.hits + step
end;

procedure Reset;
begin
  t.hits := 0;
  t.misses := 0
end;

end.

program uses_counters(output);

import counters;

var t: tally;

begin
  Reset(t);
  Bump(t);
  writeln(t.hits:1)
end.
