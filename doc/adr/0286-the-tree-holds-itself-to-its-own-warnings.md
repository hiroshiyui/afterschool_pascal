# 286. The tree holds itself to its own warnings

Date: 2026-09-01

## Status

Accepted, 2026-09-01. Closes the `doc/sop.md` §7 row ADR-0283 opened, and
overturns the reason that row gave for declining a gate.

## Context

ADR-0272 gave this compiler a diagnostic that is not an error, and there are
four of them: an unused local, a statement after one that leaves, a function
that writes its result on one path, and — ADR-0283's — a `var` parameter
nothing writes through.

A **test case** is held to all four by a sidecar. A case with `name.warn` must
produce exactly those warnings, and a case *without* one must produce none,
which is the half that keeps a warning added later from appearing silently on
dozens of green cases. That mechanism is the reason ADR-0272 could add a
warning at all.

`selfhost/`, `lib/` and `lsp/` have no sidecars. They are compiled by CMake,
by `irtest.sh`, `producttest.sh`, `verify.py` and `lsp/build.sh`, and by every
gate that runs the compiler over its own source — and **every one of them
reads the exit status rather than what the compiler said.** A warning here is
printed into a build log and nothing fails.

ADR-0283 met that immediately. Its warning found 130 parameters in this tree
that could say `protected`, iterating to a fixed point over seven rounds, and
54 were given the word; the count is now zero and **that zero was held by
nobody**. `doc/sop.md` §7 recorded the gap in the same commit, which is the
register working as intended, and gave a reason for declining a gate:

> It is also a **fixed point** rather than a count, so a gate over it would
> have to iterate to convergence rather than compare a number, which is why
> one was not written here.

**That reason is wrong**, and it is wrong in the shape `doc/roadmap.md`'s
tooling chapter kept finding: *a row saying a feature is blocked is a row
nobody has tried.* Iterating to convergence is what **reaching** zero needed.
*Holding* zero needs one sweep — a source that acquires an unprotected
read-only `var` parameter reports it on the next compilation, and if fixing
that one exposes another, the next run says so. The fixed point is a property
of the repair, not of the measurement.

And once a sweep exists the narrow claim is the expensive one. Parsing the
compiler's output for one warning's wording would be a second reader of
Pascal-shaped text outside the compiler — the shape that broke
`foreign-reserved` and that ADR-0229 and ADR-0230 moved `kind-exhaustive` off.
The compiler is **quiet on success**. So the strongest claim is also the
simplest, and it covers all four warnings and every message added after them:
the compiler writes nothing at all.

## Decision

`tests/checks/warning_free.py` compiles every Pascal source in `selfhost/`,
`lib/` and `lsp/` and makes **two** claims.

**1. Every implementation source compiles silently.** Exit status 0, and not
one byte on either stream. Nothing is parsed and no wording is matched, so a
warning added in five years' time is covered by this gate on the day it is
written.

`tests/` is deliberately not swept. A case there is already governed by its
`.warn` sidecar in both directions, and a second opinion here would be free to
drift from the first.

**2. Every source named as deliberately broken really is.**
`selfhost/torture.pas` and the bad-parse and bad-Sema corpora are the only
exclusions, they are named in a list rather than detected, and each is
compiled and required to **fail**.

That second claim is what makes the gate fail in both directions, and it is
not decoration. The obvious design — sweep everything and skip whatever the
compiler refuses — would have turned *a source that broke* into *a source that
was skipped*, which is `procedure-coverage`'s defect (ADR-0269) and
`line-coverage`'s degradation-to-a-skip (ADR-0233) met a third time. **It also
found something on its first run**: `selfhost/badsema/components/exporter.pas`
is a §6.13 program-component a bad-Sema case imports, it compiles, and a
prefix exclusion on `selfhost/badsema/` had swallowed it. The claim named it
before any mutation was staged.

A floor of 20 refuses to pass by sweeping an empty list, for
`variant-check`'s reason, and the source list is filtered through
`git check-ignore` **only if git answers** — ADR-0282's repair, carried into
the new file rather than learned again on CI.

## Consequences

The gate is a `ctest` case and takes **1.2 seconds**: 40 implementation
sources compiled once each, and 174 refused ones compiled to confirm they
still are. It runs before a push rather than reporting after one.

**The mutation is the argument, and the number is what makes it.** Removing
`protected` from one parameter of `selfhost/apfront.pas` — the exact inverse
of one of ADR-0283's 54 — leaves **798 of 798 cases green**, and the build
itself prints the warning and succeeds, which is the §7 row's own sentence
demonstrated. `warning-free` names the file, line, column and parameter.

What this does **not** do:

- It says nothing about `tests/`, by design, and nothing about a warning
  emitted for an *imported* component: Sema's third guard is
  `curFile = mainFile` (ADR-0272), so each source is judged as a main file
  and only then.
- It cannot see a warning the compiler should have written and did not. That
  is the same one-directional limit every catalogue here has for the messages
  it does not name, and `diagnostic-coverage` is the gate that watches it.
- It does not format, lay out or style anything. ADR-0285 declined that and
  the decision stands; this gate is about what the compiler *says*, not about
  what the source looks like.

## Alternatives rejected

**Grep the build log for `warning:`.** The build log is not an artefact this
tree keeps, CMake interleaves output under `-j`, and `lsp/build.sh` and the
four harnesses each build differently. A claim about a compilation belongs
where the compilation is made.

**Match ADR-0283's message specifically.** That is the narrow claim, and it
costs more than the broad one: it needs the wording, so a reworded diagnostic
silently stops being checked, and it leaves the other three warnings — and
every future one — exactly as unheld as they were.

**Add `.warn` sidecars to `selfhost/`, `lib/` and `lsp/`.** The sidecar
mechanism belongs to `tests/run_test.sh` and these are not cases; giving them
sidecars would mean each carries an expected-warnings file whose correct
content is *empty*, in forty places, and the day one is not empty is the day
the mechanism has stopped saying anything.

**Iterate to convergence inside the gate**, as §7's declining reason imagined.
A gate that repairs what it measures is not a gate; and there is nothing to
converge on, the tree being at the fixed point already.
