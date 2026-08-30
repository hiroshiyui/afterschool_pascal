# 260. A map is keyed by whatever a program names, and no constraint was needed

Date: 2026-08-30

## Status

Accepted, 2026-08-30.

It closes `doc/roadmap.md`'s *a hash of anything but a string* row, and
**corrects the reason that row gave** for why it was open.

## Context

The row read:

> **a hash of anything but a string** | `PasMap` maps `string(n)` to `integer`
> | Which is the container row above, one step on: a generic map needs growth
> on the heap *and* a way to say that a key can be hashed and compared — the
> second being a constraint, and the dialect has none.

So the item was filed as waiting on a **language feature**. It was not.

## Decision

`PasContainer`'s `Map` takes its key type as a schema argument —
`Map(K: type; V: type; cap: integer)` — and every operation takes the hash and
the equality as **procedural parameters**.

**No constraint is required, and the probe is the argument.** §6.7.3.4 and
§6.7.3.5 have admitted a procedural parameter since ISO 7185; `PasSort` has
used exactly this shape since it was written, precisely so it never sees an
element; and a formal procedural parameter may be handed on as another generic
routine's actual, which is the whole of what a hash table's internals need.
What a constraint would buy is not the capability but the two arguments per
call, which is an ergonomic question and not an expressive one.

**Two features that landed for other reasons are what make it cost little.**
The key's type is written `type of m^.slots[1].key` — AP 6.4.9 as ADR-0215
widened it — so it is read off the map the caller handed over rather than
named again. And AP 6.7.3.10.4 infers `Ptr` from `m` (ADR-0254), so
`MapPut(m, 'k', 1, StrHash, StrEq)` names no type at all. Only `MapGet` and
`MapKeyAt` still need one written, their element types standing solely in a
result that §6.7.1 makes a type-name and not an actual.

**The type-inquiry is not a convenience here; it is what makes the design
work.** Binding `K` as an ordinary type parameter was tried first and failed
in a way worth recording: inference then took `K` from the *actual key*, so
`MapPut(m, 'k3', …)` bound it to the literal's own string type rather than to
the map's, and every hash was refused as incongruent. Reading the type off the
container also makes the *hash's* own parameter type follow the map, so a hash
written for the wrong key type is a §6.7.3.6 congruence error rather than
something accepted and quietly misused.

## Consequences

**It uncovered a compiler defect, and the defect is the more valuable half.**
ADR-0211 runs `ForgetResolved` over a generic's heading once per instantiation
— ADR-0039's remedy, because a resolved denoter caches its type and the second
translation would otherwise read the first one's. The loop walked `grType`,
and a **procedural** group has none: its types are in a formal-parameter-list
of its own and in its result. So a generic taking a procedural parameter whose
own parameter type is a type-inquiry read the previous instantiation's answer,
and the actual was refused against a type appearing nowhere in the activation
being complained about.

`ForgetFormals` walks both, and recurs, a procedural parameter being able to
take one itself. `tests/dialect/generic_procparam.pas` is the case and
`lib_container` catches the same mutation.

**Nothing could have found it before.** The omission is invisible unless a
procedural parameter's type *depends on the tuple*, which needs a type-inquiry
inside a procedural parameter — a combination no source in this tree had. It
was found by writing the client, which is ADR-0182's lesson and ADR-0116's:
the module is what asks the question a gate cannot.

**And the diagnostic that found it is one day old.** ADR-0259's attribution
line is what pointed at the second activation; without it the report named a
type from an activation the reader was not looking at, with nothing to connect
them.

**A hash in this language must reduce as it goes**, and the test says so
because the first version of it did not. Integer overflow traps here
(ADR-0014) rather than wrapping, so the `k * <large odd constant>` a hash is
written with in C stops the program on the first key large enough — `999 *
2654435` is past `maxint`. `StrHash` reduces by a prime at every step and the
case's own `NumHash` now does too.

**`MapKeyAt` is meaningful only where `MapLiveAt` is true**, and that is now
stated rather than implied. A slot that never held a pair has a key that was
never written; there is nothing to clear it to, an arbitrary key type having
no empty value. The string-keyed map cleared it to `''`, which made a dead
slot's key misleading rather than undefined — the contract was the same then
and had not been written down.

**What is genuinely still open** is not this. A generic body that adds its `T`
values is refused at the instantiation for a type that cannot be added, and
`doc/sop.md` §7 records what that costs a reader; ADR-0259 made it
attributable. That is the case a constraint would serve, and it is an
ergonomic one — so the roadmap's "generics have no constraints" stays, with
the hash row no longer filed behind it.
