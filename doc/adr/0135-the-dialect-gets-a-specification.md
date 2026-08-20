# ADR-0135: The dialect gets a specification, and it is written against the standard it amends

Date: 2026-08-20

## Status

Accepted. Answers the second of the seven open questions in `doc/roadmap.md`'s
*The two standards and the dialect*, and makes two of this repository's oracles
reachable by dialect code for the first time.

Constrains ADR-0117's admission rules: a dialect feature now lands with a clause
as well as a record.

## Context

`doc/roadmap.md` states the problem as a table, and the table is the argument:

| | ISO 7185 | Extended Pascal | the dialect |
| --- | --- | --- | --- |
| third-party corpus | BSI, 812 programs | — | — |
| second implementation (difftest) | yes | yes | **skipped** |
| clause-cited scenarios | yes | yes | **not expressible** |
| independent reading | ADR-0101, ADR-0107 | ADR-0101, ADR-0107 | **nothing to read** |
| goldens, irtest, `verify/` | yes | yes | yes |

Every oracle in this repository bottoms out in *the standard says X*.
`.claude/skills/langspec-audit/` exists because `doc/sop.md` §1 is right that no
oracle here can contradict a **reading**, and its remedy is independent readers
holding the standards text. The dialect has no text. Its correctness has been
"what the compiler does, plus what its ADR said it should do", which is the
closed loop ADR-0072's set-packing deviation survived inside for four documents
and a purpose-written test.

Thirteen increments landed between ADR-0114 and ADR-0132. Each record is
excellent at *why* and — deliberately, per ADR-0001 — immutable, so none of
them is where the current language is written down. A reader wanting to know
what `--std=afterschool` accepts has to read thirteen records in order,
subtracting the ones a later record amended. That is not a documentation
inconvenience; it is the reason the third and fourth rows of the table are
empty.

## Decision

**The dialect gets a specification document, `doc/afterschool-pascal-spec.md`,
written as an amendment to ISO/IEC 10206:1991 and structured as that standard
is.**

### 1. It amends rather than restates

The document specifies only the differences and incorporates
ISO/IEC 10206:1991 in whole. Two reasons, and the second is decisive:

- the dialect *contains* Extended Pascal (ADR-0117), so a delta is the honest
  shape and a freestanding document would assert independence the language does
  not have;
- **a freestanding document is not available to us.** It would have to state
  what ISO/IEC 10206:1991 states, and no text of either standard may appear in
  this repository — `doc/vendor/`'s notice forbids inclusion in another product
  and `doc/vendor/` is gitignored for that reason. A delta cites clause numbers,
  which is what `tests/spec/clauses/*.tsv` already established as the line
  between a citation and a copy.

### 2. Its clause numbers are the standard's

A clause carries the number of the ISO/IEC 10206:1991 clause it modifies; an
addition takes the next number free in that clause. So the optional-type is
AP §6.4.11 because clause 6.4 ends at 6.4.10, and slice parameters are
AP §6.7.3.9 because clause 6.7.3 ends at 6.7.3.8.

The alternative was a numbering of our own, and it was rejected for the reason
the whole document exists: a reader holding the standard should find our
addition at the address of the thing it changes. The ambiguity that buys —
"§6.4.11" meaning two things — is handled by the citation convention in
AP §4.2 and by `tests/spec/`'s tag already carrying the language name.

**Imitating the structure paid for itself before the document was finished.**
Aligning our clauses with theirs put AP §6.1.4 against ISO/IEC 10206:1991
§6.1.4, whose NOTE anticipates this extension by name: it observes that many
processors provide a remote-directive spelled `external` for a heading whose
block lies outside the program-block. ADR-0121 chose that spelling on its own
reasoning and did not know the standard had named it. The same NOTE recommends
enforcing type compatibility across the boundary, which this processor does not
and cannot — so the alignment produced both an external authority for a design
choice and a precise statement of where the dialect departs from advice the
standard gives. Neither was visible from the records.

### 3. It is derived from the records and verified by probe, never from the source

This is the rule the document's value rests on, and it is AP §5.5 a).

A specification written by describing an implementation agrees with that
implementation by construction. It can contradict nothing, and it would make
every one of the four empty table rows *look* filled while filling none of
them. So each requirement was written from ADR-0117 – ADR-0132, and then a
program was compiled to find out what the processor does.

