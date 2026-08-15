# ADR-0104: The compiler instruments itself

## Status

Accepted.

## Context

ADR-0103 measured procedure coverage and said plainly what it could not see: a
procedure entered once counts as covered, so the `case` arm nobody reaches is
invisible. It also said why the obvious finer measurement was refused — IR basic
blocks are the wrong denominator, because 8,304 of the compiler's own 26,655
are the bounds-check and nil-check failure paths CodeGen emits for its own
subscripts, unreachable by design.

That record ended by naming what would be needed instead: *"the honest
denominator is lines a human wrote, and reaching it needs the compiler to emit
line information, which is a feature and not a script."* This is that feature.

The alternative was DWARF — emit debug line info, then symbolize
SanitizerCoverage's addresses back to source. It is more work, produces block
granularity rather than statement granularity, and makes the compiler carry an
opinion about a debug format. Emitting a counter directly is smaller and says
exactly what is meant.

## Decision

**`pascalc --coverage` emits one call to `pas_cov_hit` per statement, carrying
the line the statement begins on.** The runtime records which lines were reached
and writes them to `$PASCOV_LINES` at exit.

**The compiler decides what is executable, and says so in the IR.** This is the
part that matters and the reason the feature is small. The *denominator* is not
a separate artefact to be derived, guessed at, or kept in step: it is the set of
lines the compilation emitted a call for, readable straight out of the `.ll`
that compilation wrote. So the two halves of a coverage figure come from one
artefact and **cannot disagree about which lines were executable** — there is no
second notion of an executable line to drift. Every line-coverage tool that
keeps its own idea of executability has that drift; this one has nowhere to keep
it.

**What is instrumented is a *statement*, and the counter goes before it.** A
statement that traps still counts as reached, which is what makes a report
usable on a program that stopped. Two kinds are skipped and both would be noise:
an empty statement, which §6.8.1 admits anywhere and which emits nothing, and a
compound, whose line is the `begin` and whose constituents are each counted
already.

**It is a product flag, not a private hook.** `--coverage` is documented in
`-h`, in README and in `tools/pascalcc`, and works on any Pascal program. This
repository's own use of it (`tests/checks/line_coverage.py`) is one caller.

**The gate is a ratchet, and the record says that is weaker.** ADR-0103's
allowlist works because there are two entries with two arguments; a per-line
catalogue of arguments is not writable at 650. `tests/checks/line_coverage.txt`
therefore records the count *and* the per-procedure breakdown, and a regression
names the procedures that moved rather than only moving a number. That is worse
than the allowlist and better than a bare percentage, and `doc/sop.md` §7
carries the row saying which.

## Consequences

**95.1% of statements, and the 650 that are not are now a list.** Procedure
coverage had reported 99.6% and could report nothing finer; the same corpus runs
12,708 of 13,358 statements, and the report attributes every missing one to the
procedure containing it — which the `; <name> <line>` comments ADR-0103 added
are what make possible.

**It confirmed ADR-0103's proof from the other side.** `EmitTrapLength` shows
13 of 13 statements never run, which is what that record argued from the guard
conditions alone.

**It found the command line untested.** `ParseArgs` had 22 statements never run,
all of them error paths — an unknown option, `-o` with nothing after it,
`--import` with nothing after it, two input files, no input file. Nothing tested
any of it, and nothing *could* have noticed: those messages carry the
`pascalc: ` prefix, which `diagnostic_coverage.py` filters out as driver output
rather than a diagnostic about a program. **The gate that counts messages is
blind to them by construction.** `producttest.sh` now asserts each message and
its non-zero exit — the exit status mattering for the same reason the
rejected-program check gives, that a driver misreporting a bad flag as success
is worse than one saying nothing.

Writing those five checks found a bug in the checks rather than the compiler:
`grep -F "-o needs a file name"` parses `-o` as a *grep option*. Three cases
reported failure against a compiler that was behaving correctly. `--` fixes it,
and it is worth recording because the same shape will recur — every message this
project greps for begins with the flag it is about.

**Coverage costs an ordinary program nothing.** The `declare` is emitted only
under `--coverage`, so a module compiled without it is byte-identical to what it
was before this existed; the runtime's table is allocated on the first call, so
a program that never calls it has no BSS, no `atexit` and no startup cost.

**The two measurements are kept separate deliberately.** Procedure coverage is
gated by an allowlist with arguments and is the stronger instrument; statement
coverage is a ratchet and the weaker one. Merging them would mean taking the
weaker rule for both. They share `coverage.corpus()`, so there is one definition
of what the corpus is and the two cannot be told different things about it.

**What this still does not measure.** A line, not a branch: `if c then a else b`
written on one line counts as covered when either arm runs, and a multi-statement
line counts once. Statement coverage is not branch coverage, and this record
should not be read as claiming otherwise.
