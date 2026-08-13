{ §6.7.2.2, D.46: "a term of the form i mod j is an error if j is zero **or
  negative**."

  The second half is the one that had no program, and it is the one where the
  two halves of this compiler disagreed with each other: `const c = 5 mod -3`
  has always been a compile-time diagnostic — "the right operand of mod must be
  positive" — while the same expression over a variable quietly computed 1.
  ADR-0054 requires a folded operator to answer what the emitted one answers,
  and the comment beside the folder said this one did. It does now, in the same
  words, which is what makes the two answers the same answer.

  A positive divisor still gives ISO 7185's non-negative result, not C's
  truncating remainder, and `tests/arith.pas` is what pins that. }
program TrapModNeg(output);
var i, j: integer;
begin
  i := 7;
  j := 3;
  writeln('7 mod 3 is ', (i mod j):1);
  j := -3;
  writeln((i mod j):1)
end.
