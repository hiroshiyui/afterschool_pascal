{ AP 6.5.6 (ADR-0219) widens 6.5.6's third error condition by exactly one
  value, and this is the value on the other side of it.

  `s[4..3]` is the empty substring and legal here; `s[4..2]` is a transposed
  pair and is not. A relaxation to `hi < lo` rather than `hi < lo - 1` would
  admit both, and every case in substring_empty.pas would still pass -- which
  is why this file exists rather than a comment claiming the bound is tight.

  The legal case is printed first, so a check that fired too eagerly would fail
  here rather than at the trap.

  The other two disjuncts need no case under this directory: `s[0..3]` and
  `s[2..9]` are unchanged by the dialect, so tests/extended/trap_substring_lo
  and tests/extended/trap_substring_hi cover them under --std=afterschool too,
  by way of the dialect-containment sweep. tests/extended/trap_substring is the
  one that diverges and has an entry in containment_exceptions.txt. }
program SubstringEmptyTrap(output);
var s: string(10);
begin
  s := 'abcdef';
  writeln('[', s[4..3], ']');
  writeln('[', s[4..2], ']')
end.
