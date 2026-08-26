# 211. A routine may be parameterised by a type

Date: 2026-08-26

## Status

Accepted. AP 6.7.3.10.

## Context

ADR-0209 let a **schema** be parameterised by a type, and closed by naming
what it did not do:

> A schema with a type discriminant may **not** be a parameter-form and says
> so: a schematic formal reads its discriminants from a descriptor at run time
> (ADR-0040) and a type is not something a descriptor can carry, so a routine
> generic in `T` would have to be translated once per `T` — which is the next
> increment and not this one.

So a container's *storage* could be written once and every routine over it
still had to be written per element type. `PasVector` holds integers,
`PasStrVec` strings, `PasList` strings, `PasMap` maps a string to an integer,
and the way to have one for another type is to copy the file — the standing
argument in `doc/roadmap.md` and the reason those four modules are four.

Two things were established by probe before anything was designed, and both
changed the plan.

**The spelling was already decided by the language.** `T: type` in a
formal-parameter-list is not free space: 6.7.3.1 admits `type` there as the
first word-symbol of 6.4.8's type-inquiry, `x: type of v`. But a type-inquiry
is `type` followed by `of` and nothing else, so `type` followed by anything
else is a juxtaposition no conforming program can write. One token of
lookahead, which is ADR-0140's test asked of a *parameter-form* rather than of
a statement — and it is the same spelling ADR-0209 gave a discriminant, in the
other place where a type can be a parameter.

**And the mechanism was already built, twice.** A generic routine's block
cannot be checked where it is written, because its types are not known there,
and cannot be checked where it is *called*, because every name in it would
resolve against the caller. What it needs is to be checked later, in the region
it was written in — which is exactly what ADR-0053 built for a module:
`CheckModuleHeading` saves `scopeTop` and `scopeDepth` into the module record
and `CheckModuleBlock` restores them. The second half is ADR-0039's: a schema
keeps its *syntax* and not a type, re-resolved once per distinct tuple, interned
so two tuples that are equal produce one thing.

## Decision

**A formal-parameter-section may be a type-parameter-specification, and a
routine that has one is translated once per distinct tuple of type
arguments.**

    procedure Swap(T: type; var a, b: T);
    ...
    Swap(integer, i, j);
    Swap(Point, u, v);

### The body is re-parsed, not copied

An instantiation needs its own tree, because Sema annotates nodes in place and
two instantiations would otherwise overwrite each other's answers. The two ways
to get one are to copy the tree the declaration parsed or to parse the tokens
again.

**Re-parsing, and the reason is this repository's own recurring one.** A copy
walker is a second statement of every node's shape — sixty-odd kinds, each with
its fields — and it can name every kind correctly and still copy the wrong
field of one, silently, with `kind-exhaustive` satisfied and no other gate
looking. That is the argument ADR-0206 made about `pas_handle_release_result`
("the same three lines, not a second copy beside the first, because a copy is
free to drift"), and it applies with more force here because the thing being
copied is bigger. Parsing the same tokens a second time cannot disagree with
parsing, because it is parsing.

`pos` is a cursor into a token array that is never cleared, so the cost is one
integer on the declaration node. What it does **not** reach is a generic in a
component read by `--import`, whose tokens the import loop discards — see
*What this does not do*.

### The heading is not re-parsed, and is forgotten instead

The instantiation shares the generic's parameter nodes and calls
`ForgetResolved` over them first. Without it the second instantiation reads the
first one's cached types and `var a: T` is whatever T was last time — which is
what the probe did, giving *cannot assign integer to a variable of type point*
inside a body that names neither.

Asymmetric on purpose: forgetting is what a schema already does to its body per
tuple, it is cheap, and a heading has no statements whose annotations could
disagree. The body gets the stronger treatment because it is where the risk is.

### The heading rule is shared and not repeated

`InstantiateHeading` is the half of `DeclareProcHeading` that resolves the
result type and builds the formals, split out so the declaration and every
instantiation run the same code. Writing it twice was the alternative and is
the failure mode this record is otherwise built to avoid: a program would be
checked against one copy and translated from the other.

### An instantiation is an ordinary procedure-declaration

It is appended to the procedure-part of the block the generic was declared in,
so `DeclareProcs` gives it a frame type and `EmitProcs` emits it without either
being told that generics exist. `CheckDeclarations` skips a node whose symbol
carries a `genOf`, since it is already declared and its body already checked.

The cache is keyed by the tuple of type-ids, ADR-0209's `typeId` reused, and
the entry is registered **before** the body is read — without which a recursive
generic instantiates until the heap runs out.

### The generic itself is nothing

No formals, no result type, no frame, no emitted body, and its block is never
checked. A generic activated by nothing is never subjected to the requirements
of the specification at all, which AP 6.7.3.10.2 NOTE 3 says outright and a
scenario pins with a body that names a field of a record that has none.

Two places had to learn that a name can denote a generic. Inside a generic
function's body its own name is still bound to the generic — a recursive call
has to reach something generic to name its types to — so 6.8.2.2's containment
test treats an instantiation as its generic, and the function whose result is
assigned is the instantiation, which is where the result variable lives.

## Consequences

`tests/dialect/generic_routine.pas` is one body over `integer` and over a
record, a generic function, a recursive one, and AP 6.4.7.1 and 6.7.3.10
composed: `Vec(T, cap)` written once and `Push(T: type; …)` over it written
once. `generic_errors.pas` carries six refusals in one run.

**The conformance modes say different things, and both are right.** Under
`--std=extended` the mode is named, which is ADR-0154's requirement and is
carried by `src/` as ADR-0121 requires. Under `--std=iso7185` the answer is *a
type-inquiry is an Extended Pascal feature* — one step earlier, because `type`
is not a parameter-form in that standard at all. Annex B records both, which is
the same shape ADR-0160 found for `a[i..j]`.

**What this does not do.**

- **A generic in an imported component cannot be instantiated.** `--import`
  re-parses a component's full source and then clears the token array, so a
  generic declared in `lib/` has a saved token position pointing at tokens that
  are gone. Retaining them is a small change — the string pool already survives
  the import, and a module is about 1250 tokens against a capacity of 300000 —
  but it makes a fixed buffer hold every source in the translation rather than
  one, and that is a decision about a documented limit rather than a detail.
  Until it is taken, **the library cannot use this**, which is the caller the
  feature was built for: `doc/roadmap.md` carries the row.
- **No inference.** The types are written at the call. Inferring them from the
  value arguments is a separate feature with a separate question — what happens
  when two arguments imply different types — and nothing here needs it yet.
- **No constraints.** A generic body that adds its `T` values compiles for the
  types that can be added and is refused, at the instantiation, for those that
  cannot. The diagnostic names the generic's line, which is where the program
  is wrong, but nothing says which call asked for it (`doc/sop.md` §7).
