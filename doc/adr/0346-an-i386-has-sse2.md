# ADR-0346: An i386 has SSE2

Date: 2026-09-06

## Status

Accepted. Adds a processor to the clang command line `tools/pascalcc` builds
for `i386-pc-linux-gnu`, and closes the `doc/sop.md` §7 row ADR-0345 opened the
same day. ADR-0325, which admitted the target, is not superseded; this says
which i386 it admitted.

## Context

ADR-0345 pinned `-march=pentium4` inside `tests/checks/target32.sh` so that the
gate would answer the same thing on clang 19, which compiles this triple for
`i686`, and clang 21, which compiles it for `pentium4`. That was right for the
gate — it asks whether a program behaves when a *pointer* is four bytes, and a
floating-point unit is a second axis it never chose — and it left the real
question open, in `doc/sop.md` §7: **x87-only i386 was then untested rather than
working**, and two things were measured failing on it.

  a) §6.7.6.3 defines `round(x)` as equivalent to `trunc(x ± 0.5)`. At
     `x = -0.49999999999999994` that difference is exactly `-1.0` as a double
     and a shade above `-1` in an eighty-bit register, so `round` contradicts
     the clause that defines it. `tests/round_equivalence.pas` exists for this
     distinction and says so in its own header.

  b) D.32 makes `sqr(x)` yielding a value the type does not have an **error**,
     and the check is that the result is infinite where the operand was finite.
     An x87 register has a fifteen-bit exponent, so `sqr(-1e200)` is an
     ordinary finite number in it, the check does not fire, and the program
     prints a value where every other target here stops.

The second is the one that decides it. A difference in arithmetic is a
difference; **an error condition this language says it detects, going
undetected on one target, is a hole in the language on that target.**

## Decision

**An i386 this compiler emits for has SSE2.** `tools/pascalcc` names
`-march=pentium4` on every `clang` it starts when the target is
`i386-pc-linux-gnu`, and on no other target.

The rule is the *driver's* and not the compiler's, because the IR does not
change: a `double` is a double in it whatever the processor, and what the rule
decides is which x86 the assembler generates for. Nothing about this reaches
`pascalc`, which goes on emitting one module for the triple.

`pentium4` rather than `-msse2 -mfpmath=sse`: one flag, it names a processor
rather than a pair of code-generation switches, and it is what a current clang
already defaults to — so on clang 21 this changes nothing at all, and on
clang 19 it changes the two cases above.

**`doc/implementation-defined.md` §2.2 carries it**, in the row answering what
the real-type is. That row said "IEEE 754 binary64" and was answering about
storage; it now says *at every stage of an expression*, which is the sentence
the target requirement is derived from.

## Consequences

**A pre-2003 x86 is no longer a target of this compiler**, and that is the
whole of what is given up. The Pentium 4 shipped in 2000 and SSE2 has been the
x86-64 baseline since the beginning, so what is excluded is a Pentium III or
earlier — and ADR-0109's test is whether a program someone would actually write
today needs it.

**Two places name the processor and each names the other.**
`tests/checks/target32.sh` builds a runtime and a probe with direct `clang`
calls, which is the one path `pascalcc` is not on, and a runtime built for a
different processor than the programs linking it is exactly what a shared
`double` in a struct would find. There is no third.

**`producttest` asserts it in both directions**, and the second direction is
the one that matters: a rule written without its condition would narrow *every*
target to a 2003 processor and no other check here would notice. The check
reads the clang command line out of `bash -x` rather than the IR, because the
IR is where this is deliberately invisible — the only property in that harness
that cannot be read off the emitted module. The trace is read whether or not
clang then succeeds, so a machine with no 32-bit toolchain still asserts it.

**It closes a `doc/sop.md` §7 row on the day it was opened**, which is unusual
here and worth noting: the row said the decision had never been put, and the
distance between *that has never been decided* and a decision was one sentence
from the person whose call it was.

## What this does not do

**It does not make the compiler refuse an x87-only i386.** There is nothing to
refuse — `--target=` takes a triple and a triple does not name a processor, so
a user who wants x87 can pass `-march=i686` in `AFTERSCHOOL_PASCAL_CFLAGS` and
get the two divergences back. What this decides is the *default*, which is what
every program built by this driver gets.

**It does not touch the other two targets.** aarch64 and x86-64 both have
IEEE-conforming double arithmetic without a flag, which is why the condition is
written rather than the flag applied everywhere.

**It does not revisit `-ffloat-store` or `-fexcess-precision=standard`.** Both
were measured on clang 19 and neither fixes the conversion: the value is stored
as `-1.0` and converted from the register as `0` in one statement.

## Alternatives rejected

**Catalogue the two cases as i386 divergences.** This was ADR-0345's position
for about an hour, and it records b) — a missed error condition — as a property
of the target. The catalogue is for what cannot be fixed; this could be fixed
with one flag.

**Pin `-march=i686` and keep the x87.** The conservative reading of the triple,
and it makes the language weaker on that target for the sake of processors this
dialect has no other reason to serve.

**Put the flag in the compiler rather than the driver.** The compiler emits IR
and the IR is unchanged, so the flag would be a fact about assembly held by the
half that does not assemble — and `pascalc` would need a second opinion about
what a target means. ADR-0009's split is what makes the driver the right place.
