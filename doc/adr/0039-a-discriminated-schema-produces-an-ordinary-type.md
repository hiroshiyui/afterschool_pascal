# 39. A discriminated schema produces an ordinary type

Date: 2026-08-11

## Status

Accepted. The schematic *formal parameter* is deliberately not part of this
record; see "What this does not do".

## Context

ISO/IEC 10206:1991 §6.4.7 adds schemata, which the standard's own introduction
summarises as two things:

> Schemata. A schema determines a collection of similar types. Types may be
> selected statically or dynamically from schemata.
>
> A schematic formal-parameter adjusts to the bounds of its actual-parameters.

A schema-definition is a type-definition with a formal-discriminant-part
between the name and the `=`:

```
schema-definition       = identifier '=' schema-name
                        | identifier formal-discriminant-part '=' type-denoter .
formal-discriminant-part= '(' discriminant-specification
                          ( ';' discriminant-specification )* ')' .
discriminant-specification = identifier-list ':' ordinal-type-name .
discriminated-schema    = schema-name actual-discriminant-part .
actual-discriminant-part= '(' discriminant-value ( ',' discriminant-value )* ')' .
```

§6.4.8 is the rule that gives the feature its shape:

> A type produced from a schema with a tuple shall be distinct from a type
> produced from the schema with a distinct tuple and from all types produced
> from a distinct schema with a tuple.

That sentence has two halves, and the second one is easy to miss: distinct
tuples give distinct types, *and* one tuple gives one type however many times
it is written. `vector(3)` in a variable declaration and `vector(3)` in a type
definition are the same type, and a whole-array assignment between them is
legal.

This is the largest feature since the bootstrap closed, and the first whose
scope had to be decided rather than read off the clause.

## Decision

**A discriminated schema produces an ordinary `Type`, and nothing downstream of
Sema learns that schemata exist.** `vector(3)` resolves to exactly the
`array [1..3] of real` the compiler would have built for that denoter written
out, so ADR-0017's layout, ADR-0016's frames, both code generators and every
proof rule are untouched. The whole feature lives in the parser and in Sema,
and the one line codegen needed is for §6.8.4's `v.n`, which is a constant.

**A schema keeps its syntax, not a type.** Its body is *not* resolved when the
type part is walked — it has no discriminant values yet, and resolving it once
would produce the single type every use then shared. `Symbol::schemaBody` is
the type-denoter, re-resolved once per distinct tuple with the discriminants
bound as ordinary constants in a scope that exists only for that resolution.
That is what lets `array [1..n] of real` reach the existing subrange and array
code with nothing added to either: by the time it is resolved, `n` *is* a
constant.

**§6.4.8's identity rule is a table, not a comparison.** Productions are
interned by the pair (schema, tuple), so two productions with equal tuples
return the same object and ADR-0017's identity comparison then says exactly
what the standard says. `assignable` gains no case for schemata at all — which
is the test of whether the rule was encoded in the right place.

**A produced type is named after the schema and the tuple.** Without it,
`vector(3)` and `vector(5)` both print as `array [1..n] of real` with different
bounds, and two productions that differ only in a discriminant the body never
mentions — §6.4.7's NOTE 1 says that is a thing you may deliberately write —
print identically. A diagnostic that reported the rule while hiding the reason
would be worse than one that said less.

**Discriminant values must be constants**, and the message says so in those
words. §6.2.3.2 evaluates an actual-discriminant-part when the block is
entered, so `var s: string(n)` with `n` a parameter is legal Extended Pascal
and is refused here. This is the deferral that decides the scope of this
record; see below.

**Two restrictions the standard does not spell out, both diagnosed.** A schema
whose body contains an enumerated type is refused: §6.4.2.3 declares an
enumeration's constants into the scope the *type* appears in, and a body
resolved once per tuple would declare them once per tuple, into a scope that
lasts only as long as the production. Silently losing them — which is what the
first implementation did — is worse than saying so. And a schema that names
itself outside the domain of a pointer is refused, which §6.4.7 does require;
without the check the production recurses until the stack runs out.

## Consequences

**A schema nobody produces a type from is never looked at.** Its body has no
meaning until a tuple gives its discriminants values, so an error inside it is
reported at the first production and not before. That is a consequence of
§6.4.7 rather than a shortcut, but it does mean `tests/extended/schema_errors.pas`
has to spend a variable on every mistake it wants reported — which is stated at
the top of that file, because a reader who added a broken schema and saw
nothing would reasonably conclude the check was missing.

**A body reporting an error names two places.** The body is written in one
place and its discriminants are chosen in another, and `hollow(0)` fails inside
`array [1..n]` where no tuple is visible. So a failed production adds a second
diagnostic at the denoter that chose the tuple. Two messages for one mistake is
a cost; neither location alone says what to change.

**`--dump-sema` shows the last type a schema produced.** The body carries
whatever the most recent production left on it, because the cache is cleared
*before* each production rather than after. A schema body has no one type, so
either that or a row of `?` is a half-truth; this one at least shows what the
resolution looks like, and it is deterministic because productions happen in
source order. Both compilers do it, which is what the differential checks.

**Fifteen mutations, fifteen caught**, but one needed a test the corpus could
not have had by accident: *a discriminant value outside the discriminant's own
type*. §6.4.7's domain is the tuples **allowed by the formal-discriminant-part**,
so `narrow(20)` where the discriminant is `1..9` is not in the domain. Nothing
saw it, because every schema in the corpus had an `integer` discriminant and a
subrange is assignment-compatible with its host — so the compatibility check
that catches a `char` passes a 20, and only the range test refuses it. It takes
a *named* subrange to write the case at all, because §6.4.7 requires an
ordinal-type-**name** and `1..9` is not one.

The two ISO 7185 refusals are caught only by the differential, because
`selfhost/badparse/` is where a parse error of that language lives and ctest
compiles it as ISO 7185. The three Extended Pascal parse errors went to
`tests/extended/` for the mirror-image reason — ADR-0034's trap, hit again and
avoided this time by checking where each message is reachable from.

## What this does not do

Named here so that "schemata: done" cannot be read as more than it is:

- **Discriminant values that are expressions**, and with them the dynamically
  sized variables of §6.2.3.2. This is the deferral that matters, because it is
  what `string(n)` needs.
- **Schematic formal parameters** — `procedure p(var v: vector)`, the second
  half of the standard's own summary. A formal whose bounds come from the
  actual needs those bounds at run time, which needs a descriptor beside the
  address: the shape ADR-0030 already uses for a procedural parameter's
  code-and-link pair. It is a separable piece of work and gets its own record.
- **A schema as the domain of a pointer**, and `new(p, discriminants)`.
- **A discriminant as a variant-selector** (§6.4.3.3), which fixes a record's
  arm at production rather than at run time.
- The required schema **`string`**, and **`type of`** (§6.4.9's type-inquiry).

Each of those is a decision of its own, and none of them changes what this
record decides: that a *discriminated* schema is an ordinary type.
