# ADR-0352: A generic body belongs to two files

Date: 2026-09-06

## Status

Accepted. Adds `tests/checks/lsp_coverage.py`, its ratchet, and a
`PASLS_COVERAGE_IR` seam in `lsp/build.sh`. Follows ADR-0350, which met the
same problem one directory over and answered a weaker form of it.

## Context

`lsp/pasls.pas` is 3814 lines, the second-largest program written in this
dialect, and had 32 replay sessions and **no statement coverage**. That it
needed one is not a guess: `--dump-symbols` crashed on any source containing a
`trait` for a day and every session stayed green, because no session named such
a source (ADR-0349).

ADR-0350 measured `lib/` by instrumenting exactly one module per link, because
`$PASCOV_LINES` records a bare line number and no file. The server needs the
same rule and it is not sufficient here, for a reason that record's subject
could not show.

## Context — the part that is new

**A generic routine's body is emitted into the translation that activates it**
(AP 6.7.3.5, ADR-0211). `pasls.pas` imports `PasContainer`, whose routines are
generic, so **eighteen bodies — `vecinit`, `vecpush`, `mapget`, `findslot` and
the rest — are emitted into `pasls.ll` and instrumented with it, carrying
`PasContainer`'s line numbers.** `; vecinit 128` opens a body whose first
statement emits `pas_cov_hit(343)`, and 343 is a line of `pascontainer.pas`.

So instrumenting one module is not enough: the module's own IR contains another
file's lines. Read naively the answer is 1474 of 1376, and **it is wrong in
both halves** — 48 of the "instrumented lines" are not the server's at all, and
30 of the server's own lines would be marked covered by a vector operation
running somewhere else entirely.

ADR-0350 saw the mirror image and could not see this one: there, a module of
generics contributed *nothing* to its own IR and reported a denominator of 0,
which is visible and was written down. Here the contamination is inside a
number that looks reasonable.

## Decision

**The IR is partitioned by routine, and a routine the source does not declare
is foreign.** `pascalc --dump-symbols lsp/pasls.pas` says which routines
`pasls.pas` itself declares — asked of the compiler rather than read out of the
Pascal, for ADR-0239's reason — and every other body in the module is an
instantiation belonging to somebody else. Its 78 line numbers are subtracted
from **both** halves.

**The 30 server lines that collide are excluded and counted**, as `ambiguous 30`
in the ratchet, and **ratcheted upward too**. Without that a new generic call
site would eat more measurable lines, shrink the denominator, and read as an
improvement.

**The gate drives `lsp/run.sh` rather than reimplementing it.** Framing,
`.mcp`, `.workspace`, `.scratch`, `.tmpdir` and `PASHEAP_BALANCE` are that
script's business and a second copy would drift — `thread-sanitizer`'s argument
(ADR-0327) applied to a different harness. A consequence worth stating: this
gate fails when a session golden fails, deliberately, because a coverage number
taken from a conversation that went wrong measures nothing.

**`lsp/build.sh` gains `PASLS_COVERAGE_IR`**, an environment variable rather
than a flag, because `run.sh` passes that script its two arguments and has none
to spare — `AFTERSCHOOL_PASCAL_OPT` above it took the same shape for the same
reason. Setting it instruments `pasls.pas` and no component, and writes the
instrumented IR out, so the denominator comes from the very module the
numerator came from.

## Consequences

**1303 of 1396 statements, 93.3%, over 32 sessions, in 2.4 seconds.** The worst
are `renamesymbol` 9/58, `finduse` 8/48, the program level 5/52, and
`readformatted`, `readuses` and `usesofcomponent` at 5 each.

**Two floors, and one of them fires before measuring** (ADR-0282): fewer than
25 sessions replayed, or fewer than 1000 statements instrumented, is a failure
rather than a number.

**The mutations name what moved.** Removing the `rename_across` session gives
*98 statements never run, was 93 — 5 lost*, naming `identin: 0 -> 4 of 7` and
`renametarget: 0 -> 1 of 14`. Cutting the sessions to 24 fires the floor
instead, before any measurement is taken.

**93.3% is a percentage of 1396 and not of 1426.** Thirty of the server's own
statements are neither covered nor uncovered, and a reader comparing this with
`line-coverage`'s 98.1% is comparing two denominators that were arrived at
differently.

## What this does not do

**It does not measure the thirteen `lib/` components the server links.** Only
`pasls.pas` is instrumented, so how much of `paslsp.pas` or `pasjson.pas` an
LSP *conversation* exercises is still nobody's question — `lib-coverage`
answers over the corpus, which is a different sweep. This is not a gap that was
closed and must not be read as one.

**It does not measure branches.** `--coverage` emits the counters and this gate
unsets `$PASCOV_BRANCHES`, so `if c then a` with no else-part is covered
whenever it is reached. That is a second ratchet somebody could add, and a
fifth one-directional number to justify (`doc/sop.md` §7).

**It cannot say which session covers what.** The union is over all 32, so a
session that has become redundant is invisible to it.

## Alternatives rejected

**Attribute the foreign lines to `PasContainer` instead of dropping them.**
They are real coverage of a real module and it is tempting. It cannot be done
honestly: the line numbers collide with the server's own, so a counter at 343
could be either, and choosing would be inventing an answer. The compiler
recording a *file* per counter is what would close it, and that is a feature.

**Reimplement the session replay inside the gate** to avoid failing when a
golden fails. It buys a coverage number from a broken conversation, which is
the thing not worth having.

**Count the ambiguous 30 as covered.** They are reached by *something*, so it
would even be defensible. It also inflates the number by exactly the amount
nobody can check, which is how a coverage figure stops meaning anything.
