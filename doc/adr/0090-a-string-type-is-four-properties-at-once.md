# 90. A string-type is four properties at once

Date: 2026-08-15

## Status

Accepted.

## Context

ISO 7185 §6.4.3.2:

> Any type designated packed and denoted by an array-type having as its
> index-type a denotation of a subrange-type specifying a smallest value of 1
> and a largest value of greater than 1, and having as its component-type a
> denotation of the char-type, shall be designated a string-type.

Four properties, and this compiler asked two of them — `packed`, and a
component whose *base* is char. So `packed array [0..3] of char`,
`packed array [2..5] of char`, `packed array [1..4] of 'A'..'Z'` and
`packed array [blue..green] of char` were all string-types, assignable from a
literal and writable whole. §6.9.3.6 gives a whole-array write the same rule, so
that was wrong in two clauses for the price of one.

Six of the BSI suite's DEVIANCE programs are that shape, and
`doc/implementation-defined.md` documented both halves as deviations — one of
them describing the length-only comparison as "the standard's own exception to
name equivalence", which is true of the comparison and not of the predicate that
decides what may enter it.

## Decision

**One predicate, and every site follows.** `IsCharArray` is the only place the
question is asked; `IsStringType`, `Assignable`'s structured branch, the
write-parameter check and the value-parameter length rule all read it. Adding
the two missing clauses to it fixed all six programs and touched nothing else.

- **The component must be `char`, not a type whose base is char.** `IsChar`
  sees through a subrange to its host, which is right everywhere else in this
  compiler (ADR-0018) and wrong here: §6.4.3.2 says *a denotation of the
  char-type*, and `packed array [1..4] of 'A'..'Z'` denotes no char-type.
- **The smallest *value* is not the smallest ordinal.** For an index-type of
  `blue..green` over `(red, blue, yellow, green)`, `ord(blue)` is 1 — so a
  lower-bound test alone accepts it, and DEV070's own comment says it is
  testing exactly that. `IsInteger(indexType)` is the clause that catches it and
  is not redundant with the bound beside it.

**One of the four is gated on the standard, and only one.** ISO/IEC 10206:1991
§6.4.3.3.2 requires the first bound to be nonvarying, to contain no
discriminant-identifier and to denote 1, and requires **nothing** of the largest
value — so `packed array [1..1] of char` is a fixed-string-type under Extended
Pascal and is not a string-type under ISO 7185. The other three bind under both.

## Consequences

**452 cases pass and the compiler still compiles itself**, which was the risk
worth measuring rather than reasoning about: `selfhost/compiler.pas` is built
out of padded char arrays — `kwLit`, `wordLit`, `msgLit`, `textLit`, the 440,000
character `pool` — and every one of them is `packed array [1..n] of char` with
n ≥ 2, so all four clauses hold on both sides of every `PoolIs` and `PutLit`.

**The `--std` gate is load-bearing in a way no argument would have shown.**
Making the largest-value clause unconditional fails `selfhost-codegen` and three
`tests/extended/` cases — the compiler is an Extended Pascal source (ADR-0082)
whose schema strings are `packed array [1..cap] of char` with a discriminant
upper bound. The gate is not defensive; without it the compiler cannot build
itself. `tests/extended/stringtype_capacity1.pas` is the half that says so.

**Two paragraphs left `doc/implementation-defined.md`**, and one of them was
mis-citing its own reason. Neither deviation exists now.

**No test in this tree had ever written any of the four shapes.** Six BSI
programs did, which is ADR-0086's argument for having a corpus nobody here
wrote — and ADR-0067's rule again, that a claim no test names is a claim
nothing checks.

### What this does not do

**It does not make `packed` mean anything in the layout.** §6.4.3.1 leaves that
to the implementation and `llvmType` packs nothing (ADR-0067); what changed is
which types are *designated* string-types, which is a Sema question. CodeGen and
`verify/` are untouched.

**It does not touch set compatibility's packing rule**, which §6.4.5 c) states
separately and which ADR-0072 recorded as a deviation.
