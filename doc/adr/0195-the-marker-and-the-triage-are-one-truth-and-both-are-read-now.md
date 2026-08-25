# 195. The marker and the triage are one truth, and both are read now

Date: 2026-08-25

## Status

Accepted. AP 5.6, and a second half added to `spec-clause-traceability`.

## Context

AP 5.6 was written three days before this record so that a design could be
written down before it was built — the text model's whole specification existed
for two increments before any of it worked. It says a clause stating a
requirement the processor does not meet shall be marked
`[not yet implemented]` **and** shall have every clause under it classified
`not-implemented` in `tests/spec/clauses/triage.tsv`.

Two places, one truth. Only the second was read: the triage class is what makes
`spec-clause-traceability` refuse a scenario claiming the feature works, and
nothing looked at the marker at all. `doc/sop.md` §7 recorded the gap on the
day 5.6 was written, which is the right instinct and not a fix.

Each direction is its own kind of wrong:

- **triaged, marker dropped** — the document reads as though the processor
  meets the clause. A reader consults 6.4.15 and believes it; only somebody
  who thinks to open a `.tsv` in `tests/` finds otherwise.
- **marked, left `testable`** — the clause sits in `clauses/pending.txt` as
  ordinary work nobody has got to, and the gate that should refuse a scenario
  about it refuses nothing.

This is ADR-0144's shape in a document rather than in a compiler: one truth in
two places with one of them read, which is what `foreign_reserved.py` was doing
when it kept a regex copy of a rule and compared it against itself.

## Decision

**`spec-clause-traceability` compares them, in both directions.**

The gate reads `doc/afterschool-pascal-spec.md` for headings carrying
`[not yet implemented]`, expands each to the clauses under it — a marked
heading carries its sub-clauses, which is what marking 6.4.15 meant when the
text model was three increments from being built — and requires that set and
the `not-implemented` rows of the triage to be **equal**.

It costs about forty lines in a gate that already reads the triage, and it
needed no new file: the marker is in a document this repository owns and the
triage is beside the gate.

## Consequences

Both sets are empty today and the check passes vacuously, which is the state
AP 5.6 expects to be in — the mechanism exists for the next feature designed
ahead of its implementation, not for a standing backlog.

Demonstrated in both directions rather than argued: marking 6.4.15's heading
again fails thirteen times, once per clause under it, and triaging 6.4.15.7
`not-implemented` without a marker fails once — and, incidentally, fails a
second time through the check that already existed, because a scenario cites
it.

## What this does not do

**It does not check that a marked clause is genuinely unimplemented.** Nothing
can: the whole point of the marker is that there is no code to ask. A clause
marked out of caution, or left marked after the feature landed, passes as long
as the triage agrees with it — which is the same limit `partial_cases.txt` and
every other catalogue here has.

**It does not reach the two ISO standards' triage rows.** They have no marker
convention and want none; both standards are complete, so `not-implemented` is
a class only the dialect can currently need.

**It does not enforce AP 5.6's prose about 5.1.** That sub-clause also says a
processor complies "other than by such a clause", and whether the compliance
statement is read correctly is a question about a reading, which no gate here
can answer (ADR-0072).
