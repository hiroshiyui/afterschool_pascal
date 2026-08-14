# 93. A set-constructor has not chosen a packing

Date: 2026-08-15

## Status

Accepted. Retires the second of the two deviations ADR-0072 recorded as
deliberate.

## Context

ISO 7185 §6.4.5 c):

> T1 and T2 are set-types of compatible base-types, and either both T1 and T2
> are designated packed or neither T1 nor T2 is designated packed.

ISO/IEC 10206:1991 §6.4.5 c) is that sentence word for word. This compiler
compared only the base types, so `set of boolean` and `packed set of false..true`
were compatible, which BSI's DEV097 is written to catch.

**ADR-0072 recorded that as deliberate, and its reason was wrong.** It argued:

> Every set is one 256-bit word whatever is written, so the check could only
> reject programs that work — and **the standard does not say what packing a
> set-constructor has**, so requiring agreement would make `s := [1]` succeed
> or fail according to how `s` was declared.

§6.7.1 says exactly what packing a set-constructor has, in a sentence both
standards carry verbatim:

> A set-constructor containing one or more member-designators shall denote
> either a value of the unpacked-canonical-set-of-T-type or, **if the context so
> requires**, the packed-canonical-set-of-T-type.

The dilemma the record describes is the one that clause exists to dissolve, and
BSI shipped CONF147 in 1982 to test the dissolution. The first half of the
argument is true and irrelevant: §6.4.5 c) is a *type* rule, and "the
representation is the same anyway" is equally an argument for making `packed
array` and `array` compatible, which this compiler correctly refuses.

## Decision

**`packed`, `unpacked`, and *not yet decided* are three states, and `isPacked`
has two.** `Type::setCanonical` is the third: true for a set-constructor's type
and for the empty-set singleton, false for every set-type a denoter named.
Compatibility then asks that the base types agree **and** that either side is
canonical or both agree on packing.

That is the whole of the feature. There are only three places a set type is
built, so the marking site is unambiguous; everything else routes through
`Assignable`, which the relational operators, `+ - *`, `><`, assignment and
value parameters all already consult. `in` was untouched and had to be: it
compares an *element* against a base type, and §6.7.2.4 takes either packing.

**A set operator's result takes the operand that has committed.** Table 5 makes
the result "the same as the operands", so `[1] + p` must be `p`'s type — a
canonical result would launder a packed operand into something that compares
equal to anything.

**The diagnostic had to learn the word `packed`.** Without it
`u <= q` over two anonymous types reports *"found set of boolean and set of
boolean"*, and `WriteDistinctTypeNote` then offers its advice about naming the
type once — which cannot help, because the types differ in something a name does
not fix. ADR-0074's own fault, reappearing in the feature that created it.

## Consequences

**460 cases pass.** `selfhost/compiler.pas` declares no set type at all, so
self-hosting could not be affected.

**The corpus contained a test asserting the deviation, and repeating its false
justification.** `tests/packedset.pas` existed to hold the compiler to
ADR-0072 — "if the check is ever added, this file has to change deliberately
rather than a deviation quietly disappearing", which is exactly what happened —
and its closing comment stated that the standard does not say what packing `[1]`
has. It is rewritten to the conforming rule, with the two illegal assignments
moved to `tests/packedset_compat.pas`, whose legal half is the §6.7.1 exemption.

**The third state is load-bearing and measurably so.** Comparing `isPacked`
directly breaks **23** cases, because assigning a constructor to a packed set is
ordinary Pascal and the corpus is full of it.

**This is ADR-0072's own closing lesson turned on ADR-0072.** That record ends
"a wrong citation is invisible to every oracle here", and its wrong claim was
repeated in `doc/implementation-defined.md`, `README.md`, `doc/roadmap.md` and
the test — five copies, none of which any oracle could contradict, because no
program in this tree wrote two set-types that disagreed on packing.

### What this does not do

**It adds no rule to `verify/`.** This is a type rule with no lowering: a set
is one 256-bit word whatever the source wrote (ADR-0028), so CodeGen is
untouched and a rule here would restate the compatibility test rather than
prove anything about emitted code.

**It does not make `packed` mean anything else.** §6.4.3.1 still leaves the
representation to the implementation, and this one still packs nothing.
