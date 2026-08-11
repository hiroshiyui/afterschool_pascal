# 44. A discriminant may be the variant-selector

Date: 2026-08-11

## Status

Accepted. It is the last of ADR-0039's five deferrals: a discriminant as a
variant-selector.

## Context

ISO/IEC 10206:1991 §6.4.3.4 spells a variant-selector

    variant-selector = [ tag-field ':' ] tag-type | discriminant-identifier .

so a variant part inside a schema body may be selected by one of the schema's
own discriminants. `shape(k: kind) = record case k of round: (r: real);
square: (s: real) end` is then a discriminated union in the sense the phrase
usually means: which arm is live is a property of the *type*, fixed when the
type was produced, rather than a value the program stores and may get wrong.

The earlier records made a schema's discriminants reach an array's bounds
(ADR-0039), a parameter's descriptor (ADR-0040), a block's entry (ADR-0041)
and a heap header (ADR-0043). Every one of those was about *size*. This one is
not: the layout of a discriminant-selected variant part is byte for byte the
layout of a tagless `case T of`, and what changes is only which arm the
standard says is active.

The four earlier records also each had a question about where a run-time value
lives. This one had to be asked whether it has one at all.

## Decision

**It does not, and that is the whole design.** §6.4.3.4 says the selector "shall
be designated a field of the record-type if and only if it is associated with a
field-identifier" — and the discriminant form has no tag-field to associate.
So the selector has no storage: the tuple is the only place the value exists,
and the tuple is already reachable, by ADR-0039's `v.k`, from a produced type's
`Type` and from a descriptor or a header for a generic one.

The consequences follow from that one sentence:

- **CodeGen is untouched.** Not "almost": the diff is empty. Nothing in the
  layout ever reads a tag — ADR-0034 established that when the
  variant-part-completer landed — so a variant part with no tag field is a
  shape codegen has emitted since ADR-0018.
- **`verify/` gains nothing**, for the same reason.
- **§6.4.3.4's dynamic-violation cannot be committed.** "It shall be a
  dynamic-violation to attribute another value to such a selector" needs a
  program that can write one, and there is no designator that denotes it. The
  rule is enforced by construction rather than by a check, which is why this
  record adds no runtime error where ADR-0041 and ADR-0043 each added two.

**The two forms are told apart by the symbol, not by the syntax.** `case k of`
is a tag-type when `k` names a type and a discriminant-identifier when `k`
names a discriminant, and the parser cannot know which. So Sema asks *before*
resolving the denoter — as a type-denoter the name would be reported unknown —
and `Symbol::discBinding` is what it asks. The flag is needed because the
symbol *kind* cannot answer: a schema production with a tuple binds each
discriminant as an ordinary `Const`, and an ordinary constant is a `Const` too.

That the flag is set in two places is the feature's only real cost, and it is
the price of ADR-0039's decision to resolve a schema body by *binding* its
discriminants rather than by carrying them: a constant production binds values,
a generic one binds `Disc` symbols, and this form has to work in both. It does,
and one of them going unmarked is caught in each compiler.

**A tag-field with a discriminant selector is refused.** The grammar offers it
to the tag-type alternative only, and the reason is worth stating rather than
deferring to the syntax: a field would be a second place to keep a value the
tuple already fixes, and one the program could then assign — which is the very
thing the section calls a dynamic-violation.

**`new(p, c₁, ..., cₙ)` may not select such a variant part.** §6.7.5.3 requires
that "the variant-part corresponding to cᵢ shall closest-contain a tag-type",
and this one contains a discriminant instead. The check is per variant part and
not per record, so an outer part with a tag-type is selectable and the one
nested inside the arm it selects is not — `new` walks in and asks again.

This is also where the feature meets ADR-0043, and the meeting is a
coincidence worth naming: for `p: ^shape`, `new(p, round)` supplies a *tuple*,
and the tuple happens to select the variant. Two readings of one argument list
that agree — but they agree only because ADR-0043 decided the form is chosen by
the domain and by nothing else. Had it been decided by the arguments, this
would be the program that made it ambiguous.

## Consequences

**Schemata gain their second reason to exist.** Until now every one of them
produced an array, because §6.4.7's discriminants had nowhere else to be read.
A record whose variant is fixed by its tuple has no dynamic size at all — it is
`staticThroughout`, so it passes the "the discriminants have to bound an array"
test without that test being weakened. `shape(round)` and `shape(square)` are
distinct types by §6.4.8, and a variable of one cannot be assigned a value of
the other: the union is discriminated at compile time as well as at run time.

**One compiled body serves every variant.** A schematic formal `var v: shape`
takes any tuple, reads `v.k` from the descriptor and branches on it — so the
tag travels with the type, which is the difference between this and the ISO
7185 record it otherwise compiles to.

**Eighteen mutations across both compilers, all caught**, over the nine places
the feature touches: the selector lookup, the two bindings, the flag, the
tag-field refusal, the `new` refusal at the outer and at a nested level, the
`discBinding`-versus-kind distinction, and the denoter annotation the dumps
read. The nested `new` refusal needed a test written for it — the corpus
reached the outer one only, which is the shape of gap ADR-0022 onwards keeps
finding.

**Nothing was added to `verify/`, `codegen.cpp`, the emitter, the parser or the
lexer.** The whole feature is one function, one flag on `Symbol`, one flag on
`Type` and `Variant`, and two diagnostics. That is what a language feature
costs when the standard's own words happen to describe something the
implementation already had.

## What this does not do

ADR-0039's five deferrals are now closed. ADR-0040's second half stands: a
schematic formal whose discriminants reach past an array, which is the shape
the required schema `string` itself has.

The initial-state rules of §6.4.3.4 — a) through d), which say what a selector
bears before anything is assigned — are not implemented, because this compiler
has no initial states at all; `value` initial-state specifiers are their own
unlanded feature. Reading an inactive arm is still undetected, exactly as
ADR-0027 left it for a tag-selected variant part.
