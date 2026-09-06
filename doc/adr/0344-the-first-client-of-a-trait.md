# ADR-0344: The first client of a trait

Date: 2026-09-06

## Status

Accepted. Adds `lib/dialect/passortx.pas` and one diagnostic to
`CheckTraitDecl`, and amends AP 6.7.9. ADR-0338 to ADR-0341 are not
superseded; this is the client they were building toward, and ADR-0341's claim
about separate translation is exercised here by a module rather than by a
probe.

## Context

Traits landed on 2026-09-06 with a corpus of cases that declare a trait,
implement it, and select an implementation. What no program in this tree did
was **use one to get work done**, and `doc/sop.md` §4a says that is the step
that finds things: a construct with a surface needs a client written where a
program would write it, and the library for a feature is part of that
feature's work rather than a tidying-up afterwards.

`lib/passort.pas` was the obvious client, and it named itself. Its header
opened by saying that "this compiler has no way to write one over an arbitrary
element type", which was true when it was written and had stopped being true
four days earlier. `SortIndexed` answers by taking the caller's `less(i, j)`
and `swap(i, j)` and never seeing an element, and the roadmap's *Traits /
protocols* row had said since 2026-09-03 that its successor could be written
over the element itself.

Writing it took under an hour and found two things, one in the compiler.

## Decision

**`lib/dialect/passortx.pas` is the successor and `lib/passort.pas` stays.**
It exports the trait `Sortable` — one routine, `Before`, a strict weak order —
and `Sort`, `SortWith`, `IsSorted` and `LowerBoundOf` over an `array of T`.
The trait is declared in the module and **every implementation is the
client's**, which is not a limitation but the only shape §6.13 admits
(ADR-0341): a client translates against the interface alone, so an
implementation in this module's block would be invisible to every importer,
and these routines reach the client's because AP 6.7.3.5 re-reads a generic's
body in the translation that activates it.

`PasSort` is not deprecated and not rewritten. It is conforming Extended
Pascal where this module is dialect-only, and `SortIndexed` still answers a
question the generic one does not — a caller sorting several parallel arrays
at once, or a file read into a buffer, has no single element to compare. Its
header is corrected to say which of its sentences the dialect has overtaken.

**`SortWith` stands beside `Sort`, taking the order as a procedural
parameter.** AP 6.7.10 gives a type at most one implementation of a trait per
program-component, so the trait fixes *the* order of a type and a caller
wanting another — descending, or by a second field — has nowhere to put it.
`SortWith` also serves a type that implements nothing. That is `PasSort`'s
bargain kept for the cases that need it, and it is why the module has two
entry points rather than one.

**A trait may not be named `numeric`, `ordinal`, `ordered` or `equatable`**
(AP 6.7.9, and the NOTE that now says why). AP 6.7.3.10.5 identifies those
four spellings in a bound position by spelling alone and looks nothing up
there; AP 6.7.9 makes a bound the only position a trait may stand in. So a
trait of one of those names is a declaration that can never be applied. The
check asks `CatOfName` rather than writing the four spellings a second time,
so a fifth category cannot be admitted in one place and refused in the other.

## Consequences

**The feature works, and this is the first evidence of it that is not a
test.** Four records preceded one working feature and each said why the
previous was wrong; a module a program would actually import is the rung above
the one ADR-0341 stood on.

**The refusal was found by falling into it.** The first trait written for this
module was named `Ordered`, because that is what the concept is called. It
declared, it implemented for two types, and the call reported that a record
was not admitted by a category admitting "any ordinal type, and int64, real, a
string-type and utf8" — a message about a category the program had not
written, at a position it had no reason to look at. Nothing in the tree could
have found this: every trait in every case here is named `Sortable`, `Ord`,
`Key` or `Shown`.

**A second collision is documented rather than refused.** §6.1.2 folds case, so
a local named `t` in a generic whose type parameter is `T` **is** the type
parameter, and the next denoter naming `T` resolves to a variable — reported
as `unknown type 't'`, which is true and is not what a reader is looking for.
This is ADR-0340's `self`/`Self` collision met a second time, one scope
further in, and it is left alone: `unknown type` is the message every
not-a-type name gets, the rule is §6.1.2's rather than this feature's, and a
special case for one letter would be a rule about spelling. `passortx.pas`
names its temporaries `top` and `u`, and says why at the declaration.

**One module is not thirty.** ADR-0315's staging asked for one library module
rewritten as proof before any judgement about the others, and that was said of
increment A. This is increment B's version of the same test and it is a *new*
module rather than a rewrite, `PasSort` having a reason to stay. What the
other thirty need is still unmeasured.

## What this does not do

**It does not give `PasContainer`'s map a `Key` trait.** That is the larger
payoff — a client writing one `impl Key for MapKey` removes `StrHash, StrEq`
from thirty call sites — and it is a change to a module every corpus case
imports, where this one is additive. It stays where the roadmap has it.

**It does not fix the diagnostic for a name that is not a type.** See above.

**It does not measure anything.** Heapsort here is heapsort there, and no
claim is made that the generic form is faster or slower than
`PasSort.SortInts`; the module exists because the call is `Sort(a)` and not
because of a number.

## Alternatives rejected

**Add the generic sort to `lib/passort.pas`.** It is the module the feature is
about, and putting it there would end that module's portability to a
conforming Extended Pascal processor — which is the one property distinguishing
`lib/` from `lib/dialect/`. The `x` suffix is `pasmathx`'s, and it already
means exactly this.

**Export `Before` from the module.** A trait's routine names have no
defining-point in the block containing the trait (AP 6.7.9.2), so there is
nothing to export; a client writes the name inside its `impl` and reaches it
through the trait-keyed selection. Discovering that the export-part did not
need it is what confirmed the reading.

**Refuse a local whose spelling folds to a type parameter's.** It would catch
the second collision, and it would also refuse a program that shadows a type
name deliberately, which §6.1.3 and §6.2.2 both allow anywhere else. The rule
would be about this feature and the collision is about §6.1.2.

**Give the trait a three-way `Rank` rather than `Before`.** `Rank` returning
an integer says more — it gives equality for free — and it invites
`p.x - q.x`, which traps on overflow for two integers far apart (ADR-0014).
`PasSort`'s own contract is a `less`, and a strict weak order is what a sort
needs.
