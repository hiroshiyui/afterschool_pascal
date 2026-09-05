# ADR-0334: A gate with two axes

Date: 2026-09-05

## Status

Accepted. Adds a second step to the `thirty-two-bit` job and corrects
`tests/dialect/int64_foreign.pas`. ADR-0325 is not superseded; ADR-0328's
`clong` is what the corrected declaration uses.

## Context

`tests/dialect/int64_foreign.pas` declared three libc routines:

```pascal
function llabs(x: int64): int64; external 'llabs';
function imaxabs(x: int64): int64; external 'imaxabs';
function labs(x: int64): int64; external 'labs';
```

The first two are right on every target — C's `long long` and `intmax_t` are
sixty-four bits wherever this compiler emits. The third is wrong on every ILP32
target, C's `long` being the target's width, and it had been wrong since the
file was written on 2026-08-19. ADR-0328 added `clong` for exactly this and did
not revisit the one case in the tree that needed it.

**`target32` swept it 570 times and passed.** The gate builds an i386 runtime
and runs the whole corpus, and it ran this program at `-O2`, where the
optimiser folds `labs` of a constant away before the ABI matters. At `-O0` the
call is made and the answer is `-3028092405585415680`.

**No job ran the combination.** `thirty-two-bit` takes the default `-O2`; the
`unoptimised` job runs the suite at `-O0` and has no 32-bit libc, so `target32`
skips inside it and ctest reads the skip as success. Two jobs, two axes, and
the cell where they cross was empty.

## Decision

**`thirty-two-bit` runs `target32` twice, once at each optimisation level**,
both with `TARGET32_REQUIRE=1`. The gate already honours
`AFTERSCHOOL_PASCAL_OPT` — it reaches `run_test.sh` from the environment — so
this is a second step and not a second harness.

**And `labs` is declared with `clong`**, with an actual a thirty-two-bit `long`
can hold. The case now says what it was written to say and one thing more: that
`int64` and `clong` are different foreign types and a program has to choose.

## Consequences

**The job costs about a minute more**, which is the second sweep of 570 sources
against an i386 runtime that is already built.

**It generalises to a question this repository has not asked of its other
gates.** `sanitizers`, `tls`, `fpc-differential` and `second-backend` each run at
one optimisation level, and the argument that `-O0` is covered by the
`unoptimised` job holds only for gates that do not skip in it. That argument is
now written in `doc/sop.md` §7 rather than assumed.

**It is the third defect this class has produced**: a claim measured on one axis
and reported as though it were measured on the plane. `format-check` swept an
empty list (ADR-0282), `require-consistency` matched a name in a comment
(ADR-0330), and this one passed at the level where the defect is invisible.

## What this does not do

**It does not make the compiler refuse the wrong declaration.** An `external`
heading is the program's statement about what is on the other side, and ADR-0121
put the responsibility there deliberately; `clong` and `csize` are what make the
statement expressible, not a check that it is true. `foreign-layout` asks the
analogous question about a record and needs a C compiler holding the real header
to do it; nothing here has libc's prototypes.

**It does not add the second axis to any other gate.** Which of them would pay
is a question `doc/sop.md` §7 now carries, and answering it by adding steps
everywhere would double the CI bill for gates whose defects are not
optimisation-sensitive.

## Alternatives rejected

**Give the `unoptimised` job a 32-bit libc.** It would close the same cell, and
it makes the documented dependency list a lie in a second job — the exact reason
ADR-0325 gave `thirty-two-bit` a job of its own.

**Catalogue `int64_foreign` as a known i386 divergence.** It is a defect in the
case and not a limit of the target, and the catalogue is for the second kind. A
row there would have recorded a wrong ABI as a property of i386.
