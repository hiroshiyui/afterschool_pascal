# ADR-0105: Scenarios start from the clause

## Status

Accepted.

## Context

`doc/sop.md` §1 tabulates every oracle here and what each is blind to. One row
is unlike the others:

> **ADRs, `README`, `CLAUDE.md`** — checks the reasoning — blind to a
> **misreading**. No oracle here can contradict a reading of the standard.

That is not a gap one more test closes, and the reason is structural: **every
other oracle starts from the compiler.** A golden records what the compiler
printed. `verify/` proves a model of the lowering against a model of the
standard, and neither model touches the compiler. `irtest` asks whether the
compiler is a fixed point under itself. `tests/bsi/expected.tsv` records what
*this* compiler does with 812 programs. A rule read wrongly and implemented
consistently satisfies all of them at once, which is exactly how ADR-0072's
set-packing deviation survived in four documents and a purpose-written test, and
how ADR-0074's invented restriction was justified by a citation that says the
opposite.

`.claude/skills/langspec-audit/` is the existing answer — independent readers
given the behaviour and not the reasoning, told to prove the compiler wrong from
the standards text. ADR-0101 is what it found. But an audit is an event; between
audits nothing carries a clause.

The corpus has the same shape. `tests/*.pas` is organised by feature and names
its clauses in comments, which are prose: nothing can enumerate them, nothing
notices when one is wrong, and a case that cites §6.5.3.2 while testing an
array-*constant* compiles, runs, prints the right answer, and is wrong about
what it is testing (ADR-0072 again).

## Decision

**A suite whose unit is a clause, written as scenarios, in a subset of
Gherkin.** `tests/spec/`, run by `run.py`, one `ctest` case per feature file.

**A scenario states the requirement, not the implementation.** "The bounds are
checked only if the statement is executed" is a sentence about §6.8.3.9; "the
for loop emits its check inside the entry test" would be a sentence about
`EmitFor`. The first can be checked against the standard by someone holding it;
the second can only be checked against the code.

**This does not close the blind spot, and the record should not be read as
claiming it does.** A scenario is written by the same reader who might misread
the clause. What changes is that the reading becomes *findable*: every scenario
carries `@iso7185:6.8.3.9`, so a wrong reading is attached to the clause it is
wrong about instead of buried in a comment. That is a smaller claim than
"conformance is tested", and it is the true one.

**A Gherkin subset, parsed here.** `behave` and `pytest-bdd` are the obvious
alternatives and were declined: this repository needs `cmake`, `make` and
`clang`, and `z3` is its one optional extra — a suite that cannot run in the CI
containers until someone pips a package is a suite that stops running. The
parser is about two hundred lines and the dialect is small enough to be listed
in full in one docstring.

**An unrecognised step is an error, not a skip.** A step that silently does
nothing is a scenario that asserts nothing, which is the failure this whole
suite exists to avoid; frameworks that report "undefined step" and carry on
would reintroduce it.

**Clause numbers and headings are committed; no text of either standard is.**
The copies in `doc/vendor/` carry *"Do not modify this document. Do not include
this document in another software product"*, so `doc/vendor/` is not in the
repository — and the rule saying so was in `.git/info/exclude`, which is not
committed either, so the protection lived on one machine and no clone had it.
It is in `.gitignore` now. `tests/spec/clauses/*.tsv` holds the structure a
citation needs and nothing else, which is the position `tests/bsi/README.md`
already takes towards BSI's terms and the one CLAUDE.md has taken all along by
citing §6.8.3.9 throughout.

**Clause coverage is reported, not gated.** 292 headings across the two
standards, of which many are structural — definitions, grammar productions, the
shape of the document — and will never carry a scenario. Gating an untriaged
denominator would produce a percentage nobody can act on, which is the mistake
ADR-0104 avoided when it rejected block coverage. The row in `doc/sop.md` §7
says the denominator is untriaged rather than implying the number is low.

## Consequences

**Forty-three scenarios over thirteen clauses**, chosen where this project's own
history shows the rule is subtle rather than where it is easy: `succ` of a
subrange and §6.7.1's substitution (wrong in both directions for a release,
with every oracle agreeing), a variant part's labels against its tag-type
(ADR-0096, which looks over-strict and is not), `mod`'s non-negative result and
its error conditions (where the compiler once disagreed with itself), the two
string comparisons ISO/IEC 10206 §6.7.6.7 NOTE 3 keeps apart, and §6.4.8's
identity rule for discriminated schemata.

**Several scenarios exist in pairs on purpose.** One rule alone cannot
distinguish a correct implementation from a wrong one where the wrong one errs
in the other direction: `succ(d)` of a `1..9` holding 9 must yield 10 *and*
storing it back must fail, and an implementation that trapped at the `succ`
would pass a suite containing only the second.

**It makes a standards difference executable.** The same case-statement program
is an error under ISO 7185 and well-defined under Extended Pascal, and the two
scenarios sit next to each other with different verdicts — which is a fact about
the languages that no single-standard corpus can state.

**The clause inventory needed repairing, and that is worth knowing.** Both PDFs
lose the fi/fl ligatures, differently: ISO 7185 emits the pair as its own token
(`Implementation-de fi ned`) and ISO/IEC 10206 drops it (`Schema-de nitions`).
Eleven headings are affected and are repaired by an explicit list rather than a
rule that guesses. ISO 7185 also renders clause numbers with spaces around the
dots, so extracting one standard's structure with the other's assumptions
yields five headings out of a hundred and seventeen — which looks like a thin
standard rather than a broken regex.

**What it costs.** A second place where a rule is written down, which can drift
from `tests/` and from the ADRs. The mitigation is that it drifts *visibly*: a
scenario names its clause, so the drift is a disagreement between two things
that both claim to be about §6.8.3.9, rather than between a test and a memory.

**What it is not.** Not a conformance claim — it cites clauses and does not
validate against them, and no document here may say otherwise. Not a
replacement for `tests/`, which is far larger and covers the compiler where this
covers readings; a feature landing still needs its `.pas` pair. And not
complete: thirteen clauses of 292 is a beginning, and the value is in which
thirteen.
