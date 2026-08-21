{ Annex B: `int64` is a required identifier of the dialect (ADR-0128), which
  §6.2.2.10 puts in a scope enclosing the program -- so under a conformance mode
  it is simply not there, and a program using it is using an undeclared name.
  No diagnostic mentions the dialect, and none should: the spelling is one any
  program may declare for itself, which is what made adding it survivable. }
program int64_refused_iso(output);
var n: int64;
begin
end.
