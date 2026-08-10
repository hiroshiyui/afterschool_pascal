# 41. A discriminant may be evaluated when the block is entered

Date: 2026-08-11

## Status

Accepted. It closes the deferral ADR-0039 named as the one that mattered.

## Context

ISO/IEC 10206:1991 §6.2.3.2 says an actual-discriminant-part is evaluated when
the block containing it is entered. `var s: vector(n)` with `n` a variable is
therefore a legal declaration, and the variable it declares has a size that is
not known until the activation exists.

ADR-0039 refused it and said so in those words, because every type it could
produce was a type of the *program*: interned by (schema, tuple), laid out
once, and named in diagnostics by the constants that produced it. A tuple
computed on entry has none of that. ADR-0040 then built the machinery a type
with a run-time tuple needs — a descriptor beside the address, discriminants as
symbols with storage, sizes as emitted arithmetic — for a schematic formal
parameter, whose tuple arrives from the caller.

This record is the observation that those are the *same* thing. A variable with
non-constant discriminants and a schematic formal parameter differ in exactly
one respect: where the tuple comes from. Everything after that — the
descriptor, `v.n`, the bounds checks, `dynSize`, the byte-wise addressing — is
already written.

## Decision

**Such a variable holds a descriptor, and the prologue fills it.** The frame
slot is ADR-0040's `{ptr, d₁, ..., dₙ}`. On entry the discriminant expressions
are evaluated, stored into the tuple, and the storage they size is claimed with
an `alloca` of a computed length — the same three steps a schematic *value*
parameter's prologue already took, with the tuple computed instead of
received. `Symbol::discExprs` is the whole of the difference, and it is what
distinguishes the two everywhere the distinction is needed.

**§6.2.3.2's position is the whole of the permission.** A discriminant that is
not a constant is accepted in a variable-declaration's own type-denoter and
nowhere else. `resolveType` withdraws the offer before it recurses, so
`array [1..3] of vector(n)` and `record f: vector(n) end` and `type later =
vector(n)` are all refused exactly as they were — a component, a field and a
type name each denote something the program has rather than something an
activation has. One flag, cleared at one place, is what says that.

**A tuple is checked where it is chosen.** ADR-0040 could argue that a
schematic formal's bounds needed no run-time check because the actual's type
had been produced from constants and checked when it was produced. That
argument does not survive here, so the two checks it stood in for are made on
entry:

- a discriminant outside its own type is outside §6.4.7's domain, and the store
  into the descriptor is where the value enters a variable — so the check that
  guards every other such store makes this one, and reports it in the words a
  subrange always uses;
- a tuple that leaves an index range empty selects no type at all (§6.4.7
  NOTE 2), and that is a comparison of two bounds per dynamic dimension,
  emitted once on entry rather than at every subscript.

With those in place ADR-0040's argument becomes true again rather than merely
true so far: *every* type that reaches a descriptor has had its tuple checked,
whether Sema or the prologue did it.

**A variable cannot be one of its own discriminants.** Its name is in scope by
the time its type-denoter is read — Pascal's scoping is the block, not the
point of declaration — so `v: vector(v)` resolves, and without a word about it
it would read a descriptor that has not been written. Diagnosed, because the
alternative is a program that compiles and reads uninitialised storage.

**One denoter, one type per name.** `var a, b: vector(n)` gives `a` and `b`
their own descriptors and therefore their own types, where `var a, b: vector(3)`
gives them one interned type and lets `a := b` through. That is the same
consequence ADR-0040 recorded for two schematic formals, arrived at by the same
route, and it is the one place where a group of names does not share a type.

## Consequences

**The storage is an `alloca`, so it lives exactly as long as the frame does.**
Nothing is freed, nothing is registered, and a recursive procedure gets one per
invocation — which is what `tests/extended/schema_dynamic.pas` checks by having
each depth report its own length after the deeper call returned. A non-local
`goto` out of such a block abandons it with everything else the frame held;
ADR-0032's file list is unaffected because no file is involved.

**The prologue's order is load-bearing and unenforced.** The tuple must be
stored before anything asks the descriptor for a size, and the parameters must
be in place before a discriminant names one. Both hold because
`initDynamicVars` runs after the parameter loop and stores the tuple before it
sizes anything — and a mutation that moved it before the parameters is what
says the order was chosen rather than fallen into.

**`--dump-sema` prints the schema's name for the type, not a tuple.** There is
no tuple to print: `vector` rather than `vector(3)`. That is the same thing
ADR-0040 does for a parameter, and it is honest — two variables of `vector(n)`
in one block have the same *denoter* and, at run time, possibly different
lengths.

**No proof rule was added, again.** For the same reason as ADR-0040: `verify/`
quantifies the array rules over their bounds, so a pair computed on entry is
already inside what they say. The new run-time checks are a subrange store
(covered by `subrange-store-traps-exactly-outside`) and an emptiness test whose
ISO condition *is* the emitted comparison — which ADR-0013 says not to write a
rule for, because it would prove nothing.

**Fourteen mutations on the C++ side and eight on the Pascal one, all
caught — after two escapes that each named a missing test.** "The domain is
checked at the outermost dimension only" needs a schema with two dynamic
dimensions *and* a tuple that empties the inner one, which is
`tests/extended/trap_schema_domain_inner.pas` and exists for no other reason.
"A non-constant discriminant is taken anywhere" needs a schema *body* that
names another schema with a variable discriminant — the one place
`resolveType`'s guard is reachable, and one the obvious refusals
(`array [1..3] of vector(k)`, `record f: vector(k) end`) do not reach at all,
because the flag was never offered to them in the first place. Both were
written and both then caught it.

## What this does not do

`string(n)` is now buildable and is still not built: it is a required schema
with its own operators, assignment rules and `write` behaviour (§6.4.3.2), and
it wants the whole-variable assignment this record still leaves out. Of
ADR-0039's five deferrals, two remain untouched — a schema as the domain of a
pointer with `new(p, discriminants)`, and a discriminant as a variant-selector
(§6.4.3.3) — and ADR-0040's two stand:

- **A whole-variable assignment between two schematic-typed variables**, which
  needs the tuple comparison §6.7.3.3 calls a dynamic-violation. Every piece of
  it now exists — two descriptors, a length, a memcpy — so this is the next
  small one rather than the next hard one.
- **A schematic formal whose discriminants reach past an array**, which is the
  shape `string` itself has.
