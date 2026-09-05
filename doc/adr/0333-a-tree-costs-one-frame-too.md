# ADR-0333: A tree costs one frame too

Date: 2026-09-05

## Status

Accepted. Amends AP 6.4.14's NOTE 2 a second time. ADR-0322 is not superseded:
its loop is the mechanism this generalises, and its two mutations still kill
`tests/dialect/owned_deep.pas`.

## Context

ADR-0322 made an owned **chain** cost one frame however long it is: the release
continues at the first direct field whose type is an owned pointer to the
domain, instead of recursing into it. Its Consequences said what it left —

> A **tree** still costs a frame per level … whichever field is chosen as the
> continuation the other still recurses.

— and priced it as the shape that does not occur, every owned container in this
tree being a chain. The price was wrong in a way the sentence hides. These are
the same program, differing in which of two identically typed fields is written:

| `Node = record v: integer; l, r: Own end` | 400 000 nodes |
| --- | --- |
| `fresh^.l := take(head)` | released, exit 0 |
| `fresh^.r := take(head)` | `built` prints, then exit 139 |

**A program's survival depended on the order two fields were declared in**, and
nothing in the source of either program says which one the release will walk.
That is worse than a bounded capacity: it is a capacity that moves when a
declaration is reordered, and 400 000 is not a large tree.

## Decision

**Every self-owned field of the domain is emptied and pushed onto a work list,
and the work list is threaded through the nodes waiting on it.** The link — the
first such field, which ADR-0322 already emptied — carries the thread.

    pop a node, and continue the list at what its link field holds
    empty the link
    for each other self-owned field: take it out, empty it, and push it
    release everything else the node owns   (unchanged, and recursive)
    dispose the node
    go round again

**Pushing is a loop, and that is the whole of the correctness argument.**
Writing the thread into a node's link overwrites what the link held, so the
value is rescued first and pushed in front of the node — which walks that
node's own link-chain, iteratively. The invariant is that *the link of a node
on the work list holds the next item*, and it holds on the tail without being
written: a node still in an original chain has its own link there, and its own
link **is** the next item. That is why the value taken out of the popped node
goes straight into the cursor and needs no push of its own, and it is why the
one-field case emits exactly the code ADR-0322 wrote — `SelfOwnedOthers` is
false, the second cursor is not even allocated.

**Both cursors are `alloca`s in the entry block**, which is ADR-0102's rule and
the same reason ADR-0322 gave: the block is reached once per call however many
nodes the two loops then walk.

**Emptying a field before pushing it is what keeps the walk from finding it
again.** The second mutation below drops that store, and it is not a depth
defect — it kills a **three-node** program with a double release, which is the
distinction worth having: the emptying is about correctness and the pushing is
about depth.

## Consequences

**`tests/dialect/owned_tree.pas` is the case**, at 400 000 nodes in each of
three shapes — degenerate on the link, degenerate on the other field, and
alternating, which no choice of a single field could have helped — plus a
balanced tree of 8 191 nodes, which says nothing about the stack and everything
about the walk. The whole case costs the suite 0.1 s.

**The order of disposal changes for a tree.** ADR-0322 said its change kept
disposals in the same order; this one does not, a pushed subtree being released
before the rest of the list. Nothing observes the order: `heap-balance` counts
calls, and no other oracle here can see a release at all.

**A domain with two self-owned fields now makes two calls per node that find
`nil`** — `WalkFiles` still walks every owned field, and both have been emptied
by the time it runs. ADR-0322 accepted the same for one field and the callee's
first act is the empty test.

**`SelfOwnedField`'s choice is now arbitrary in the way a choice of
representation is.** It was arbitrary in a way that decided whether a program
ran.

## What this does not do

**It does not bound every depth**, and AP 6.4.14's NOTE 2 now names the two
that are left. A self-owned pointer the domain does not hold **directly** — one
inside an array or a sub-record component — has no link field to thread and
still recurses per level; and a **cycle of domains**, `A` owning a `B` owning an
`A`, is two generated routines calling one another, which nothing here threads.
Both are stated rather than measured, which is the difference between this
paragraph and ADR-0322's.

**It does not turn an exhausted stack into a diagnostic.** That alternative is
unchanged and still costs a counter on every release of every program, to report
a case that is now much harder to reach.

**It does not touch `dispose`, `new` or an assignment.** Each calls the release
routine and is unaffected by its shape, exactly as ADR-0322 left them.

## Alternatives rejected

**Pointer reversal** (Deutsch–Schorr–Waite), rejected by ADR-0322 for needing
the field layout at run time. That reason is weaker than it read — the release
is generated *per domain*, so the layout is static in the generated code — but
the mechanism is still the wrong trade here: it needs a bit per node to say
which field is being reversed, and it rewrites the structure it is walking. The
work list threaded through the link field needs neither, because the nodes are
being freed and their links are dead.

**Choose the field with the deeper subtree.** Not knowable, and it answers the
wrong question: it would move the crash rather than remove it.

**An explicit worklist in the runtime.** ADR-0322's reason stands unchanged — it
allocates while freeing, which is the one time a program may have no memory.

**Leave it and widen the roadmap row.** The row was already there and said a
tree costs a frame per level. What it did not say, because nobody had written
the two programs side by side, is that the *same* tree costs one frame or
crashes depending on a declaration order — and a row that reads as a bound on an
unusual shape, when it is really a dependence on invisible source order, is the
kind of cell this project has now mispriced three times.
