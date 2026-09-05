# ADR-0339: A trait heading names one type, and one scope

Date: 2026-09-05

## Status

Accepted. Follows [ADR-0338](0338-a-bound-belongs-where-the-type-is-written-down.md),
which it completes rather than supersedes: that record's decisions — the bound
on a schema's discriminant, `impl` naming a schema, the `T: Ord type` spelling
and `skTrait` — all stand unchanged. What it lacked was a rule for **where
`Self` may be written** and an answer for **what happens when two traits want
one routine name**, and both were carried as claims rather than as findings.

Nothing is implemented. The parser half is on the `traits-b` branch and does
not pass its gates; this record is written before the clause, which is the
order ADR-0338 was written in and for its reason.

## Context

ADR-0338 rested on two unprobed assertions. Both were probed against the
compiler as it stands, and neither survived intact.

### `Self` substitution can reuse the congruity check — half true

A trait keeps its headings' *syntax* and resolves them once per implementation
with `Self` bound, which is 6.4.7's schema shape and the reason ADR-0338 gives
for it. The claim was that §6.6.3.6's congruity, which the compiler already
computes, then compares the impl's heading against the trait's.

**`Congruous` compares by type *identity*** — `f^.sym^.stype <> a^.sym^.stype`,
and `want <> got` for the result. So the claim holds exactly as far as
substitution yields the *same type object*:

- **`self: Self`** is a bare type-name. Substituted, the object *is* the impl's
  type, and two separately-written parameters of a named type are congruous —
  probed, and it compiles and runs.
- **`xs: array of Self`** is not. §6.4.1 makes each type-denoter that is not a
  type-name denote its own type, so `array of Point` written in the trait and
  `array of Point` written in the impl are two objects. Probed with procedural
  parameters, which is where `Congruous` is already used: *`'impl' does not
  match the parameter list of procedural parameter 'q'`*.

**`^Self` is not a case at all**, and for a better reason than a refusal:
§6.7.3.1's parameter-form is a type-name, a schema-name or a type-inquiry, so a
pointer denoter cannot be written in a parameter position. It is **unformable**
rather than checked, which is ADR-0201's shape — with ADR-0201's caveat, that a
feature adding a way to form one takes the property with it silently.

### A trait's routine names do not collide — false

The claim was that two traits declaring `Compare` would be a matter for
`export-unique` to catalogue. It is not: §6.11.2 puts every imported name into
one scope, and the program is **refused outright**. Two modules exporting the
spelling, imported together:

    mc.pas:2:13: error: 'compare' is already declared in this block

That is severe rather than untidy, because the names a trait wants are exactly
the contested ones — `Compare`, `Hash`, `Eq`, `Len`, `Write`. One trait per
*program* could own each spelling, and a library could not offer two traits with
a routine name in common.

**The escape already exists and needed nothing invented.** §6.11's `qualified`
import keeps both, and both run:

    import MAi qualified; MBi qualified;
    …
    writeln(MAi.Compare(3, 1));      { 2 }
    writeln(MBi.Compare('a', 'b'));  { -1 }

## Decision

**`Self` shall stand only as a whole parameter-form or result-type**, and a
trait heading writing it anywhere else is refused **at the trait-declaration**.

The refusal is at the declaration and not at the impl, and that placement is
the decision rather than a detail. `array of Self` parses, and left unchecked
it produces — at *every* implementation of that trait, in the impl's source — a
message about a procedural parameter's parameter list, which names nothing the
reader can act on and points at the wrong file. The trait is where the mistake
is, and it is where it should be reported: *`'self' may stand as a parameter's
whole type or as a result type, and not inside one`*.

**A trait's routine names are ordinary exported names, and a collision is
answered by `qualified`.** They enter the export-part with the trait, so
`export-unique` sees them and its rule is untouched; two traits with one
spelling are a program's problem exactly as two modules with one spelling are,
and the language already has the word for it.

## Consequences

**The restriction is narrower than it sounds, and the arithmetic is why.** A
trait heading's parameters may be a type-name, a schema-name, a type-inquiry
(§6.7.3.1) or a slice (ADR-0125). Of those, `Self` is admitted in the first and
refused in the last; a schema-name argument and a type-inquiry over `Self` are
not settled here and are refused for now, with the same message, because
neither has a caller and both would need the substitution to build a fresh
object that identity comparison would then refuse. **A trait routine therefore
takes and returns whole values of the implementing type**, which is what
`Compare`, `Hash` and `Eq` want and is the whole of what B's own measurement
asked for.

**Congruity is reused unmodified**, which was the point of the claim and
survives it. No change to `Congruous`, no `Self`-aware comparison path, and no
second congruity rule to drift from the first — the substitution happens before
the comparison and the comparison is the one the language already has.

**`export-unique` gains a denominator and keeps its rule.** A trait name and its
routine names are exported names. The gate has a floor of modules and exports so
that it cannot pass by sweeping nothing, and these move it upward, which is the
direction that cannot hide anything.

**This is the strongest argument yet for increment A, and it is not the one the
record gives.** ADR-0315 justifies A by 118 call-site spellings, which ADR-0338
found blocks no program and fails ADR-0109's test. But `x.Compare(y)` resolves
in the *receiver's* type scope, so it is precisely the collision-free form of
the thing this record has just had to answer with `qualified`. **A is still not
a prerequisite for B** — that stands, and was established against the mechanism
— but it is the ergonomic answer to the namespace pressure B introduces, and
that is a reason of its own where the prefix count was not. It belongs in the
judgement when A is next taken up.

## What this does not do

**It does not settle `Self` in a schema-name or a type-inquiry.** Both are
refused with the same message and neither has a caller. When one appears, the
question is whether substitution can be made to *intern* a type rather than
build one — the schema table already does exactly that (ADR-0039), so the
mechanism exists and the work is deciding whether a trait may use it.

**It does not add a trait-qualified call.** `Ord.Compare(a, b)` was considered
and is unnecessary: `qualified` already qualifies by *module*, which is where
the collision is, and a second qualification syntax would be a second position
for one fact.

**It does not change what a trait is for.** The bound, the schema discriminant
and the impl-for-a-schema are ADR-0338's and are untouched.

## Alternatives rejected

**Making `Congruous` `Self`-aware**, so that `array of Self` compares
structurally. Rejected: it is a second compatibility rule beside the one
§6.6.3.6 gives, and ADR-0058's sentence — a permission granted in a shared
predicate leaks to every caller — has cost this project three times, with
ADR-0146's gate standing over it. The restriction costs a construct nobody has
asked for; the permission would cost a rule everything asks.

**Refusing `array of Self` at the impl instead of the trait.** Rejected on the
diagnostic: the message would arrive once per implementation, in the wrong
file, and would describe procedural parameters to a reader who wrote neither.

**Requiring trait routine names to be unique across the library**, enforced by
`export-unique`. Rejected because it makes the gate's rule a language rule and
puts the cost on whichever trait was written second, for a collision the
language already resolves.

**Namespacing a trait's routines so they are not exported names**, as
increment A does for methods. Rejected *for B*: it needs the per-type scope A
builds, and adopting it here would make A a prerequisite after all — which is
exactly the claim two investigations asserted and neither could support.
