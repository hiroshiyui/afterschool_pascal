{ Where ADR-0128's int64 is refused, and the one decision every refusal comes
  from: it is a *numeric* type and not an ordinal one.

  That is not a restriction chosen position by position. Nothing this compiler
  can hold is a value of the type -- its own integers are 32 bits -- so every
  construct that needs the compiler to *have* the value cannot be given one:
  a case label is folded, a subrange bound is folded, an array's extent is a
  count, a set is 256 bits with one per value, a for statement counts, and
  succ, pred, ord, odd and chr each compute. `IsOrdinal` answers no, and each
  of the messages below is the one that position has always given -- not one
  of them was written for this type.

  `read` used to be the one exception in the other direction -- a required
  procedure that took the type where `write` did -- and ADR-0134 closed it:
  6.9.1's rule is the same sentence at both widths, so what it needed was the
  bound and not a second reader. `int64_read.pas` is that half.

  The literal's own bound is in int64_toobig.pas rather than here, because it
  is the *lexer* that reports it and every stage after a failed one is skipped
  (the Compile pipeline's rule) -- so one file cannot carry both. }
program Int64Types(input, output);
var
  a: int64;
  s: set of int64;                { 6.4.3.4: the base type is an ordinal }
  arr: array [int64] of integer;  { 6.4.3.2: the index type is an ordinal }
  sub: 1..maxint64;               { 6.4.2.4: a bound is an ordinal constant }
  n: integer;
begin
  a := 1;
  n := 2;
  case a of 1: writeln('unreached') end;
  for a := 1 to 3 do writeln(a);
  writeln(succ(a), pred(a));
  writeln(ord(a));
  writeln(odd(a));
  writeln(chr(a));
  writeln(a in s);
  { nothing narrows without being asked to: `trunc` is the one way }
  n := a
end.
