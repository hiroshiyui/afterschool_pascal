{ AP 6.4.13's type-denoter in the dumps. It nests on both sides, unlike a
  handle, so each side is printed indented under it and --dump-sema names the
  record it resolved to -- which is the type's whole semantics (6.4.13.2) and
  the reason the sides are worth seeing.

  This case exists because there was none: `DumpTypeExpr` had no arm for the
  kind, so a case-statement with no matching label stopped the compiler
  (ADR-0018) on any program declaring one. Every dump flag over the whole
  corpus said nothing, because a dump's exit status is not what the coverage
  sweep reads and no case here had a fallible-type in it. }
program fallible_dump(output);
type
  Reason = (bad, worse);
  Number = integer ! Reason;
  Nested = string(8) ! Reason;
var
  a: Number;
  b: Nested;
  c: char ! boolean;
begin
  a := 7;
  b := worse;
  c := true;
  writeln(a.ok, ' ', b.ok, ' ', c.ok)
end.
