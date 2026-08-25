# 197. A register only appended to is one that decays

Date: 2026-08-25

## Status

Accepted. `doc/sop.md` §7, audited as a whole for the first time, and
`tests/dialect/text_arena_loop.pas`.

## Context

§7 is the live list of what is currently *not* checked here. Every gate in this
repository exists because of a row in it, and the section's own instruction is
two sentences: add to it when a gate is declined, remove from it when one is
closed.

Only the first sentence has ever been followed. The register reached 57 rows
over ninety-odd records, and no one had read it end to end — each change added
the row its own work argued for and left the rest alone. That is exactly the
decay a blind-spot register exists to prevent, happening to the register.

**One row had predicted its own violation.** ADR-0111's string arena is
released at the end of any statement that took storage, and *which* statements
those are is a counter the emitter's producers bump. The row about it ended: *a
fifth would still have nothing looking for it.* Three arrived at once with
AP 6.4.15 — a text's join, its store, and the operand of a comparison that is
not already a text — and none was pinned by anything. The sentence naming the
hazard was in the tree, in the file whose job is naming hazards, while the
hazard happened.

The failure mode is not carelessness about one row. It is that a row stating a
condition under which it closes has no reader at the moment the condition is
met: the person who meets it is working on the feature, not on the register.

## Decision

**The register is audited as a whole after a milestone**, the way the rest of
the documentation is (`docs-engineering`), and the audit is dated in §7's own
preamble so the next reader can see when it was last true rather than assuming.

**A row that names its own closing condition is re-read when the condition is
met.** Two rows here did, in the same words — *this row is dated from the
record, not from the first dialect feature* — and both records had shipped long
since.

**And what an audit produces is evidence, not a rewrite.** Every claim this one
touched was re-measured: the eight arena producers were each mutation-checked
on the day, the tagless variant part was re-probed and still reads an inactive
arm and exits 0, and every count was taken from the gate that reports it rather
than from the previous sentence.

## Consequences

**The arena gap is closed rather than recorded.**
`tests/dialect/text_arena_loop.pas` pins the three producers AP 6.4.15 added,
and all eight producers are now mutation-checked: five were already pinned by
`tests/extended/str_arena_loop.pas` and `tests/dialect/foreign_string.pas`, and
each of those five was re-checked rather than believed.

**A property of such a test was found by writing one.** A loop that pins an
arena producer has to **isolate** it. The counter decides whether a *statement*
releases, so a bump removed from a producer that shares its statement with
another is invisible: `t := a + b` over texts holds the join and the store, and
dropping the join's bump changes nothing observable. The first loop written was
that shape and the mutation survived it. The loop that pins the join therefore
compares instead of assigning — and that the test isolates its subject is a
property of the test, which nothing checks.

**Four rows were stale and are corrected.** Two dated themselves from records
whose features had shipped; one carried a citation count from before four
increments moved it (101 citations over 100 scenarios, against 284 over 257);
one named its own closing condition — corpus programs reaching
`runtime/pasrt_unicode.c` — which had been met four increments earlier, so the
row now states the narrower thing that is left: the *tables* are read only by
a sweep that skips without the Unicode Character Database.

**Two stale numbers were outside §7**, in AP 5.5 d) and in `CLAUDE.md`: both
said 74 of 77 testable clauses where the answer is 86 of 89, and both still
said the whole of 6.4.15 was `not-implemented`, which was what held AP 5.6's
mechanism. It is implemented, nothing is marked, and the mechanism is properly
vacuous (ADR-0195). A documentation sync had run the same day and missed them,
which is worth stating: a sweep looking for what a document says about the
*code* does not see a document quoting a *gate*.

**`doc/design-digest.md` said three producers where there are eight**, in the
paragraph that explains why the counter exists at all. That is the same defect
one level in.

## What this does not do

**It builds no gate, and cannot.** Every row is a claim that something is *not*
checked, and a claim of absence is what no oracle here can measure — a gate
over the register would need each row to carry a machine-readable closing
condition, which is a gate per row, which is the thing the row says does not
exist. What replaces it is a habit and a date.

**It does not read every row against the code.** Fifty-odd rows were judged
from their own text and from what has landed since; the four corrected are the
ones where a claim was checkable and had moved. A row like *a misreading is
invisible to every oracle here* is not the kind of thing an audit confirms.

**It does not touch the compiler.** No `Model-unchanged:` question arises: the
only Pascal in this change is a test case.

## Alternatives rejected

**Striking the stale rows quietly** while landing the arena test. It would have
left the register looking as though it had always been right, and the one fact
worth carrying out of this is that it was not — which is why the preamble says
what the first audit found rather than only that one happened.

**A gate that fails when a row is older than N commits.** It would fire on the
rows that are permanently true — *a misreading is invisible*, *casing has no
conformance file*, *`-O1` and `-O3` are unexercised* — which are the majority,
and a gate whose usual outcome is "acknowledge and move on" is one people learn
to acknowledge without reading.

**Folding the audit into `docs-engineering`.** That skill checks documents
against the code, and every row here is a statement about something the code
does *not* have. It found none of these on the day it ran. The audit is closer
to `code-review` in what it asks and belongs where the register does, in
`doc/sop.md`.
