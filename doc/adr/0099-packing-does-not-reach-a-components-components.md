# 99. Packing does not reach a component's components

Date: 2026-08-15

## Status

Accepted. Completes §6.6.3.3, which ADR-0092 left two-thirds done.

## Context

ISO 7185 §6.6.3.3, last paragraph — word for word ISO/IEC 10206:1991 §6.7.3.3's,
so **nothing here is gated on the standard**:

> An actual variable parameter shall not denote a field that is the selector of
> a variant-part. An actual variable parameter shall not denote a component of a
> variable where that variable possesses a type that is designated packed.

ADR-0092 landed the third restriction — a parenthesised actual — and recorded
these two as not done. They are the last two DEVIANCE programs the BSI suite did
not refuse.

## Decision

**A field is the selector when the record's variant part names its index.**
`ResolveVariantPart` sets `tagField := FieldCount(fields)` and then hands that
same number to `AddField` as the field's `index`, so the tag-field's index *is*
the record's `tagField` at that path and one comparison decides it.
`TagFieldAt` answers −1 for a tagless part and for a discriminant-selected one
(ADR-0044), which no field index can equal, so both are excluded without a case.

**A packed component means the *immediate* container, and no further.** This is
the part worth reading twice, because the obvious implementation is wrong.
§6.4.3.1:

> The designation of a structured-type as packed shall affect the
> representation in data-storage of that structured-type only; i.e., if a
> component is itself structured, the component's representation in
> data-storage shall be packed only if the type of the component is designated
> packed.

So packing does not propagate inward. `pa[1].f` over a `packed array [1..3] of
urec` is a component of `pa[1]`, and `pa[1]` is an unpacked record — the token
`packed` in front of `pa` never designated it. Walking the whole designator and
refusing if anything on the chain is packed is a *different rule*, and refuses a
legal program.

**The multi-dimensional abbreviation is not an exception**, which is what makes
the narrow reading safe: §6.4.3.2 designates every array-type the abbreviation
constructs packed when the original is, and `ResolveArray` already does that —
so `a[1][2]` over a `packed array [1..3, 1..3]` is caught by the immediate
container anyway.

## Consequences

**467 cases pass**, and this closes the last two: every DEVIANCE program in the
suite is now refused except one that traps at run time, which is that category's
other correct outcome.

**It found a non-conforming program in this repository.**
`tests/extended/bindprogparam.pas` passed `bnd.name` to a `var` parameter, and
§6.4.3.4 requires `BindingType` to be "a record-type designated packed" — so the
call was illegal from the day ADR-0052 wrote it, twice, with every oracle
agreeing. `WriteTail` now takes the record. What that costs is the schematic
`var s: string` formal it used to demonstrate, which
`tests/extended/string.pas` demonstrates instead. **The same trap is loaded for
`TimeStamp`**, which §6.4.3.4 also designates packed; no test passes one of its
fields by reference today.

**Only the new test distinguishes the two readings of the packed rule.**
Implementing the walk instead of the immediate container leaves all 812 BSI
programs unmoved and fails `tests/varparam_restrictions.pas` alone — on
`TakeInt(pa[1].uf)`, the one line written for it. A corpus of 812 programs from
1982 does not contain the case, which is ADR-0067's rule again: a claim no test
names is a claim nothing checks.

### What this does not do

**It does not check ISO/IEC 10206:1991 §6.7.3.3's third sentence** — a component
of a string-type. Its fixed-string half comes free, a fixed-string-type being a
packed array of char; a component of a *variable*-string is not checked, and is
now the only unenforced sentence of that clause.
