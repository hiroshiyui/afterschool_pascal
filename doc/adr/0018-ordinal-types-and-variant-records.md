# 18. Enumerations and subranges are ordinal types, and variants share storage

Date: 2026-08-09

## Status

Accepted

## Context

Items 3 of ADR-0004's dependency list — enumerations, subranges and `case` —
arrive together because each is nearly useless without the others, and because
a record's variant part cannot be written until all three exist. This is also
the point at which the compiler's own source becomes expressible: an AST node
is a tag plus a variant record, and the tag is an enumeration.

Three questions had to be settled.

**What is a subrange, to the rest of the compiler?** Either a type in its own
right, with every rule about integers restated for it, or an integer that
carries a restriction. The first is more faithful to the standard's prose and
doubles the size of every type rule. The second needs the restriction to be
enforced somewhere it cannot be forgotten.

**Where does an out-of-range value get caught?** ISO 7185 §6.4.6 makes storing
one an error. It could be checked on every read (cheap to describe, useless —
the wrong value is already there), on every arithmetic operation (expensive and
wrong: intermediate results legitimately leave the range), or where a value
enters the variable.

**How is a variant part represented?** LLVM has no union. The arms could be
padded into one struct with the fields of every arm laid out end to end
(wasteful, and `sizeof` stops matching the standard's intent), or share one
block of storage that each arm is laid over.

## Decision

**A subrange is its host type plus bounds.** `Type::base()` returns the host,
and `isInteger()`, `isNumeric()` and the rest all answer for the base — so
`1..9` is an integer everywhere except where its bounds matter. Assignment
compatibility is decided on the base, which gives §6.4.5's rule that a subrange
is compatible with its host type and with its siblings, without a single case
analysis. The machine representation is the host's.

**An enumeration is its ordinal number**, an `i32`, with the constants numbered
in declaration order. Two enumerated types are never compatible however alike
they look, so they are the one place `base()` equality is not enough and
identity is required.

**Range checks happen where a value enters a variable**: assignment, a value
parameter, and both bounds of a `for` loop. Nothing between the bounds of a
`for` needs checking, because the loop never leaves them. `checkedForSubrange`
is a no-op for every other type, so it can be applied at each of those points
without a conditional at the call site, and it emits nothing at all for a
subrange that covers its whole host type.

**`succ` and `pred` run out at the ends of the expression's own type** —
`blue`, or 9, or `maxint` — rather than always at the integer bounds.

**`case` lowers to an LLVM switch whose default traps.** ISO 7185 §6.8.3.5 has
no `else` arm, and none is invented: a selector matching no label stops the
program.

**A variant part is one block of shared storage** with each arm a struct laid
over it. The block's element type carries the alignment — `[k x i64]` where an
arm needs 8-byte alignment — because `[n x i8]` would be 1-aligned and would
misalign a `real` inside a variant.

## Consequences

Making the type predicates answer for the base is what kept this change small:
arithmetic, comparison, `write`, array indexing and parameter passing all
handled subranges with no edits at all. The cost is that `isInteger()` no
longer means "is exactly the integer type" — code that needs the distinction
asks `isSubrange()`, and there are only a handful of such places.

Checking on store rather than on use means a subrange variable always holds a
value of its type, so nothing downstream has to re-establish that. It also
means the check is on the path where the optimiser knows the most, and a loop
over a subrange's own bounds optimises to nothing.

Two new rules in `verify/rules.py` state the two halves of this, with the
bounds symbolic — so they are theorems about *every* subrange and *every*
enumeration rather than about the ones a test happens to declare.
`succ-traps-exactly-at-the-end-of-its-type` subsumes the integer-only rule that
preceded it, which could not have seen this generalisation because it had
`maxint` written into it.

Rejecting `else` costs convenience. A `case` that has quietly stopped covering
its type becomes a run-time failure rather than a silent no-op, which is the
right trade for a compiler's own source, where a missing arm is a missing
feature. If it becomes intolerable it should arrive as a documented extension
with its own record, not as a quiet addition.

A tagless variant part is supported, so a record can be read as either arm
without a discriminator. That is ISO 7185 §6.4.3.3 and it is genuinely unsafe —
the standard says as much — but it is the only reinterpretation the language
has, and the alternative is that a self-hosted compiler cannot express one.

A variant part inside a variant is rejected. It is legal Pascal; nothing in the
bootstrap needs one, and a diagnostic keeps the gap visible rather than letting
it be discovered by a wrong answer.

Type identifiers still cannot be used before they are defined. That is the
standard's rule outside pointer domains, and it will need revisiting when
pointers arrive — a recursive type is exactly what an AST needs.

## Notes for the port

An enumeration and a variant record together are what ADR-0005's tag-dispatched
AST becomes when it is rewritten in Pascal: `NK` is the enumeration, the node is
the record, and `as<T>(n)` is the `case` on the tag. The C++ in `ast.h` was
shaped to survive that translation, and this is the milestone at which the
target of the translation exists.
