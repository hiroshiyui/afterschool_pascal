# 66. A set-value is told from a subscript by the symbol

Date: 2026-08-13

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.8.7.1 gives a structured-value-constructor three forms:

> structured-value-constructor = array-type-name array-value
> | record-type-name record-value
> | set-type-name set-value .

ADR-0061 implemented the first two and refused the third, for a reason it
stated plainly: "a set is a value and needs none of this; and `sieve[2,3]`
cannot be told from `a[2,3]` without the symbol". Both halves were true. The
first is why the feature is small; the second is why it was deferred.

§6.8.7.4 is four lines:

> The type of a set-value shall be a set-type, and the set-value shall denote a
> value of that type.
> set-value = set-constructor .
> The value of the set-constructor of a set-value shall be
> assignment-compatible with the type of the set-value.

So `digits[1, 3]` is the ordinary set-constructor `[1, 3]` with a type name in
front of it, and what the name adds is a **type**. A bare constructor infers
its type from its members and the empty one has none at all (ADR-0028), which
is why `[]` needs whatever it is compared or assigned to in order to mean
anything. A set-value never does.

## Decision

**The symbol decides, in Sema.** The parser builds whichever spine the
punctuation suggests — a subscript chain for `digits[1, 3]`, a substring for
`digits[1..3]` — and `Sema::setValueTypeOf` walks down the *base* links of that
spine to its root, looks the name up silently, and answers with the set type
when the name denotes one. ADR-0053 parts a qualified name from a field
selection exactly this way, and ADR-0044 parts a variant-selector from a
tag-type; this is the third time the answer has been "ask the symbol, not the
syntax", and the first where the two readings are a *value* and a *variable*
rather than two values.

The walk is down base links only. A member-designator may be any expression,
subscripts included, and those hang off `index`, `lo` and `hi` — so
`sets[a[i]]` asks about `sets` and never about `a`.

**The spine carries the answer; it is not rewritten.** `IndexExpr::setValue`
and `SubstringExpr::setValue` hold the `SetExpr` the members were moved into,
which is `FieldExpr::qualified`'s shape and was chosen for the same reason: the
node the parent holds cannot be replaced, because `checkExpr` takes a raw
pointer and annotates in place. Every later pass reads the field first and
finds nothing else left to read — the member expressions are *moved* out of the
spine, so what remains is a husk that carries the answer.

**A set-value is not a designator, and no rule says so.** `checkSetValue`
returns before the base is ever checked, so the root `VarRef`'s symbol stays
null and `isDesignator` — which asks the base — answers false. Assignment to
one, passing one as a `var` parameter and reading into one are all refused
through the tests that were already there. That is ADR-0061's own finding
("a constructor is not a designator and needed no rule saying so") reached by a
different route, and it is why nothing was added to `baseSymbol`,
`rootDesignator` or `heapHeader` either.

**The constructor makes the check ADR-0028 said a constructor could not.**
`checkedForSetBase` carries this comment: it is "the check a set constructor
cannot make for itself, because a constructor does not know what it is being
assigned to". A set-*value* knows — the type name says so — and §6.8.7.4's
assignment-compatibility rule is exactly that check. So `digits[i]` traps on a
stray member with no assignment anywhere in the statement, where `[i]` alone
must wait for one. The trap is the existing one, emitted at the constructor
instead of at the store, and `tests/extended/trap_setvalue.pas` is the program
with no assignment in it.

**The empty `digits[]` arrives by the other road.** An empty bracket is
something a subscript list may never be, so `looksLikeStructuredValue` already
answered true for it and it reaches Sema as a `StructValueExpr` — which is why
that is the one spelling ADR-0061 could refuse by name. It is now the
null-set-value, the thing `[]` alone cannot spell.

**The parser gave up one rule, and Sema took it back.** §6.8.7.4's members are
a *list*, so `digits[1..3, 5]` must parse; §6.5.6's substring-variable is one
range and no list. The two build the same spine, so the parser now admits a
comma after a range and records on the node that one followed
(`SubstringExpr::listed`). Sema refuses it for everything that is not a
set-value. Without that flag the relaxation would quietly have made
`s[1..3, 2]` mean `s[1..3][2]` for a string — a permissive change to the
language, made silently, in a feature about sets.

## Consequences

**Two compilers, one shape.** `selfhost/compiler.pas` gains `ixSetValue`,
`ssSetValue` and `ssListed` beside `fdQualified`, and the two dumps agreed on
the first run — `setvalue` prints as its own head with the members under it and
no base, exactly as `qualified` does.

Two things the port needed that the C++ did not. `NewNode` clears Sema's fields
per kind, so `nkIndex` and `nkSubstr` had to leave its "nothing to clear"
group; and `EmitExpr` had no `nkSubstr` arm at all, its catch-all not listing
that kind either, so the case was not exhaustive over `nodeKind` before this.
A Pascal `case` traps at run time on a missing arm, which is the failure this
would have been.

**`verify/` gained nothing**, and that is right rather than convenient: no
arithmetic is new, the members go through the same `setIndex` bounds check they
always did, and the one error condition is `checkedForSetBase` moved to a
second call site. A rule restating where an existing check is called from would
be the kind ADR-0013 warns against.

**A set-value is nonvarying when its members are**, so §6.6's
`digits value digits[1, 3..4]` is an initial state. `nonvarying` had no case for
a subscript spine at all and fell through to false, which is the right answer
for a subscripted variable and the wrong one for this — so the two spine kinds
each answer through their `setValue` and are varying without one.

**It reserves nothing.** No word-symbol, no required identifier: a set-value is
punctuation and a type name the program already declared. The fourth such
feature, after `and then`, `type of` and set-member-iteration.

**§6.8.8's structured constants are what is left**, and they are not this. A
constant-access reads a *component* of a constant that has a structured value —
`c[i]` for a `const c = t[1: 1; 2: 2]` — where the index need not be constant
at all (§6.8.8.1's own NOTE says so). That needs constants with structure to
live somewhere, which is a different mechanism from anything here.

### What this does not do

**A set-value of a schematic set type is not possible**, and nothing was
written to prevent it: §6.4.7's schema produces array, record and string types,
and a set is none of them, so `setValueTypeOf` cannot find a schema where it
looks for a `SymKind::Type`.

**The set-value's type name is not checked for being *only* a set type.** A
name that denotes an array type followed by a bracket is an ordinary subscript
of a type name and reports what it always did — `'vec' is a type and has no
value`. The two diagnostics differ, and the second is the older and vaguer one;
nothing routes an array-type name into the set-value path in order to say
something better, because the tokens genuinely are a subscript's.
