# 88. A defining-point precedes its applied occurrences

Date: 2026-08-14

## Status

Accepted.

## Context

ISO 7185 §6.2.2.9:

> The defining-point of an identifier or label shall precede all applied
> occurrences of that identifier or label contained by the program-block with
> one exception, namely that an identifier can have an applied occurrence in
> the type-identifier of the domain-type of any new-pointer-types contained by
> the type-definition-part containing the defining-point of the type-identifier.

§6.2.2.8's NOTE is the same sentence from the other side: within the scope of a
defining-point there are no applied occurrences of an identifier that cannot be
distinguished from it and whose own defining-point is in an enclosing region.

**This compiler enforced it only where the name resolved to nothing.** ADR-0069
made `var v: t` before `type t` the forward reference the clause says it is,
which works because an unknown name is visibly unknown. Where the name resolved
to an *enclosing* declaration nothing looked wrong: the earlier uses kept the
outer meaning, the later declaration took effect from its own position, and one
name had two meanings in one block with no diagnostic.

The BSI validation suite (ADR-0086) has nine programs of that shape, which made
it the largest single gap in `doc/implementation-defined.md` §6.1 — a constant
in its own definition, a type in its own, a procedure called before a nested
redeclaration, a parameter shadowing a type its own list had used.

## Decision

**A symbol records when it was last applied; a block records the counter when
it was entered; the check is one comparison.**

- `applySeq` counts applied occurrences and nothing else. `Lookup` bumps it and
  stamps the symbol it found.
- `scopeMark[d]` is `applySeq` when the block at depth `d` was entered.
- `Declare` asks whether the *outer* symbol of that spelling has been applied
  since this block was entered, and refuses the declaration if it has.

**The latest application is enough**, which is what keeps this to one integer
per symbol rather than a list. The check runs at a defining-point, so nothing
later in the program has happened yet; if the newest application is not inside
this block, none is.

**The comparison is with the block, not with the depth.** A sibling procedure's
body is at the same depth and is not contained by this block, and shadowing
there is exactly what the rule permits — `tests/definingpoint_order.pas` leads
with two procedures that must *not* be reported, before any that must.

**`Lookup` and `LookupRaw` are split rather than given a flag.** Every
resolution of a name the program wrote goes through the first; the places that
ask whether a name is *taken* — `Declare` itself — go through the second.
Asking the second question through the first would record an applied occurrence
for a defining one and refuse every redeclaration in the language.

## Consequences

**Five of the nine are now refused**, and the compiler still compiles itself:
24,600 lines of Pascal are the false-positive test that matters, and 449 cases
passed unchanged.

**The one false positive was the standard's own exception, and the test for
another feature caught it.** A pointer's domain may name a type defined later
in its own type-definition-part, so that occurrence is precisely the one a
defining-point need not precede. `ResolvePointer` therefore looks the name up
*without* recording an application — and it was `tests/pointer_domain_shadow.pas`,
written the same day for ADR-0087's neighbouring fix, that went red and said so.
A clause with an exception in it is a clause where the exception needs a test.

**Four remain, and three share one cause with ADR-0087.** DEV112, DEV264 and
DEV265 use a required identifier — `ord`, `integer` — before the program
declares one. The earlier occurrence resolves to a *builtin*, which this
compiler recognises by name and which is not a symbol, so there is nothing to
stamp. That is the same seam ADR-0087 narrowed for the read/write family, met
from the other side, and the real answer is the one that record stopped short
of: declare the required identifiers as symbols in an outermost scope. Then
§6.2.2.9, §6.2.2.10 and the gap below all fall out together. DEV043 is
unrelated — a field-identifier and a type-identifier of one spelling — and the
occurrence it turns on is the pointer-domain one this record exempts.

**A required *type* cannot be redeclared at all**, which was found while
sizing that work and is worth recording as its own gap: `type integer = char`
is accepted, and `var v: integer` still resolves to the built-in type, because
`BuiltinType` is consulted before the scope in a type-denoter. §6.2.2.10 makes
required identifiers behave as if declared in a region enclosing the program,
so the program's definition should win — as it already does for a required
*function*, which `tests/` now shows working. Recorded in
`doc/implementation-defined.md` §6.1; not fixed here.

### What this does not do

**It does not enforce the rule for labels**, which §6.2.2.9 names alongside
identifiers. A label is a number rather than a name and does not go in a scope
(ADR-0029), so it has no symbol to stamp; two blocks may each declare label 1
and nothing about that changes.

**It does not report *which* earlier use conflicts.** The symbol keeps one
counter, not a position, so the diagnostic names the declaration and not the
occurrence that precedes it. Keeping the position instead would cost nothing
and is worth doing when someone has a program where it would have helped.

**It does not make an unused enclosing name a shadowing hazard.** A block that
declares a name it never used before is unaffected, which is the overwhelming
majority of shadowing and is legal.
