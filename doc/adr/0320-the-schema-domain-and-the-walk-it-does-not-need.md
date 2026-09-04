# ADR-0320: The schema domain, and the walk it does not need

Date: 2026-09-04

## Status

Accepted. Amends AP 6.4.14.2, which ADR-0181 wrote. ADR-0181 is not superseded:
the restriction it added was right for the reason it gave, and this record
narrows it to the cases that reason reaches.

## Context

ADR-0318 made `owned ^T` protectable so that a library could accept a chain
without being granted the right to destroy it, and `doc/roadmap.md`'s second
memory-safety row said what that unblocked: `lib/`'s containers, whose accessors
take their handle by **value**, which AP 6.4.14.3 forbids. The row's table
classified nine ordinary pointer types — five refused for a schema domain, four
for value parameters — and named the second group as the ones a rewrite would
reach.

**The table was wrong, and probing it is what found the real restriction.**
Changed to `owned` one at a time and compiled, the nine (now eleven, with
`examples/arena_graph.pas`) answer differently: `StrMap`, `IntVec` and `StrVec`
are themselves schemas, so `SMapPtr`, `IVecPtr` and `StrVecPtr` were in the
first group too; and `JsonPtr`, put in the second group, is refused before any
parameter is reached because `JsonNode` has a **variant part**. Ten of eleven
were refused by 6.4.14.2 and one by 6.4.14.3, where the row had it five and
four. ADR-0318 unblocked none of them.

So the binding restriction was never the value parameter. It is 6.4.14.2, and
that clause states its own reason:

> Releasing the variable means walking its type, and a schema-produced type's
> lengths are discriminants read from the descriptor a *frame* holds — the tuple
> header a heap variable carries is stepped back over by `dispose` and read by
> nothing else, so a release routine has no way to ask how long an array in it
> is.

Every word of that is true, and it is about the **walk**. A walk happens only
where the variable holds something whose release is more than giving the storage
back — a file, a handle, or another owned pointer. `EmitOwnRels` was already
asking exactly that question, to decide whether to walk at all:

```pascal
if HoldsFile(r^.dom) then WalkFiles(own, r^.dom, ...);
```

And the comment on the line after it named itself as the second place to change:

> No stepping back over a tuple header, where dispose's own arm does it:
> 6.4.14.2 refuses a schema domain, so HeaderSize is zero for every type that
> can reach here and the arm would be unreachable. **If that restriction is ever
> lifted, this is the second place to change** — the release and dispose must
> give back the same address.

## Decision

**A schema domain is admitted where the type it produces holds nothing affine.**
AP 6.4.14.2's first requirement becomes: where the domain is a schema-name, the
produced type shall not contain a file-type, a handle-type or an
owned-pointer-type. The variant-part requirement is unchanged.

Two lines of implementation, and the second is the one the comment predicted.

**Sema** asks `ContainsFile` — the `IsAffine` walk (ADR-0181) — of the produced
type rather than refusing the schema. It is asked of the *production* and not of
the tuple, because a schema's discriminants choose extents and never members: no
actual-discriminant-part can introduce a file into a body that has none, so one
production answers for all of them. The question is asked on **both** resolution
paths — the direct one and the pending list a domain named later goes through —
which `tests/dialect/owned_errors.pas` has pinned since ADR-0181.

**CodeGen** steps the release routine back over the tuple header before
`pas_dispose`, exactly as `dispose`'s own arm does, because what was allocated
is the header and the variable together. Until that line existed a block-scoped
release of a schema-domain owned pointer reached `free()` with the variable's
address and aborted with `free(): invalid size` — which is how the experiment
that relaxed only the Sema half ended, and is the mutation that kills it.

## Consequences

**Nine of the eleven ordinary pointer types outside the compiler are now legal
as `owned ^T`**, measured the same way the wrong table was: `IVecPtr`,
`SMapPtr`, `StrVecPtr`, `CountMap`, `WordVec`, `PathVec`, `DocMap` and the two
in `examples/arena_graph.pas`. What each still needs is a *usage* rewrite —
accessors taking `protected var` instead of a value parameter (ADR-0318),
assignments becoming `take`, `p := nil` becoming `dispose` — and their remaining
diagnostics are all of that kind rather than about the type.

**The two that stay refused are `JsonPtr` and `JsonChars`**, and for the other
half of 6.4.14.2: `JsonNode` is a tagged union, so its child pointers are fields
of a variant part. That restriction is untouched here and is harder — the arms
share storage and there is no answer to which arm's pointer to release without
reading the tag, which nothing obliges a program to have set.

**`ADR-0318` and this record are the two halves of one unblocking**, and neither
is sufficient alone: the value-parameter rule and the schema-domain rule both
had to go for a growable container to own its storage. That the roadmap row
credited the first with the whole job is why this one was found by probing
rather than by reading it.

**The library is not converted here.** That is a change to `lib/pasvector.pas`,
`lib/pasmap.pas` and `lib/passtrvec.pas` and to every caller of them, and it
belongs in its own increment.

## What this does not do

**It does not remove the walk's problem, it avoids it.** A schema-produced type
holding a file still cannot be owned, and the reason is still that the release
has no descriptor to read an extent from. Closing *that* means putting the
discriminants somewhere the release can reach — which the tuple header already
is, so it is a matter of teaching `WalkFiles` to read from it rather than from a
frame. Nothing has asked, and ADR-0116's rule applies.

**It does not touch the variant-part restriction**, which is what now blocks
`PasJson`.

**It does not change `dispose`, `new` or `take`**, which handled a tuple header
already; the only emitter change is that the *release routine* now does what
`dispose` always did.

## Alternatives rejected

**Leave the restriction alone and convert the containers to a fixed capacity.**
That is what refusing a schema domain amounts to, and §6.4.7 is the reason the
containers are on the heap at all: a schema fixes its extent at the declaration,
so growth needs `new(p, d)`. Refusing the domain refuses growable containers,
which is most of `lib/`.

**Read the extents from the tuple header in the release walk**, closing the
restriction entirely rather than narrowing it. It is the more general answer and
it is more work — `WalkFiles` takes its bounds from the frame descriptor, and
a second source for them is a second way for them to be wrong. Narrowing first
costs nothing that the general answer would later have to undo: the condition
would simply become vacuous.

**Refuse only where the produced type holds a *file*, admitting handles and
owned pointers.** They are one list for one reason (ADR-0181's `IsAffine`), and
each needs the same walk. Splitting them would be three conditions where the
release has one.
