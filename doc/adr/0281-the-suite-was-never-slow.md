# 281. The suite was never slow; the instructions were

Date: 2026-09-01

## Status

Accepted, 2026-09-01.

## Context

`doc/roadmap.md`'s chapter *What would make this easier to work on* closed with
a fifth item, and it was the one item on that list whose author said outright
that it probably did not repay the effort:

> **The suite is 262 seconds, and sixteen cases are 234 of them.** The other
> 758 take about 28 seconds between them, so this is not a suite that is slow;
> it is a suite of gates with a suite attached. `selfhost-codegen` — the
> stage-2-equals-stage-3 fixed point — is 63.6 s, `sanitizers` 49.8 s and
> `fpc-differential` 44.4 s, which is 60% of the wall clock in three cases,
> and each of the three is a whole second corpus run by construction rather
> than an accident of implementation.

Every sentence of that is true and the conclusion drawn from it was wrong,
because the measurement was taken of a configuration nothing uses. It was
taken with `ctest --test-dir build --output-on-failure`, which is what
`CLAUDE.md`, `README.md`, `doc/sop.md` and four of the skills tell a reader to
run, and which runs the 795 cases one after another on one core.

`.github/workflows/ci.yml` has run `ctest --test-dir build --output-on-failure
-j"$(nproc)"` since `a544d67` wrote the workflow on 2026-08-14, in every one of
its jobs. So the suite has been executed in parallel on every push for the life
of the workflow, and serially by every person who followed the documentation.
Nobody compared the two.

## Decision

**The documented command gains `-j"$(nproc)"`**, and the divergence between the
local loop and CI closes in favour of CI.

The measurements, all on a 12-core machine on 2026-09-01, over the 795 cases
this tree has as this is written:

| run | wall |
| --- | --- |
| `ctest` | 290 s |
| `ctest -j12` | 86 s |
| `ctest -j12 --schedule-random` | 93 s |
| `ctest -j12`, no accumulated cost data | 86 s |

**3.4×, for a flag.** All 795 pass in every one of them, and the shuffled run
is the interesting one: order is not a thing this suite depends on.

### What makes it safe, which is not an accident

Three mechanisms, and two of them were put there deliberately by someone who
was thinking about concurrency without saying so — plus a fourth that was
already written down:

- **Every harness works in a directory it created for the run.** 31 of the 48
  harness files under `tests/`, `selfhost/`, `lsp/`, `verify/` and `tools/`
  call `mktemp -d`, `mkdtemp` or `TemporaryDirectory`; the other 17 are
  read-only analysers that parse sources and compare them against a catalogue.
  `tools/pascalcc` is in the first list, which is what makes an ordinary test
  case safe, because every case that wants an executable goes through it.
- **A port is asked for and not assumed.** `tests/dialect/lib_net.pas`,
  `lib_net_wait.pas` and `lib_http.pas` all `Listen(srv, 'localhost', '0')`,
  and `tests/checks/tls.sh` scans `24433..24473` for one that will take a
  server, with a comment saying why a fixed number would be wrong.
- **`lsp/run.sh` gives each server its own `TMPDIR`**, and says in a comment
  that it is so two servers do not choose the same file.
- **`benchmark` is `RUN_SERIAL`** (ADR-0270), because its answer is a duration.
  It is the one case here whose *correctness* depends on what else is running,
  and it was already marked before this record. `doc/developer-guide.md` says
  so in as many words — *it is `RUN_SERIAL` because under `ctest -j` it would
  be measuring the other jobs* — which is the sharpest evidence that the
  parallel run was anticipated: a gate was designed around a flag the
  instructions never learned to pass.

### `PROCESSORS` is the obvious fix and it is a regression

Three gates are internally parallel with `os.cpu_count()` workers —
`procedure-coverage`, `line-coverage` and `fuzz` — and declare nothing, so
`-j12` oversubscribes the machine twelve-fold through each of them. The
principled repair is `set_tests_properties(... PROPERTIES PROCESSORS 12)` so
that ctest's scheduler knows what it is handing out.

