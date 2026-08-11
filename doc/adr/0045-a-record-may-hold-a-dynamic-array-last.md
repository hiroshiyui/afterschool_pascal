# 45. A record may hold a dynamically bounded array, last

Date: 2026-08-11

## Status

Accepted. It is ADR-0040's second half: a schematic formal whose discriminants
reach past an array.

## Context

ADR-0040 gave a schematic formal a descriptor and then said what a descriptor
could describe: an array, and arrays inside it, and nothing else. The reason
given was that "a record field after a dynamically-bounded one would sit at an
offset nothing can compute" — which is true of a field *after* one, and was
applied to every field.

ISO/IEC 10206:1991 §6.4.7 places no such restriction: a schema body is a
type-denoter and a discriminant may appear anywhere in it. The restriction is
this compiler's, and the shape it most obviously excludes is the one the
standard's own required schema has (§6.4.3.3.3): a length beside a buffer whose
capacity is the discriminant. Nothing else about `string` can be attempted
while a record cannot hold a dynamically bounded array at all.

## Decision

**A record may hold a dynamically bounded array as its last field, and only as
its last.** Recursively: the tail may itself be such a record, and such a record
may be the component of a dynamically bounded array.

The rule is not "the last field" out of taste. It is the exact boundary of the
sentence ADR-0040 wrote: *every offset inside the type must stay a constant
while the type's size need not.* A field after a dynamically-sized one has an
offset that is not a constant; there is no field after the last one. So the
record's layout is entirely static and only its **size** is dynamic — which is
the property `dynSize` was already written to express, for arrays.

Three things follow, and each is the reason the change is as small as it is.

**LLVM already had the representation.** ADR-0040 lowers a dynamically bounded
array to `[0 x T]`, because the bounds are folded into the index arithmetic and
nothing asks the type for an extent. A struct whose last member is `[0 x T]` is
C's flexible array member: `getStructLayout` gives the right offset for every
field, `getABITypeAlign` gives the right alignment, and **`fieldAddress` is
untouched** — `s.len` is the same `getelementptr` it always was. No byte
arithmetic was introduced anywhere.

**`dynamicExtent()` reads the last field and not "any field".** That is the
whole of the type-side change, and the asymmetry is deliberate: a record with a
dynamic field somewhere else is not a type with a dynamic extent, it is a type
that is *refused*. Writing the predicate over all fields would make it describe
a type this compiler never builds.

**The size is rounded up to the record's alignment.** A static record's
allocation size already is, and an array of these strides by it — so a
component of 4 + cap content bytes at 4-byte alignment must stride 12 for
cap = 5, not 9. This is the one piece of arithmetic that is new rather than
reused.

**Two positions are refused, and the second needs saying.** A field after the
dynamic one, which is the rule itself; and a **variant part**, because its
shared block is laid out after the fixed fields and so sits at exactly the
offset that cannot be computed. The variant-part clause is separate from the
field clause and not implied by it: a *tag-field* is an ordinary field and lands
after the dynamic one, so `case k: T of` is already refused by the field rule —
but a **tagless** `case T of` contributes no field at all, and without its own
clause it would be accepted and laid out wrongly.

## Consequences

**The check is one predicate, stated once.** `dynamicTail` replaces ADR-0040's
"walk down the array spine, then ask `staticThroughout`" with a recursion that
says what it means: a type qualifies when its size may depend on the
discriminants and none of its offsets do. The diagnostic changed with it, and
now names the position rather than only the shape.

**CodeGen gained a case in two places and nothing else** — `dynSize`, which
computes the last field's constant offset plus the tail, and
`checkSchemaDomain`, which descends into the tail exactly as it descends into a
component. §6.4.7 NOTE 2's empty-range check therefore reaches an array nested
inside a record with no new machinery.

**Everything a schematic type could already do, it can do here.** Assignment
compares the tuples and copies `dynSize` bytes (ADR-0042); `new` puts the tuple
in a header and sizes the block from it (ADR-0043); a discriminant evaluated on
block entry sizes an `alloca` (ADR-0041). None of those needed a case for
records — they were all written in terms of `dynSize`, and this record only
taught `dynSize` a new shape. The string operations of §6.7.2.5 reach the tail
too, because a `packed array [1..cap] of char` is a string type wherever it
sits.

**Fifteen mutations across both compilers, all caught, and one equivalent.**
The equivalent one is `dynamicExtent` answering for any field rather than the
last: every record it newly admits is refused by `dynamicTail` before codegen
sees it, so no program distinguishes them — recorded here so the next reader
does not go looking for a test.

Two of the fifteen needed cases the corpus did not have, and both are the same
kind of gap: a record with **two** dynamic fields (a static field after a
dynamic one already fails the "is the last field dynamic" question, so the rule
about the fields before it was never reached), and a record with a **tagless**
variant part (the tagged one is refused by the field rule, as above). Each was
written after the mutation escaped, not before.

**No proof rule**, for the third record running: `verify/`'s array rules
quantify over their bounds, so a bound reached through a record's tail is
already inside what they say. The layout arithmetic is checked by running —
`tests/extended/schema_record.pas` writes every row of a dynamically strided
array before reading any of them, so a stride one byte short is a wrong answer
rather than a lucky one.

## What this does not do

**A record's dynamic part must still be last.** ISO 7185 has no constraint of
the kind, so this remains an implementation restriction and is stated as one.
Lifting it means computing field offsets at run time, which means a record with
no LLVM struct type and byte arithmetic at every field access — a different
decision, and one that would reach code this record leaves alone.

The required schema **`string`** is now expressible but not *required*: §6.4.3.3
gives it its own type-class with a capacity, an assignment that truncates, and
the operators of §6.7.2.5 defined over unequal lengths. Being able to write the
shape by hand is what this record delivers; the type is its own feature.
