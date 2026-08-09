# 19. Pointers, and the language's only forward reference

Date: 2026-08-09

## Status

Accepted

## Context

Item 4 of ADR-0004's dependency list. The AST of a self-hosted compiler is a
heap-allocated tree, and until now `tests/variants.pas` had to fake one with an
array of nodes and integer indices. What was missing is not the pointer itself
but the *recursive type*: a record cannot contain a pointer to its own type if
every type identifier must be defined before it is used.

ISO 7185 §6.4.4 answers this directly. A pointer's domain is written as a type
*identifier*, not as a type-denoter, and that identifier may be one defined
later in the same type-definition-part. It is the only forward reference in the
language, and it exists for exactly this reason.

The other question is what a pointer costs at run time. ADR-0014 committed to
trapping on ISO's error conditions, and §6.5.4 makes dereferencing `nil` an
error. Dereferencing a pointer whose storage has been disposed of is *also* an
error by the standard, and that one cannot be detected without a garbage
collector or a full memory model.

## Decision

**The domain is resolved lazily, within the type part.** When `^T` names a type
that does not exist yet, the pointer type is created with a null domain and the
name recorded; at the end of the type part every pending domain is filled in,
and any that never arrived is reported there. Nothing outside `resolveType` and
one loop knows this happened.

**Every dereference is nil-checked**, and `dispose(p)` sets `p` to nil.

**`nil` has its own type** — a pointer with no domain — which is assignable to
and comparable with any pointer type, and which nothing else is assignable to.
Two named pointer types remain as distinct as any other named types, so
ADR-0017's name equivalence needed no exception.

**Pointers compare only with `=` and `<>`** (§6.7.2.5). There is no ordering: a
heap address is not a value the program may reason about beyond identity.

**`new(p, c1, ..., cn)` is rejected** with a diagnostic. This compiler always
allocates the whole record, which is safe but is not the feature §6.6.5.3
describes, and pretending otherwise would be worse than declining.

**No SMT rule was added for any of this**, and that is a decision rather than an
omission — see below.

## Consequences

Recursive types work, and `tests/pointers.pas` builds the same expression tree
`tests/variants.pas` builds, on the heap, with `new` and `dispose`. That is the
last structural thing the compiler's own source needed.

Because opaque pointers make every pointer the same LLVM type, a recursive
Pascal type needs no forward declaration in the IR at all. The laziness is
entirely a front-end concern.

Setting a disposed pointer to nil is stricter than the standard, which leaves
it undefined. It converts the common form of use-after-dispose — reusing the
variable that was disposed — into the nil trap. It does nothing for the general
form, where another pointer still refers to the same storage, and it should not
be read as a claim that it does.

**What is not verified.** The nil check is `p = nil`, and a rule stating "the
check fires exactly when the pointer is nil" would be the same sentence twice —
it would pass immediately, prove nothing, and make the catalogue's count look
better than the catalogue is. The verification catalogue is about *arithmetic
lowering*, where the compiler computes something and might compute it wrongly;
pointer safety is a different kind of property, and the honest tools for it are
the cross-check (a heap list built, walked, and released, compared at `-O0` and
`-O2`) and a run under AddressSanitizer with LeakSanitizer, which is how the
`new`/`dispose` pairing in `tests/pointers.pas` was actually confirmed —
verified against a deliberate leak to establish the detector was live.

So the catalogue still reads 29 rules and no known gaps, and that claim still
means what it meant before this change. Use-after-dispose through a second
pointer is undetected, and no proof in this repository says otherwise.

## Notes for the port

`Type` now has a kind whose field means something different from every other
kind's — a pointer's domain shares `elem` with an array's component type. That
is deliberate: `Type` is heading for a Pascal variant record, where sharing
storage between arms is what the construct is for, and ADR-0018 already built
the machinery.
