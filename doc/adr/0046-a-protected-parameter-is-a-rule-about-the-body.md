# 46. A protected parameter is a rule about the body

Date: 2026-08-11

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.7.3.1 allows `protected` before a value- or
variable-parameter-specification:

```pascal
procedure illustrate(a : integer;            { value param }
                 var b : integer;            { variable param }
       protected     c : integer;            { protected value param }
       protected var d : integer);
```

The standard's own note explains why the word is not redundant on a *value*
parameter, where the caller cannot see the change anyway: "It indicates to the
reader and the processor that the value cannot change within the procedure."

This is the first Extended Pascal feature here that adds no way to write
anything down. It removes one.

## Decision

**`protected` is a Sema-only property of a parameter symbol.** Nothing after
Sema reads it: a protected `var` parameter is still an address, a protected
value parameter is still a copy, the calling convention is untouched, and
CodeGen never asks.

Three rules, and the standard puts each in a different clause.

**§6.5.1 is the whole enforcement**: "No statement shall threaten a
variable-access closest-containing a protected variable-identifier." §6.9.4
defines *threatens*, and every entry on its list is a place this compiler had
already decided the argument was a *variable* — so each check sits beside an
existing `isDesignator` test rather than in a walk of its own. What is checked:
an assignment's target, a `read`/`readln` target, and an actual var parameter.

**"Closest-containing" is the walk `baseSymbol` already made.** A subscript and
a field selection stay inside the same variable; a dereference leaves it.
Nothing is lost at the dereference, because §6.4.1 makes a pointer type
unprotectable and so a protected parameter can never be one.

**§6.4.1's protectable types are a predicate on `Type`**: not a file, not a
pointer, and not a structure holding either. The standard gives both reasons in
a NOTE, and both are about protection being *ineffective* rather than
ill-defined — nearly every operation on a file modifies it, and a pointer's
value can be copied out of the protected variable and disposed of through the
copy.

**§6.7.3.6 makes it part of a procedural parameter's signature**: "Either both
contain protected or neither contains protected." That is one line in
`congruous`, and it is deliberately symmetric — a body that writes its
parameter may not stand in where a protected one was promised, which is the
direction that is easier to forget.

## Consequences

**Passing a protected parameter on is legal exactly when the formal is also
protected**, which is §6.9.4 b)'s "corresponding to a formal variable parameter
that is **not** protected". Without that clause the feature would be unusable:
a protected parameter could not be given to any procedure taking it by
reference. With it, protection forwards, and `congruous` is what keeps a
procedural parameter honest about doing so.

**A `with` had to be told.** §6.9.4 i) propagates a threat through a
with-statement's field-designators, and a `with` is precisely where a protected
variable's name stops being written down — so the hidden binding ADR-0017 makes
carries the protection, or `with p do f := 1` would slip past a rule `p.f := 1`
obeys. The diagnostic there names no variable, because the binding's name is a
frame slot's and not the program's.

**§6.9.4 e), `new(p)`, is enforced by construction and needs no check** — the
same shape as ADR-0044's dynamic-violation. A pointer is unprotectable, so no
designator reaching `new` can have a protected variable under it. The code says
so where the check would have gone, so that the absence reads as a decision.

**Nothing is proved.** `verify/` states properties of emitted arithmetic, and
this feature emits nothing; there is no lowering to model. Two records running
now, and for the same reason each time.

**Twenty mutations across both compilers, all caught.** One needed a case the
corpus did not have — a protected parameter of an *array of pointers*. A record
holding one was already there, and it is a different answer: a record checks its
fields, an array checks its element, and neither implies the other.

The mutation harness itself had a defect this feature found: after restoring a
C++ mutation it did not rebuild, so the *next* Pascal mutation was compared
against a compiler still carrying the C++ defect, and the two agreed. That is
the stale-artifact trap that has now appeared three times in this project in
three different disguises. The harness rebuilds on restore.

## What this does not do

`protected` is accepted **only on a parameter**. §6.11.2 also allows it in an
export-clause, and §6.7.3.7.1 on a conformant-array parameter; the first waits
for modules and the second for conformant arrays. The enforcement path is
already the one both would use — a flag on the symbol and §6.9.4's list — so
neither needs a second mechanism, only a second place to set the flag.

`protected` is now a reserved word under `--std=extended`, which is the cost
ADR-0033 said each feature would pay when it landed.
