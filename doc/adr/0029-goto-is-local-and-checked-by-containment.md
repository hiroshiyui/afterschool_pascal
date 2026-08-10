# 29. `goto` is local, and where it may land is a containment test

Date: 2026-08-10

## Status

Accepted. The non-local form this record deferred — and whose cost it set out
— is now implemented; see ADR-0032. Everything else here stands unchanged.

## Context

`goto` is the second of the three ISO 7185 features left after sets. It is two
constructs — the label declaration part of §6.1.6 and the goto-statement of
§6.8.2.4 — plus a restriction, §6.8.1, on which labels a given goto may reach.

The restriction is the interesting part. ISO allows a goto to *leave* a
structured statement and forbids it from *entering* one, and forbids it in both
directions across blocks except to a label at the top level of an enclosing
block's statement part.

## Decision

**A label is a number, not a name.** §6.1.6 makes it an unsigned integer of at
most four digits, so it is not a Symbol and does not go in a scope: two blocks
may each declare label 1 and each means its own. Sema gives every label a
program-wide unique id, and that id — not the number — is what a goto is
resolved to and what codegen branches to.

**Where a goto may land is a prefix test on statement paths.** Each labelled
statement records the chain of statements that contain it, and each goto
records its own. §6.8.1 then reads, exactly:

> the label's chain must be a prefix of the goto's

— because that says "every statement containing the label also contains the
goto", which is what leaving-but-not-entering means. Jumping out of a loop
nest: the label's chain is shorter and shared, so it is a prefix. Jumping into
a loop: the label's chain has the loop and the goto's does not. Jumping between
two sibling loops: neither chain is a prefix of the other. One comparison
decides all three.

A block's statement part is *not* on the path, because it is the outermost
statement-sequence rather than a statement containing one. That is what makes
"at the top level of the block" the same thing as "an empty chain", which is
what the non-local rule is stated over.

In the C++ the chain is a vector compared element-wise. In the Pascal it is a
linked list built by pushing in front and never mutated, so two chains *share*
their common suffix and the prefix test is a pointer comparison after dropping
the depth difference. Different data structures, same theorem.

**A goto is resolved when its block has been walked, not where it is written.**
A label may be declared before the statement it labels appears, so a forward
jump has nothing to resolve against at the point of use. Gotos are collected
and resolved at the end of the block — and a goto whose label belongs to an
*enclosing* block is handed outwards rather than resolved, because a nested
procedure's body is checked before the statements of the block containing it.
Without the hand-off, a perfectly ordinary non-local goto reports "label 1 is
declared but labels no statement", which is both wrong and baffling.

**The lowering is a basic block per label.** A labelled statement branches to
its own block and continues there, so the label is a join point rather than a
second entry to the block before it. A goto branches and then opens a fresh
block for whatever follows it in the same sequence — which is dead code, but is
still code that has to go somewhere.

## Consequences

**The non-local form is refused, and that is the part not done.** A goto to a
label in an enclosing block abandons every activation between here and the
target. Doing it properly needs `setjmp`/`longjmp` — a jump buffer in the
target's frame, a dispatch at its entry, and a platform-specific buffer size
alongside `PAS_FILE_SIZE` — and it needs the abandoned frames' *files closed*,
which ADR-0021 made a block-exit obligation and which a `longjmp` would
silently skip. That is a coherent piece of work and it is not this one. Sema
reports it as unimplemented rather than miscompiling it, and §6.8.1's placement
rule is still checked first, so both branches are reachable and both are
tested.

**Everything else about the epilogue is unchanged.** ADR-0021's "a block exit
closes the files the block declared" relied on Pascal having no early return.
A *local* goto cannot leave the block, so the single exit point each body ends
with is still the whole epilogue. It is the non-local form that would break
that, which is a second reason it is not a small addition.

**Ten mutations of the lowering and the checks, eight caught, and the two that
escape are behaviour-preserving.** Six of the ten are diagnostic mutations,
which no golden-output test can see — a valid program produces no diagnostics.
Their oracle is the differential dump over `selfhost/badsema/labels.pas`, which
is `difftest.sh` doing what it is for. The two escapes:

- *Not opening a new block after a goto.* LLVM's assembler accepts instructions
  after a terminator and silently drops them, and the dropped instructions are
  exactly the unreachable ones — so the malformed text assembles to the same
  program. The fresh block is what keeps the emitted text well-formed; nothing
  observable depends on it, and no test can.
- *Not clearing the label-to-block map between functions.* Label ids are unique
  across the whole program, so a stale entry can never be matched. Clearing
  bounds what is kept and is not what makes the block numbers right. The
  comment now says so rather than claiming a correctness role it does not have.

**`tests/goto.pas` covers the three shapes a program actually uses**: the
backward jump that is a loop, the forward jump out of a nest of loops, and the
label-and-goto both inside one structured statement — the "next iteration" a
Pascal program has no other way to write. That third one is what pins the
prefix test: with the label at the top level of the block, a wrong comparison
still accepts every legal program in the file.
