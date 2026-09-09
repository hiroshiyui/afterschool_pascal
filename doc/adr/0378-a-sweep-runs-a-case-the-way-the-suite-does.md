# ADR-0378: A sweep runs a case the way the suite does

## Status

Accepted. Closes `doc/sop.md` §7's row *`lib-coverage` cannot measure a case
that takes a program-parameter*, and adds a second claim to the same gate.

## Context

`tests/run_test.py` is the harness some 850 ctest cases run through, and it
hands every program **two writable scratch paths** and feeds it `<stem>.in`
where the case has one. Both are part of what a case *is* here: a program
whose header names external files gets somewhere to put them, and a program
that reads gets its input.

`lib-coverage` (ADR-0350) links each case against one instrumented library
module and runs it for the lines it reaches. It ran it as `[exe]`, with
`/dev/null` on standard input.

So a case that names a program-parameter stopped at its first statement — the
runtime cannot bind a file it was given no path for — and a case that reads
reached only the statements before its first `read`. Seven cases under
`tests/dialect/` name a program-parameter (`lib_fs`, `lib_io`, `lib_dir`,
`lib_os`, `lib_path`, `lib_process`, `lib_stream`) and three have an `.in`
(`lib_lsp`, `lib_lsp_jsonl`, `lib_term`).

**The number that came out said something other than what it read as.** An
uncovered line means *no case in this corpus executes this*; what these were
was *the sweep did not run the case*. The two are indistinguishable in the
output, and the second is the gate's own defect being reported as the
library's.

It had a visible consequence and it was mistaken for a fact about the corpus:
`tests/dialect/lib_fs_tempdir.pas` exists as a *parameterless workaround*, and
says so in its own header comment, so that `PasFS.TemporaryDirectory` could be
measured at all (ADR-0363).

## Decision

**The sweep runs a case the way `run_test.py` runs it**: two scratch paths in
the per-case directory it already makes, and `<stem>.in` on standard input
where the case has one, `/dev/null` otherwise.

Measured: **70 statements** that the corpus was covering all along — 386
uncovered where the ratchet said 456, over the same corpus and the same
library. 59 of the 70 are the `.in` and 11 are the arguments; the largest
single move is `paslsp.pas`, 71 uncovered to 20, and `pasfs.pas` goes 10 to 4.
Coverage is 89.1% where it read 87.2%.

**And the denominators are compared, which they were not.** `instrumented` at
the head of `lib_coverage.txt` and each row's `n/M` were written by
`--write-ratchet` and read by nothing: the file said 3521 where the run
measured 3556 and the gate passed. That is exactly the defect ADR-0354 closed
in `runtime-coverage` the same week, present here in a second gate — a total
that is *written* looks identical to one that is *checked*. Both totals and
every module's denominator are now compared in both directions.

## Consequences

`lib_fs_tempdir.pas` keeps its place — it is the case for
`TemporaryDirectory` — but its header comment no longer names a gap that has
closed. A comment that contradicts the code is worse than none.

**Every change to `lib/` that adds or removes an executable statement now
re-ratchets**, and says in the commit message what moved. That is the cost,
and it is the point: a denominator that drifts unremarked is the half a
ratchet on the numerator cannot see, since a module losing statements takes
uncovered ones with it and the percentage *improves*.

Three mutations, each killed by this gate and by nothing else:

| Mutation | What it reports |
| --- | --- |
| take the two scratch paths away again | `397 never run, was 386 -- 11 lost`, naming `linktarget`, `info`, `rename` |
| stop feeding `<stem>.in` | `445 never run, was 386 -- 59 lost`, naming `pushutf8`, `parsestringinto` |
| edit either denominator in the catalogue | the total, or the module, with the number it should be |

**The class is worth naming, because this is its third instance in a week.**
`doc/sop.md` §7 already carries *nothing detects a harness that ignores a
path, target or flag it is handed* — `sanitize.py` and `AFTERSCHOOL_PASCAL_OPT`
(ADR-0335), `llc_check.py` and the target (ADR-0345), `seed_current.py` and an
absolute path (ADR-0347). This is a fourth, and it is the same shape from the
other side: not a flag ignored but a **convention not followed**, where the
convention is what makes a case a case. The row stays open and now names four.

## Alternatives rejected

**Give the sweep its own convention.** It could have declared that a case it
measures takes no arguments, which is what the workaround case assumed. That
makes the corpus two corpora — one the suite runs and one the gate runs — and
the number then measures the wrong one while reading as the right one, which
is the defect this record is about rather than a fix for it.

**Skip the cases that take parameters.** Honest and useless: they are the
cases that exercise the filesystem, the terminal and the process modules,
which is most of what `lib/dialect/` is for. A denominator that quietly
excludes the interesting half is `line-coverage`'s own lesson (ADR-0104).
