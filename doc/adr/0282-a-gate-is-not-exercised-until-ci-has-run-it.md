# 282. A gate is not exercised until CI has run it

Date: 2026-09-01

## Status

Accepted, 2026-09-01.

## Context

Sixteen commits stood on `main` unpushed, and four of them added gates:
`benchmark` (ADR-0270), the branch half of `line-coverage` (ADR-0274), `fuzz`
(ADR-0275) and `format-check` (ADR-0279). Each was green locally every time it
was run, across a dozen full suites.

The push ran them on four platforms for the first time. **Two failed, in every
job that reached them**, and neither failure was reachable on the machine they
were written on.

This tree's own sentence is *a green suite is not evidence; evidence is a named
case that fails without the change*. What both defects add to it is narrower
and was not written down: **a green suite is not evidence that a gate runs at
all somewhere else.** A gate that cannot execute reports nothing, and reporting
nothing looks exactly like finding nothing.

## Decision

### `format-check` asked git, and git will not always answer

`tests/checks/format_check.py` took its corpus from

    subprocess.run(["git", "ls-files", "*.pas"], cwd=root, capture_output=True)

and read `.stdout` without looking at the status. `git` exits **128** in a
container whose checkout it calls dubiously owned, which is every job in
`.github/workflows/ci.yml`, so the list was empty and the sweep formatted
nothing — 0.05 s, on all four platforms.

**The tree already knew this, twice, and neither piece of knowledge reached the
new file.** `tests/checks/clause_citations.py` carries the hazard in a comment
— *walked rather than asked of `git ls-files`, which exits 128 in a container
whose checkout git calls dubiously owned — it did, in three CI jobs, and a gate
that cannot run is worse than one that is merely narrow*. And
`tests/checks/variant_check.sh` carries the repair: `find` the four roots that
hold Pascal, then subtract what `git check-ignore` names **only if git answers
at all**. That shape is now `format_check.py`'s, and it produces the same 785
sources as `git ls-files` did on a machine where git speaks.

**The floor is what made this a failure rather than a silence.** ADR-0279 gave
the gate `FLOOR = 500` for `variant-check`'s reason — an instrument that
measures nothing must not pass — and it is the only thing that stood between a
red bar and a gate that swept an empty list on every push while printing a
number nobody would have read twice.

### `benchmark` measures a machine, and said it did not

ADR-0270's premise is that **a millisecond is a fact about the machine that
took it**, so what is committed is six proportions, each divided by something
measured in the same run. The unstated half is that a *proportion* is a weaker
fact about the machine rather than none, and CI made both halves visible at
once:

- **The aarch64 job reported `share:parse` at 0.035 against a baseline of
  0.055** — a 36% move on a compiler that had not changed a line. The four
  stages have different instruction mixes, so a different machine reweights
  them. There is no defect to find here and no tolerance that would make the
  comparison mean anything; an aarch64 baseline is a set of numbers nobody has
  taken.
- **The `-O0` job reported `share:sema` at 0.303 against 0.260**, 16% against a
  15% tolerance, while two other x86 jobs of the same commit passed it. Those
  tolerances are margins over a spread *measured over six consecutive runs on
  an idle machine*, which ADR-0270 says in as many words; a shared CI runner is
  not one. A gate that goes red for a neighbour's build is the thing ADR-0275
  already named — a check that fails randomly on someone else's commit is one
  people learn to ignore.

So `benchmark` **abstains** where it cannot answer, with `SKIP`:

- when `platform.machine()` differs from the architecture the baseline records,
- when `$CI` is set.

The baseline gains an `arch` line. It recorded the platform before, in a
**comment**, explicitly *for a reader* and not compared — which is precisely
the shape ADR-0185 rejected for `@cstruct` claims and ADR-0270 rejected for its
own milliseconds. A fact a gate depends on is data.

## Consequences

- **`benchmark` says nothing on CI**, and that is a `doc/sop.md` §7 row rather
  than a hidden cost. It is a local-loop instrument: it answers *did a stage
  get about a third slower on the machine you are developing on*, which is the
  question ADR-0270 built it for, and it never claimed a second one.
- **A future gate whose answer is a duration must abstain the same way**, and
  must record what its baseline is a fact *about*. This is the second property
  of the suite that parallelism and portability can break silently — ADR-0281
  named the first, `RUN_SERIAL`.
- **An aarch64 baseline is now a well-defined thing.** Taking one needs an idle
  aarch64 machine, which is not the shared runner that exposed this; a baseline
  taken there would commit the noise as the standard.
- **A new harness must not ask `git` for anything it cannot do without.** Three
  files now carry that: the comment in `clause_citations.py`, the conditional
  in `variant_check.sh`, and the walk in `format_check.py`.
- **ADR-0281 overstated one sentence and this is the correction.** It said the
  48 harness files split into 31 that make a private directory and 17 that are
  read-only analysers. `benchmark.py` is in the second group and is not
  read-only: it writes `build/benchmark`, a fixed path. It is safe because it
  is `RUN_SERIAL`, and it keeps the fixed path deliberately — moving a timing
  harness's output to a `TemporaryDirectory` may move it onto a tmpfs and shift
  the very durations it exists to measure. Both facts follow from the same
  thing: it is the one gate here whose answer is a duration.

## Alternatives rejected

**Widen the tolerances until CI passes.** `share:parse` would need better than
36% and ADR-0270 measured what that costs: a single 25% figure lets a code
generator made 20% slower through, which is most of what the gate is for. A
tolerance wide enough for a different architecture is a tolerance wide enough
for nothing.

**Set `git config --global --add safe.directory '*'` in every CI job.** It
would make `git ls-files` work, and it fixes one file by editing eight job
definitions and leaves the next harness to rediscover the same hazard. The
walk needs no cooperation from the environment, which is what a gate wants.

**Commit a baseline per architecture.** Correct, and blocked on a calibrated
aarch64 machine that nobody here has. The abstention is what makes that a
future increment rather than a permanent wrong answer.

**Take `benchmark` out of `ctest` and make it a script run by hand.** It would
stop the flake and lose the thing that makes it work: it runs on every local
suite, which is how a stage made a third slower is caught the day it happens
rather than at a release.