Where the two disagreed, neither was presumed right. AP Annex E lists all five
disagreements found.

### 4. The document wins against an ADR; the ADR keeps the reasoning

ADRs are immutable and state what was decided when they were written. The
specification states what the language is now. Where they disagree the
specification is the current statement — and the disagreement goes in AP Annex E
rather than being smoothed over, because a record that quietly stopped being
true is the thing this repository has been bitten by before (ADR-0067's `pack`
and `page`, asserted complete in three documents).

### 5. It is not a standard, and says so in its own compliance clause

AP §5.1 states that exactly one processor complies with it and that this is the
whole difference between it and the two documents it amends. There is no
external body, no conformance claim, and no stability promise — ADR-0117
declined to invent versioning before there was anything to stabilise, and this
does not reverse it. What changes is that the language at a version is written
down, so a change to it is visible as a change to a document.

## Consequences

- **Two empty rows of the table become fillable.** A dialect scenario becomes
  expressible — `tests/spec/run.py`'s tag pattern needs a third alternative and
  the clause list needs a fourth `.tsv`, generated from this document's own
  headings rather than from a PDF — and `langspec-audit` gains something for a
  reader to hold. Neither is done by this record; both are unblocked by it, and
  the wiring is the next change.
- **A dialect feature now costs a clause.** ADR-0117's admission rules gain one:
  a feature lands with its record *and* its clause, in the clause of
  ISO/IEC 10206:1991 it modifies. That is a real ongoing cost and it is the
  point — the alternative is the document going stale, which is the failure mode
  of every specification written once.
- **The first use found a compiler defect** (AP Annex E.5): an unsigned-integer
  greater than `maxint` written where a constant is required — a
  constant-definition, a subrange bound, an array's index-type, a set's
  base-type, a case-constant — **stops the processor** with `case: no label
  matches the selector`, a case-statement in its own source with no arm for the
  wide literal. Dialect-only; both conformance modes reject the literal in the
  lexis. No case in `tests/dialect/` writes one in a constant position, so every
  gate was green. It is not fixed here: AP §6.4.2.6.2 already requires those
  constructs to be refused, but ADR-0128 described the constant-definition case
  as naming the digits and nothing more, which reads as an acceptance — so what
  the program should be told is a language decision and gets its own record.
- **It found four divergences from the records** besides (AP Annex E.1 – E.4),
  of which one had reached a live document: `doc/roadmap.md` said in the present
  tense that `hypot` and `atan2` are unavailable to a program, which stopped
  being true when the processor took `pas_`-prefixed names for its own uses of
  them. `README.md` had it right. Corrected in the same change.
- **`doc/implementation-defined.md` is unaffected**, as ADR-0117 said: it
  describes a conforming processor and the dialect is not one.
- **The reference front end is unaffected.** `src/` is frozen at the conformance
  surface and this document specifies no conformance-mode behaviour.

## What this does not do

- **It does not freeze the dialect.** AP §5.4 keeps ADR-0117's position.
- **It does not specify the library.** `lib/` and `lib/dialect/` are programs
  written in the two languages, not part of either. AP Annex D says so and says
  why the two layers duplicate.
- **It does not close the first two rows of the table.** No third-party corpus
  and no second implementation exists for the dialect, and neither is something
  a document can supply. AP Annex C.5 and C.6 state both.
- **It does not make the dialect's correctness checkable by itself.** A
  specification written by one reader is a reading; what it changes is that the
  reading is *findable* and attached to the clause it claims to be about, which
  is exactly the improvement ADR-0105 argued for with `tests/spec/` and no more.

## Alternatives rejected

**Write it as an ADR.** Considered first, and it is the wrong instrument twice
over. An ADR is immutable and a specification must track the language; and an
ADR answers *why*, which the thirteen records already do well. What was missing
is *what*, in one place, in the register a requirement is written in.

**Number the clauses ourselves.** Rejected in 2. It would have cost the
alignment that produced the §6.1.4 finding.

**Generate it from the compiler.** The obvious labour saving and the thing that
would have made the document worthless — see 3. It is worth naming as rejected
because a generated document would have been longer, more complete, and unable
to find a single one of the five divergences.

**Wait until the dialect settles.** The argument against is the defect in
Annex E.5: it has been reachable since ADR-0128 and no oracle here could see
it. A specification is most useful while a language is moving, which is exactly
when it is least convenient to write.
