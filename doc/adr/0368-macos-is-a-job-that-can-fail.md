# ADR-0368: macOS is a job that can fail

## Status

Accepted. Promotes the `macos-experiment` job added with the first macOS run
to `macos`, a job without `continue-on-error`. Does **not** enable the release
matrix leg; the `package` job's comment says what is left before it can be.

## Context

macOS had never been tried when the job was added, so it was written as an
experiment: `continue-on-error: true` made its result advisory, and it set no
`*_REQUIRE` variable on purpose. Both were right for the question being asked
— *does the rest of this work at all* — and the job's own comment said to
promote it once green.

**It is green, and has been across the whole conversion to Python.** 901 of
911 cases run and pass on arm64. The nine failures that got it there were
every one a harness assuming Linux and not one was in the compiler, and
ADR-0366 has since removed the class those belonged to: there is no shell
harness left to assume anything.

**An advisory job answers a question nobody asked twice.** Its value was the
first run; after that it is a job whose failures are read only when somebody
remembers to look, and this repository has a record of what that is worth —
`format-check` swept nothing on CI for as long as it did because nothing
failed when it swept nothing (ADR-0282).

## Decision

**`continue-on-error` is removed.** A macOS failure now stops the build, which
is the whole of the promotion.

**`SANITIZE_REQUIRE` is set and the other nine variables are not**, and the
reason is the same one ADR-0330 gives: a job that fails because a tool is
absent reports the runner and not the port. `sanitizers` and
`thread-sanitizer` already run on this machine and pass, so the variable pins
what is true rather than demanding something new. `VALGRIND_REQUIRE` and
`RUNTIME_COVERAGE_REQUIRE` guard their own skips, so setting this one does not
reach them.

**The ten skips are listed in the job with the reason for each**, read off the
run at `a84659a` rather than predicted. That list is the promotion's honest
half: a required job in which ten gates pass by skipping is the shape ADR-0330
refuses, and writing down which ten and why is what turns it from a silence
into a work queue.

**`unicode-conformance` is the cheapest of the ten and is deliberately not
closed here.** It skips only because this job does not fetch the database, and
a fetch step would close it — but it would also make `runtime/pasrt_unicode.c`
compile under `-std=c11 -pedantic-errors -Wall -Wextra -Werror` on a compiler
nothing in this tree has tried. That is a second question. Two questions in
one commit is how a promotion comes to look like a regression.

## Consequences

**Every change must now keep macOS green**, which is the point and is also the
cost. The platform is a second reader of every harness, and the first run
after this record is where that is proved — this decision could not be tested
locally, and saying so is part of it.

**Its first required run found something, and it was a test.**
`tests/dialect/lib_net_wait` failed on macOS with two blocks of output
transposed. The case had passed there twice and failed the third time with no
relevant change between, so it is nondeterministic rather than platform-wrong:
its golden pinned an *arrival order* — which of a line buffered in the runtime
and a reply still on a socket a round finds ready — and that is the operating
system's answer, not the program's. The case now collects what it heard and
prints it sorted, which is what it was always asserting; ADR-0205's own
mutation, a buffered line no longer reported ready, is still caught, and now
three ways rather than one. **This is the class of defect a second platform is
for**, and no Linux run in the case's life had shown it.

**Reverting is one line.** `continue-on-error: true` goes back and the job is
advisory again. That is the property that made it reasonable to take the step
without a Mac to try it on.

**The release leg is still disabled, and that is not a run finding anything.**
Three decisions stand between here and an archive: `APASCAL_STATIC_PASCALC`
OFF and `RELEASE_REQUIRE_STATIC` unset, there being no `-static`; a `--check`
that reports the link kind as unknown, there being no `ldd`; and an `arch` for
an archive whose compiler writes an x86-64 header, `--target=` admitting no
Darwin triple (ADR-0156). A platform is run before it is shipped, and this job
is the running.

**Nine gates still pass by skipping there.** Each is named in the job, and
each is either a tool the runner has not got or a question this platform
cannot ask. `require-consistency` is unaffected: every variable is still set
by some job.

## Alternatives rejected

**Set every `*_REQUIRE`.** The job would fail because `macos-latest` has no
valgrind, no fpc, no 32-bit libc and no cross compilers — a red build that
says nothing about the port. ADR-0330's convention is that a job which
*installed* a tool must refuse to skip past it; this runner installs none of
them.

**Promote and enable the release leg together.** The roadmap's own order is
the other way round, and the reason is in the `package` job: a leg there would
be the first run of the port and a release archive at the same time. The
running is now done; the shipping needs three decisions that are nobody's yet.

**Keep it advisory until every skip is closed.** Nine of the ten need a tool
this runner has not got, so that is a condition that would not be met — and
the job would go on being one whose failures are read only when somebody
remembers to look.
