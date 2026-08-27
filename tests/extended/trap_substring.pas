{ §6.5.6's three error conditions, and the one that is *not* `substr`'s.

  "It shall be an error if ... the value of an index-expression in a
  substring-variable is less than 1 or greater than the length of the value of
  the string-variable ... or if the value of the first index-expression is
  greater than the value of the second index-expression."

  That last clause is the whole reason this cannot share a check with
  §6.7.6.7's `substr`. There, `substr(s, 3, 0)` is legal and yields the
  null-string — a count of zero is fine. Here `s[3..2]` has i > j and is an
  error, and `s[3..2]` is exactly the empty substring. The two conditions agree
  everywhere except at the empty case, which is the one place a shared check
  would have been wrong in silence rather than loudly.

  **This case is where the dialect parts company** (AP 6.5.6, ADR-0219). The
  disagreement above between two constructs of one standard is what argued for
  admitting `s[i..i-1]` there, so under --std=afterschool this program prints
  `[]` and runs to the end. Everything above stays true of Extended Pascal, and
  this file goes on asserting it; tests/checks/containment_exceptions.txt is
  where the divergence is argued for, and tests/dialect/substring_empty.pas is
  the other side of it.

  The legal cases are printed first, so a check that fired too eagerly would
  fail here rather than at the trap. }
program TrapSubstring(output);
var s: packed array [1..6] of char;
begin
  s := 'abcdef';
  writeln('[', s[1..1], '][', s[1..6], '][', s[6..6], ']');
  { Legal for `substr` and an error here: i > j. }
  writeln('[', s[4..3], ']')
end.
