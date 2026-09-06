# ADR-0350: The library had no coverage

Date: 2026-09-06

## Status

Accepted. Adds `tests/checks/lib_coverage.py`, its ratchet, and two assertions
to `tests/checks/new_project.sh`. ADR-0104 and ADR-0274 are not superseded —
this is their machinery pointed at a body of code they were never aimed at.

## Context

A coverage review asked what is measured, and the answer was 46 718 lines of
67 931. `line_coverage.py` iterates `components.COMPONENTS`, which is the
compiler's three program-components and nothing else. The rest:

| | lines | measured |
| --- | --- | --- |
| `selfhost/` | 46 718 | yes — 98.1% of statements |
| `lib/` | 11 160 | no |
| `runtime/*.c` | 5 551 | no |
| `lsp/pasls.pas` | 3 814 | no |
| `tools/pascalcc` | 688 | no |

Every library module *is* imported by some case — checked, and the first grep
saying six were orphaned was wrong, which is `doc/sop.md`'s own *count, don't
assume* rule catching the person applying it. But *imported* is
`procedure-coverage`'s question. What fraction of `PasRegex` or `PasJson` any
case runs was nobody's.

## Decision

**`lib-coverage` measures `lib/` over the cases that import it**, and answers
**2165 of 2554 statements, 84.8%**, per module.

**The attribution problem has one answer and it was already here.**
`$PASCOV_LINES` records bare line numbers with no file, so a program linking
six modules yields six sources' lines in one heap. `line_coverage.py` solves it
by instrumenting exactly one component per build; this instruments exactly one
*module* per link, and a line is then unambiguously that module's.

**What makes it affordable is that only the link repeats.** A module's IR does
not depend on which other module was instrumented, and neither does an
importing program's — so each module is translated twice and each program once.
125 (case, module) pairs cost 115 translations rather than 500, and the gate
runs in under seven seconds.

**Two neighbours of a tested key are asserted.** `build.ldflags` was proved
both ways when ADR-0348 landed — `-lm` links and a bogus library must not —
and `build.target` and `build.cflags` were not, so a key this reader parses and
then drops would have passed every test. Both are asserted by *refusal*, which
needs no toolchain: a target no compiler admits and a flag no clang accepts
must each fail the build.

## Consequences

**A generic library module cannot be measured this way, and the gate says so
rather than reporting a flattering zero.** A generic routine's body is re-read
and emitted in the translation that *activates* it (AP 6.7.3.5, ADR-0211),
which is the client's — so `lib/dialect/passortx.pas`'s own IR carries **no**
coverage sites while an importing program's carries 187. The module therefore
has a denominator of 0, which means *nothing here is measurable this way* and
never *everything here is covered*, and the run prints such modules by name so
the two cannot be confused. Closing it properly needs the compiler to record
which **file** a counter belongs to, which is a feature and not a fix.

**`PasTls` and `PasHttps` read 0 of 168 and are not uncovered.** Their only
exercise is `tests/checks/tls.sh`, a gate rather than a corpus case. Driving it
from here was rejected because that gate skips without libssl, and a ratchet
whose number moves with a machine's packages is not a ratchet — which is
ADR-0346's lesson, learned the same day about a different gate.

**A fourth one-directional gate is a cost, not a free win.** `doc/sop.md` §7
carried one row about the statement ratchet's weakness and now carries it about
a family: four numbers nobody has to justify, where `uncovered_procedures.txt`
and `heap_balance.txt` demand an argument per row and fail when one stops being
true. A per-line argument is not writable at this scale, and that is the whole
of the reason.

**Timeouts are reported rather than swallowed.** The first run took four
minutes at 15% of one core, waiting on cases that open a socket. Giving stdin
`/dev/null` and cutting the wait to fifteen seconds took it to seven seconds
**and raised coverage from 80.7% to 84.8%**, because reading cases finished
instead of blocking. What a timed-out case did reach is still counted —
`$PASCOV_LINES` is written as the program runs — and the count of cases that
gave up is printed, because a sweep that quietly waits is a sweep whose number
means something other than what it says.

## What this does not do

**It does not measure branches.** `line-coverage` gates a second ratchet over
directions (ADR-0274) and this measures statements only, which is the weaker
instrument for the reason that record gives.

**It does not measure `runtime/*.c`, `lsp/pasls.pas` or `tools/pascalcc`.**
The first two are the same shape and tractable; the third is shell and has no
instrument at all. All three are `doc/sop.md` §7 rows.

## Alternatives rejected

**Extend `line_coverage.py` to take `lib/` as a fourth component.** The
components are a §6.13 translation order (ADR-0233) and the library is 32
independent modules with 51 different driving programs; folding them in would
make one number of two questions and break the gate whose count two documents
quote.

**Instrument every module at once and one build per case.** Fewer links, and
the line numbers then collide across 32 files with no way to attribute one —
the exact problem the one-at-a-time rule exists to solve.

**Run `tls.sh` from the sweep to cover the last two modules.** See above; it
buys 168 statements and costs the property that the number means the same thing
on every machine.
