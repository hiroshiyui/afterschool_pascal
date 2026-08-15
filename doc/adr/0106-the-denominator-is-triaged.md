# ADR-0106: The denominator is triaged

## Status

Accepted.

## Context

ADR-0105 built a suite whose unit is a clause, and reported clause coverage
without gating it. The reason was stated there and in `doc/sop.md` §7: 292
headings exist across the two standards, and most of them could never carry a
scenario. `6.4.7 Example of a type-definition-part` is the standard's own
illustration. `6.7.2.1 General` introduces the subclauses under it. `3.1 Error`
defines a term. Counting a scenario against those is counting against
something that does not exist, and the resulting percentage is one nobody can
act on.

This project has made that mistake at one level already. ADR-0104 measured IR
basic-block coverage, found 33%, and rejected it as a headline because 8,304 of
26,655 blocks are trap paths unreachable by design — a denominator a third of
which cannot be covered. Clause headings are the same shape one level up: the
figure was 4–5%, and almost all of the gap was clauses that are not
requirements.

An untriaged denominator is worse than no measurement, because it will be
quoted. "5% of the standard is covered" is a sentence someone will write, and
it is not true of anything.

## Decision

**Every clause of both standards is classified, and the classification is what
the gate reads.** `tests/spec/clauses/triage.tsv`, three classes:

- **testable** — states a requirement a Pascal program can exercise, and this
  processor implements it. 189 clauses: 74 of ISO 7185's 117, 115 of
  ISO/IEC 10206's 175.
- **structural** — cannot carry a scenario: a container that introduces its
  subclauses, a definition of a term, a compliance statement about what a
  processor *is*, or one of the standards' own examples. 93 clauses.
- **not-implemented** — the processor does not provide the feature by a
  documented decision. 10 clauses, all of them conformant array parameters:
  this is a level 0 processor and `doc/implementation-defined.md` says so.
  Kept distinct from *structural* because the reason is entirely different —
  one is a fact about the document and the other a fact about this compiler,
  and folding them together would hide a decision that could be revisited.

**A citation of a non-testable clause fails.** That is the direction that makes
the triage self-checking: if a scenario cites `6.4.7`, either the scenario is
tagged with the wrong clause or the triage is wrong about that clause, and both
are worth hearing about immediately. Without it the classification would be an
unchecked assertion — which is precisely what this suite exists to stop.

**A clause that stops being cited fails**, against
`tests/spec/clauses/pending.txt`. A clause that *starts* being cited does not
fail; it prints "newly cited, regenerate the pending list" and exits 0. The
asymmetry is deliberate and is the one place this gate differs from
`uncovered_procedures.txt`: gaining coverage is the goal, and a gate that broke
the build for reaching it would train people to avoid it.

**The triage is a reading, and nothing here can check a reading.** That is
ADR-0105's whole premise applied to its own instrument. The file says so, and a
change to a classification is to be argued in the commit message like any other.

## Consequences

**The number means something now.** 13 of 189 testable clauses, rather than 13
of 292 headings — and the report says in the same breath how many headings
carry no requirement, so nobody has to take the denominator on trust.

**The pending list is a work queue, not a shame list**, and is described that
way in the file: 176 clauses that can carry a scenario and do not yet. Anyone
looking for useful work on this suite has an enumerated answer, which the
untriaged version could not give — it could not distinguish a clause worth
writing a scenario for from a heading that is a paragraph break.

**Triaging turned up more ligature damage.** ADR-0105 recorded eleven headings
mangled by the PDFs' lost fi/fl ligatures; reading all 292 found three more and
a second failure mode — `ff` goes the same way (`Bu er-variables`), and ISO 7185
loses the space as well as the ligature (`Theoating-point`), where ISO/IEC 10206
keeps it (`The oating-point`). The repairs are an explicit list for the reason
ADR-0105 gave: a rule that guessed would mangle a title that is merely unusual.
Reading a list end to end is the only thing that finds this, which is the same
lesson ADR-0073 recorded for Annex D.

**Four failure modes, each checked by mutation**: a scenario citing a structural
clause, a scenario citing a number that is not a clause at all, a feature file
removed, and a new citation. The fourth exits 0 with a message, and that is
asserted too — a gate whose "good news" path is untested is a gate that can fail
open.

**What it does not do.** It does not say a testable clause is *well* covered:
one scenario citing §6.8.3.9 marks it cited, and that clause has six
requirements this suite happens to check and more that it does not. Clause
citation is presence, not depth, and the same caution ADR-0104 gave for
statement coverage applies here one level further out.
