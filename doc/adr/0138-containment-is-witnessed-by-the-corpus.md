# ADR-0138: Containment is witnessed by the corpus, not by one program

Date: 2026-08-20

## Status

Accepted. Answers the fourth of the seven open questions in `doc/roadmap.md`,
and is the gate ADR-0117's claim had been asserting without.

## Context

ADR-0117 makes `--std=afterschool` **contain** ISO/IEC 10206:1991: everything
Extended Pascal accepts, the dialect accepts and means the same thing. That is
the property every dialect feature is added to, and it is the reason the
containment can be stated at all — `stdKind` is ordered, `HasExtended(s)` is
`s >= stdExtended`, and all 40 sites asking "does this mode have Extended
Pascal?" go through the predicate.

`CLAUDE.md` already records what happens when one of them does not:

> Never write `langStd = stdExtended`; it silently switches Extended Pascal off
> for the dialect and almost every case still passes — it was 545 of 547 when
> the predicate was written, and the two that noticed are the reason it exists.

Two of 547. The witness was `tests/dialect/inherits_extended.pas`, 122 lines,
exercising the Extended Pascal features its author thought to write down. It
has no `readstr`, no `writestr`, no `bindable`, no `date` or `time`.

A claim about every program was therefore witnessed by one program, while the
corpus that would witness it properly — 228 sources under `tests/extended/`,
each with a golden — sat compiled under exactly one mode. That is the same
shape as the gap ADR-0067 and ADR-0080 were written about: no corpus program
had ever written `pack`, `page` or a string constant, so every oracle agreed
they worked.

## Decision

**Compile the whole of `tests/extended/` a second time under
`--std=afterschool` and require the same behaviour.**
`tests/checks/containment.sh`, a `ctest` case named `dialect-containment`,
13 seconds, 228 cases.

Four decisions inside that sentence:

**a) Behaviour, not IR.** The obvious implementation diffs the emitted `.ll`.
It does not work and the reason is not incidental: 19 of 219 sources differ
textually, and sixteen of those differ because the dialect is working —
ADR-0119 spells `--std` into a module's activation names, and ADR-0118 adds a
tag check to every variant access. A gate with sixteen permanent exceptions is
a gate whose exception list nobody reads. Containment is a claim about what a
program *means*, so the gate runs the program: `run_test.sh` already decides
"same compilation outcome, same output, same diagnostics", and it is handed the
case with `afterschool` instead of `extended`.

**b) A catalogue with an argument per entry, failing in both directions.** Four
cases diverge. Three are the `*_refused` cases, whose subject *is* what
`--std=extended` says about a dialect construct — asking for that refusal from
the mode that has the feature would be asking the dialect not to have it. The
fourth is `substring_errors`, below. A listed case that stops diverging fails,
because an entry that has stopped being true describes a compiler that no
longer exists (ADR-0013's `KNOWN_GAP` rule, applied to a sixth catalogue).

**c) The bar for an entry is containment, not difference.** Not "the two runs
differ" but "they differ and the difference is not something Extended Pascal
accepts". A case that accepts a construct under the dialect which Extended
Pascal also accepts, and means something else by it, is a containment defect and
may never be listed. The catalogue says so at its head, because the failure mode
of every exception list is that it becomes the place failures go to be quiet.

**d) The corpus size is reported and zero fails.** A gate enumerating its corpus
by glob has two ways to be green — everything passed, and nothing ran.
`difftest_check.py` carries the same check for the same reason.

## Consequences

**The mutation that motivates it now fails.** Switching Extended Pascal off for
the dialect at the `readstr`/`writestr` site — `langStd = stdExtended` where
`HasExtended(langStd)` belongs, the literal error `CLAUDE.md` warns against —
produces a working compiler under which **all 617 existing cases pass**,
`inherits_extended` included. `dialect-containment` names sixteen.

The same mutation at the string-comparison site is caught by
`inherits_extended`, with one opaque failure; the gate reports ten cases with
their diagnostics. So the gate is both broader and more specific, and the two
are not alternatives — the witness stays, because it is the readable statement
of what containment means and the gate is a sweep.

**It found one thing, and the thing it found was not in the corpus.**
`substring_errors` is the only case in 228 that diverges for a reason other
than being about the dialect: `a[1..2]` on an `array [1..4] of integer` is a
substring of a non-string under Extended Pascal and a slice under the dialect,
so the two modes reject the program with different messages. Containment is
intact — no valid Extended Pascal program writes `a[i..j]` on a non-string —
and this is the weakest form of `doc/roadmap.md`'s open question §6 observed
rather than reasoned about: what the *dialect* says about a program both modes
refuse.

Following it found a defect no corpus program could reach, because slices are
dialect-only and the corpus is conforming: two slices are compatible
(AP §6.4.5), the relational operators ask compatibility, and
`a[1..2] = a[3..4]` was accepted by Sema and emitted as `icmp eq { ptr, i32 }`
— invalid IR, an error about a file nobody wrote. ADR-0139 is the fix.

That is worth stating precisely, because it is not the claim this gate makes:
the sweep did not find the defect. It found a diagnostic difference, and the
diagnostic difference was a thread. A gate that makes a corner of the language
visible is doing something a gate that tests a corner cannot.

**A hole in the gate itself was found by testing it.** An entry naming no case
— a typo, or a case since renamed or deleted — was accepted in silence, which
takes an argument out of service without failing anything. That is the quiet
half of "fails in both directions", and it is now the third failure direction:
listed-and-passing, and listed-and-matching-nothing.

## What this does not do

**It does not sweep `tests/` under `--std=extended`.** The first two standards
are *not* nested (ADR-0033) — Extended Pascal reserves word-symbols a valid
ISO 7185 program may use as identifiers — so there is no containment to check
between them and a sweep would compare two rejections, which ADR-0034 already
records as the mistake that passes.

**It does not compare the dialect against itself at two optimisation levels**,
and it does not replace `inherits_extended.pas`.

**It cannot see a feature the corpus does not exercise.** 228 sources are a
much better witness than one and they are not the language: a word-symbol the
dialect reserves in future breaks containment for every program using that
identifier, and this gate sees it only where a corpus program does. That is the
open question `doc/roadmap.md` §1 asks, and this gate is the instrument that
would report the answer rather than the answer.
