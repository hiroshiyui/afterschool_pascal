# ADR-0332: A formal is bound before its activation exists

Date: 2026-09-05

## Status

Accepted. Amends AP 6.4.14.9 with a fourth paragraph and a NOTE. ADR-0326 is
not superseded — the third way it found is real and the check for it stays;
what was wrong is the answer `CanName` gave when the routine handed over was
itself a formal-parameter.

## Context

ADR-0326 closed a use-after-free by asking `CanName` of the routine an
activation-point is *given* as well as of the one it activates. `CanName`
answers from a defining-point: a routine reaches a variable if it is declared
inside the block that declares the variable. Asked of a **formal**, that is the
formal's own defining-point, which is inside that block — so this was refused:

```pascal
procedure Holder(procedure k);
var p: ON;
begin new(p); p^.v := 7; Runner(p^, k) end;
```

That is the ordinary callback: a routine that owns something, lending a borrow
of it to the routine it was handed. Both paragraphs of the clause had it — the
callee form `r(p^)` for a procedural formal `r`, and the with-statement form
for both — so five distinct sites, and the effect was that a block owning a
variable could lend a borrow of it to nothing at all. The rule was written and
reviewed against programs whose procedural actual was a *declared* routine, and
`tests/dialect/owned_procparam_errors.pas` is entirely of that shape.

**The routine bound to a formal cannot name a variable of the activation the
formal belongs to.** An actual-parameter corresponding to a formal-parameter of
`Holder` is denoted at an activation-point *of* `Holder`, and the block
containing that activation-point has an activation that is a proper ancestor of
the one being established — a formal is bound before its activation exists. A
routine declared inside `Holder` can be denoted there, but only from within an
activation of `Holder`, and its static link is then to *that* activation, not to
the new one; the `p` it names is a different variable from the `p` the new
activation borrows.

## Decision

**A procedural or functional formal-parameter of a block does not denote a
block that can name a variable whose defining-point is in that same block.**

It is one conjunct in `CanName`, so both paragraphs of the clause get it and
neither had to be edited: `callee^.kind = skProcParam` and
`callee^.owner = v^.owner`.

**Both conjuncts are the rule and not a guard.** Dropping the second admits the
case the exemption must not reach: a procedural formal of a block nested *one
deeper* than the owner's. There the actual is denoted inside the block that
declares the variable, where a routine that can name it is in scope —

```pascal
procedure Outer;
var p: ON;
  procedure Killer2; begin dispose(p) end;
  procedure Nested(procedure k); begin Runner(p^, k) end;
begin new(p); Nested(Killer2) end;
```

— and `Nested`'s `k` is `Killer2`. That program is case 6 of the errors file and
is what the second mutation below kills.

## Consequences

**It gives back programs the clause never meant to refuse**, which is the whole
of the change: no program that was accepted is now refused, and the two cases
pin both directions.

**The exemption is about the symbol, not about the call.** `CanName` is asked
in four places and all four are 6.4.14.9; a fifth caller would inherit it, and
should, the property being about what a formal can denote rather than about
borrowing.

**A variable of the outermost block is untouched.** `CanName` answers yes on
level 0 before reaching the conjunct, and must: a routine bound to a formal can
name a global whatever else it cannot.

## What this does not do

**It does not weaken ADR-0326.** A declared routine handed alongside a borrow is
refused exactly as before, and the errors file that demonstrates it is unchanged
but for the case added to it.

**It does not make the model sound**, and NOTE 1a's argument still carries the
residue. This record is one more instance of that NOTE being probed rather than
re-read — the argument was right about which blocks obtain a routine and the
implementation of it was wrong about which block a formal is.

**It does not ask what was actually bound.** Nothing here is interprocedural:
the answer is a property of where the formal is declared, which is available in
one component and across every boundary.

## Alternatives rejected

**Ask `NestedIn` of the formal's *owner* rather than of the formal.** It gives
the right answer for the case above by accident — `NestedIn(Holder, Holder)` is
true and `callee <> v^.owner` then fails — and the wrong one for `Nested`'s `k`,
whose owner is `Nested`, nested in `Outer`. The distinction the clause needs is
which block the actual is denoted *in*, and that is the owner compared for
equality, not for nesting.

**Refuse the shape and tell the program to restructure.** The shape is a routine
lending what it owns to a callback it was handed; there is no restructuring that
keeps the ownership where it is. Refusing it makes an owned pointer unusable in
any block that takes a procedural parameter.
