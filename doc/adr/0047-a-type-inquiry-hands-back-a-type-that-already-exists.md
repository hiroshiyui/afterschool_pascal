# 47. A type-inquiry hands back a type that already exists

Date: 2026-08-11

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.4.9:

```
type-inquiry        = 'type' 'of' type-inquiry-object .
type-inquiry-object = variable-name | parameter-identifier .
```

"The type denoted by a type-inquiry shall be the type possessed by the
variable-identifier or parameter-identifier contained by the type-inquiry."

It is the only type-denoter that names a **variable**. Everything else in the
type-denoter grammar names a type or builds one.

## Decision

**A type-inquiry resolves to the `Type *` the named symbol already holds**, and
that is the whole of the feature. It builds nothing, interns nothing, and owns
nothing.

That is not an implementation shortcut; it is what §6.4.9 asks for. ADR-0017
made two structured types the same only when one type identifier denotes both
(§6.4.5), so a type-inquiry that *built* a type alike the original would be
useless: `b: type of a` could not then be assigned from `a`, which is the one
thing anybody writes it for. Handing back the same object makes the assignment
an ordinary whole-variable copy and needs no case anywhere.

**It reserves nothing.** `type` and `of` are both already reserved in ISO 7185,
so this is the second Extended Pascal feature here to cost that language
nothing lexically, after ADR-0038's `and then`. There is no ambiguity to
resolve either — `type` cannot begin a type-denoter in ISO 7185 at all, so one
token decides.

**§6.4.9's parameter form needed nothing added.** The interesting use is
`procedure p(var a: point; b: type of a)`, where the object is a parameter of
the *closest-containing* formal-parameter-list. `declareProcHeading` already
pushes a scope before building the formals and `addFrameVar` declares each into
it, so by the time a later parameter's type-denoter asks, the earlier one is an
ordinary lookup. A first version carried a side list of the parameters built so
far; it was deleted when the scope turned out to answer, because a second
lookup path that never fires is worse than none.

**Two things are refused, and only one of them is §6.4.9's.**
§6.7.3.1 forbids the parameter-form containing "an applied occurrence of the
parameter-identifier", so `x: type of x` is an error — and it has to be checked
*before* the names are declared, or the name finds itself and the check never
fires.

The other is this compiler's: a type-inquiry whose object is a **schematic
formal parameter** is refused. Its type has no tuple, and the bounds live in a
descriptor belonging to that one parameter (ADR-0040), so a second name reading
them would have to share the *descriptor* rather than the type — which is a
different mechanism, not a different denoter. Refusing it says so; handing back
the generic type would have produced a variable whose bounds nothing could
read.

## Consequences

**CodeGen is untouched and `verify/` gained nothing**, both for the same
reason: by the time either runs, the type is one that some other declaration
made, and nothing records that a second name arrived at it this way.

**Where a type-inquiry may appear is exactly three places**, and two of them
were free. It is a `type-denoter` alternative (§6.4.1), so every declaration
takes one; it is an `ordinal-type` alternative (§6.4.2.1), and "a type-inquiry
in an ordinal-type shall denote an ordinal-type" is enforced by the existing
message at each ordinal position, because the denoter resolves to a type and
that type is then asked the question it was always asked. Only the third,
`parameter-form` (§6.7.3.1), needed a parser change — one token added to the
test that a parameter's type is a name.

**A function's result type is not one of the three.** §6.7.2 spells
`result-type = type-name` and stops, so `function f: type of n` is refused —
by the message that was already there.

**Thirteen mutations across both compilers, all caught** — but only after two
escaped and were given tests. Both were the parser's, and both are the same
gap: the corpus had no ISO 7185 program containing a type-inquiry, and none
with `type` not followed by `of`. A feature whose whole test corpus is written
in the language that *has* it cannot see either check.

## What this does not do

**Where a *parameter-identifier* object may live is not enforced.** §6.4.9
requires it to be in the closest-containing formal-parameter-list; here the
name is found by ordinary lookup, so a type-inquiry inside a procedural
parameter's own list can also see the enclosing list's parameters. Refusing
that needs a distinction between a parameter-list region and a block region
that this compiler does not keep. The direction of the deviation is
permissive — a program this accepts and a conforming processor rejects — and
it is stated here rather than discovered later.

**A schematic object waits**, as above. §6.7.3.3 defines what a var parameter
whose form is a type-inquiry on a schematic variable means, down to the
dynamic-violation when the tuples differ; landing it means sharing a
descriptor between two symbols, which is the mechanism ADR-0040 introduced and
deliberately gave to exactly one parameter each.
