{ ISO 7185 §6.3 makes a constant-definition's right-hand side a `constant` — a
  signed literal or the name of another constant — and §6.4.2.4 says the same
  of a subrange bound. ISO/IEC 10206:1991 §6.8.2 replaces both with a
  constant-expression, so this is a change of language rather than an
  extension, and every line below compiles under `--std=extended` and none
  under `--std=iso7185`.

  The two refusals read differently on purpose. A constant definition holding
  an expression is *parsed* and then found not to be constant, which is what
  ISO 7185 makes it. A subrange whose low bound is an expression is not even
  recognised as a subrange there: §6.4.2.4's bound is one token, so `base - 1`
  followed by `..` reads as the type name `base` and then a syntax error. }
program ConstExprIso(output);
const
  base = 10;
  folded = base * 2;
type
  shifted = base - 9 .. base;
var s: shifted;
begin
  s := 1;
  writeln(folded:1, s:1)
end.
