# 58. A restricted type is a type kind

Date: 2026-08-12

## Status

Accepted. The *reason* its passing rule gives is superseded by
[ADR-0115](0115-a-string-value-parameter-is-converted-by-the-callee.md):
there is somewhere to build the conversion now, so a `restricted string(12)`
value parameter is refused pending a reading of whether a restricted value
may be copied at all, rather than for want of a mechanism. The rule itself,
and the point that a restricted type does not launder a rule about passing,
stand.

## Context

ISO/IEC 10206:1991 §6.4.2.5:

> A restricted-type shall denote a type whose set of states is associated
> one-to-one with the states determined by another type, designated the
> underlying-type of the type denoted by the restricted-type.
>
>     restricted-type = 'restricted' type-name .

So a restricted type has the underlying type's values and the underlying type's
representation. What it does not have is the underlying type's *operations*,
and the clause's NOTE says exactly which four survive:

> A value of a restricted-type may be passed as a value parameter to a
> formal-parameter possessing its underlying-type (see 6.7.3.2) or returned as
> the result of a function (see 6.9.2.2). A variable of a restricted-type may
> be passed as a variable parameter to a formal-parameter possessing the same
> type or its underlying-type (see 6.7.3.3). **No other operations, such as
> accessing a component of a restricted-type value or performing arithmetic,
> are possible.**

Together with the two sentences about attribution, that is: assign to and from
the underlying type, pass by value, pass by reference, return.

The standard's own example is a module that exports `widget = restricted
realwidget` and not `realwidget`, so a user of the interface can hold widgets
and hand them on and do nothing else with one.

## Decision

**A restricted-type is its own `TypeKind`, and that is the enforcement.**
`isInteger`, `isOrdinal`, `isArray`, `isRecord`, `isStringType`, `isNumeric`
and the rest all answer `false` for one, so arithmetic, comparison, indexing,
field selection, `write`, `read`, a `case` selector, a `for` control variable,
`ord`, `succ` and every other operation refuse it through **the diagnostic each
already had**, naming the type. Nothing enumerates what is forbidden.

This is the third time this project has reached for refusal-by-construction:
ADR-0044's variant-selector has no storage so nothing can assign to it, and
ADR-0046's `new(p)` needs no protection check because a pointer is
unprotectable. The test of whether it was done in the right place is that
`tests/extended/restricted_errors.pas` produces seven diagnostics and six of
them were written for other features.

**Two predicates see through, and only two.** `isStructured` and `isMemory`
answer for the underlying type, because *how a value travels* is not an
operation the program performs — a restricted record must be copied and passed
by address exactly as the record is. `llvmType` follows for the same reason,
and it is the only line CodeGen gained.

**The one refusal that had to be written down is the comparison**, and it had
to be written down *because* the assignment rule exists. §6.4.2.5's first two
sentences make a restricted type and its underlying type assign to each other,
so `assignable` learned about them — and a relational operator asks
`assignable`. Without a line of its own, `n = 3` would ride in on the
assignment's permission. That is the shape to remember: a permission granted in
a shared predicate leaks to every caller of it.

**Two restrictions of one underlying type do not assign to each other.**
§6.4.2.5 permits attribution between a restricted type and *its* underlying
type and says nothing about a second restricted type, so ADR-0017's name
equivalence stands and exactly one side of the rule may be restricted. The
same-type case is answered before this one, which is what leaves it to say.

**The var-parameter rule is a widening, not a compatibility.** §6.7.3.3's
same-type requirement exists because nothing is converted through a reference,
and here nothing is: the representation is the underlying type's. It goes one
way only — a variable of the underlying type may not be passed where the
restricted one is expected, or the restriction would be escapable by declaring
one parameter.

**The initial state is handed on** (§6.4.2.5's last sentence), by the same
`initialStateOf` a type-name uses (ADR-0048); the states are one-to-one, so the
expression needs no adjusting on the way through. **`bindable restricted` is
refused**, because §6.4.2.5 makes the bindability nonbindable. **A restricted
file is refused**, because §6.4.2.5's NOTE leaves a file no permitted operation
at all — a file is never assigned, never a value parameter and never a result.
**Restricting a restricted type is refused**, because every type already has an
underlying type and a second wrapper would have nothing to tell it from the
first.

## Consequences

`verify/` gained nothing and no lowering changed.

**The word costs the ISO 7185 corpus nothing and the Extended corpus a name.**
`restricted` is not reserved in ISO 7185, so `tests/restricted_iso.pas` is a
legal program that uses it as a variable — the opposite shape from ADR-0056's
ISO gate, where a notation had to be *refused*. Under `--std=extended` the
program `Restricted` could not be called that, which is ADR-0048's "the first
reserved word to cost the corpus something" for the second time.

**It is the first word-symbol too long for the Pascal lexer's keyword table.**
`kwLit` is nine characters wide — the longest ISO 7185 word-symbol — and
`restricted` is ten. Widening it would repad 188 literals across the file for
one word, so `restricted` is recognised by one comparison beside the table
instead, with a `StrIsWide` matching the `PoolIsWide` that already exists
because ISO/IEC 10206:1991 has *identifiers* the table cannot spell
(`lastposition` is twelve). The token dump then writes its spelling out
literally, in the same arm `and then` and `or else` use for the same reason:
they are in no table either (ADR-0038).

**A diagnostic cannot contain a section sign.** The C++ message was written
with `§6.4.2.5` and the Pascal one cannot be — `char` is a byte (ADR-0021) and
the source would carry two of them. `difftest` reported it as a one-character
disagreement, which is the cheapest way that lesson has ever arrived.

**Assignment unwraps; passing does not.** `emitStore` takes the underlying
type of both sides before it asks anything, which is §6.4.2.5's attribution
sentence written once and covers a restricted record, array, string and scalar
alike. It had to be written: `isStringType` deliberately does *not* see
through — that predicate grants the string *operators* — so without the unwrap
a restricted variable-string missed the string path and stored a scalar over
the length word. `emitString` asks the same question for the same reason.

That unwrap then made the two see-through predicates invisible to every
assignment, and the only programs that can still tell them apart are the ones
that ask **how a value travels**: a value parameter of a restricted record, and
a function returning a restricted string. Both are in the corpus now, and each
was added because a mutation of the predicate survived without it.

**A restricted type does not launder a rule about passing.** ADR-0052 refuses a
variable-string *value* parameter — it would need a conversion and there is
nowhere to build one — and `restricted string(12)` needs exactly the same
conversion. The check asks the underlying type; before it did, such a parameter
was accepted and read a garbage length.

**The port found a latent hole in `ForgetResolved`.** The Pascal denoter walk
had no arm for `nkInquiry` either, so a type-inquiry inside a schema body would
have trapped; it is complete now. Nothing reached it, and nothing was looking.

### What this does not do

**Nothing about modules.** §6.4.2.5's whole purpose is a type-name exported
without its underlying type (§6.11), and that works — an interface exports
symbols, and a restricted type-name is a symbol like any other. But no test
exercises the combination, because the feature is orthogonal and the module
tests are about §6.11.

**A restricted type is not protectable-aware.** §6.4.1 decides protectability
from what a type *is*, and a restricted record answers as a record does, which
is the right answer for the wrong reason — `protectable()` looks at the kind
and would need to see through as `isStructured` does. No program can tell,
because a restricted variable cannot be threatened in any way a protected one
would forbid, but the code does not say so.
