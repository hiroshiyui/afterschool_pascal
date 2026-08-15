# 102. An alloca belongs where it is claimed once

Date: 2026-08-15

## Status

Accepted.

## Context

ADR-0043 wrote the rule down and applied it to one place:

> the Pascal emitter is sequential and cannot put an `alloca` in the entry block
> afterwards, so scratch storage would grow the stack for a `new` inside a loop.

That sentence is about the emitter, not about `new`. It is true of every
`alloca` this compiler writes, and the reasoning was never carried across to the
`for` statement, which writes two: the sequence form stored its limit in one,
and the set form (ADR-0063) steps a counter in another. Both are emitted where
emission has reached, so a `for` nested inside any loop claimed fresh stack on
every iteration of the loop around it.

Nothing computed a wrong answer. The program ran out of stack, and only at
`-O0` — at `-O2` LLVM hoists an alloca whose address does not escape, and the
whole corpus compiles at `-O2`. So 495 tests, the validation suite, the SMT
proofs and the stage-2/stage-3 fixed point were all green over a compiler that
turned an ordinary nested loop into a segfault.

## Decision

**The two halves needed different answers, and the difference is whether the
storage is written more than once.**

The sequence form's limit needed **no storage at all**. §6.8.3.9 requires the
limit to be evaluated once; this compiler implemented "once" by storing the
value and loading it back twice per iteration, when the value is already an SSA
register defined before any of the loop's blocks exist. It therefore dominates
every use inside them, however the to-expression was emitted — including one
that itself created blocks, since emission ends in the block the loop is then
built from. The store and both loads are gone.

The set form's counter **is stepped**, so it has to live somewhere, and it lives
in a frame slot Sema gives the statement. That is the shape ADR-0017 gave a
`with` binding and ADR-0052 gave `binding(f)`'s record: storage that outlives an
expression and is claimed once per activation. It is per *statement* rather than
per block, so nested or adjacent `for … in` statements cannot share one.
`nkFor` therefore leaves `NewNode`'s "nothing of Sema's to clear" group — the
move ADR-0066 made for `nkIndex` and `nkSubstr`, and for the same reason: the
dump reads the field whether or not Sema ran.

**The general rule, for the next one:** an `alloca` is only safe where the
emitter reaches it once per activation — a prologue. Anywhere a statement can
be nested inside a loop, storage that has to survive is a frame slot and
storage that does not is an SSA value. The three remaining `alloca` sites are
prologue ones (ADR-0041's computed discriminants, a schematic value parameter's
copy, and the array-of-files loop counter) and stay as they are.

## Consequences

**Testing it needed two things that are not Pascal**, because the defect is
invisible to an ordinary golden — the program's output is the same either way.

`tests/run_test.sh` gains a `name.opt` sidecar naming an optimisation level, in
the shape `name.std`, `name.in` and `name.epoch` already have. Storage is the
only thing that has needed it and the header comment says so, because a sidecar
that spreads would quietly make the corpus stop testing `-O2`.

`run_program` now bounds the stack at 8 MB. That is the same argument the
`ulimit -n 256` beside it already makes for the descriptor table — a test that
exhausts a resource can only fail where the resource can run out — and 8 MB is
the ordinary Linux default, so no other case moves.

**Two files, not one.** `tests/for_nested_stack.pas` and
`tests/extended/forin_nested_stack.pas` are separate because the two fixes are
different: one removed a store and the other moved one. Each mutation kills only
its own test, which a single program exercising both would not have shown.

**The `-O0` corpus is still one case wide.** `verify.py --crosscheck` compiles
at both levels and compares, but only over its own generated program; every
other case runs at the default `-O2`. A codegen bug visible only without the
optimiser has two tests looking for it and no more.

### What this does not do

**It does not add a rule to `verify/`.** The model describes what the emitted
instructions compute, and this changes where one of them is written rather than
what any of them means — the loop's arithmetic, its bounds check and its
stop-before-stepping care are untouched, and their theorems still hold.
