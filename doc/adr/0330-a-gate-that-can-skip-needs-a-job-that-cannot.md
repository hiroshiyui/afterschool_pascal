# ADR-0330: A gate that can skip needs a job that cannot

Date: 2026-09-05

## Status

Accepted. Adds `require-consistency`. Closes the `*_REQUIRE` rows `doc/sop.md`
§7 has carried since ADR-0234, and makes `SANITIZE_REQUIRE` real.

## Context

A gate here skips with 77 where the thing it needs is absent — `fpc`, a 32-bit
libc, libssl, z3, `llc` — because that is right for a developer's checkout and
would be wrong as a hard dependency. **ctest reads 77 as success**, so a
skipped gate and a clean one print the same green bar. The convention that
closes it is a `*_REQUIRE` environment variable: set it in a CI job that
installed the thing, and the skip becomes a failure.

**The convention has shipped broken three times.** `doc/sop.md` §7 records
`fpc-differential` landing with a `FPC_DIFFERENTIAL_REQUIRE` no job set, and it
records the register only catching it by being read end to end. `target32`
landed the same way on 2026-09-05 and was closed within the day. I avoided a
third with `thread-sanitizer` only because writing the register row made it
obvious — which is not a mechanism, it is luck.

So this was written, and it found two more before it ran once.

**`TLS_REQUIRE` has been set by no job since ADR-0264.** It guards the only
check of whether `lib/dialect/pastls.pas`'s transcribed OpenSSL constants are
still OpenSSL's — and ADR-0264's own argument is that a wrong one fails
*quietly*: `SSL_VERIFY_PEER` written as 0 turns verification off and every
behavioural case stays green. That gate has been answering on whatever machine
happened to have libssl, and CLAUDE.md's table says in as many words that
`TLS_REQUIRE` refuses to pass by skipping.

**And `SANITIZE_REQUIRE` was named by a comment and read by nothing.** The
`sanitizers` job's header said *`SANITIZE_REQUIRE` is that refusal. A green run
of this job means the sanitizers actually ran* — and no script read the
variable. The job refused a skip by grepping its own log, so the mechanism
worked and the sentence describing it was false. That is the same defect as the
other three read backwards: a sentence standing in for a mechanism.

## Decision

**Both directions, which is this repository's rule for a catalogue (ADR-0013).**

  a) Every `*_REQUIRE` a check reads must be set by some job, or the gate
     answers only where its author was.
  b) Every `*_REQUIRE` a workflow sets must be read by some check, or a job is
     setting a variable nothing consults.

`sanitize.sh` reads `SANITIZE_REQUIRE` now, the way every other gate reads its
own, and both `sanitizers` steps set it instead of grepping a log. A `tls` job
installs libssl and `openssl` and sets `TLS_REQUIRE`.

## What its own mutation caught

The first version matched a variable **anywhere** in the YAML. Renaming the
setting to something else left the name in the job's comment above it, and the
gate went on passing — which is exactly the `SANITIZE_REQUIRE` failure it
exists to catch, committed by the thing catching it. It matches a mapping key
at the start of a line now: a workflow must *set* the variable, not mention it.

Writing the mutation is what found that. The gate would otherwise have been a
comfort — green, cheap, and blind to half of what it claims.

## Consequences

**It reads no Pascal and needs nothing installed**, which makes it the cheapest
gate here after `markdown-tables` and, like that one, the only thing watching
what it watches: every other check in `tests/checks/` asks about the compiler,
and this one asks about the checks.

**A floor of four**, well under the six that exist, so a run that read nothing
cannot pass by comparing nothing — and so the floor does not move when a gate
is added.

**It excludes itself by name.** This file's own prose names every variable it
is about, and a check that counted its own docstring would report itself as the
reader of them all.

**Two CI jobs are added or changed** and neither can be tested from a
developer's machine, which is why each carries a probe or an explicit install
step: a wrong package name reddens with an obvious cause rather than as a
Pascal failure.

## What this does not do

**It does not check that the job actually installed the thing.** A job may set
`TLS_REQUIRE` and fail to install libssl; the gate then fails, loudly, in that
job — which is the right place and the right noise, and is not this check's
business.

**It does not reach a `*_REQUIRE` a gate reads through a variable name it
computes.** Every one here is a literal, and a gate that built the name at run
time would be invisible to this. Nothing does that and nothing should.

**It does not stop a gate shipping with no `*_REQUIRE` at all.** A check that
simply exits 0 where its dependency is missing has no variable to be
inconsistent about. What refuses that is the review, and `doc/sop.md` §7.

## Alternatives rejected

**Keep grepping the log in each job.** It works, it is per-job, and it puts the
refusal in the workflow rather than in the gate — so a developer running the
gate by hand with the variable set gets no refusal, and the two ways of running
it differ. Uniformity is the point: every gate reads its own variable.

**Make the gates fail rather than skip.** It turns `fpc`, libssl, z3, `llc` and
a 32-bit libc into documented dependencies of a Pascal compiler whose whole
build needs `clang` and nothing else (ADR-0085).
