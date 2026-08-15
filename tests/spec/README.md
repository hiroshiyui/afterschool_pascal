# The specification suite

Scenarios written against **clauses of the two standards**, in a subset of
Gherkin, run by `run.py`.

```sh
ctest --test-dir build -R '^spec-'            # as part of an ordinary run
python3 tests/spec/run.py --pascalcc tools/pascalcc
python3 tests/spec/run.py --coverage          # which clauses are cited
python3 tests/spec/run.py --check-clauses     # the traceability gate
python3 tests/spec/run.py --write-pending     # after adding a citation
```

`clauses/pending.txt` is the work queue: the testable clauses no scenario cites
yet. Adding one is the ordinary way to grow this suite — write the scenario,
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
feature (applying to every scenario in it) or on one scenario:

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
- **Not complete, and citation is not depth.** `--coverage` reports 13 of the
  **207 testable** clauses — the denominator is triaged in
  `clauses/triage.tsv` (ADR-0106, corrected by ADR-0107), so the 75 structural
  headings and the 10 for conformant array parameters are excluded rather than
  counted as gaps. But a
  clause with one scenario counts as cited, and §6.8.3.9 alone has more
  requirements than the six here. `doc/sop.md` §7 carries that caveat.
