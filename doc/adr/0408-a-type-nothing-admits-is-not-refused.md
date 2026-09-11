# ADR-0408: A type nothing admits is not refused

## Status

Accepted. Increment C1 of [ADR-0315](0315-methods-and-traits-without-inheritance.md),
whose staging table this splits: the trait object's **type** lands here and its
**value** does not.

## Context

ADR-0315 proposed `dyn T`, the trait object, as increment C. Probing it before
building found three things that record does not have, and one of them moved
the design.

**A routine can be passed and cannot be kept.** This language has §6.7.3.1's
procedural *parameter* and no procedural *type*: `type F = function (x:
integer): integer;` is `error: expected a type, found 'function'`, and so is a
procedural field. So a vtable cannot be built by hand at all, and a
heterogeneous collection has no representation except a **closed** variant
record — which requires every type to be named where the collection's type is
declared, so a library can never offer the facility to a program's own types.
That is a sharper argument for the feature than ADR-0315's own, and it is the
one that passes ADR-0109's test: a program someone would write cannot be
written.

**The container half is already here**, which the same probes settled:
`array [1..3] of owned ^Node` compiles and `Vec(owned ^T, n)` takes an owned
pointer as a type actual. So `dyn` is the only missing piece.

**And the release is not what ADR-0315 says it is.** That record says *the
existing owned-pointer machinery answers every question about* `owned ^dyn T`.
It does not: release is a per-type `@ownrelN` chosen at translation time from
the pointed-to type — a record owning another emits `@ownrel1` calling
`@ownrel2` then `pas_dispose` — and behind a `dyn` that type is not known. The
vtable must carry the release, which is a second reason for it to exist beside
the trait's own routines. That belongs to C2 and is recorded here so it is not
discovered there.

## Decision

**The type, and no value.** `tyDyn` is the 22nd type kind; `nkDyn` the node;
`IsDyn` the 42nd predicate; AP 6.7.11 the clause. Every position a program can
write one in is **refused**, with a diagnostic naming the two positions
6.7.11.1 will permit.

**AP 6.7.11 is the first clause to carry AP 5.6's `[not yet implemented]`
marker.** That mechanism was written by ADR-0189, compared against the triage
in both directions by ADR-0195, and used nowhere — a fact ADR-0407 turned up
the day before, when AP 6.7.10.2's normative text and its own NOTE 14
contradicted each other because the gap had been written into prose instead.
This is the shape that stops: the clause states the requirement, the triage
says `not-implemented`, and `spec-clause-traceability` refuses a scenario
citing it, so no passing test can make the document claim the feature is
there.

### The finding that changed the design

**A type that answers false to every predicate is not refused — it is treated
as an ordinary small value.**

The plan was refusal by construction: `tyDyn` answers false to all 41 existing
predicates and true only to `IsDyn`, so — the reasoning went — every place
that asks a permission refuses it without naming it, which is CLAUDE.md's rule
and the shape a restricted type and a discriminant-selected variant both take.

Compiling it showed the premise was wrong. A `dyn` field, a `dyn` array
element, a `dyn` variable and a `dyn var` parameter **all compiled**, and the
only complaint was a `protected` warning. Refusal by construction works where
the default is to refuse and a predicate grants; in each of those positions the
default is to **permit**, and a predicate is what would have refused.

So the refusal is one diagnostic, written where the denoter resolves — which
is also the only place a program can be told where a trait object *will*
stand, rather than being told something about assignment three passes later.
Increment C2 replaces it with the two grants.

### What the spelling costs, measured

`dyn` reserves nothing: it is an identifier juxtaposed with an identifier,
which is `owned ^T`'s shape one token over, and a type-denoter is complete
after a type-name in both standards. A program may declare a type, a field and
a parameter named `dyn` and keep all three; `tests/dialect/dyn_positions.pas`
does.

**A trait is not a type**, so the type record holds `dynTrait: symPtr` rather
than using `elem` — the field every other kind that refers onwards uses. What
it does not hold is an implementation: which one a value carries is the
vtable's answer at run time, and that is the whole difference between this and
a bound (§6.7.3.10.5), where the implementation is chosen at instantiation and
no vtable exists.

**`owned ^dyn T` cannot be written inline**, which ADR-0315 writes throughout.
§6.4.14's domain is a type-*identifier*, for §6.4.4's reason — a type must be
able to own something of its own type — so the spelling is
`type D = dyn Renders;` and then `owned ^D`. AP 6.7.11.1 NOTE 3 says so.

## What it cost, and what a gate missed

A type kind: **7** case-statements (each `21 of 21`, so a missing arm is a
crash), **6** tag if-chains whose denominators moved and whose numerators did
not — a trait object is no ordinal, has no dynamic extent, is no
write-parameter and is no schema's domain — and **41** predicate answers.

A node kind costs more: **4** exhaustive lists needing an arm and **45**
catalogue denominators.

**And one crash got through `kind-exhaustive`.** `DumpTypeExpr` has a
catalogued partial case, argued as *each names its own third* — expressions,
statements, type-denoters. `nkDyn` is a type-denoter, so adding it falsified
that argument while the numbers still matched 15 against 15, and `--dump-ast`
over any program containing a `dyn` stopped the compiler with
`case: no label matches the selector`.

**`procedure-coverage` caught it**, by ADR-0269's rule that the compiler must
*survive* every invocation and that a crash is not a rejection. The general
lesson is now a `doc/sop.md` §7 row: a catalogued partial case is only as good
as its argument, the gate compares two numbers, and the argument is prose that
nothing re-reads when the enumeration grows.

## What this does not do

It does not accept a trait object anywhere, emit a vtable, or lower a call.
Those are C2, and C3 is the release slot.

It does not decide whether C2 is built. ADR-0315's *whether any of it is built
is not a promise either way* stands, and this increment is useful without it:
the clause is written, the spelling is reserved against a conforming program
taking it, and a person who writes `dyn` is told where it will stand instead of
getting a syntax error.
