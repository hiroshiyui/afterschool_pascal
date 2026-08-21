# ADR-0152: The clauses with no titles

Date: 2026-08-21

## Status

Accepted. Repairs the machinery `doc/roadmap.md` §2 is about, and corrects one
of that entry's claims.

## Context

§2 names the risk this project's own history says is real: **every oracle here
bottoms out in "the standard says X"**, so a misreading is invisible to all of
them at once. ADR-0072's set-packing deviation survived in four documents and a
purpose-written test; `.claude/skills/langspec-audit/` exists because no oracle
here can contradict a reading, and ADR-0144 ran it once.

What §2 did not anticipate is a mistake in the **machinery between the standard
and the gate**.

`tests/spec/` is the one suite whose unit is a clause (ADR-0105). Its
denominator is two files: `clauses/iso7185.tsv` and `clauses/iso10206.tsv`,
generated from the standards by `clauses/extract.py`, and `clauses/triage.tsv`,
written by hand, which classifies each clause `testable`, `structural` or
`not-implemented` (ADR-0106). No text of either standard is in this repository
and none may be, so the inventory holds numbers and headings, which is what a
citation needs.

**A clause need not have a heading.** Every sub-clause of §6.2.2 (Scopes) and
§6.2.3 (Activations), in both standards, is a bare number on a line of its own
with the requirement under it:

```
6.2.2.9
The defining-point of an identifier or label shall precede all applied
occurrences ...
```

`extract.py` matched `number  Title-beginning-with-a-capital`, so it saw none
of them. **37 clauses** — 16 in ISO 7185, 21 in ISO/IEC 10206:1991 — were in no
inventory, no triage and no work queue.

They are not obscure. They are the most load-bearing clauses in this project:

| Clause | What it is | Citations in this tree |
| --- | --- | --- |
| §6.2.2.9 | a defining-point precedes its applied occurrences (ADR-0069, ADR-0100) | 56 |
| §6.2.3.8 | the events of a commencement, and b) is where a bound is evaluated (ADR-0113, ADR-0133) | 34 |
| §6.2.2.10 | required identifiers sit in a region enclosing the program (ADR-0097) | 29 |
| §6.2.3.6 | a supplying module commences first (ADR-0053) | 22 |
| §6.2.2.11 | what a name denotes at its defining-point it denotes everywhere (ADR-0101) | 4 |
| §6.2.2.5 | shadowing — the clause ADR-0144 found mis-cited as §6.1.3 | 9 |

**214 citations across the tree named a clause the apparatus did not have**, and
tagging a scenario with one produced

```
spec: extended §6.2.3.8 is cited by '...' but is not a clause of that standard
```

about a clause two records are about. `tests/spec/features/subrange_bounds.feature`
already carries §6.2.3.8 b) in its **header comment** as the clause it is
really about, and is tagged `@extended:6.4.2.4` because the right tag was
unavailable.

No reader would have found this. A reader cites a clause from the standard and
never opens the `.tsv`; the audit ADR-0144 ran was given the specification and
the standards, not the harness. `extract.py`'s own docstring carries the same
lesson one level up — assuming ISO 7185's kerning for ISO/IEC 10206 "yields five
headings out of a hundred and seventeen, which looks like a thin standard rather
than a broken regex" — and its `len(found) < 50` floor is far below 117 and 175.

## Decision

**1. A clause is a number, whether or not it has a title.** `extract.py` gains a
second pattern, and accepts a bare number as a clause only when **every
lower-numbered sibling is present too** — clause numbering is consecutive, and a
stray cross-reference has no run behind it. Titled siblings count as present, so
a part-titled parent still works. Over both PDFs this admits exactly the 37 and
nothing else.

The heading column takes the parent's heading and `(untitled)`. It is not a
title and must not be read as one; what the column is for is telling a reader
where the clause sits, and the parent's own heading is already in the file, so
nothing new is quoted from the standard.

**2. The inventory and the triage must name the same clauses, in both
directions**, checked by `spec-clause-traceability`:

- a triage row for a clause the inventory lacks means the **extractor lost
  one** — the regression guard for this defect, since the inventory is generated
  and the triage is not;
- an inventory clause with no triage row means the **denominator is short by
  one**, which is how 37 sat outside the count.

**3. The 37 are triaged**: 23 testable, 14 structural. The definitional ones —
"local to", "within", "activation-point", what an activation contains, what
"supplies" means — carry no requirement a program can exercise. The rest do.

**4. Two diagnostics stop asserting the wrong cause.** *"Not a clause of that
standard"* was said of a clause that is one and merely untriaged, which sends a
reader to the wrong file; and a clause entering the pending list was reported as
*"was cited by a scenario and is not any more"*, which is one of its two causes
— the other is the denominator growing, as it does here 23 times. Both still
fail; only the diagnosis changes.

**5. Six scenarios, for clauses that could not be cited at all.**
`tests/spec/features/scopes.feature` states §6.2.2.5, §6.2.2.9 twice (the rule
and its pointer-domain exception), §6.2.2.10, §6.2.2.11 and §6.2.3.5 as the
clauses state them. Each is a rule an ADR already argued — ADR-0097, ADR-0100,
ADR-0101 — and none had a clause-shaped test.

The §6.2.2.9 refusal is written **inside one constant-definition-part**, and
that is the interesting one: the obvious spelling, a procedure using a constant
declared after it, is refused too and for the wrong reason — ISO 7185 fixes the
order of the declaration parts, so that program fails the grammar before it
reaches §6.2.2.9. The scenario asserts the diagnostic for that reason.

## Consequences

Coverage moves from 61 of 256 testable clauses to **68 of 279**: the denominator
grew by 23 and seven newly-citable clauses gained a scenario. `pending.txt` goes
from 195 to 211.

Reverting `extract.py` and regenerating fails the gate **37 times**, one per
orphaned triage row, each naming the clause and saying the extractor has lost
one.

### And one of §2's claims was wrong

§2 says every FFI-facing decision has an authority available to it — POSIX, the
C ABI — and that "nothing else in the dialect has an authority". That is not
true of the largest dialect feature. **ISO 7185 §6.6.3.7's conformant array
parameter** is a formal parameter whose bounds travel with the actual, which is
what AP §6.7.3.9's slice exists for, and ISO/IEC 10206:1991's schematic formal
(ADR-0040) is a third member of the same family.

The standard answers the question differently in three ways the dialect chose
against deliberately — bounds preserved rather than renumbered from 1, a whole
array rather than any contiguous run of one, a value form as well as a borrow —
and congruity is a fourth, §6.6.3.7 having rules of its own where the dialect
uses compatibility, which is what ADR-0139 and ADR-0143 were each about. None of
it was written down: AP §6.7.3.9.4's NOTE argued the index domain against "the
open array of other Pascal dialects" while a standard on the shelf had the same
question. It is AP §6.7.3.9.1 NOTE 2 now.

`doc/roadmap.md` kept the coincidence without noticing it: *What is next* §3 is
**Conformant array parameters, and level 1**, and the two entries are about one
clause.

### What is not fixed, and cannot be by a gate

**The inventory has no oracle of its own.** It is checked against the triage and
the triage against it, and if the extractor silently dropped a clause nobody had
triaged either, both files would agree and both would be wrong — which is
exactly the state this record found. Only a reader holding the standard can see
that. It is a row in `doc/sop.md` §7 and it is `langspec-audit`'s job, not a
gate's.

The two rows of §2's table that were empty are still empty: there is no
third-party corpus for a language this project invented, and no second
implementation, `src/` being frozen at the conformance surface on purpose.
Neither is something this or any record can supply.
