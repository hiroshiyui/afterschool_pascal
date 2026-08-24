# 181. An owned pointer gives a created variable an owner

Date: 2026-08-24

## Status

Accepted. AP 6.4.14.

## Context

ADR-0151 divided ADR-0109's memory-safety goal into two halves and reported
the first one finished. *Lifetime* — "an owned value is released when the
variable holding it dies, and cannot be copied out of that variable" — was
found already implemented, having arrived from ISO 7185 §6.4.6 a) and §6.6.3.1
by way of the file variable in 1982. *Aliasing* was left open with a criterion
rather than a mood: it becomes decidable at the first construct admitting two
live names for one owned value, and concurrency is the construct that certainly
forces it.

The roadmap has said since that the lifetime half is done. **It is not, and
the sentence that says so is what hid the hole**: it quantifies over "the
variable holding it", and a variable created by `new` is held by nothing.

    type Stream = handle external 'fclose';
         Box = record s: Stream end;
    var b: ^Box;
    ...
    new(b);  b^.s := ExtFopen('/tmp/x', 'w');   { and no dispose }

AP 6.4.12.3 releases a handle at the first of "termination of the activation in
which the variable exists", `dispose` of a variable containing it, and
reassignment. A heap variable exists in **no activation**, so the first reaches
nothing of it; the second is what the program forgot; the third never happens.
Both halves of the mechanism are built and correct — `new` emits
`pas_handle_init` for every handle in the domain, `dispose` emits
`pas_handle_done` for every one — and between them there is nothing that makes
`dispose` happen.

Measured rather than argued: under `ulimit -n 64`, a loop allocating one such
record per iteration reports `fopen answered empty at iteration 62`. The same
hole with a plain `text` in the heap record compiles, runs, exits 0 and never
closes the `struct pas_file`. No document here recorded it — not
`doc/sop.md` §7, not Annex C, not the roadmap's own entry on the subject.

The shape of the fix is visible in the shape of the defect. The reason the 1982
model worked is that every file variable is *declared*, so it has exactly one
scope that ends. A heap variable has no scope, therefore no owner, therefore no
release. To give it one, give it an owner.

## Decision

**`owned ^T` is a pointer-type whose variable owns the variable it identifies.**
The identified variable is disposed, and everything owned within it released,
when the pointer's own variable ceases to exist; the pointer cannot be copied.

Five things follow, and the first is why this was available at all.

**It decides nothing about aliasing.** An owned pointer admits no second live
name — it cannot be copied at all — so ADR-0151's criterion is not met and the
fork stays open. This is ADR-0174's move a second time: extend the lifetime
half, decline the aliasing question, and let the construct that forces it be
the one that forces it.

**It is a flag on `tyPointer`, not a type kind.** `isText` and `setCanonical`
are the precedent: what changes is the ownership, and nothing about the
pointer. Every rule about a pointer — the domain is a type-identifier so a type
may name itself, `nil`, the dereference — is a rule about this one, and reusing
the kind is what makes that true by construction rather than by 54 case-arms
being edited. `kind-exhaustive` therefore has nothing new to read.

**The refusals arrive through `ContainsFile`.** `IsAffine` is `IsOwned` plus
`IsOwnedPointer`, and `ContainsFile`/`HoldsFile` ask it; §6.4.6 a) then refuses
assignment, comparison, value parameters, function results and a fallible
side without a call site being touched — the handle's own route (ADR-0174), and
`predicate-callers` sweeps the positions. What `IsOwned` keeps to itself is
`IsMemory`, because an owned pointer's *value* is still one word and goes on
being loaded and stored the way every pointer is. Two questions were one name
until this record: ownership and representation.

**Release is a generated function per domain type.** A type may own a variable
of its own type, so the depth is the program's and not the translation's, and
straight-line code at the release point cannot express it. `@ownrelN` takes the
pointer value, returns on `nil`, walks the variable with the same `WalkFiles`
the block epilogue uses, and disposes it. Bodies are emitted from a worklist
after the last user function — the emitter is sequential and a definition
cannot nest inside the one that calls it — and the number is handed out at the
first *call*, which is what lets the body contain a call to itself.

**`new` is a release point.** Without it a second `new` over one variable
abandons the first, which is the leak this type exists to close; it was, at
iteration 62 of the same probe. This is 6.4.12.2's assignment rule for the
handle, arrived at for the same reason.

