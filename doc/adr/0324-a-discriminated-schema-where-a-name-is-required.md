# ADR-0324: A discriminated schema where a name is required

Date: 2026-09-05

## Status

Accepted. Adds AP 6.7.3.1.1 and AP 6.7.2.1. Closes the finding ADR-0171 §2
recorded and declined to resolve, and the last entry of
`doc/roadmap.md`'s Known limitations that had no record.

## Context

ISO/IEC 10206:1991 §6.7.3.1 gives

    parameter-form = type-name | schema-name | type-inquiry .

and §6.7.2 gives

    result-type = type-name .

A *discriminated-schema* — `string(5)`, `Box(3)` — is in neither production, so
`procedure q(x: string(5))` and `function f: string(5)` are outside that
standard's grammar. **This compiler accepts both and always has.**

ADR-0171 found the first while probing something else, called it "an extension
inside a conformance mode, which `doc/implementation-defined.md` §5 lists two of
and this is not one", and left it: refusing it would have taken something from
working programs, and the resolution it named — refuse it in the two
conformance modes, admit it in the dialect with a clause of its own — was "a
feature-sized change and not an adjudication". ADR-0232 then removed the modes,
so half of that resolution is gone and what is left is the clause.

The entry has been the one program shape in this tree that was neither refused,
specified, nor deliberately extended.

## What was measured, and what it corrected

**The entry's own numbers were wrong twice, and the second time was mine.**
`doc/roadmap.md` carried it as *three sources under `tests/extended/`* until a
count on 2026-09-04 made it sixteen sources and 22 formal parameters. Re-taken
on 2026-09-05 by a scan that separates a formal-parameter from a result-type,
it is **24 formal parameters in 18 sources, and one result-type** — and the
result-type had never been mentioned. That is the position ADR-0215 wrote down
as an open question and believed unwidened:

> Whether AP should widen `result-type` as well is a question of its own and is
> not answered here.

It was already widened, for this form. Nobody had asked.

**The surface is exactly one production alternative, which had to be checked
rather than assumed.** `ParseFormalParameters` hands a parameter's type to
`ParseTypeDenoter`, which parses *any* type-denoter — so the acceptance could
have been far wider than a discriminated-schema. It is not: the guard above
that call admits only an identifier, `type` and `array of`, so every other
denoter is refused with *a parameter's type must be a type name or a conformant
array schema*. An inline record, an inline subrange, an inline enumeration, a
pointer denoter, a set denoter and an inline array are each refused, in both
positions. What is accepted is a name optionally followed by a tuple, and
nothing else.

**And the semantics are a named type's, in every position.** Probed one at a
time: a value parameter copies and its `capacity` is the formal's; a variable
parameter requires the actual to possess that very type, so `string(6)` for
`string(5)` and `Box(4)` for `Box(3)` are refused; `protected var` takes it; a
procedural parameter's inner heading takes it and §6.7.3.6 compares two of them
by the type they denote; a section of two names writes the form once; the
discriminants must be constants; a capacity of zero or less is refused where it
is written. The type-name spelling and the discriminated one are one type —
`Cap5` and `string(5)` are interchangeable in both directions.

## Decision

**A discriminated-schema may be written wherever ISO/IEC 10206:1991 requires a
type-name in a parameter-form or a result-type**, and denotes the type that
schema and that tuple produce. AP 6.7.3.1.1 and AP 6.7.2.1.

Nothing in the compiler changes. What lands is the clause, the record, and the
cases that pin the acceptance.

Three arguments carry it, and they are the three the roadmap named before the
probe agreed with them.

**It takes nothing from any program.** A discriminated-schema is outside the
production it is added to, so no conforming program can have written one there
and none changes meaning — AP 6.0.1's test, met by construction rather than by
inspection.

**It is the convenience ADR-0109 says belongs here.** What it removes is a
type-definition whose only purpose is to give a capacity a name, in a scope
enclosing every routine that takes one.

**It costs nothing to state, because the addition is a type.** Every rule this
language has is stated over types, so all of them answer here without being
told about the spelling. That is why the refusal case reports rules from
§6.7.3.3, §6.4.7, AP 6.4.3.3.2 and §6.7.3.6 and not one rule of its own.

## Consequences

**The `schema-name` alternative and this one are different requirements**, and
AP 6.7.3.1.1 NOTE 2 says so because they look like two spellings of one thing.
`x: string` is ISO/IEC 10206:1991's schematic formal — the tuple is the
actual's, one routine serves every capacity, and the formal reads its
discriminants from what it was handed (ADR-0040). `x: string(5)` names one
type. A formal whose capacity is not known where it is declared is what the
first is for, which is also why the second requires constants.

**The conforming layer is unaffected and was checked.** `lib/` outside
`lib/dialect/` writes the form in no formal parameter, so ADR-0120's claim —
that a reader can port `lib/` to another Pascal — is untouched. The one shipped
module that writes it is `lib/dialect/pasjson.pas`, which is the dialect layer.

**`doc/implementation-defined.md` §6.1 loses its last undecided entry**, and it
moves to §5 with the other extensions that have a record. The section's own
sentence — *the one program shape in this document that is neither refused,
specified, nor deliberately extended* — stops being true.

**A citation is corrected.** ADR-0215 and `doc/history.md` cite §6.7.1 for
`result-type = type-name`. In ISO/IEC 10206:1991 §6.7.1 is
*Procedure-declarations* and §6.7.2 is *Function-declarations*, which
`tests/extended/typeinquiry.pas` had right. `clause-citations` cannot see this:
it asks whether a number names a clause at all and both do, and ISO 7185's
§6.7.1 is *General* — an expressions clause several records here cite
correctly, which is why the wrong one read as ordinary. The ADR is accepted and
is not edited; `doc/history.md` is.

## What this does not do

**It does not admit a type-inquiry as a result-type.** That is ADR-0215's
question left where it stood. A type-inquiry denotes the type of a
*variable-access*, so what a result-type built from one would denote depends on
which variable is in scope at the declaration and at every activation; a
discriminated-schema names a type outright and raises no such question. The two
are not one widening and should not be argued for together.

**It does not widen any other position.** A parameter's type is still not a
type-denoter: an inline record, array, set, subrange, enumeration or pointer
denoter is refused in both positions, and the clause says the addition is one
alternative rather than a relaxation.

**It changes no behaviour**, so there is no mutation of a fix to report. The
mutation is of the *acceptance*: made to refuse a discriminated-schema in a
parameter-form — which is what a conforming processor does — the compiler fails
`discriminated_form`, `discriminated_form_errors`, `binding_writable`,
`fallible`, `generic_fallible`, `lib_io`, `lib_json` and five spec scenarios.

**It does not make the form preferable.** A type-definition still reads better
where a capacity is used more than once and has a meaning worth naming;
`PasContainer`'s `MapKey` is exported for exactly that reason and stays.
