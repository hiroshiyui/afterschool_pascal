# ADR-0112: A record is a region at every occurrence

## Status

Accepted.

## Context

ADR-0098 established that a record-type is a region: §6.4.3.3 gives a
field-identifier its defining-point in "the region that is the record-type
closest-containing the field-list", and §6.2.2.4 makes the scope of a
defining-point the whole of its region "and all regions enclosed by that
region". So inside a record type-denoter, a spelling that is one of its fields
is an applied occurrence of the *field*, whatever else the program declared
under that name outside.

It was implemented in one place — `resolvePointer` — because that is where the
BSI Validation Suite's DEV043 pointed. `^fred` beside a field `fred` was
refused; every other occurrence of a type-name inside the record was not:

```pascal
r1 = record a: fred;  fred: integer end;                { accepted }
r2 = record b: array [idx] of integer; idx: 1..2 end;   { accepted }
r3 = record d: set of base; base: 1..2 end;             { accepted }
r4 = record f: integer; integer: real end;              { accepted }
```

ADR-0101 recorded the gap and `doc/implementation-defined.md` §6.1 has carried
it since as the one rule of ISO 7185 a program could break here without being
told. `doc/sop.md` §7 had it as a live blind spot.

The clause names no production. It is a statement about which region a spelling
belongs to, so enforcing it at one occurrence and not the others is not a
partial reading of the rule — it is a different rule, one about pointers.

## Decision

**The region is asked wherever a name is resolved inside a record's denoter,
and the three occurrences ask through one function.**

`fieldOfOpenRecord(qualifier, name)` is the whole of it: scan the stack of open
record denoters, answer whether the spelling is a field of any of them. It is
called from

- a pointer's domain-type (§6.4.4), which is where it already was,
- a type-name (§6.4.1), which covers a field's own denoter, an array's
  index-type and component-type, a set's base-type and a file's
  component-type — every one of them is a `type-name` occurrence and none of
  them needed a case of its own, and
- a schema-name (§6.4.8), because the clause does not care which production the
  occurrence sits in.

**It is asked before the lookup, not after it.** A field's defining-point is
nearer than anything the lookup would find, including the region enclosing the
program where the required identifiers live (§6.2.2.10, ADR-0097) — so a field
named `integer` takes that spelling inside its own record and `f: integer` is
refused there. Resolving first and testing afterwards would have made the
answer depend on whether a type of that name happened to exist.

**One message, written once.** `errorFieldNotAType` is the only place the words
are, so three call sites cannot drift into three phrasings of one rule.

## Consequences

**§6.1 of `doc/implementation-defined.md` is now empty.** It listed one rule of
ISO 7185 that a program could break without this compiler saying so, and that
was this one. The section stays, because what it records is a *kind* of finding
and the next one belongs there.

**A program that compiled may now be refused**, and it is a narrow class: one
that uses a type-name inside a record type-denoter and also has a field of that
spelling. Called out in `CHANGELOG.md`.

**Two of the new diagnostics arrive with a second message behind them.** An
index-type and a set base-type each get a further complaint once the name has
not resolved, because both fall back to `integer` to keep the tree checkable.
That cascade is not this rule's: an *unknown* type in either position has always
produced the same pair, and `tests/record_region_field.pas` says so in a comment
rather than the golden looking like a defect.

**What this does not do.** It does not reach an occurrence that is not a name
being resolved as a type. A *constant* occurrence — `array [1..fred]`, or a
field's initial-state expression naming a field — goes through the expression
checker and is not asked, so a program can still write one and have it mean
whatever `fred` means outside the record. The clause covers those too. They are
a separate change because the expression checker resolves names for a different
purpose and the fallback on failure is a different thing; §6.1 records what is
left rather than the section being emptied and the remainder forgotten.

## Alternatives rejected

**Add the scan at each occurrence separately.** Five call sites, each with its
own copy of the loop and its own copy of the message, and each free to be
forgotten when a sixth production is added. The single function is also what
makes the *next* occurrence a one-line change.

**Resolve the name first, and reject only when it resolved to something
outside.** It reads as the smaller change and it is the wrong rule: `record f:
integer; integer: real end` would then be accepted, because `integer` resolves
perfectly well in the region enclosing the program. §6.2.2.4 is about which
defining-point is in scope, not about whether some other one exists.

**Enter the fields into a scope and let the ordinary lookup find them.** That is
how a region is modelled everywhere else here, and it cannot be done at this
point: the fields do not exist as symbols yet — the record is being resolved,
which is exactly ADR-0098's reason for asking the *denoter*. Building a
throwaway scope from the denoter first would be a second representation of the
field list to keep in step with the real one.