**Spelled by juxtaposition, reserving nothing.** A type-denoter is complete
after a type-identifier, so `^` following one is a syntax error in both
conformance modes; `owned ^T` is therefore a position no conforming program
could have written, which is ADR-0140's test — `array of`'s shape (ADR-0125)
and `handle external`'s (ADR-0174), not the required-identifier shape of
`int64`, `argcount`, `exit` and `try`. `tests/dialect/owned.pas` declares a
type *named* `owned` and uses it, in the same program.

## Consequences

A list, a tree or a chain is owned by its root and released by leaving the
block, and the traversal is a recursive procedure taking `var`: a loop
assigning a second pointer is a copy and is refused. That is Rust's `Box`
reached from the file variable, and it is the honest cost of not deciding
aliasing — there are no references, so there is no iterative traversal.

A long enough list exhausts the stack on release, as it would on any recursive
traversal. AP 6.4.14 NOTE 2 says so.

The `foreign-reserved` gate failed on first run, which is ADR-0144's mechanism
working: `@ownrelN` is a global the emitter names, and a program binding that
foreign name would make LLVM refuse a module about a file nobody wrote. The
bare spelling `ownrel` is reserved as well as the numbered ones, where `frame`
is not, because the call is written as a literal `@ownrel` and a counter and
that literal is what the gate harvests.

`src/` needs nothing. The refusal under a conformance mode is the parser's
existing "expected ';' … found '^'", which the reference front end already
says — unlike ADR-0121's `external`, where a directive is an ordinary
identifier and only a rule about the mode could refuse it. `difftest` passed
unchanged.

## What this does not do

**A non-local `goto` out of the activation leaks the storage.** Every file and
handle inside the owned variable is still released — those are registered with
the runtime individually when the variable was created, and the runtime's own
unwind walks them — but the `malloc`ed block is not given back. Closing that
would mean a fourth runtime registry and a per-block runner, which is
ADR-0175's shape and was declined for now: what is abandoned is memory and not
a resource, and `halt` has the same gap with the process about to exit anyway.
It is a row in `doc/sop.md` §7.

**The domain may not be a schema.** Releasing means walking, and a
schema-produced type's lengths are discriminants read from a descriptor a
*frame* holds; the tuple header a heap variable carries is stepped back over by
`dispose` and read by nothing else. A release that walked a guessed length is
worse than a refusal.

**It is not a field of a variant part.** Two arms share one slot and there is
no answer to which arm's pointer is to be disposed. ADR-0118 makes the tag
authoritative and so could answer it, but `WalkFiles` does not walk a variant
part at all.

**It does not touch §6.4.4.** An ordinary pointer is unchanged, and
use-after-dispose through a second one stays undetected, which is ADR-0019 and
a known limitation. This record adds a type; it withdraws nothing.

**It closes no aliasing question**, and the roadmap entry that said the
lifetime half was finished is corrected rather than confirmed: it is finished
*now*, for declared and created variables both.

## Alternatives rejected

**A runtime type descriptor walked by `pasrt.c`.** Emit a static description of
each type — offsets and kinds — and let C recurse over it. Less emitter work,
and rejected because it introduces a *second* description of layout that must
agree with `LlSize`/`LlAlign`. This repository has twice been bitten by a copy
free to drift (`PAS_FILE_SIZE`/`fileSize`, and what `target-layout` exists to
watch), and a descriptor would be a third.

**A fat slot, the handle's shape.** Make the slot a `struct pas_own` with the
value, the release routine and list links, registered like a handle so the
runtime's unwind releases it. This buys the non-local `goto` case and costs
making an owned pointer `IsMemory`: 32 bytes per pointer, a load through
`->value` at every dereference, and a carve-out at each site that already has
one for the handle. Declined for the size of the interface change against the
size of what it buys — a memory leak on a construct a program uses to leave a
block early.

**Release at program termination only**, by registering every allocation and
walking the list at exit. It closes the exit case and not the one the probe
measured: the 62nd descriptor was exhausted mid-run, and a program that drops
its last pointer holds the resource until it ends. It also decides nothing,
which is the wrong shape for a record.

**A borrow — reading an owned pointer as a plain `^T`.** It would give the
iterative traversal back and it is exactly the aliasing question, which is
undecidable on the evidence in hand (ADR-0151). Left refused, which is what
makes this feature available before that fork is taken.
