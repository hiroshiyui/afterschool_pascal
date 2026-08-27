# 231. The dialect build, measured

Date: 2026-08-28

## Status

Accepted. Answers with measurement the objection ADR-0190 raised and ADR-0223
restated; neither is overturned, and `selfhost/compiler.std` does not change.

## Context

ADR-0109 wants to know whether Afterschool Pascal is pleasant to write
something large in. The largest program within this project's reach is the
compiler, and it is excluded from nearly everything the dialect was built for:
`selfhost/compiler.std` says `extended`, so `defer`, `owned ^T`, slices,
`break`, `exit`, the generics and `type of` are all unavailable to it.

Making it a dialect source has been declined twice. ADR-0190 put it plainly:

> **Make `selfhost/compiler.std` `afterschool`.** … It is not obviously wrong
> and it is not free: the fixed point holds only while the compiler is an
> Extended Pascal source, and ADR-0082's conversion went the other way for a
> reason.

ADR-0223 restates it, and is also the way through: it builds the compiler a
second time under `--std=afterschool` and uses that build as a **reader**,
never as the product, which is why its own Decision says ADR-0190's objection
"is about the **product**. Nothing here is the product."

`doc/roadmap.md`'s v3 chapter frames what that leaves: *"the question v3 should
put is not does the product change its standard but how much of the dialect the
reader build can use before the product follows."*

The objection has never been tested. It is a claim about what would happen, and
the artefact that would settle it — a compiler built from this source under the
dialect — has existed since ADR-0223 and was only ever asked whether it trapped
while reading.

## Decision

Ask that artefact two more questions, in `tests/checks/dialect_build.sh`.

**1. Is the dialect build a fixed point?** Compile `compiler.pas` under
`--std=afterschool` with the shipped compiler; link it; compile `compiler.pas`
under `--std=afterschool` again with *that*; require the two IR files to be
byte-identical. This is `irtest.sh`'s stage-2-equals-stage-3, asked of the
dialect build.

**2. Is it the same compiler?** For every `.pas` in `tests/`, `selfhost/` and
`lib/`, compile with both builds under the standard the path names, and require
byte-identical IR where both accept, or the same exit status and byte-identical
diagnostics where either refuses. The refusals are half the corpus and the more
interesting half: the error paths are where two builds could most easily part
company.

A floor of 500 sources refuses to let the gate pass by reaching nothing, as
`variant-check` and `difftest` each do.

**It is a separate gate from `variant-check` although it builds the same
artefact.** The subject is different — that one asks whether every node was
read through the arm its tag selects, this asks what the build *is* — and a
shared gate would have one name for two claims and one failure message for two
causes. The second build costs about two seconds; the whole gate is eleven.

## Consequences

**Both claims hold, and this is the first time either has been checked.**

| | |
| --- | --- |
| stage 2 vs stage 3 under `--std=afterschool` | byte-identical |
| sources compared | **1025** |
| compiled to identical IR | 564 |
| refused with identical diagnostics | 461 |
| differing | **0** |

So the dialect build is not merely a reader: it is a complete, self-hosting
compiler, behaviourally indistinguishable from the one that ships, carrying
2 874 variant guards the shipped one does not.

**ADR-0190's objection is narrowed, not overturned, and the distinction
matters.** *"The fixed point holds only while the compiler is an Extended
Pascal source"* is now known to be false as a statement about this source: the
fixed point holds under the dialect too. What the record was protecting is
untouched — the shipped compiler is still built under `--std=extended`, and
this argues for no change to that. It removes one reason the flip could not be
made: "we do not know that it would work" is no longer among them.

**What remains before the product could follow** is the seed, and it is not
small. `seed/pascalc.ll` must accept whatever `compiler.pas` becomes, and a
dialect feature must be expressible in what the seed already accepts or the
seed is refreshed first (ADR-0109). Nothing here refreshes a seed, and a seed
is refreshed in a release rather than casually. So this measures the
*destination* and does not take a step toward it: the source is unchanged and
uses no dialect construct.

**Neither half is vacuous, and that was checked rather than assumed.** Handed
the seed compiler in place of the shipped one, the gate reports the fixed point
broken and exits 1. And over 40 sources the shipped compiler and the seed emit
different IR for all 22 that both compile, so the comparison distinguishes two
compilers rather than comparing a file with itself.

**Claim 2 is a watch and not a proof, in the sense `buffer-headroom` is.** Both
builds come from one source, so a defect written into `compiler.pas` is in both
and this compares two copies of it. It is an equivalence check, not a
correctness one — `irtest.sh` and the goldens are what say the compiler is
right. What it would catch is the dialect's own checks changing the compiler's
answers: a variant guard trapping mid-compilation, or one of ADR-0138's
argued-for divergences reaching the compiler's own code.

**It costs eleven seconds and one more compiler build per `ctest` run.**

## Alternatives rejected

**Flip `selfhost/compiler.std` to `afterschool`.** The thing the roadmap is
actually asking about, and this is the evidence for it rather than the act. It
needs a seed refresh and belongs to a release; and it should be argued on what
the dialect *buys* the compiler, which is a question no measurement here
answers.

**Fold this into `variant-check`.** The artefact is shared and the claims are
not. Two claims under one name is how a gate comes to have a failure message
that does not say what failed.

**Compare the two builds' own binaries rather than their output.** They differ
by construction — one carries 2 874 guards — so the comparison would be
meaningless. What is comparable is what they *emit*, which is the thing a
compiler is for.

**Run the corpus's programs under the dialect build and check the goldens.**
That is `irtest.sh`'s job for the shipped compiler, and doing it twice would
double the slowest harness here to re-answer a question byte-identical IR
already settles: if the IR is the same, the program is the same.
