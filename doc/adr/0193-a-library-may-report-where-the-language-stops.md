# 193. A library may report where the language stops

Date: 2026-08-25

## Status

Accepted. The fourth of ADR-0189's four increments, and the last of the text
model. `lib/dialect/pasunicode.pas`.

## Context

ADR-0191 made ill-formed bytes an **error** that stops the program, and argued
for it from §6.4.6's own model: a store into a subrange has been an error since
1982, and a text's invariant is a constraint on a value of the same kind. That
is the right rule for a program's own literals and its own capacities.

It is the wrong rule for bytes a program did not write. A line off a socket, a
filename out of `PasDir`, a file whose encoding nobody promised — a program
that must keep running when those turn out not to be UTF-8 has, under
AP 6.4.15.5 alone, nowhere to put them. Both ADR-0191 and ADR-0192 pointed at a
library for this and neither built one.

Two other things the language deliberately does not have. An element of a text
is an extended grapheme cluster, and a program sometimes wants the **scalar
values** under one — to classify a character, to write an escape, to implement
something Unicode specifies in terms of code points. AP 6.4.15 offers no such
view and should not: three sequences live in one text, and a type offering all
three would have to say at every operation which it meant.

## Decision

**`PasUnicode` is a binding, not an implementation.**
`lib/dialect/README.md`'s term: it exports Pascal and keeps the `external`
directive to itself. `ToText` and `NextScalar` both go to the runtime.

That is the decision worth defending, because the alternative looks cheaper. A
UTF-8 decoder is forty lines of Pascal arithmetic and needs no table at all —
and it would be **a second reading of The Unicode Standard's table 3-7**. That
table needs care for exactly the reason a second reading would get it wrong: an
overlong encoding, a surrogate and a code point above U+10FFFF each have a lead
byte that looks ordinary, so the admissible range of the *second* byte depends
on the first. One reading, in one place, checked by `unicode-conformance`
against Unicode's own files (ADR-0190).

**Encoding is written in Pascal, and decoding is not.** The asymmetry is the
point rather than an inconsistency: encoding a scalar value to UTF-8 is
unambiguous arithmetic with one rejection (a surrogate is not a scalar value),
and table 3-7 is a table about *decoding*. Where a duplicate reading could be
wrong, there is one; where it cannot, the library does the work.

**The scalar view is over `string` and not over `utf8`.** A program that wants
bytes holds a string, which is what AP 6.4.15.8's NOTE already says, and a text
does not cross the foreign boundary in either direction (ADR-0191). So
`ToText` is the bridge and everything below it is bytes.

**`ToText` distinguishes its two failures**, `errSyntax` from `errFull`,
because a caller can act on the difference: one is a fault in the data and the
other in the capacity the program chose. It assigns nothing unless the answer
is `errNone`, so a failed conversion leaves the target holding what it held.

Two runtime entry points, both `pasx_` and so bindable by any program
(ADR-0131): `pasx_text_check`, which answers whether bytes are well-formed
*and* whether their normal form fits a given capacity, and `pasx_text_scalar`,
which decodes one. The first exists because the fit cannot be computed from the
byte counts — normal form can be longer than its source, so comparing lengths
would answer wrongly in both directions.

## Consequences

**A third guard of the same shape was found, in three increments.**
`EmitAssign` selects the string store with `if IsStringType(t)`, and a text is
not a string-type — so `t := s` between a schematic `var t: utf8` and a
`string` fell through to the schema tuple-comparison, which reads the
*destination's* schema and does not ask whether the source came from the same
one. It compared a string's capacity against a text's and stopped the program.

That is the third: ADR-0191 found `IsMemory` asking `IsVarString` and emitting
`icmp` on an aggregate, then the codegen comparison dispatch, and now this. All
three are a predicate used as a guard where the question was "does this take
the string path?", and none of them is a case-statement, so `kind-exhaustive`
sees none of them. `doc/sop.md` §7's row on this now has three instances behind
it rather than one, which is the argument for the sweep it proposes.

**All three were found by writing a client**, not by a gate. The first two by
probing every operation against the new type by hand; this one by writing the
library that the type exists to be used through. That is ADR-0182's lesson a
second time — `take` was found by writing a list over `owned ^T` — and it is
the strongest argument for building the library increment at all.

**`lib/dialect/` is twelve modules.** `ToText` takes the `ErrorCode` shape,
which is the commonest of the four `lib/dialect/README.md` records.

## What this does not do

**No case mapping, no case folding.** Each wants a table this runtime does not
carry — `UnicodeData.txt`'s simple mappings for the first, `CaseFolding.txt`
for the second — and neither is a line of Pascal away. They are a further
increment with a generator change behind them, and the honest reason they are
not here is size rather than difficulty.

**No grapheme-indexed slicing.** `for g in t` walks elements and a program that
wants the third one counts to three. An `ElementAt(t, i)` is O(n) and would
read as though it were not, which is the same objection AP 6.4.15.9 NOTE makes
to an integer index; if it lands it should be spelled so the cost is visible.

**No collation, no display width, no normalisation form but C.** Those are
ADR-0189's "what this does not do", unchanged.

**No U+0000.** A `string` crosses the foreign boundary as a NUL-terminated copy
and the marshalling traps on `chr(0)` rather than truncating (ADR-0122), so a
text containing U+0000 is one this module cannot be asked about. It is a scalar
value like any other and the restriction is real; it is the same restriction
every foreign string call in this repository has.

## Alternatives rejected

**A UTF-8 decoder in Pascal.** Above: a second reading of the one table in
Unicode where a careless reading is wrong in three separate ways, to save a
foreign call.

**Making `ToText` a required function of the dialect** rather than a library
routine. It was tempting while AP 6.4.15.5 refused an assignment from a string,
because then the type could not be filled at all without one. ADR-0191 removed
that pressure by admitting the assignment, and what is left is a routine with
a library's shape: it answers an `ErrorCode`, it composes with the other eleven
modules, and it needs nothing from the compiler.

**Answering an optional (`?utf8`) instead of an ErrorCode.**
`lib/dialect/README.md`'s rule decides it: absence is not a failure, and this
*is* one — a caller may well want to report which of the two things went wrong.

**Returning the text as a function result.** A result would have to have a
declared capacity, which would make the module choose one for every caller. The
`var` parameter takes it from the actual instead, which is what a schematic
formal is for and what `PasDir.Next` already does with a string.
