# ADR-0331: The second backend, on the second machine

Date: 2026-09-05

## Status

Accepted. Narrows `doc/sop.md` §7's aarch64 row, which has stood since
ADR-0159. Extends ADR-0330's `*_REQUIRE` convention to `llc-second-backend`.

## Context

`doc/sop.md` §7 said a miscompilation of the compiler that only an aarch64
backend produces has nothing looking for it. ADR-0159's job builds and runs the
whole corpus natively on arm64, which catches a compiler that is *wrong* — and
cannot catch one that is wrong **and reproduces itself**, because both stages
of `irtest.sh` come from one binary and every golden was written by it. That is
ADR-0025's argument, and `llc-second-backend` is the answer to it: the compiler
built a second way, through `llc` rather than `clang`, required to translate
`compiler.pas` to byte-identical IR.

It skipped on arm64, because no `llvm` was installed there.

**It was recorded as a resource problem and it is not one.** The row was
carried into a list of work deferred for want of resources, and checking it
before writing it down is what this project's own rules require. The objection
in `second-backend`'s own header is specific: `llvm` must not go into the
container the *other* jobs share, because ADR-0085's claim is that the
documented build needs nothing of LLVM's and that workflow exists to keep the
claim falsifiable. That objection is against a step of `test`. It says nothing
about a job of its own — which is exactly the shape `second-backend` already
is — and GitHub's arm64 runners were already in use by the job beside it.

The price is a CI job of about thirty lines. It was filed as a machine nobody
has.

## Decision

**`second-backend-aarch64`**: the arm64 runner, `llvm` installed, and
`llc-second-backend` required to run. What it varies is the backend
*configuration* and not the reader — llc and clang share LLVM's parser and
verifier — and on that host the configuration is the aarch64 one.

**And `LLC_REQUIRE` is read by the gate**, where the x86-64 job used to refuse
a skip by grepping its own log. ADR-0330 made that the convention: a gate
refuses a skip the same way whoever runs it, and `require-consistency` keeps
the variable and the workflow in step. Both jobs set it.

## Consequences

**Two hosts now answer the question `irtest.sh` cannot.** A `clang` that got a
corner of `selfhost/compiler.pas` wrong would build a wrong compiler that
reproduced itself exactly, on either machine, and every golden would agree
because that binary wrote them. This is the only thing here that can
contradict it, and until now it could do so on one architecture.

**The job may go red the first time it runs**, and that would be a finding
rather than a fault in the job: nothing has ever built this compiler through
`llc` on aarch64. The check passes on x86-64 in 13 seconds and there is no
reason to expect otherwise, but *no reason to expect* is what this repository
distrusts, which is why the job exists.

**What still does not follow is the SMT proofs**, and that stays deliberate:
`verify/` proves properties of the lowering *model*, which is the same Python
file on either machine, and the two x86-64 jobs already require it. Nothing
about it is a question about the host. `doc/sop.md` §7's row is narrowed to
that.

## What this does not do

**It does not make the aarch64 archive fully attested.** ADR-0296's row about
what that archive does not claim stands, minus this one oracle.

**It does not add a second reader of the IR.** llc and clang share LLVM's front
half; a genuine second reader would be another toolchain, and putting one into
this workflow is the trade ADR-0085 declines.

**It does not test the job.** No CI job here can be exercised from a
developer's machine, which is why this one carries an explicit install step and
a version-recording step — a wrong package name reddens with an obvious cause.

## Alternatives rejected

**Install `llvm` in the existing `aarch64` job.** It is one line and it
destroys the property those containers exist to check, silently: the suite
would still pass.

**Leave it deferred.** The row said *insufficient resources* about a thirty-line
CI job on a runner already in use. A reason written beside a gap, never
re-checked, is the failure this session has found six times.
