# 213. A pointer domain may bind type discriminants

Date: 2026-08-26

## Status

Accepted. AP 6.4.4.1, AP 6.4.4.2.

## Context

This was found by trying to do the library work the three generics records
were for, and failing at it in a specific place.

ADR-0209, ADR-0211 and ADR-0212 between them let a container's storage, the
routines over it, and both across `--import` be written once. So collapsing
`PasVector`, `PasStrVec`, `PasList` and `PasMap` into one generic module was
attempted. **It got two of the four**, and the boundary it hit is what this
record is about.

What worked: a **generic owned chain**, completely — growth there is one `new`
per node, no tuple is involved, and one body serves `integer` and a record
alike. And a **fixed-capacity vector**, with the client naming the production
and passing the *pointer* type as the type argument.

What did not: **growth on the heap**, which `PasVector`, `PasStrVec` and
`PasMap` all do. `VecReserve` and `Rehash` are `new(p, cap)` with a fresh
capacity, and that needs a pointer whose domain is the schema. Three spellings
were probed and all three refused:

- `^Vec` — ADR-0209 refuses a bare domain of a schema with a type
  discriminant, and its message advises *naming the types it was produced
  with*, a spelling that did not then exist;
- `^Vec(integer, 8)` — not grammatical: ISO/IEC 10206:1991 6.4.4 makes a
  domain-type a type-name or a schema-name and admits nothing after either;
- `IntVec(cap) = Vec(integer, cap)` — a schema's actual discriminants must be
  ordinal **constants**, so a schema cannot be defined as a partial
  application of another.

So a generic routine could reach a container of fixed capacity and no other.

## Decision

**A pointer domain may name a schema's type discriminants and leave its
ordinal ones open**: `^Vec(integer)`, with `new(p, 8)` supplying the rest.

    domain-type = type-name | schema-name [ '(' type-name { ',' type-name } ')' ] .

**The split is not arbitrary and is the whole idea.** What the type
discriminants decide is the identified variable's **layout**, which a
pointer-type must know. What the ordinal ones decide is its **extent**, which
`new` may vary from one created variable to the next. `^Vec(integer)` is
therefore exactly what `^IntVec` already is, with the element type chosen —
and a routine over it may create, copy and dispose variables of every
capacity for whichever type the domain named.

### It is a derived schema, not a new mechanism

`BoundSchema` interns one schema symbol per `(schema, tuple of type-ids)`,
whose `discs` are the ordinal discriminants **and nothing else** and whose
body is the original's syntax, with the type bindings carried alongside in
`boundTypes` and installed by `BindBoundTypes` before the body is resolved.

`BindBoundTypes` has **one** call site, in `GenericFromSchema`, and that is a
fact worth stating because a second one was written first and removed. A
derived schema is made only by `BoundSchema`, reached only from a pointer
domain, which reaches the body only through `HeapFromSchema` — and that builds
*one* generic type per schema whose discriminants are read from each object's
own header (ADR-0043), so there is no per-tuple production for
`ProduceFromSchema` to see. The second call did nothing for an ordinary schema
(`boundTypes` is nil) and was unreachable for a derived one; the whole suite
passed without it, which is how it was found rather than argued away.

Everything downstream then sees an ordinary schema. `SchemaHasTypeDisc` is
false of it, so every refusal that reads that is quiet; `HeapFromSchema`,
`new(p, cap)`, the heap header, the descriptor and the whole of ADR-0043 are
reached **unchanged**. That is the argument for deriving a schema rather than
teaching each of those about type discriminants: one new routine and two
one-line calls, against a change at every site that asks what a schema's
discriminants are.

The tuple is ADR-0209's `typeId` for the third time, and it is interned for
ADR-0039's reason: two domains naming the same schema with the same types must
produce one type.

### 6.4.1 is untouched

Two variables declared `^Vec(integer)` separately have two types, exactly as
two declared `^integer` separately do — each type-denoter that is not a
type-name denotes its own type. The interning is of the **derived schema**,
not of the pointer-type, and the distinction is what AP 6.4.4.2 says out loud
because the two look alike from a program.

### The spelling

A parenthesis after a domain name, which 6.4.4 admits nothing after — so it is
ADR-0140's test asked where a *domain-type* ends rather than where a statement
does. Nothing is reserved. Both conformance modes stop at the parenthesis and
name the mode (ADR-0154), and `src/` carries that refusal (ADR-0121).

## Consequences

`tests/dialect/pointer_typedisc.pas` pushes six elements into a capacity of
two, so it must grow twice, and grows a vector of records with the same
routine. `pointer_typedisc_errors.pas` carries four refusals including a
schema of *two* type discriminants named with one.

**ADR-0209's refusal comment was stale and is corrected.** It justified itself
partly by saying per-tuple translation "is a mechanism this compiler does not
have, and a large one" — which ADR-0211 built and ADR-0212 carried across
6.13. What is left of that reason is the clause-level half, which is still
sound and is now all it claims: a schematic formal reads a tuple that
*arrives*, and no amount of translating per tuple changes what a descriptor
can hold. A pointer domain is the one of the three nouns with a way out,
because its tuple is 6.7.5.3's rather than an actual's.

**The four modules can now be one**, which is library work and is not done
here. `doc/roadmap.md` carries it.

**What this does not do.** A schema may still not be *defined* as a partial
application of another (`IntVec(cap) = Vec(integer, cap)`), and a schematic
formal may still not name a type-discriminant schema. Both were probed here
and neither is needed for the container: the first is sugar for what
`^Vec(integer)` now expresses, and the second is refused for a reason that
does not change.
