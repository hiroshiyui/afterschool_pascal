# ADR-0354: A line that runs when a thread loses a race

Date: 2026-09-07

## Status

Accepted. Changes how `tests/checks/runtime_coverage.py` compares against its
ratchet, and closes the `doc/sop.md` §7 row that had been chasing a compiler
intermittent. ADR-0351 is not superseded; this is what its number turned out
to be made of.

## Context

Two things happened on the same day and looked like one.

**A coverage sweep reported `tests/extended/lib_strings.pas:10:53: error:
unexpected character '}'`**, once, in a corpus that compiles cleanly. It was
recorded as a suspected short read in the source reader, then investigated:
the reported position was correct for the file, so nothing had been truncated;
400 parallel compilations were clean; Valgrind found zero errors translating
that file and all three program-components. It was none of those. The sweep
was a sibling agent's, run in the working tree while `lib-coverage`'s mutation
check rewrote every line of that file matching `Reverse(` or `Times(` to
`{ removed }` — and line 6 of its leading comment contains `Reverse(s)`. The
`}` closes the comment there; lines 7–9 lex as identifiers; the real `}` at
10:53 is the first and only error. Applying that regex to the file and
compiling reproduces it exactly. `tests/mutation/run.py` refuses to start with
uncommitted changes precisely so a mutation never edits a tree something else
is reading; a mutation done by hand in the checkout bypassed that.

**Then `runtime-coverage` was made to fail in both directions**, as its two
siblings had been the same morning (ADR-0350, ADR-0353's commit), and CI
failed at once: 433 lines never run where the ratchet said 436, with nothing
in the tree different. Four measurements here said 436 — this machine, a
`debian:trixie` container on clang 19, the same pinned to two cores by
affinity, the same on one core. The fifth, one core **under a busy loop**,
said 433 and named the unit:

```
runtime/pasrt_task.c 28/291  ->  25/291
```

Three lines. They are the `ETIMEDOUT` arm of `select`
(`runtime/pasrt_task.c:406–409`), which runs only when the deadline beats the
receive. On a fast, idle machine the receive wins every race the corpus
poses; on a loaded runner it loses some. **Which lines of that unit run is a
property of how loaded the machine is.**

## Decision

**`runtime-coverage` gates per translation unit, and two of the four are
reported, never compared.** `pasrt_task.c` and `pasrt_posix.c` each contain a
wait with a deadline — `pthread_cond_timedwait`, `poll`, `select` — and a line
whose coverage depends on a race cannot be held by a ratchet in *either*
direction without lying on some machine: gated against a loss, a faster
machine than the one that wrote the file fails; gated against a gain, CI does.
`pasrt.c` and `pasrt_unicode.c` contain no such wait and are held in both
directions, exactly as `lib_coverage.txt` is.

**The set is written down and the deterministic half is checked against the
source.** The two reported units are named in the script rather than derived,
so a stray match in a comment cannot quietly ungate a unit; and every unit
held both ways is required to contain no wait with a deadline, so that a
`poll()` added to `pasrt.c` later fails the gate with a message rather than
becoming a flaky number.

**The §7 row for the `}` intermittent is closed**, with the cause and the
reproduction, and the lesson filed where it already was.

## Consequences

**The number CI reports and the number this machine reports will differ, and
that is now correct rather than a failure.** The gate prints the delta and says
why. The ratchet file's rows for the two reported units are informational.

**The register's count moves the right way.** Of five one-directional coverage
numbers this morning, two are now held both ways by mechanism, one pair is
one-way by an earlier choice (ADR-0104), and a few lines of two units are
outside any gate *by nature* — which is a smaller and better-explained cost
than five numbers nobody had to justify.

**Two harnesses were investigated for a defect that was operator concurrency.**
The compiler was cleared by every instrument available and then by the actual
cause. The instruments were not wasted: Valgrind over the compiler's own three
components, clean, is a result this project did not have (ADR-0353).

## What this does not do

**It does not make the three lines deterministic.** A `select` with a
deadline is supposed to have a race in it; that is the construct.

**It does not gate `pasrt_posix.c`'s error paths.** They were the reason its
coverage is low before any of this (ADR-0351), and they stay a fault-injection
question.

**It does not explain `fpc-differential`'s one flake.** That row stands.

## Alternatives rejected

**A tolerance of three lines on the total.** It is the measured variance on
one day on two machines, and a slower runner than CI's would exceed it. A
number that is right until the hardware changes is the shape ADR-0346 spent
a morning on.

**Regression-only gating on the timed units, baselined on a fast machine.** It
passes here and on CI and fails on any machine faster than this one, which is
the same lie with the sign flipped.

**Derive the reported set by grepping every unit.** A comment mentioning
`poll()` would then ungate a deterministic unit with no message. The
one-directional check kept here — a unit *claimed* deterministic must match
nothing — is the half that cannot mislead.
