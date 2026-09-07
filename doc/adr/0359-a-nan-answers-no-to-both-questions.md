# ADR-0359: A NaN answers no to both questions

Date: 2026-09-07

## Status

Accepted. Fixes a guard that has never fired, moves the routine it guards to
where a second caller can reach it, and opens a question about the compiler
that this record does not answer.

## Context

`PasJson` renders a real as the shortest decimal that reads back (ADR-0309).
The search asks the processor for the value at a precision, reads that back and
keeps the first spelling that returns what it started from — so it needs the
value to *have* a decimal spelling, and it refused the two that do not:

```pascal
if (x <> x) or (abs(x) > maxreal) then PlainReal(x, s)
```

The second half answers for an infinity. The first is the usual spelling of
*is this a NaN* and, on this processor, it is not one. `<>` on reals emits
`fcmp one` — **ordered** not-equal, false whenever either operand is
unordered — so `nan <> nan` is FALSE and the guard was never taken for a NaN.
The scan below then looked for the `E` in what `writestr` writes for one, did
not find it, and read one character past the end of the string:

```
runtime error: array index out of bounds (1..21) at lib/dialect/pasjson.pas:1157:14
```

A program that asked a library to write a number was stopped by the library,
at a line of the library, with a message about an array. Every oracle here was
green over it, and would have stayed green: no corpus case ever built a NaN,
because **this language has no literal for one**. Both values had to be
constructed — `1e308 * 10.0` and then `inf - inf` — and
`doc/implementation-defined.md` §3 already recorded the first as breaking no
rule, §6.7.2.2 making the accuracy of the real operations implementation-
defined rather than making an unrepresentable result an error.

It was found by writing `PasToml` (ADR-0360), whose format *does* have
literals for both: `inf` and `nan` are TOML floats, so the second client of
this conversion is one that will hand it exactly the values the first could
not spell.

## Decision

**Ask `not (x = x)`.** `=` emits `fcmp oeq`, false for a NaN, and negating it
is true. The line does not depend on how the question below is answered.

**Move the conversion into `lib/pastext.pas` as `RealToStr`**, where
`IntToStr` already is, and have `PasJson` import it. It stopped having one
caller the moment a second format wanted the same doubles written for a person
to read, and a hundred-line search copied into a second module is the shape
this repository treats as a defect in itself — a copy free to drift, and one of
the two copies would still hold the guard that could not fire.

The move is in the same commit as the fix because the two are one edit to one
routine: fixing first and moving second carries the fix along, and moving first
and fixing second puts it in the same line of the same routine. Splitting them
would mean writing the fix twice or moving a known defect.

## What this does not do

**It does not decide whether `<>` ought to be the negation of `=`.** ISO 7185
§6.7.2.5 and ISO/IEC 10206:1991 §6.8.3.5 name the operators for the relations
*equal* and *not equal*, and a processor on which both `x = x` and `x <> x`
are false for some value of a type has made them something other than a
relation and its negation. Neither standard contemplates a NaN — real
arithmetic accuracy is implementation-defined and there is no such value in
either model — so nothing in the text settles it, and this processor admits
NaNs by admitting IEEE arithmetic.

Changing `opNe` on reals from `fcmp one` to `fcmp une` is a class A change: it
touches every real `<>` in the tree, needs a `verify/` rule and a model change,
and would make `<>` the negation of `=` at the cost of `a <> b` no longer
implying `a < b or a > b`. That is a decision with two defensible sides and it
belongs to whoever takes it, not to a library fix. `doc/sop.md` §7 carries the
row, and `tests/dialect/lib_json_nan.pas` pins **both** answers, so the day it
is decided the case is what says so.

**It does not change what is written for a non-finite value.** `RealToStr`
answers what `writestr` wrote — `INF`, `NAN` — and neither is a JSON number,
so `JsonRender` of one produces a document no JSON reader will take back. That
was true before this change for an infinity and is now true for a NaN as well
rather than being a trap. JSON has no spelling for either value, so no answer
here is a correct one; making `JsonRender` write `null` instead would be a
change to what an existing program produces and is a separate decision.
`PasToml` does not inherit the problem: TOML *has* both literals and writes
them itself.

**It does not assert the spelling.** The case prints whether the call returned,
not what it returned, because the text of a non-finite value is the host C
library's `%E` and no clause of either standard fixes it. A golden holding
`NAN` would be a golden about glibc.

## Consequences

`lib/pastext.pas` gains `RealToStr` and its two private routines, and its
heading gains the paragraph reconciling them with the module's own rule about
`readstr`: the rule is *never `readstr` on a caller's text*, not *never
`readstr`* — what the search reads back is a string it has just written itself.

Seven `.components` files gain `../../lib/pastext.pas` before their `pasjson`
line, and `lsp/pasls.components` gains its own. A case that reaches PasJson
through `--import-path` needed no edit, resolution being transitive
(ADR-0244).

`tests/dialect/lib_json_nan.pas` is the first case in this tree to hold a NaN
or an infinity at all.

The mutation `0359-a-nan-is-not-equal-to-itself` restores `x <> x`; the case
fails with the index out of bounds it was written for.
