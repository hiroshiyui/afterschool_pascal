# 85. Stage 0 is retired

Date: 2026-08-14

## Status

Accepted.

## Context

ADR-0004 said it at the start: *"Stage 0 (the C++ compiler) only has to be good
enough to compile the stage-1 Pascal source once. It is not the deliverable."*
Everything since has been toward the moment that could be acted on — the
bootstrap closing (ADR-0025), the compiler becoming the product (ADR-0083), and
v0.1.0 shipping it.

`doc/roadmap.md` decided against retirement earlier on the day this was written.
That entry weighed the loss of `selfhost/difftest.sh` and of `verify/`'s subject
against "a capability the fixed point already provides", and concluded there was
nothing to gain. It was wrong about the gain, and the omission was specific:
**every language feature shipped twice**, in C++ and in Pascal, in the same
commit, and that tax was permanent. Halving the cost of every future feature is
the reason, and it is not a capability — which is why a record framed around
capabilities missed it.

## Decision

**`src/` and `selfhost/difftest.sh` are deleted.** `selfhost/compiler.pas` is
the only compiler.

**`seed/pascalc.ll` is a committed compiler in LLVM IR**, and is what makes the
tree buildable without one. `clang` assembles it; the result translates the
current source; that is what ships. Two stages, and the second is the point —
`build/bin/pascalc` is always built from the source in the tree, and the seed
only bootstraps.

IR rather than a binary, because ADR-0006 made textual `.ll` a first-class
output — "the backend that survives the rewrite" — and this is what that was
for. It is refreshed at release tags rather than per commit, and `seed/refresh.sh`
refuses to write a candidate that does not reproduce itself.

**`tools/pascalcc` is where linking lives.** No standard Pascal program can
start another (ADR-0083), so the compiler stops at the IR and one shared wrapper
adds `clang` — used by `run_test.sh`, `irtest.sh`, `producttest.sh` and
`verify.py`, which is why those kept their logic and changed only which compiler
they are handed.

**`pascalc` behaves like a compiler now**: quiet on success, diagnostics as
`file:line:col: error: message`, dumps behind `--dump-*`. It wrote three dump
sections unconditionally for as long as there was a second binary to compare
them against, which ADR-0025 gave as the reason there was no mode to select.
That reason expired here.

## Consequences

**A tree with no C++ compiler and no LLVM development files builds the
compiler**, passes all 435 cases, reaches the stage-2/stage-3 fixed point and
proves all 43 rules. `find_package(LLVM)` is gone; `clang` on PATH is the
requirement. That is the plainest evidence the retirement is real.

**The differential test is gone and nothing replaces it.** It compared two
independent implementations over 436 sources, and the defects it caught were
exactly the ones every other oracle agreed about: a diagnostic that named two
types identically and explained nothing (ADR-0074), a comment-delimiter rule
implemented wrongly in both compilers (ADR-0073), a builtin's enumerator one
apart (ADR-0059). What remains — goldens, the fixed point, the proofs — cannot
find that class of defect, because a golden cannot disagree with the program
that wrote it. This is the cost, it is permanent, and it is why the decision was
worth arguing about.

**157 error-path sources were adopted rather than orphaned.**
`selfhost/badparse/`, `selfhost/badsema/` and `torture.pas` had no goldens at
all — they existed to be diffed. Each is now a case with a `.err` golden, taking
the suite from 279 to 435. The goldens were generated only after checking that
both compilers agreed on all 158, which was the last moment that check could be
made.

**The 158th was a finding.** `badparse/variant-in-variant.pas` had been
*accepted* by both compilers since ADR-0026 made a variant part inside a variant
part legal. It stopped being a negative test and nothing noticed, because
difftest only asked whether the two agreed — and they agreed, on accepting it. A
differential oracle is blind to a test that has stopped testing anything.

**`verify/` survives, and its tie to the compiler is weaker.** `lowering.py`
models an emitted instruction sequence rather than any compiler's internals, so
it transferred unchanged. But the two backends were *measured* emitting
different instruction counts for the same program — LLVM's IRBuilder folds a
`getelementptr` where a textual emitter writes one out — so the model could be
read against C++ line by line and cannot be read against the Pascal emitter that
way. What holds it now is `--crosscheck`'s 44 adversarial values at `-O0` and
`-O2`, and the 66 `trap_*.pas` goldens. That is the tie ADR-0013 always
specified; it is simply no longer backed by a second implementation a person
could read.

**The repository is x86-64 Linux only.** The seed carries a `target triple` and
`target datalayout`, and it must — ADR-0028 records the segfault that came of
leaving the datalayout unstated. Porting means producing a seed on the new
target, which needs a working compiler there first. Before this, any platform
LLVM and a C++ compiler supported would do.

**Provenance becomes a chain rather than an inspection.** A reader could
previously build a compiler from source alone. Now the first compiler comes from
a committed artefact whose only warrant is this repository's history — the
trusting-trust problem in its ordinary form. Tag `v0.1.0` is the last commit
where `src/` existed.

### What this does not do

**It does not delete anything irrecoverably.** `src/` is in the history and at
`v0.1.0`, and a second implementation could be started again from there if the
differential oracle is ever judged worth its cost.

**It does not change the language.** Both standards are accepted exactly as
before; 435 goldens say so.

**It does not make `pascalc` link.** That remains outside the language, and
`tools/pascalcc` remains where it is answered.
