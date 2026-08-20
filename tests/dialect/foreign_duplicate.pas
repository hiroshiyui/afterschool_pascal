{ ADR-0147: one linker symbol is named by one `external` declaration.

  ADR-0121 lets a program name a linker symbol and emits one `declare` per
  foreign heading. Two headings on one symbol emitted two declarations of one
  global, and LLVM refuses that -- *invalid redefinition of function 'abs'*, an
  error about a file nobody wrote, which is the exact shape ADR-0121's own
  `foreign-reserved` gate exists to prevent from the other direction.

  The emitter has a duplicate check and it never fired: `SameLink` compares the
  pool *positions* of the two names, and the pool interns nothing, so two
  sources of the word `abs` are two positions and two different links. That is
  a question about where text was written rather than about what it says.

  The rule is Sema's rather than the emitter's, because what the emitter would
  do with a duplicate is the wrong thing either way. Keeping the first
  declaration and dropping the second emits `declare i32 @abs(i32)` beside a
  call written `call double @abs(double ...)`, and LLVM does not check a direct
  call against a declaration under opaque pointers (doc/sop.md §7) -- so the
  accidental refusal would have become silent undefined behaviour. Nothing here
  checks a foreign heading against the routine it names, so a second heading is
  a second unchecked claim about one symbol and buys nothing that calling the
  first one does not. }
program ForeignDuplicate(output);

function Abs1(x: integer): integer; external 'abs';

{ the same symbol again, with the same heading: harmless, and still refused --
  the rule is about the symbol and not about whether the two agree }
function Abs2(x: integer): integer; external 'abs';

{ ...and with a heading that disagrees, which is the pair that matters }
function AbsReal(x: real): real; external 'abs';

{ A foreign name is a linker symbol and is compared exactly. Identifiers in
  this language are case-folded (6.1.3) and this is not one -- it is a
  character-string, and `ABS` is a different symbol from `abs`. }
function AbsUpper(x: integer): integer; external 'ABS';

{ and a symbol nothing has named is not a duplicate of anything }
function LongAbs(x: integer): integer; external 'labs';

begin
  writeln(Abs1(-1), Abs2(-2), AbsReal(-3.0):3:1, AbsUpper(-4), LongAbs(-5))
end.
