# ADR-0144: The first audit of the dialect's specification

Date: 2026-08-20

## Status

Accepted. Records the second run of `.claude/skills/langspec-audit/`, the first
against `doc/afterschool-pascal-spec.md` (ADR-0135). ADR-0142 and ADR-0143 are
two of its findings and have records of their own; the fixes not worth a record
apiece are here.

## Context

ADR-0107 recorded the first audit, against the two conformance modes. This is
the first that was *possible* against the dialect: until ADR-0135 there was no
document stating what `--std=afterschool` accepts, so a reader had only the
compiler to read and nothing to disagree with.

`doc/roadmap.md` §2 is why it matters more here than anywhere else. ISO 7185 and
Extended Pascal have an external authority and the dialect has none — every
other oracle in this repository is anchored in a document somebody else wrote,
and the dialect's is written by the same person who wrote the compiler. An
audit's readers are the only thing here that can contradict a *reading*.

**Five readers, three to five clauses each**, told to assume the author misread
and to prove it, given the standards and a compiler and forbidden the ADRs, the
digest, the roadmap, `doc/sop.md`, `CLAUDE.md` and the scenarios for their own
clauses.

## What it found

**Two defects with records of their own**: ADR-0142, a module reachability walk
that stopped one level short and let a forbidden link succeed and then return a
wrong value; ADR-0143, a slice that could be assigned (writing outside an
array) and whose type could be named through `type of`.

**Two conformance defects fixed here.**

*ISO/IEC 10206:1991 §6.7.5.3's selectors.* `new(p, c1, ..., cn)` must attribute
each case-constant's value to the corresponding tag-field — the clause says so
and its NOTE 1 spells it out. The tags were read to size the allocation and for
nothing else, so `new(p, green)` left the tag reading `red` and `case p^.k of`
took the wrong arm: a conforming program given a wrong answer. **ISO 7185 does
not have the requirement** — its §6.6.5.3 says the created variable "shall be
totally-undefined" — so the store is gated on `HasExtended` and `--std=iso7185`
is unchanged. `pcTagVals` is a new list parallel to `pcSelect` because an arm
*index* is not a tag *value*: `1, 2: (p)` is one arm and `new(m, 2)` must store
2.

*§6.10.2's read.* The clause writes `read(f, v)` out as `begin v := f^; get(f)
end`, and its NOTE 2 says the variable-access "may be a variant-selector or a
component of a packed structure". So a read's target is assigned to, and
ADR-0118's activation applies. It did not: `designatorGuard` was `vgWrite` at
one construct only, and `read(r.gr)` trapped under the dialect while working
under `--std=extended` — a valid Extended Pascal program refused, which is a
containment break.

**One reserved-name hole.** `@frame1`, the program's level-0 activation record,
is an `internal global` and was not refused as a foreign name, so
`external 'frame1'` produced *redefinition of function '@frame1'* — the error
about a file nobody wrote that ADR-0121 exists to prevent.

**Nine citation and wording defects in the specification**, listed in its
Annex E.9. The three that matter most: §6.1.3 was credited with shadowing,
which is §6.2.2.5's; `external` was called a remote-directive, which it cannot
be, §6.1.4's production admitting one token where an external-directive is two;
and **AP §6.11 was strictly stronger than AP §6.13.1**, forbidding the very
case ADR-0137 exists for.

## Decision

Fix all of it, and record three things the audit taught about the *method*.

**a) Adjudication is not a formality.** The skill says to reproduce every probe
before acting, and it paid twice. A reader reported that the empty-statement
follow-set omits `otherwise`, and probed it with a *non-empty* arm, which has
always worked; reproducing it with an **empty** arm found a compiler defect the
reader had not — `case i of 1: otherwise s end` refused. Conversely a reader's
`p := q` finding was real but its suggested fix, an arm in `Assignable`, turned
out to be masked at the only site reaching it (ADR-0143).

**b) A clause classified `structural` is unfalsifiable by construction.**
`spec-clause-traceability` fails a scenario citing one, so a requirement filed
there can contradict a `testable` clause indefinitely and nothing may test it.
That is exactly what AP §6.11 did. ADR-0106 called this "the dangerous
direction … one-way" and the audit found the first instance. §6.11 and §6.4.3.4
are re-triaged `testable`.

**c) The readers' isolation failed in the same way as last time, and they all
said so.** Every one of the five reported that `CLAUDE.md` was injected before
its first turn and that it could not decline. ADR-0107's row in `doc/sop.md` §7
stands unchanged. One reader noted the injected text carried the *same*
mis-citation it was about to report independently, which is the clearest
demonstration available that the finding was not anchored by it.

## Consequences

Six commits, five new cases (`case_empty_otherwise`, `new_selectors`,
`read_variant`, `slice_assign`, `slice_escape`), one gate extended from seven
combinations to eight, one gate taught to read the IR it is about, and four new
rows in `doc/sop.md` §7.

**The audit's yield was higher than the first one's**, and the reason is worth
stating: ADR-0107 audited readings that had been examined before, and this
audited a document eight days old describing features that had never had an
independent reader at all. Expect the next run against the same clauses to find
much less.

**Two findings are recorded rather than fixed**, both in `doc/sop.md` §7: a
module exporting an undiscriminated schema with a tagged variant is still
called portable (no misbehaving program could be built from it), and two
`external` declarations naming one linker symbol still emit two `declare`s.

## What this does not do

**It does not make the dialect's specification externally anchored.** The
readers attacked it with the two standards in hand, which works for every claim
the document makes *about* those standards — and nine of those were wrong. It
cannot work for a requirement the dialect invents, where there is nothing to
check against and a reader can only ask whether the processor agrees with the
document. `doc/roadmap.md` §2 stays open.

**It does not audit the clauses no reader was given.** Five readers covered
lexis, slices, variants and optionals, parameters and foreign declarations, and
the triage. AP §6.5.3, §6.6, §6.9 and §6.10 had no reader.
