# ADR-0379: A number a document quotes is a gate's answer

## Status

Accepted. Adds `tests/checks/quoted_numbers.py` and its catalogue, run after
the suite rather than inside it. Narrows `doc/sop.md` §7's audit preamble and
the paragraph in `.claude/skills/docs-engineering/SKILL.md` that named this
gap and could not close it.

## Context

The documentation procedure states its own blind spot, in those words:

> That last shape is the one this skill is structurally blind to, so it is
> worth saying plainly: **step 2 audits what a document says about the code,
> and a document quoting a gate is a different question.** … When a document
> quotes a number a gate reports, run the gate.

Saying it has not been enough. **Two audits of `doc/sop.md` §7 have now found
the register clean and the documents around it wrong**, and both times the
stale things were counts:

| Gate | Answers | The document said |
| --- | --- | --- |
| `target32` | 597 of 598 | 573 of 574 (README) |
| `sanitize[valgrind]` | 389 clean | 377 (CLAUDE.md) |
| `sanitize[address]` | 389 | 383 (CLAUDE.md) |
| `sanitize[thread]` | fifteen qualify | eleven (CLAUDE.md) |
| `lib-coverage` | 33 modules | 32 (CLAUDE.md, CMakeLists.txt) |
| the triage | 144 and 390 rows | 51 and some 340 (`doc/sop.md` §7) |

Each was found by running the gate and by nothing else. A reader cannot tell a
number that *was* true from one that *is* — and neither can any other oracle
here, every one of which reads Pascal, C or a golden.

**Writing the catalogue for this check found two more within the hour**, both
in `README.md`'s own summary of what backs its answers: 887 cases under
`ctest` where the suite runs 917, and 417 scenarios where `tests/spec/` holds
427. Neither audit had thought to run those two, which is the argument: the
defect is not that people forget to check, it is that *which numbers to check*
is itself remembered by nobody.

## Decision

**A number a live document quotes from a gate is catalogued, and compared
against what that gate last said.**

`tests/checks/quoted_numbers.txt` holds `<document> | <gate> | <pattern>`. The
pattern is matched against the document; every number it captures must appear
among the numbers in that gate's own summary line. Both directions: a pattern
that stops matching is a sentence reworded away from its row, which is how a
catalogue quietly stops watching.

**The evidence is the gates' own output, not a re-run.** Every check here
prints a summary beginning with its name, and `ctest` records all of it in
`build/Testing/Temporary/LastTest.log`. So the numbers are *read*. Re-running
what they quote would be a second suite — `valgrind-corpus` alone is 170
seconds.

**It is therefore not a `ctest` case and cannot be**: during a run that log
holds whatever has finished so far, so a case reading it would compare against
a partial run or a previous one. It is a script run after the suite, by hand
and by a step in the `test` job — `seed_current.py`'s shape (ADR-0233), and
for a related reason: some questions can only be asked once everything else
has finished.

**A stale log refuses rather than answers.** If any tracked file under
`selfhost/`, `lib/`, `lsp/`, `runtime/`, `tests/`, `examples/` or `tools/` is
newer than the log, the check skips with 77 and names the file. A log from
before the change is worse than no log, because it agrees. `QUOTED_NUMBERS_REQUIRE`
turns that skip into a failure in the job that has just run the suite
(ADR-0330).

**Small counts spelled as words are read.** This tree writes *fifteen
qualify*, deliberately and everywhere, and a check that could only read digits
would be a check asking documents to stop writing English. One through twenty
are recognised; `fifteen qualify` was one of the six.

## Consequences

Nine rows today, ten numbers. What is deliberately **not** in the catalogue:

- **A number a record quotes.** An ADR states what was true when the decision
  was taken and is immutable (ADR-0001); binding one to today's answer would
  be asking history to change. `doc/history.md` is the same — its whole job is
  to say what a sweep found *then*.
- **A floor written into a gate's source.** That is a constant, and the gate
  reading it is already the check.
- **A number no gate reports.** The check has one synthetic gate — `ctest`,
  whose case total comes from the log's own `<n>/<total> Testing:` lines,
  because *how many cases there are* is quoted in two documents and is the
  number a reader is likeliest to trust.

**A row is added when a sentence is written, not when it goes stale**, which
is the part that needs a person and always will. What this closes is the
weaker half: a number already catalogued cannot drift unnoticed, and the
catalogue is a list of exactly where to look.

`docs-engineering`'s paragraph is rewritten to name the check rather than to
warn about the shape, and `doc/sop.md` §7's audit preamble now says which
kinds of number are held and which are still a reader's job.

## Alternatives rejected

**Re-run the gates the catalogue names.** The honest version, and it is a
second suite: `valgrind-corpus` 170 s, `sanitizers` 163 s, `target32` minutes.
It would also have to run them *serially* against a build tree the suite is
using. Reading what they already printed is the same evidence for nothing.

**Stop quoting numbers in prose.** It was considered and it is worse. The
numbers are what make the sentences mean something — *597 of the 598 programs
build and run for it* is a claim, and *most of them do* is not. The rule
`doc/sop.md` already gives, *count the rows rather than trusting a number in a
sentence*, is advice to the writer; this is what makes it mechanical for the
reader.

**Put the check in `ctest`.** It would then read a partial log, and the first
time it passed on one it would have taught everybody that its answer means
nothing. A gate that is sometimes measuring the previous run is worse than a
step that runs afterwards and says so.
