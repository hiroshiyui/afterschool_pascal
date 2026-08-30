# 256. A fallible value may be owned, and then the arms are laid apart

Date: 2026-08-30

## Status

Accepted, 2026-08-30.

It is the second half of `doc/roadmap.md`'s *factory* item and the half that
page called "the whole of it".
[ADR-0255](0255-a-function-may-answer-a-handle.md) is the first and ships with
it.

## Context

`function Open(p: Path): Stream ! ErrorCode` is what a library wants. AP
6.4.13.1 refused it, and the refusal was load-bearing rather than an oversight:
a fallible-type's two arms **are** a variant part, the arms of a variant part
share storage, and a handle's storage is its own. Writing a cause into the
record would overwrite the front of the `struct pas_handle` the runtime is
holding, and the block's exit would then close whatever was left there.

That is the same sentence ISO 7185 §6.4.3.3 is enforcing when it refuses a
file in a variant part, and the same invariant `HoldsFile`'s comment states —
*a variant part cannot [hold a file] … which is also what makes the walk below
able to reach every file exactly once*.

## Decision

The **value** side of a fallible-type may be affine — a file, a handle, an
owned pointer, or anything containing one — and the two arms of such a record
are then laid **beside** one another rather than over one another (AP
6.4.13.5). The **cause** side may not be.

**The asymmetry is the clause and not an economy.** A cause travels: AP
6.8.9's `try` yields the value and leaves the enclosing function with the
cause, which is a copy, and an affine value has none. The same sentence is why
`try` is refused outright on such a type — 6.8.9.4 makes the expression denote
the *value*, and denoting an owned value would be copying it. A program tests
`ok`, which is what it would do with the handle in any case.

**Storage-only, and the tag survives.** The arms are still arms: the tag still
selects, `EmitVariantGuard` still traps a read of the inactive one, and
6.4.3.4.2's requirement is inherited unchanged. Only where they sit has moved.
The alternative — collapsing them into fixed fields — would have lost the trap
and would have had to reimplement it, and `variant-check`'s guard count would
have fallen.

**Per type, not per language.** `armsApart` is set only where a side is
affine, so every fallible-type written until now keeps the layout it had and no
golden, no gate and no offset moves. An unconditional change would have grown
every fallible in the corpus for a reader that does not exist.

**One assignment.** The record contains something with no copy, so `Assignable`
goes on refusing it everywhere — the relational operators, every parameter
position, the whole-record copy — and the one value admitted is a call of a
function of this very type, built *in this variable* through ADR-0255's
`factoryInto`. A memcpy would be ADR-0150's double free with a handle in place
of a file: two records, each holding a slot the runtime is tracking, each
released at the end of its own block.

## Consequences

**The roadmap's estimate was wrong in both directions at once**, and both
halves are worth recording because this page's standing prior is that such
estimates are wrong in the cheap direction.

*Cheaper than written:* it said the change "reaches `PutStructAt`,
`SelectedSize`, `target-layout` and `foreign-layout` — the last two being
gates that compare offsets, so both would move and both would have to be
re-argued rather than regenerated." Neither gate moved. Neither holds an
expected value: both compute from the compiler's own output on every run, and
neither read a source declaring a fallible-type at all. There was nothing to
re-argue. `tests/checks/target_layout.pas` now declares one on purpose, which
is the fix for a gate that could not have seen this shape.

*Dearer than written:* it said the item is "not a clause and not a Sema arm …
a representation change". The representation change is the small half. What it
did not name is that the record then contains something with no copy, so it
needs an assignment rule of its own (a clause and two Sema arms), a mandatory
in-place build (the correctness crux), two walks taught to reach an arm, and a
decision about `try`.

**And it is the first item on that page where the standing prior does not
apply.** Five times running, *before recording that something waits on the
memory model, ask whether the address can be retired at the call* — and five
times it could. Here it cannot, and the reason generalises: the whole point of
a factory is that the callee's answer **outlives the call**. That is worth more
than the feature.

**A defect surfaced that had been unreachable.** `EmitAssign`'s handle arm
never set `designatorGuard := vgWrite`, so the address it takes was guarded as
a *read*. It could not matter while no handle could be inside a variant part;
the moment one could, `res.val := ExtFopen(...)` trapped against whichever arm
was last active. Fixed with the ordinary assignment path's two lines.

**The first mutation of the layout survived**, and that is the most useful
thing here. Laying the arms over one another again passed all 754 cases,
because the test wrote a cause only over a handle that had never been opened —
where the bytes corrupted are zero either way. `causeOverValue` writes a cause
over a *live* stream, and the mutation then exits 139. A test of a
representation is worth nothing until it stages the corruption the
representation prevents.

**What is still refused**: a `try` on such a type, a copy of such a record, an
affine cause side, and a fallible-type inside another. The first three are
this clause's own and the last is ADR-0176's.
