# ADR-0322: A chain costs one frame

Date: 2026-09-04

## Status

Accepted. Changes the release routine AP 6.4.14.3 requires; amends that clause's
NOTE 2, which said the opposite. ADR-0181 is not superseded — the recursion was
right, and this is the case where it need not happen.

## Context

`doc/roadmap.md`'s third memory-safety row measured the one capacity in this
language that ends in a **signal** rather than a diagnostic:

| An owned chain of | On release |
| --- | --- |
| 500 000 nodes | clean |
| 1 000 000 nodes | `built 1000000` prints, then exit 139 |

The message printing first is what identifies it as the release and not the
build. ADR-0012's claim about a bounded resource here is that a full buffer is
survivable **as a diagnostic**, and the per-domain release routine was outside
that claim: the safe container's release path was the crash, and it is the
container the language recommends — `PasList`'s whole shape is a chain.

The release is recursive because AP 6.4.14.3 releases every value owned within
the variable, and a type may own a variable of its own type. For `Node = record
v: integer; next: Own end` the generated routine calls itself on `next` and then
disposes the node, so the recursive call is not in tail position and one frame
is spent per node.

## Decision

**Where the domain has a direct field whose type is an owned pointer to that
same domain, the release continues at that field instead of recursing into it.**
The routine becomes a loop over a cursor:

    take the continuation out of the variable and empty the field
    release everything else the variable owns   (unchanged, and recursive)
    dispose the variable
    go round again at what was taken

A chain therefore costs one frame however long it is, and a million nodes
release in 35 ms with the balance exact.

Three things make it correct rather than clever.

**Emptying the field before the walk is what makes it safe**, and it is
6.4.14.6's move written by the release rather than by a program: the walk that
follows finds `nil` where it would have recursed, so nothing is released twice.
Forgetting the store is the second mutation below and it is a double release
that four cases catch.

**The cursor is an `alloca` in the entry block**, which is where ADR-0102 says
one belongs: the block is reached once per call however many nodes the loop then
walks. Putting it in the loop body would claim stack per iteration and reproduce
the defect in a new place.

**Only the fixed part is looked at**, and that is not an omission: AP 6.4.14.2
refuses an owned pointer in a variant-part, so every owned field of a record is
in the fixed part.

## Consequences

**The row is narrowed, not closed.** A **tree** still costs a frame per level: a
record with two self-referential owned fields is a binary tree, and whichever
field is chosen as the continuation the other still recurses. A degenerate tree
is therefore still a deep recursion, and nothing bounds it. What is fixed is the
shape that actually occurs — every owned container in this tree is a chain — and
the roadmap row says so rather than claiming the capacity is gone.

**A processor is still not required to bound the tree case**, and AP 6.4.14's
NOTE 2 now says which half is which. It had said a list long enough will exhaust
the stack on release; that sentence was true when written and is now false, and
being wrong in a NOTE is how a reader learns a limit that is not there.

**`tests/dialect/owned_deep.pas` is the case**, at a million nodes — above the
measured boundary and 35 ms, so it costs the suite nothing. It builds by a loop
and not by recursion, deliberately: what it measures is the release alone, and a
recursive build would have crashed first and hidden it.

## What this does not do

**It does not bound the depth or turn an exhausted stack into a diagnostic.**
That was the alternative and it is still available for the tree case: a counter
in the release, a limit, and a message. It costs a call per node released, on
every program, to report a case no program in this tree reaches.

**It does not change what a release does**, only the order it does it in. The
same variables are disposed, in the same order — the continuation is disposed
after the node that held it, exactly as the recursion did.

**It does not touch `dispose`, `new` or an assignment**, each of which calls the
release routine and is unaffected by its shape.

## Alternatives rejected

**Bound the recursion and report.** It satisfies ADR-0012 for every shape rather
than for chains, and it is the honest general answer — but it makes a correct
program fail where it used to work only by accident of stack size, and it costs
every release a counter. Chains are what exist; this is where the cost should
fall.

**An explicit worklist in the runtime.** Fully general, and it allocates while
freeing — the one time a program may have no memory to allocate with.

**Pointer reversal** (Deutsch–Schorr–Waite), which needs no extra memory and
handles trees. It needs the field layout at run time, which this compiler
deliberately keeps out of the runtime (ADR-0185's reason, one type over), and it
rewrites the structure while releasing it, which is unreviewable against a
`heap-balance` catalogue that counts calls.

**Rely on LLVM to turn the recursion into a loop.** It cannot: `dispose` follows
the recursive call, so it is not a tail call, and the corpus is swept at `-O0`
where nothing would happen anyway.
