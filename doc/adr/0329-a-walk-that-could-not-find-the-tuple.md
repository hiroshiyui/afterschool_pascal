# ADR-0329: A walk that could not find the tuple

Date: 2026-09-05

## Status

Accepted. Fixes the release walk for a heap variable whose type has a
discriminant-bounded array of an affine component. No clause changes: what AP
6.4.14.3 requires is what the compiler now does.

## Context

`doc/roadmap.md`'s review list carried a wart: a container **of** owned
pointers, `^Vec(owned ^Node)`, is declarable and every operation on it is
refused, so the type can be written and never used. It was recorded as
harmless.

It was not. Probing it — the type declared and `new`, then `dispose` — the
compiler emitted

    %v24 = getelementptr i32, ptr , i32 0

with no operand at all. clang refuses the module, so the program does not
build. Two probes narrowed it and the narrowing is the whole diagnosis:

| shape | |
| --- | --- |
| a schema with one owned **fixed** field, heap | works |
| a **fixed** array of owned in a record, heap | works |
| a schema's discriminant-bounded array of owned, as a **frame variable** | works, balance 0 |
| the same, on the **heap** | invalid IR |

`WalkFiles`'s array arm asks `DynLength` for the length, because it may be a
discriminant's (ADR-0040), and passed it an **empty** header. For a declared
variable that is right: `var q: A(3)` produces a type whose bounds are
constants, so `BoundValue` answers them without reading a tuple, and the
emptiness is never noticed. A heap variable's tuple is in front of the block,
and there the empty string reaches a `getelementptr`.

## Decision

**`walkHdr` is the tuple the current walk reads its dynamic bounds from**, set
by `new` and `dispose` from `block - HeaderSize(domain)` and empty everywhere
else.

**One variable for the whole walk, not a parameter threaded through it**, and
ADR-0045 is what makes that correct rather than convenient: a record holds
exactly one discriminant-bounded array and only as its last field, and the
discriminants are the *variable's* — so every dynamic bound reached below one
address belongs to one header. A parameter would have carried the same value
down five call sites unchanged.

**`new` sets it too, although `new` does not need it.** Inside `new` the tuple
has no home yet and `BoundValue` answers a dynamic bound from `newTuple`
before it reads any header, so the walk there never asks. Setting it in both
places anyway costs one `getelementptr` in a path that already computes the
same address, and avoids a difference between two walks that nothing states.

## Consequences

**A generic container may hold owned pointers.** `^Vec(owned ^Node)` builds,
and one `dispose` releases the container and every owned element in it —
`tests/dialect/owned_schema_array.pas` is 7 allocations and 7 releases with
one `dispose` written.

**The empty slots are safe because `pas_new` is `calloc`.** A program that
fills six of eight leaves two nil, and the walk steps over them; that is why
the loop may run over the *capacity* rather than over a length the container
keeps. It is worth writing down because it is the property that makes walking
an unwritten slot correct rather than lucky.

**Nothing else moves.** Both coverage ratchets are unchanged at 392 and 847,
`heap_balance.txt` gains one line at 0, the stage-2/stage-3 fixed point holds,
and `target32` goes to 571 of 572 — the new case runs on i386 as well.

## What this does not do

**It does not make `PasContainer` usable over an owned element type.** `Vec(T)`
with `T` an owned pointer still refuses every operation, because `VecPush`
takes its element by value and `VecGet` returns one, and AP 6.4.14.3 forbids
both. What this fixes is the *storage*: the type is expressible and its
release is correct, so a container written for owned elements — with `take`
where a copy is written today — is now a library question and not a compiler
one.

**It does not add a rule.** The clause already said what a release does; this
is the emitter agreeing with it.

## Alternatives rejected

**Refuse it in Sema**, the way AP 6.4.14.2 refuses an owned pointer to a schema
domain. That clause's reason is that releasing an owned variable means walking
it and the extents are in a descriptor the heap has not got — and that reason
is *false here*: the tuple is in front of the block and the walk can read it,
which the frame-variable case proved by working. Refusing would have made a
correct program illegal to spare the emitter four lines.

**Thread a header parameter through `WalkFiles`.** Five call sites and a
recursive procedure, to carry one value that is constant for the whole walk.
