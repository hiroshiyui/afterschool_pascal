# ADR-0343: The client comes before the design

Date: 2026-09-06

## Status

Accepted. Amends `doc/sop.md` §4a and adds §4b; amends
`.claude/skills/change-lifecycle/SKILL.md` steps 2, 3a and 8. ADR-0001 is not
superseded — its immutability rule is the premise of the decision here, not
its target.

## Context

The traits feature landed as one `feat:` commit and four decision records, and
each record says in its own words why the one before it was wrong:

| Record | Why the previous reading failed |
| --- | --- |
| ADR-0338 | probing beat reading |
| ADR-0339 | a probe beat that record's own claims |
| ADR-0340 | building beat probing |
| ADR-0341 | separate translation was the question none of the three had asked |

That is one ladder with four rungs, and each rung is the next-most-real
activity contradicting the one below it. The cost was not the discoveries —
all four landed before the merge, which is the process working. The cost was
four records, four roadmap edits and four commits to reach a design that the
most-real activity would have produced once.

**The shape is not confined to traits.** ADR-0334 found that no CI job ran
`-O0` crossed with a 32-bit target, and named the shape itself: *two jobs, two
axes, and the cell where they cross was empty*. ADR-0341's finding is that
same sentence about a different plane. A design that walks one axis at a time
discovers the others one round at a time.

**And the artefact made it expensive.** ADR-0001 makes a record immutable, for
a good reason: a record edited to match new reality destroys the reasoning it
exists to preserve. But immutability is precisely what makes a *falsified*
hypothesis costly — it cannot be corrected, so another record is written. Four
records for one decision is what an immutable artefact looks like when it is
used for a mutable job.

## Decision

**Three rules, and a metric.**

**1. For a feature with a surface, the client program is the first artefact.**
`doc/sop.md` §4a already required a client and placed it at step 3a, after the
design and after the record. It moves to the front: the first thing written is
a program a user would write, compiled against a compiler that does not accept
it yet. It fails, and each diagnostic is a design question with its answer
attached.

**2. A claim about this compiler carries a probe.** §6's existing rule — never
assert completeness without compiling one — generalises to every sentence of
the form *this compiler does X*. The compiler is in the tree and answers in
seconds. A record's Context may reason from a clause; a claim about this
processor is probed or is not written.

**3. One feature, one record.** Hypotheses live in a working note that is
freely rewritten while the design is live. The record is written when the
feature builds, and carries the alternatives that were genuinely rejected.

**The metric is records per landed feature**, counted afterwards. One is the
process working. More than one means it leaked, and the count says how far.

**And the axes are enumerated** in `doc/sop.md` §4b rather than rediscovered:
component, declaration site, optimisation level, word size, threads, parameter
form, and whether the spelling collides with a word-symbol, a required
identifier or a category.

## Consequences

**The first client of traits found a defect in twenty minutes** that four
rounds of reading had not. A generic sort — the construct the whole feature
was justified by — cannot name its trait `Ordered`: the trait is declarable
and implementable, and AP 6.7.3.10.5 identifies that spelling as a
type-parameter-category wherever a bound is written, so the category wins and
the trait silently bounds nothing. Four of the seven axes above were also
answered by that one program.

**A working note is not tracked, and that is the point.** Nothing gates it and
nothing preserves it. What survives a design is the record, and what the record
now carries is a decision rather than a stage of one.

**The metric can be gamed by writing fewer records**, which would be worse than
the disease. It is a prompt for a person, not a gate, and `doc/sop.md` §4b says
so — a feature that genuinely settles two independent questions may take two.

## What this does not do

**It does not relax ADR-0001.** No accepted record is edited, and a decision
that stops being right still gets a successor. What changes is which artefact a
live hypothesis goes in, not what happens to a settled one.

**It does not make the client a gate.** Nothing here can check that a client was
written first, and no oracle in this tree can: the question is about the order
two files were created in. `doc/sop.md` §7 already carries the general form of
that gap — nothing checks that a decision reached the documents — and this adds
no mechanism to it.

**It does not fix the `Ordered` collision it found.** That is a language
question with its own answer and belongs to whoever takes it; this record is
about the process that surfaced it.

## Alternatives rejected

**Allow a record to be revised while `Proposed`.** It would have collapsed the
four into one, and it reintroduces exactly what ADR-0001 forbids by a side
door: a record whose Context can be rewritten after the fact is a record whose
reasoning cannot be trusted, and `Proposed` is not a reliable fence — ADR-0315
sat `Proposed` for days while work was done against it.

**Require a probe for every claim in every document.** Unenforceable and too
broad. The rule is scoped to claims about *this compiler's behaviour*, which is
the class that was wrong four times and the class the compiler can answer.

**Add a gate.** There is nothing to measure. The failure is a design written
before the thing it designs was tried, and no artefact in the tree records
that ordering.
