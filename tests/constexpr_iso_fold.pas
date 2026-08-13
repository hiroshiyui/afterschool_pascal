{ The other half of tests/constexpr_iso.pas, and a separate program because
  the two refusals happen in different passes. A subrange bound that is an
  expression is a *parse* error under ISO 7185 — §6.4.2.4's bound is one token,
  so `base - 1 ..` reads as a type name followed by a syntax error — and the
  parser stops at its first one. Everything Sema would have said about the
  constant definitions below is therefore unreachable while a bad subrange is
  in the same file.

  So this file has no subrange at all: every line is a constant definition that
  parses under both standards and that only Sema can refuse. It is what pins
  the folder being gated on the standard rather than always on. }
program ConstExprIsoFold(output);
const
  base   = 10;
  folded = base * 2;              { §6.3: a constant, not an expression }
  called = abs(-4);               { §6.8.2 c)'s required functions, likewise }
  compared = base < 20;
  { §6.3's `constant` is a signed literal or the name of another constant, and
    `nil` is neither. ISO/IEC 10206:1991 §6.7.1 makes it an unsigned-constant,
    so there it is a constant-expression like the three above — see
    `tests/extended/constnil.pas`. It parses under both standards, which is
    what puts it in this file rather than in `constexpr_iso.pas`. }
  nilconst = nil;

var i: integer;

begin
  i := folded + called;
  writeln(i:1, compared)
end.
