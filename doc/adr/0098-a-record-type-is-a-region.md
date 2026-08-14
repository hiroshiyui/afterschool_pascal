# 98. A record type is a region

Date: 2026-08-15

## Status

Accepted.

## Context

ISO 7185 §6.4.3.3 gives a field-identifier's defining-point "the region that is
the **record-type** closest-containing the field-list", and §6.2.2.4 makes the
scope of a defining-point the whole of its region "and all regions enclosed by
that region". So inside a record type-denoter, a name spelled like a field of
that record — or of any record it is written inside — is an applied occurrence
of the **field-identifier**, and §6.4.4's `domain-type = type-identifier` has
nothing left to bind to.

This compiler accepted it, because **record fields never enter the scope
stack**: `AddField` puts them on the type and `FindField` is the only reader.
So `ptr : ^fred` beside a field `fred` found no `fred`, pended, and
`ResolvePendingPointers` later resolved it to a *type* of that name. BSI's
DEV043, and the last of the twenty-seven.

## Decision

**The question is asked of the record *denoter*, not of the record type.** At
the moment `^fred` is resolved the field `fred` does not exist on the type yet —
it is further down the same field-list and exists only in the parse tree. So
`ResolveRecord` pushes its denoter node onto a stack while it resolves its
fields, and `ResolvePointer` asks that stack before it looks anything up.

**All enclosing records, not the closest.** §6.2.2.4's "and all regions enclosed
by that region" is explicit, so a record nested inside another sees the outer's
fields too. The stack is walked to the bottom.

**It is a separate question from §6.2.2.9 and asked before it.** ADR-0088
exempts an unqualified pointer domain from the applied-occurrence check, and
that exemption is untouched: §6.2.2.9's exception is about a defining-point not
having to *precede* the domain, and says nothing about which region an
identifier belongs to. The lookup path below the new test — `LookupRaw`, the
in-type-part pend, `ResolvePendingPointers` — is byte-identical.

**A qualified domain is not asked at all.** `m.t` names an interface
constituent (§6.11.3) and cannot be a field, so asking would be wrong rather
than merely redundant.

## Consequences

**466 cases pass and the compiler still compiles itself**, which is nearly free
here: it contains no inline pointer type-denoter at all — every pointer type is
a named `xPtr = ^xRec` — so the stack can never fire during self-hosting. The
risk was entirely in the new code being wrong, not in what it rejects.

**The test carries three legal pointer domains among the five errors.** A check
about *fields* is one sentence away from a ban on pointers inside records, and
`ok1`, `ok2` and `ok3` are what keep it honest.

**Both halves are pinned by mutation.** Making the field walk answer false kills
the new test; asking only the closest record kills the test *and* the suite —
so the "all enclosing regions" reading is load-bearing rather than cautious.

**A variant arm's field-list is a field-list**, so the walk recurses through
every arm and counts a tag-field as the field §6.4.3.3 makes it. That fell out
of the shape the parser already builds (ADR-0026) and needed nothing new.

### What this does not do

**It does not put fields in a scope.** They are still reached by `FindField`
alone; what was added is a question about a denoter, asked in one place. Putting
fields in the scope stack would answer this rule and several others at once, and
would change what every unqualified lookup inside a record means — a much larger
change than the clause requires.

**It does not fix the type-name alias**, met again here: a variant part tagged
`integer` reports its type as whatever alias was last defined, because the
simple types are shared singletons and the alias is recorded on the type.
Recorded in `doc/implementation-defined.md` under ADR-0097.
