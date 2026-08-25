# 207. A mutation is a file the harness runs

Date: 2026-08-25

## Status

Accepted. `tests/mutation/`, and the third of `doc/roadmap.md`'s open
questions.

## Context

The rule this repository rests on is `doc/sop.md`'s: *a green suite is not
evidence; evidence is a named case that fails without the change.* Mutation is
how that is demonstrated, it is asked for by §4 of the same document, and it
has found something every time it has been run here — ADR-0065's two mutants
changed the compiler rather than the tests.

And it has never existed as anything but prose. Two hundred records carry
sentences like *the mutation that moves the slice arm one line down leaves all
625 cases green*, each of which is a claim about the tree on the day it was
written, in a document that may not be edited. Nobody can re-run one. A test
that is renamed, code that moves, or a later change that makes a mutation stop
being caught are all invisible.

`doc/roadmap.md` has carried this as an open item with two conditions attached,
both learned the expensive way: a wall-clock and output-size limit per mutant,
because a looping mutant filled a disk before anything noticed; and a restore
that does not preserve the mtime, or the mutant binary stays in the build tree
and the next control run reads as a broken feature.

**A third condition arrived while ADR-0205 was being written**, which is why
this landed now rather than staying on the list. A mutation was restored with
a plain `cp` and a `touch` — correctly, by the rule — and nothing rebuilt. The
next run measured the mutant, reported a property of the new feature as false,
and a golden was taken against it before the cause was found. The rule was
right and one step too short.

## Decision

**One file per mutation, executed by a harness.**

```
adr: 0205
file: runtime/pasrt_posix.c
kills: lib_net_wait
why: a readiness call that never waits prints every right answer and burns a
     processor
--- old
    n = poll(pf, (nfds_t)nfds, timeout_ms);
--- new
    n = poll(pf, (nfds_t)nfds, 0);
```

`run.py` applies each, rebuilds, runs the named test, requires it to **fail**,
and then restores and rebuilds — in that order and always, including on an
exception or a Ctrl-C, because a mutated tree left behind is worse than no run
at all.

**It is not a `ctest` gate and must not become one.** It edits the source tree
and rebuilds; ctest would run it in parallel with seven hundred cases reading
the same build directory. That is the one structural difference between this
and every other oracle here, and it is why the harness refuses to start when a
file a mutant names has uncommitted changes: restoring is `git checkout --`,
so a successful run would otherwise discard someone's work.

Four rules are made mechanical:

- **The `old` text must occur exactly once.** Twice changes two things and
  proves neither; none would pass by mutating nothing, which is exactly what a
  silent skip looks like from outside. This is `difftest`'s corpus-size check
  in miniature.
- **A mutant that breaks the build proves nothing** — `doc/sop.md` §4's own
  rule, reported as `BUILD-FAILED` rather than as a kill.
- **Restore keeps no mtime and always rebuilds.**
- **Every test run gets a wall clock and an `RLIMIT_FSIZE`.** The build does
  not: an `.ll` for the compiler is tens of megabytes.

**The catalogue is seeded with eight**, and with the eight whose build tree was
still standing rather than the eight most interesting. That is deliberate: a
transcribed mutation nobody re-ran is a claim with a second layer of trust in
front of it, which is the state the prose was already in.

## Consequences

**A mutation that stops being caught now says so**, which is the property none
of the two hundred prose sentences has. It fails in one direction only — a
mutant that starts being caught by a *different* test is not detected, because
`kills:` names one test and the harness asks only whether that one fails.

**It is a `.mut` file's job to be re-runnable, not to be complete.** No claim
is made about mutation coverage of the compiler and none should be: this is a
register of demonstrations, not a measurement. `doc/sop.md` §7 carries that
distinction, because "the mutation suite passes" is exactly the kind of
sentence that gets read as more than it says.

**`doc/sop.md` §4 gains the rebuild** and a pointer to the directory. The
roadmap's third open question is struck.

**Two of the eight are ADR-0206's and one is ADR-0205's fourth**, all made the
same day as the features they belong to — which is the cadence intended:
a mutation is committed with the change it argues for, the way an ADR is.

## What was measured

All eight killed, and the control passes with the tree restored. The one worth
naming is `0205-empty-slot-reported-ready`, which does not fail by printing
something: it makes a server read a socket nobody is on, and the program
blocks. It is caught by the `timeout:` field, which the harness passes to
`ctest` — and it is why `tests/dialect/` gained a `TIMEOUT` in ADR-0205, that
corpus being the only one here that can open a socket.

## Alternatives rejected

**A `ctest` case.** It is what every other gate here is, and it cannot be: the
harness mutates the tree that the other cases are reading. Running the suite
single-threaded to allow it would make every push slower for one gate that is
not meant to run on every push.

**A mutation generator** — flip every comparison, delete every statement, and
measure what survives. It is the standard tool and it answers a different
question: *how much of the compiler is exercised*, which `line-coverage`,
`procedure-coverage` and `diagnostic-coverage` already answer three ways here.
What has actually gone wrong in this repository is a specific claim quietly
ceasing to be true, and a generated mutant has no claim attached to it.

**Transcribing every mutation in the records.** Two hundred sentences, of which
most name code that has since moved; the product would be a large catalogue of
entries nobody had re-run, which is what the prose already is. Seeding with
what could be verified on the spot and growing with each change is the same
discipline `tests/checks/`'s catalogues use.

**Storing a patch instead of an old/new pair.** A patch carries line numbers
and would go stale on any edit near the site; a string that must match exactly
once fails *loudly* when the code moves, which is the behaviour wanted.
