# ADR-0160: The dialect's refusal surface is where a second implementation reaches it

Date: 2026-08-22

## Status

Accepted, and **retired by
[ADR-0232](0232-afterschool-pascal-is-the-language.md)**. Annex B stated what
each dialect construct got under a conformance mode, and `annex-b` required a
golden to contain the message the annex named. Both halves are about a refusal
surface that no longer exists; the annex is kept in the specification, marked
historical, because it is the only construct-by-construct record of what the
modes said.

## Context

`doc/roadmap.md` §2 keeps a table of what backs each of the three languages.
Two of its rows are empty for the dialect and the entry says why:

> there is no third-party corpus for a language this project invented, and no
> second implementation, `src/` being frozen at the conformance surface on
> purpose.

Both sentences are true and neither is the whole story. **A dialect construct
compiled under a conformance mode is a conformance question**, and ADR-0121
established that `src/` must carry the refusal for it — because leaving `src/`
alone made it answer "expected 'begin'" where the compiler names the mode, and
that is a difftest failure, correctly. ADR-0154 made the general rule: a
dialect feature may not change what the two conformance modes *accept*, and may
change what they *say*.

So the refusal surface is not on the dialect's side of the freeze. It is
conformance behaviour, both front ends have an opinion about it, and difftest
compares them — wherever a program exercising it exists.

`doc/afterschool-pascal-spec.md`'s **Annex B** is the table of that surface:
five constructs, and what a conformance mode says about each. It had two
problems.

**It was a table nothing read.** Of the five constructs, one had a case
(`external`, under `--std=extended` only). Nine of the ten (construct, mode)
pairs had no program in the tree, so difftest had nothing to compare and no
golden pinned the message.

**And it was wrong.** Probing the five showed that the two modes do *not* agree
about `a[i..j]` over an array: ISO 7185 has no substring notation, so its parser
stops at the `..` and complains about a token, where Extended Pascal parses the
construct and Sema refuses it by type. The annex had one column and stated the
Extended Pascal answer for both. Nobody had noticed because nobody had probed —
`doc/sop.md`'s own rule, and the one that found `pack`, `page` and §6.3's string
constant.

## Decision

Ten cases, one per (construct, mode), and a gate that ties them to the annex.

- **`tests/<case>_refused_iso.pas` and `tests/extended/<case>_refused.pas`**,
  each with an `.err` golden. Five of these existed in some form; five are new.
  Only the ISO side carries a suffix: a `ctest` name is flat across the two
  corpora, `tests/extended/optional_refused.pas` was here first, and renaming
  three working cases to buy symmetry is churn charged to a reader.
- **Annex B gains a `Case` column and a second message column.** The `Case`
  column is the link between the document and the cases; the second message
  column is the correction.
- **`tests/checks/annex_b.py`** reads the table and requires, for every row, that
  both cases exist, that each has a golden, and that **the golden contains the
  message the annex states**. So the specification is not merely accompanied by
  tests — it is what the tests are checked against, which is ADR-0135's rule
  ("it is specified, and the specification is enforced") applied to an annex
  that had escaped it.

It fails in **both** directions: a row whose cases are missing, and a
`*_refused` case that no row names. The second is the one that matters, because
it is what a sixth dialect construct trips — a feature added with cases and no
row is exactly how this annex got out of date the first time.

## Consequences

The dialect's second-implementation row is no longer empty. It is not full
either, and the roadmap says which: **the refusal surface** is compared by
`src/`, on ten programs; everything the dialect *accepts* is compared by
nothing, `difftest.sh` skipping a dialect source by directory.

**Four of the five refusals need no code in `src/` at all**, which is worth
knowing before the next feature. ADR-0140's rule — a dialect construct is
spelled in a *position* where a conforming program could not have written it —
means the refusal usually falls out of a grammar both front ends already share.
`external` is the exception, because §6.1.4 makes a directive an ordinary
identifier in the one position it may occupy, so only a rule about the mode can
refuse it. A new construct that needs teaching in `src/` is a signal that its
spelling is not in such a position.

**The `dialect-containment` catalogue grew by two entries**, and had to: a case
whose expectation *is* a refusal by the conformance mode cannot expect the same
refusal from the dialect, which has the feature. Those five entries and Annex
B's five rows are now required to be the same length by two gates rather than by
attention.

## What this does not do

- **It is not an external authority**, and does not pretend to be. `src/` is
  written by the same author from the same reading, which is the blind spot
  ADR-0107's audit exists for and which no gate closes. What it adds is that a
  *second implementation* now disagrees loudly if either front end changes its
  answer.
- **It says nothing about what the dialect accepts.** Ten refusals are ten
  programs neither front end compiles. The semantics of a slice, an optional or
  `int64` are checked by goldens, `irtest` and the spec scenarios, all of which
  are anchored in one reading.
- **It does not supply a third-party corpus.** Nothing can; the language is this
  project's own. The BSI suite is unavailable here for a second reason besides
  novelty — the dialect does not contain ISO 7185, Extended Pascal's reserved
  word-symbols being in the way (ADR-0033).
- **It does not check the ten messages against the standards.** A golden agrees
  with whoever wrote it. What the annex now guarantees is that the document and
  the compiler say the same thing, not that either is right about §6.6.3.1.
