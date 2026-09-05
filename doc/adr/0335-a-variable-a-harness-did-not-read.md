# ADR-0335: A variable a harness did not read

Date: 2026-09-05

## Status

Accepted. Follows ADR-0334, which opened the question this answers for one
harness and leaves the rest of it measured rather than assumed.

## Context

ADR-0334 found a defect that was invisible at `-O2` and added a second
optimisation level to the `thirty-two-bit` job. The row it wrote in
`doc/sop.md` §7 said the general question — which other gates would pay from a
second axis — had not been measured. Measuring it found something one step
before the question:

**`tests/checks/sanitize.sh` compiled the corpus at a level it chose itself and
read `AFTERSCHOOL_PASCAL_OPT` not at all.** It is the only harness here that
sweeps the whole corpus for a *behavioural* answer and pins its own level; every
other one either drives `tests/run_test.sh`, which honours the variable, or asks
a question no optimiser can change.

So `AFTERSCHOOL_PASCAL_OPT=-O0 ctest` reported 869 cases green at `-O0` with two
of them — `sanitizers` and `thread-sanitizer`, 383 programs each time — quietly
at `-O1`. **CI's `unoptimised` job made that claim on every push**, and its whole
reason for existing is that `-O0` and `-O2` are different compilers.

The mechanism was silent in the way this repository has been caught by before:
nothing errors when a variable is not read.

## Decision

**`sanitize.sh` takes the level from `AFTERSCHOOL_PASCAL_OPT`, defaulting to
`-O1`, with a `name.opt` sidecar winning over both** — which is `run_test.sh`'s
own order, one harness over.

**The default does not move.** `-O1` is what a sanitizer build wants: `-O0`
buries a report in noise, and `-O2` optimises away the undefined behaviour UBSan
is looking for. It is the level this gate has always answered at.

**The other `-O1` in the file stays pinned.** It is the level the *runtime's own
C* is built at under the sanitizer, which is the sanitizer's business and not the
corpus's. Two numbers that looked alike and are different questions.

## Consequences

**The `unoptimised` job's claim becomes true**, and costs nothing: `-O0` measured
at 69.6 s against `-O1`'s 72.6 s.

**The measurement is recorded and it found nothing**, which is the honest
outcome and is worth writing down as a number rather than an expectation:

| corpus at | `sanitizers` | `thread-sanitizer` |
| --- | --- | --- |
| `-O0` | clean, 69.6 s | clean, 6.8 s |
| `-O1` (default) | clean, 72.6 s | clean, 6.9 s |
| `-O2` | clean, 73.0 s | clean, 6.9 s |

**What was demonstrated is the mechanism and not the finding.** With
`AFTERSCHOOL_PASCAL_OPT=-Onosuchlevel` the gate now fails, naming the first case
that would not build; before the change it passed in 72 s, having compiled 383
programs at `-O1` and read nothing. That is the both-directions demonstration a
harness change owes (`doc/sop.md` §2, class D), and it is the one a green run
could not have given.

**The rest of ADR-0334's row is now measured rather than open.** `tls` drives
its behavioural half through `run_test.sh` and already honours the variable;
`llc-second-backend` runs *both* levels internally and always has;
`fpc-differential`, `target-sizes` and `unicode-conformance` ask questions an
optimiser cannot change — a disagreement about a printed value, two struct
sizes, and the Unicode database. `target32` was the one that paid and ADR-0334
took it.

## What this does not do

**It does not run the sanitizers at more than one level in CI.** The `test` job
gets `-O1` and the `unoptimised` job now genuinely gets `-O0`; a third would be
70 s for an axis that has just been measured and found flat.

**It does not make an unread variable detectable in general.** `require-consistency`
(ADR-0330) does exactly that for `*_REQUIRE`, and the same shape for
`AFTERSCHOOL_PASCAL_*` would have to know which harnesses *should* read which
variable, which is a judgement and not a comparison. The §7 row carries it.

## Alternatives rejected

**Make `-O0` the default under the sanitizer.** It is the level a debugger wants
and the wrong one for UBSan: at `-O0` clang emits checks the optimiser would have
folded, and the report volume goes up without the coverage doing so.

**Leave it, since the measurement is flat.** The measurement is flat *today*, and
a gate that silently ignores the knob it is handed will be flat tomorrow whatever
the compiler does. The claim the `unoptimised` job makes is the thing being
repaired, not the sanitiser's output.
