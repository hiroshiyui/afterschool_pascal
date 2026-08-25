# The specification suite

Scenarios written against **clauses of the two standards and of the dialect's
own specification**, in a subset of Gherkin, run by `run.py`.

```sh
ctest --test-dir build -R '^spec-'            # as part of an ordinary run
python3 tests/spec/run.py --pascalcc tools/pascalcc
python3 tests/spec/run.py --coverage          # which clauses are cited
python3 tests/spec/run.py --check-clauses     # the traceability gate
python3 tests/spec/run.py --write-pending     # after adding a citation
```

`clauses/pending.txt` is the work queue: the testable clauses no scenario cites
yet.

## The three clause tables

`clauses/iso7185.tsv` and `clauses/iso10206.tsv` are extracted from PDFs that
are **not** in this repository and may not be — `clauses/extract.sh` needs
`pdftotext` and the documents, and does nothing without them.

Two things about that extraction are worth knowing before trusting it. **A
clause need not have a heading**: every sub-clause of §6.2.2 and §6.2.3 in both
standards is a bare number on its own line with the requirement under it, and
reading only titled lines lost 37 of them — including §6.2.2.9, the most-cited
clause in this repository (ADR-0152). They are recognised now by their numbering
being consecutive, and their heading column reads `Scopes (untitled)`: the
parent's heading, and not a title. And **the inventory has no oracle of its
own** — it is checked against `clauses/triage.tsv` in both directions, so a
clause lost from one shows up as an orphan in the other, but a clause missing
from *both* would leave them agreeing. Only a reader holding the standard can
see that; it is in `doc/sop.md` §7.

`clauses/afterschool.tsv` has the opposite problem and the opposite solution.
The dialect's specification *is* here, so its table is **generated from the
document** by `clauses/extract_afterschool.py` rather than transcribed, and the
two cannot drift. Regenerate it whenever
`doc/afterschool-pascal-spec.md` gains or renames a clause:

```sh
python3 tests/spec/clauses/extract_afterschool.py
```

A dialect clause is a numbered heading (`### 5.1 Processors`) or a numbered
bold lead-in (`**6.4.2.6.1 Values.**`), which is the form the specification uses
where a requirement is finer than a heading. Adding one is the ordinary way to grow this suite — write the scenario,
tag it, then regenerate the pending list and say in the commit message which
clause gained one.

## Why it exists

Every other oracle here starts from the compiler. A golden records what the
compiler printed; `verify/` proves a model of the lowering against a model of
the standard; `irtest` asks whether the compiler is a fixed point under itself.
`doc/sop.md` §1 says what that leaves: **no oracle here can contradict a
reading.** A misread clause is invisible to all of them at once, which is how
ADR-0072's set-packing deviation survived in four documents and a
purpose-written test.

This suite does not fix that — a scenario is written by the same reader who
might misread the clause. What it does is make a reading **findable**: every
scenario names the clause it claims to be about, so someone holding the
standard can check the claim against the text rather than against the compiler.
That is the whole of the improvement, and ADR-0105 argues it is worth having.

**What attacks a scenario is `.claude/skills/langspec-audit/`**, and the two are
built to fit: an audit sends readers who have not seen this project's reasoning
to prove a reading wrong from the standards text, and a cited clause is the
easiest target it has — the claim is written down and filed under the clause it
is about. A scenario that has survived one is a different thing from a scenario
that has only ever passed, so say which in the commit message. The audit also
checks `clauses/triage.tsv`, since a requirement filed `structural` leaves the
denominator and is never asked for again.

**There is a third class and it is the one to know about.** `not-implemented`
says the processor does not provide the feature, and a scenario citing such a
clause **fails** — which is what lets the dialect's specification state a
requirement *before* it is built without the document coming to claim, through
a passing test, that the feature is there. AP 5.6 is the rule and the text
model is what it was written for: the whole of AP 6.4.15 sat in this class for
two increments and came off it a clause at a time (ADR-0189 – ADR-0192).

