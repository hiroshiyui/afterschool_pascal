# 225. A capacity outside the schema's domain

Date: 2026-08-27

## Status

Accepted.

## Context

ADR-0224's audit returned one under-strict finding, and it is a clean
conformance defect.

ISO/IEC 10206:1991 §6.4.3.3.3, on the required schema `string`:

> Each tuple in the domain of the schema shall have one component that is a
> value of integer-type **greater than zero**, and the component shall be
> designated the capacity of the variable-string-type produced from the schema
> with the tuple.

So a capacity of zero or less puts the tuple outside the schema's *domain*, and
§6.4.8 says what that is:

> It shall be **a dynamic-violation** if the tuple is not in the domain of the
> schema.

A dynamic-violation is not an error, and the difference is the whole of this
record. §3.1:

> **Dynamic-violation** — A violation by a program of the requirements of this
> International Standard that a processor is permitted to leave undetected **up
> to, but not beyond, execution of the declaration**, definition, or statement
> that exhibits the dynamic-violation.

and §5.1 f)'s NOTE 1 leaves no room:

> Dynamic-violations, like all violations except errors, **must be detected**.

**Sema catches it where the tuple is a constant.** `var x: string(0)` has been
refused with *the capacity of a string must be greater than zero, found 0*
since the type was built. Where a discriminant brought the capacity, nothing
did:

```pascal
procedure g(n: integer);
var x: string(n);
begin x := ''; writeln('cap=', x.capacity:1) end;
begin g(0); g(-1) end.
```

`g(0)` printed `cap=0` and ran on. `g(-1)` was reported only by the later
assignment's own capacity check — *a string of length 0 does not fit a capacity
of -1* — which is well past the declaration §3.1 names, and only because
something happened to be stored.

**AP 6.4.15.1's `utf8` had the same hole and it was worse.** The dialect's text
schema carries the same "greater than zero" requirement, and §6.4.8 reaches it
unchanged because the dialect contains Extended Pascal. But no store on the
text path asks about the capacity's sign, so `utf8(-1)` ran to completion and
reported nothing at all.

## Decision

`CheckSchemaDomain` gains an arm. That routine already walks a produced type at
the declaration and emits a domain check for an array with dynamic bounds, for
a record whose dynamic part is last, and — since ADR-0133 — for a subrange with
discriminant bounds. A string was simply not among the kinds it knew.

The two kinds share the arm because they share the shape: `hi` holds the
capacity and `hiDisc` the discriminant it came from, which is the same pair
`tySubrange` and `tyArray` use, so `BoundValue` already answers for it. They
differ only in the noun, and that is the same pair of words Sema uses on the
static path — a defect reads the same whether it is caught before the program
runs or during it.

**It asks `IsStringRep`, not `IsVarString`.** ADR-0191 split those two for a
reason and this is a storage question: the value is a length and that many
bytes, which a text and a variable-string answer alike. Asking `IsVarString`
would have left the text hole open, and every string case would still pass —
which is `0225-text-capacity-domain-unchecked.mut`.

A canonical-string-type is excluded by the `hiDisc` test rather than by a kind
test: it has no capacity and no discriminant, `hi` being negative (ADR-0051).

## Consequences

**Two cases, each failing without the change**:
`tests/extended/trap_string_capacity.pas` and
`tests/dialect/trap_text_domain.pas`. Each makes the legal call first, so a
check that fired too eagerly would fail at the wrong line.

The dialect case is named `trap_text_domain` and not `trap_text_capacity`
because that name was taken, by AP 6.4.15.5's case — a text *value* too long
for its capacity. The two are worth keeping apart in the naming: one is a fault
in the data, the other in the declaration.

**Two scenarios under `@extended:6.4.8`**, both halves of the bound: a capacity
outside the domain is reported at the declaration, and one the domain admits is
not. The clause was already cited; the audit is what makes these worth writing,
since the reading behind them has been attacked rather than merely asserted.

**This arm is invisible to `kind-exhaustive`'s chain half** (ADR-0221), and
that is worth recording on the day it happens. The gate selects a chain by the
shape `x^.kind = c`, and this arm dispatches on a *predicate*. So
`CheckSchemaDomain` still records `chains 3 of 21` and the catalogue did not
move. `doc/sop.md` §7's row — a dispatch that is neither a case-statement nor a
tag chain — is exactly this, written the day before it was needed.

## What it does not do

It checks the capacity **at the declaration**, which is where §3.1 stops
permitting the violation to hide. A tuple that reaches a type by another route
is a separate question: `new(p, 0)` and a schematic formal bound to a bad
capacity are not covered here, and neither was probed. The audit found this one
through a variable declaration and this is the fix for that path; claiming more
would be claiming something nobody measured.

It also says nothing about the *other* two findings ADR-0224 records — the
string-valued constant-expression and the real-valued one. Both are
over-strictness rather than under-strictness, both are recorded in
`doc/implementation-defined.md` as restrictions under §5.1 c), and each is its
own change.
