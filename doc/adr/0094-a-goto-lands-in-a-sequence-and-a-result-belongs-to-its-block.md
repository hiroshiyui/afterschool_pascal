# 94. A goto lands in a sequence, and a result belongs to its block

Date: 2026-08-15

## Status

Accepted. Retires the §6.8.2.2 deferral recorded in ADR-0055.

## Context

Two clauses whose machinery already existed and whose questions were slightly
the wrong ones.

## Decision

**§6.8.1 admits a label three ways, and the prefix test is two of them.**

> a) the labelled statement contains the goto; b) the labelled statement is a
> statement of a statement-sequence containing the goto; c) the labelled
> statement is a statement of the statement-sequence of the compound-statement
> of the statement-part of a block containing the goto.

ADR-0029 built the prefix test — "the label's chain is a prefix of the goto's" —
which is exactly *leaving but not entering*. It never asks whether the label
sits in a **sequence**. Only a compound-statement and a repeat-statement hold
one; a branch of an if, a loop body, a with body and a case arm are each a
single statement. So a label inside one of those is reachable only from within
it, which is a) — and two labels at the same depth in *different* branches of
one if pass the prefix test, because the if-statement is on both chains.

The fix adds a) as its own question (is the labelled statement on the goto's
path?) and restricts b) to the two path entries that hold a sequence. `c)` is
the empty path and was already right.

**§6.8.2.2 says *contain*, not *be*.** "The function-block associated with the
function-identifier of an assignment-statement shall contain the
assignment-statement." A procedure nested inside `f` may write `f`'s result,
reaching it through the static chain as it reaches any enclosing variable — and
this compiler already lowers that correctly. So the test is a walk up the owner
chain, not `= currentProc`, and what it refuses is a *sibling*.

## Consequences

**462 cases pass.** `selfhost/compiler.pas` contains no `goto` at all, so the
first change could not touch self-hosting; the second found no sibling
assignment in it either, which is consistent with ADR-0055's note that the one
real instance was fixed when the never-assigns check landed.

**Two messages, because there are two shapes.** A label in the wrong branch of
one if is on the same chain and gets the new sentence; a label in a different
case arm is on a different chain and keeps ADR-0029's. `tests/goto_branches.pas`
has both, and its two *legal* jumps — outwards to the block's own sequence, and
within one compound statement — come first, because a rule about jumping in is
easy to over-apply.

**The sibling check had to suppress a second diagnostic.** Once §6.8.2.2 has
reported the target, "the left side of an assignment must be a variable" is a
consequence of that fault rather than a second one (ADR-0054). It also must not
set `assignedResult`: a function whose only assignment is a sibling's still
never assigns its own, and both messages now come out of
`tests/extended/funcresult_errors.pas` — two rules, not one.

### What this does not do

**It does not enforce the *threatens* half of §6.7.2**, which ADR-0055
deferred alongside this and which is a different rule: a `read` into a result
variable satisfies the standard and not this compiler.
