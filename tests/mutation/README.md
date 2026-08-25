# Mutations, as files rather than as prose

`doc/sop.md` §4 has asked for a mutation with every fix since the beginning —
*a green suite is not evidence; evidence is a named case that fails without the
change* — and every one of those mutations has lived in the prose of a decision
record:

> the mutation that moves the slice arm one line down leaves all 625 cases
> green

That sentence is a **claim about today's tree** written in a document that is
immutable. Nobody can re-run it. The test it names may be renamed, the code it
edits may move, and a later change may make the mutation stop being caught by
anything at all — and none of those would show up anywhere. This directory
turns each one into a file the harness executes.

## Running it

```sh
python3 tests/mutation/run.py            # every mutant
python3 tests/mutation/run.py --list
python3 tests/mutation/run.py --only 0205-timeout-ignored --verbose
```

It edits the source tree and rebuilds, so **it is not a `ctest` case and must
not become one**: ctest would run it beside seven hundred cases reading the
same build directory. Run it deliberately — before a release, and after a
change to anything a mutant names. It refuses to start when a file a mutant
names has uncommitted changes, because restoring is `git checkout --`.

## A mutant

```
adr: 0205
file: runtime/pasrt_posix.c
kills: lib_net_wait
timeout: 30
why: <one line: what property the mutation removes>
--- old
<the exact text, which must occur exactly once>
--- new
<what replaces it>
```

`timeout:` is optional and in seconds, for a mutant whose defect makes a
program **block** rather than print something wrong.
`0205-empty-slot-reported-ready` is the one that needs it: it makes a server
read a socket nobody is on.

The clock that applies is the harness's own, not `ctest`'s. `ctest --timeout`
sets a *default* and a case's own `TIMEOUT` property beats it — and every
dialect case has one (ADR-0205), which is precisely where a blocking mutant
lives. The flag is still passed, for a case with no property of its own; the
harness's `timeout + 30` is what is guaranteed.

## What the harness enforces, and what each rule cost

- **The `old` text must occur exactly once.** Twice would change two things and
  prove neither; none would "pass" by mutating nothing, which is what a silent
  skip looks like from the outside.
- **A mutant that breaks the build proves nothing.** It has to produce a
  working compiler with the defect back in it.
- **Restore does not preserve the mtime, and rebuilds.** `cp -p` leaves the
  mutant binary in the build tree and the next run reads as a broken feature.
  Restoring the mtime correctly and *not rebuilding* does exactly the same
  thing and looks less like a mistake — it cost a golden taken against a
  mutant on 2026-08-25 (ADR-0205), which is the immediate reason this
  directory exists rather than a fifth record saying mutations matter.
- **Every run has a wall clock and a file-size limit.** A looping mutant once
  wrote 38 GB before anything noticed.

## What it is not

It is **not** a mutation *generator*. Nothing here proposes mutations; every
file is one somebody made while fixing or building something, kept so it can be
made again. Coverage of the compiler by mutation testing is not claimed and is
not the goal — the goal is that a mutation which stops being caught says so.

It is also not a complete transcription of the records. Two hundred decisions
carry mutations in their prose and eight are here, all of them from work whose
build tree was still standing when this was written. Adding one is cheap and
adding one that was never re-run is worse than leaving it in prose, so the
catalogue grows the way the ADRs do: with the change.