Since ADR-0195 the class is checked from both sides: AP 5.6 also requires the
clause's *heading* to carry `[not yet implemented]`, and `--check-clauses`
compares the two sets and fails either way round. A clause triaged without the
marker reads as implemented to every human and to no gate; one marked and left
`testable` sits in the pending queue as ordinary work nobody has got to.

It is also why the scenarios are phrased as the *requirement*, not as the
implementation: "the bounds are checked only if the statement is executed" is a
sentence about §6.8.3.9, and "the for loop emits its check inside the entry
test" would be a sentence about `EmitFor`.

## What may and may not be written here

**No text of either standard appears in this repository, and none may.** The
copies in `doc/vendor/` are the online editions, whose notice reads *"Do not
modify this document. Do not include this document in another software
product."* `doc/vendor/` is therefore not committed, and neither is any excerpt
from it.

What *is* committed is `clauses/*.tsv`: clause numbers and their headings. A
clause number is a citation, and a suite meant to be traceable to a standard
cannot work without one — the same position `tests/bsi/README.md` takes towards
BSI's terms, and the same one CLAUDE.md has always taken by citing §6.8.3.9
throughout. Regenerate with `clauses/extract.sh`, which needs `pdftotext` and
the PDFs and does nothing without them.

Each scenario paraphrases its requirement **in this project's own words**. If
you find yourself wanting to quote, cite the clause number instead and write
what it requires.

## Writing a scenario

A file is `features/<area>.feature`. Tags carry the clause and may sit on the
feature (applying to every scenario in it) or on one scenario. There are three
tag prefixes — `@iso7185:`, `@extended:` and `@afterschool:` — and the last
cites `doc/afterschool-pascal-spec.md`, never a standard. A bare `§6.4.11`
anywhere in this repository means one of the two standards; the dialect's own
clauses are `AP §6.4.11` in prose and `@afterschool:6.4.11` here:

```gherkin
@iso7185:6.8.3.9 @iso7185:6.7.1
Feature: For-statements

  Scenario: the limit is evaluated once, before the loop begins
    Given the ISO 7185 program
      """
      program p(output);
      ...
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      1
      """
```

The steps are a closed set, listed in `run.py`'s docstring. **An unrecognised
step is an error, not a skip** — a step that silently does nothing is a
scenario that asserts nothing, and this suite exists precisely to avoid claims
nothing checks.

Two rules that keep a scenario honest:

- **One requirement per scenario, and the name says which.** A scenario called
  "for statements work" cannot fail informatively.
- **Where a rule has two halves that a wrong implementation could satisfy one
  of, write both.** `succ` of a subrange is the standing example: the compiler
  once trapped where the standard does not, *and* a test asserted the wrong
  rule, and only the pair distinguishes a correct implementation.

## What this suite is not

- **Not a conformance claim.** It cites clauses; it does not validate against
  them, and no document here may say it does. `tests/bsi/` carries the same
  caution for the same reason.
- **Not a replacement for `tests/`.** The golden corpus is far larger and
  covers the compiler; this covers *readings*. A feature landing still needs
  its `tests/*.pas` pair.
- **Not complete, and citation is not depth.** `--coverage` reports the cited
  fraction of the **testable** clauses — the denominator is triaged in
  `clauses/triage.tsv` (ADR-0106, corrected by ADR-0107), so a structural
  heading and the ones for conformant array parameters are excluded rather than
  counted as gaps. But a clause with one scenario counts as cited, and
  §6.8.3.9 alone has more requirements than the six here. `doc/sop.md` §7
  carries that caveat.

  **The dialect's fraction is much the higher of the three, and that is not a
  claim about quality.** Its clauses were written by someone who could probe
  the compiler for each one (ADR-0135), so the citations arrived with the
  document; the two standards' clauses were written in 1990 by people with no
  such thing in mind. A high number there means the specification is young,
  not that it is well tested.
