{ Annex B: `int64` is a required identifier of the dialect (ADR-0128), which
  §6.2.2.10 puts in a scope enclosing the program -- so under Extended Pascal it
  is not there and the name is undeclared. No diagnostic mentions the dialect,
  and none should: any program may declare that spelling for itself, which is
  §6.1.3's shadowing and what made adding a required identifier survivable. }
program int64_refused(output);
var n: int64;
begin
end.
