# 49. `complex` is a simple type, and therefore a vector

Date: 2026-08-11

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.4.2.2 e): "The required type-identifier `complex` shall
denote the complex-type. The complex-type shall be a **simple-type**. The
values shall be implementation-defined approximations to an
implementation-defined subset of the complex numbers."

§6.4.2.2's NOTE 4 adds that the representation "could be rectangular, polar, or
something quite different".

## Decision

**Simple is the word that decides the whole feature.** A simple type is a
*value*: it is assigned with a store, passed in a register, returned from a
function, and none of the by-address machinery ADR-0017 built for arrays and
records applies to it. That is exactly the position a set is in (ADR-0028), and
for the same reason — the standard says so.

**So the representation is `<2 x double>`, a vector rather than a struct.** A
two-double struct would have been the obvious shape and is the wrong one here,
because ADR-0030 already settled what happens when a two-word value has to
cross between the two backends: *nothing may depend on how a struct is passed*.
A vector is a single LLVM value that both backends can spell — built with
`insertelement`, taken apart with `extractelement` — and lowered by LLVM
identically whether the IR came from the C++ builder or from the text emitter.
Only three functions know the representation is rectangular, which is what
makes NOTE 4's latitude free to honour.

**The arithmetic is emitted inline.** `+` and `-` are one vector instruction
each; `*` and `/` are the school formulas over the extracted parts; `=` and
`<>` are two comparisons and an `and`. Nothing goes to the runtime, and that is
deliberate: a complex value never crosses the C boundary, so the C ABI's
opinion about a two-double aggregate never enters the picture.

**The transcendentals do go to the runtime, and each is two calls.**
`pas_csqrt_re` and `pas_csqrt_im` both compute `csqrt` and return half of it.
That is the same trade ADR-0030 made for a procedural parameter's pair —
travel as two scalars rather than let an aggregate ABI into the interface. The
cost is one redundant call in the six least common operations in the language;
the benefit is that the emitted IR names only doubles. The two halves cannot
disagree: each is the same libm call on the same inputs.

**§6.7.6.2's principal values are C99's**, so `csqrt`, `clog` and `catan` are
called directly rather than re-derived — the standard's NOTE describes exactly
C99's conventions (arg in (−π, π], sqrt with non-negative real part).

**Two places the result kind does not follow the operand**, and both are in
table 2: `abs` of a complex is its *magnitude* and `arg` its argument, and both
yield a **real**. Everything else — `sqr`, `sqrt`, `exp`, `ln`, `sin`, `cos`,
`arctan` — gives a complex for a complex.

**§6.8.3.5 gives complex only `=` and `<>`.** The four ordering operators take
"any simple-type **except** complex-type": there is no order on the complex
numbers, and the standard declines to invent one. The diagnostic says that
rather than saying the operator is unknown.

## Consequences

**Nothing about this feature is lexical.** `complex`, `cmplx`, `polar`, `re`,
`im` and `arg` are required *identifiers*, not word-symbols — a valid ISO 7185
program may declare a type called `complex` and a function called `re`, and
`tests/complex_redeclared.pas` is one that does. So this is the first Extended
Pascal feature here whose language gating lives in **Sema** rather than in the
lexer: the type name is refused where it is resolved, and the functions where
the call is checked and only when nothing else of that name was found.

Sema therefore had to learn which standard it is checking, which it had managed
without until now.

**A function may return a complex**, and that list of result types grew by one
word rather than by a rule: ISO 7185 §6.6.2 allows a simple type or a pointer,
and §6.4.2.2 adds `complex` to the simple types.

**`write` and `read` refuse a complex, and needed no change to do it.**
§6.10.3.1 lists what `write` accepts and complex is not on it; the existing
"a value of type complex cannot be written" is the message that was already
there for every other type not on the list. A program writes `re(z)` and
`im(z)`.

**The implicit widening is §6.4.6 c)**, so `z + 1` and `w := 2` work through
the same `assignable` question every other conversion asks. There is no
narrowing: `re` and `im` are the only way back to a real, which is why
`r := z` is refused.

**`verify/` gained nothing.** The complex arithmetic is IEEE floating point
with no error conditions to prove: §6.7.6.2 gives the type exactly one, `ln(0)`,
and that is a runtime comparison in three lines of C. ADR-0015's lesson about
FP proofs — state the property inside FP theory or it will not solve — would
apply if there were a property here worth stating, and the multiplication
formula is not one: it is the definition, not a lowering of it.

**Twenty-three mutations across both compilers, all caught, and one
equivalent.** Three escaped first and were given tests, and all three were the
same kind of gap — a value that is *read back* rather than merely computed.
`polar` was only ever checked through `abs`, which cannot tell its two parts
apart; and the Pascal backend's `LlSize` for a complex is used **only** by a
whole-variable copy and by `new`, never by an indexed access, where LLVM
computes the stride from the emitted type. A record holding a complex, copied
whole and with its *other* field read before being overwritten, is what makes
that number observable.

The equivalent one is the Pascal backend's `LlAlign` for a complex. It reaches
two places: a memcpy's alignment hint, where understating is always sound, and
a record's layout, where 8 instead of 16 gives a *smaller* size that still
covers every field — the difference is trailing padding, which no program can
read. Recorded here so the next reader does not go looking for a test.

## What this does not do

**There is no complex literal**, and the standard gives it none: `cmplx(x, y)`
and `polar(r, t)` are the only way to write one, and both are ordinary
function calls.

**A complex is not written to a text file.** That follows from §6.10.3.1 and is
not an omission, but it does mean every program that shows one writes its parts.

**`sqr` of a complex is inline and `**` is not**, which looks inconsistent and
is not: `sqr` is one multiplication and `**` is `exp(y·ln x)` with two special
cases the standard spells out (`x = 0` gives zero, `y = 0` gives 1.0). The
special cases are what keep the definition total where `ln(0)` is not, and they
live with the call that needs them.
