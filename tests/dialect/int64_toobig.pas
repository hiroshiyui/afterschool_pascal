{ The bound on an int64 literal, and the message that names it (ADR-0128).

  Above maxint there is a wider type to widen to; above maxint64 there is not,
  so the message names the bound that was actually exceeded rather than maxint,
  which stopped being the ceiling one type ago.

  A file of its own because the *lexer* reports this and the pipeline skips
  every stage after a failed one, so nothing here can also carry a Sema
  refusal -- int64_types.pas is where those are.

  The comparison is on text, and it has to be: this compiler's integers are 32
  bits, so neither side of it is a number it could hold. Leading zeros are
  dropped first, which is what int64.pas writes the other half of. }
program Int64TooBig(output);
var a: int64;
begin
  a := 9223372036854775808;
  a := 99999999999999999999999999;
  a := 0000000009223372036854775808;
  { twenty-two digits whose first nineteen are *below* the limit: only the
    length says this one is out of range, which the character comparison after
    it would happily accept }
  a := 1000000000000000000000;
  writeln(a)
end.
