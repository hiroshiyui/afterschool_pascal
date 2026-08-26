# 209. A discriminant may name a type

Date: 2026-08-26

## Status

Accepted. AP 6.4.7.1.

## Context

`doc/roadmap.md`'s borrowings table has dismissed traits and generics in six
words for eleven records — *"Later. Schemata already give parametric types."*
The library contradicts it. `lib/passort.pas` says so in its own header:

> schemata parameterise a type by a *value* and not by another type
> (ADR-0039), so `list of T` cannot be said

and the consequence is on the shelf beside it. `PasVector` is a growable
sequence of **integers**; `PasStrVec` is a growable sequence of **strings**;
`PasList` is a sequence of **strings**; `PasMap` maps a short string to an
**integer**. Four modules, and the first two are one data structure written
twice. `PasSort` escapes the question by taking `less(i, j)` and `swap(i, j)`
and never seeing an element — which works, is documented as the answer to "no
generics here", and is the shape a caller is pushed into rather than one it
chose.

And a program wanting a container of **its own record type** has nothing at
all: it writes the array, the count and every operation again.

So the question is not whether the dialect wants generics. It is what the
smallest thing is that this compiler could mean by them.

## Decision

**A formal discriminant may be written `T: type`, and the corresponding
actual-discriminant is then a type-name.**

- **The spelling is a position, not a word** (ADR-0140). §6.4.7 requires an
  ordinal-type-**name** in a discriminant-specification, and `type` is a
  word-symbol of both standards — so no conforming program can have written it
  there. Nothing is reserved, and `reserved-words` goes on passing. The two
  conformance modes refuse it differently and Annex B records both: ISO 7185
  has no schema at all and stops at the formal-discriminant-part, where
  Extended Pascal parses the schema and stops at the word-symbol.

- **The tuple component is the type's own identity.** ADR-0039 interns a
  production by `(schema, tuple)` and a tuple component is an integer, so every
  type object now carries a `typeId` handed out by `NewType` and never reused.
  Equal ids are the same object, which is ADR-0017's name equivalence and not a
  structural comparison: two records written alike are two types, and
  `Vec(a, 4)` and `Vec(b, 4)` over them must be two productions. Everything
  6.4.8 rests on — "one tuple, one type", so `Assignable` needs no rule —
  carries over with nothing added.

- **The binding is a type-name for the duration of the body.** Where an ordinal
  discriminant is declared `skConst` with its value while `schemaBody` is
  resolved, a type-valued one is declared `skType` with the argument's type.
  That is the ordinal case's own sentence one kind over: it is what lets
  `array [1..cap] of T` reach the existing subrange and array code with nothing
  added to either.

- **The parser cannot tell the two actuals apart, and Sema can.** An
  actual-discriminant is an expression in the source whether it names a value
  or a type, so which was meant is decided by looking the name up — this
  repository's recurring answer for the sixth time (ADR-0044, ADR-0053,
  ADR-0066, ADR-0071, ADR-0087).

**A schema with a type-valued discriminant may not be a parameter-form**, and
this is stated in the clause rather than left to be discovered. A schematic
formal reads its discriminants from a descriptor the actual brings (ADR-0040),
which is what lets one compiled body serve every tuple; a type is not something
a descriptor can carry, the body's layout differing for each. A routine over
such a schema names the types it is over.

## Consequences

**This is half a feature, and the half it is not is the one the library
wanted.** `Vec(T, cap)` is now one schema instead of one record per element
type, and a program can hold a container of its own record — which it could not
before at all. What it cannot do is write `Push(var v: Vec; x: T)` once. The
four container modules therefore stay four, and NOTE 2 of the clause says so
rather than leaving a reader to find out.

**What the missing half would cost is now measured rather than guessed.** A
routine generic in `T` must be translated once per `T`, which needs a distinct
symbol, frame and emitted function per instantiation, and a cache keyed the way
productions already are. The mechanism that looked prohibitive turns out not to
be the distribution: **separate translation here is already source-based** —
`--import` re-parses each component in full and keeps only its module-headings
— so a generic body is already in memory in the client, and nothing like a
header format or an object-file template section is needed. What is missing is
instantiation, not delivery. That is the next increment and it is a large one.

**It found a latent defect on the way in.** `GenericFromSchema` assigns its
result in two branches and had a third that assigned nothing — reached only
after an error had already been reported, so it returned whatever the result
slot held and the first caller to print that type stopped the compiler on a
case-statement with no matching label. A type-valued discriminant added a fourth
such branch and fell into it. The fix is one assignment at the top; the reason
to record it is that the defect was **unreachable by any correct program**, and
so invisible to every oracle here except a probe of a new error path.

**`typeId` is a second identity for a type and must not become a first.**
Nothing compares types by it — `Assignable` still compares pointers — and it
exists so that a tuple, which is a list of integers, can name one. If something
starts asking whether two ids are equal where it means "the same type", the two
answers will agree until the day a type is copied (`CopyType` makes a new
object, and correctly a new id).