It was written, measured and reverted: **107 s, against 86.** The reason is
worth keeping, because it is the shape of the whole item. The wall clock is set
by `sanitizers` (50 s alone, 66 s contended) and `selfhost-codegen` (~64 s
alone, 66 s contended), and **both are internally serial** — the fixed point is
three chained builds of a three-component compiler, each stage compiled by the
one before it, with the golden corpus run against two of them, and none of that
can be anything but a chain. The three oversubscribing gates are what keeps
the other ten cores busy while those two run. Declaring `PROCESSORS` schedules
them alone, which is honest and which idles the machine.

So the floor is about 71 s: the two poles overlapping, plus the five seconds
`benchmark` runs by itself. 86 s is within 20% of a floor that no scheduling
change can move, and moving it means making the fixed point faster, which is a
different record.

### One repair

`tests/checks/format_check.py` (ADR-0279) was the only harness here working in
a fixed path — `build/format-check/formatted.pas` — rather than one it made. It
is safe as it stands, because ctest never runs one case twice at once, but it
is safe by a property of the *rest of the tree* rather than of itself, and it
is the newest harness here, which is how a convention stops being one. It now
takes a `TemporaryDirectory`, and the sentence above is universal again.

## Consequences

- **The local loop is 3.4× shorter** and matches what CI does, so a failure
  that only appears under concurrency is now seen by the person who caused it
  rather than by the push.
- **A new harness must work in a directory it created**, and a new test that
  wants a port must ask for one. Neither is checked, and the reason is in
  `doc/sop.md` §7: a grep for `mktemp -d` proves that a private directory
  *exists*, not that everything is written inside it, and this tree does not
  keep gates that look like proofs and are not — the same objection ADR-0013
  makes to a rule that restates the lowering, and the one `clause-citations`
  answers by saying out loud that it asks the cheap half. What replaces the
  gate is exposure: the property is now exercised by every local run as well as
  every push.
- **`benchmark` must stay `RUN_SERIAL`**, and any future case whose answer is a
  duration must be marked the same way. This is the one property of the suite
  that parallelism can break silently, since a slow measurement passes a
  tolerance rather than crashing.
- **A gate that oversubscribes is not a defect here**, which is a thing to know
  before someone repairs it a second time. If the two poles ever stop being the
  wall clock, this reverses, and the number to re-measure is in the table above.
- The seven documents and skills naming the serial command are updated. The
  serial run still works and is still what `-R` uses for a single case.

## Alternatives rejected

**Set `COST` on the heavy gates so ctest starts them first.** `sanitizers` and
`selfhost-codegen` are registered at #93 and #99 of the 101 cases that stand
before the corpus, so on a tree with no accumulated cost data ctest reaches
them late by declaration order. Measured: a run with
`Testing/Temporary/CTestCostData.txt` deleted is 86 s, exactly the warm figure.
ctest reaches them early enough anyway, because the cases before them are gates
rather than the fast corpus. Nothing to win.

**Make the suite parallel by default via `CTEST_PARALLEL_LEVEL`.** A test
harness that ignores the flag it was given is a harness people stop trusting,
and `-j` is how everyone who runs ctest expects to say this. The flag is
documented instead.

**A `parallel-safety` gate.** See the second consequence: the check available
is a proxy for the property, and the property is now exercised twice per change
instead of once.

**Make the fixed point faster.** It is 66 s of the 86, and it is nine
translations of a 36 000-line compiler in a chain — seed to stage 1, stage 1 to
stage 2, stage 2 to stage 3, three program-components each — with the corpus
run against two of the stages, because a compiler that reproduces itself and
does nothing else would pass the comparison. Every one of those must happen and
none may overlap. Cutting it means cutting compile time, which is ADR-0270 and
ADR-0271's territory and has its own instrument.
