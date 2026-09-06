# ADR-0355: A map's key implements Key

Date: 2026-09-07

## Status

Accepted. Changes the interface of `lib/dialect/pascontainer.pas` — `MapPut`,
`MapGet`, `MapHas` and `MapDelete` lose two parameters and `Map` gains a bound
on its key discriminant — and every client of the map in this tree with it.
ADR-0341 anticipated this change and is not superseded; this is the payoff it
priced.

## Context

`PasContainer`'s map was generic over its key from ADR-0290 on, and the two
things a hash table needs of a key — a hash and an equality — belonged to no
type, so the caller carried them: `MapPut(m, 'k', 1, StrHash, StrEq)` was the
shape, with fourteen routine-valued parameters across two modules and thirty
call sites threading one pair through. `doc/roadmap.md` recorded that count as
the half of the evidence for traits that a library could collect, and
ADR-0341, having measured that a module cannot ship an implementation for its
clients, said in as many words that a client writing one `impl Key for MapKey`
block still removes the pair from all thirty sites, so the whole payoff
survives the restriction.

Traits landed (ADR-0338 to ADR-0341) and their first library client was
`PasSortX` (ADR-0344), whose trait the *importer* implements for its own type.
The map is the second shape — a trait declared in the module heading and used
as the **bound on a schema's type-valued discriminant**, `Map(K: Key; V:
type; cap: integer)` — and nothing in the tree had that shape: ADR-0341's probe
was a probe, and the corpus had no component whose interface both declared a
trait and bounded a schema with it.

## Decision

`PasContainer` declares and exports

```pascal
trait Key;
  function Hash(k: Self): integer;
  function Same(a: Self; b: Self): boolean;
end;
```

and the map's schema binds its key with it. `FindSlot` and the rehash call
`Hash(key)` and `Same(a, b)` directly; each call selects the client's
implementation by the key's type (AP 6.7.10.2 NOTE 11), and there is no
procedural parameter left on any map routine. `StrHash` and `StrEq` stay
exported, as what a string key's implementation calls: they are schematic over
the capacity (ADR-0290), so the implementation for a key of any capacity is
two lines.

**The client writes the implementation, before the map type is produced**, and
this holds for the module's own `MapKey` too: a module may declare a trait and
cannot ship an implementation for its clients (ADR-0341), so
`impl Key for MapKey` is written in every program that keys a map at it. The
bound is checked where the type is produced — at `^Map(WordText, integer)`,
not at the first `MapPut` — and §6.2.2.9 then puts the implementation before
that line in written order.

The four clients in this tree were converted with **every golden unchanged**:
`tests/dialect/lib_container.pas` (three implementations, one for a record
key), `tests/dialect/lib_container_key.pas` (three, one per capacity, because
`string(200)`, `string(8)` and `string(63)` are three types),
`examples/word_freq.pas` and the language server's URI map in `lsp/pasls.pas`,
whose 32 sessions replay byte for byte.

## Consequences

**Every existing map client breaks**, and this is a library and not the
language, so the change is recorded in `CHANGELOG.md` under *Changed* and
nowhere in `doc/afterschool-pascal-spec.md`: no clause of the specification
names `PasContainer`.

**The evidence the roadmap was collecting is collected.** The thirty sites
name no pair. What remains routine-valued is `PasSort`'s two parameters and
`PasFile`'s one, each taking a genuine routine rather than standing in for a
property of a type; the roadmap's paragraph is updated to say so rather than
struck, the prefix half of that inventory standing.

**This is the first trait client that found no compiler defect.** ADR-0340's
clients found six and ADR-0344's one more; building this found none, and the
mutation that proves the case is a library one — `0355-any-occupied-slot-is-
the-key.mut` replaces `Same(m^.slots[i].key, key)` with `true` in `FindSlot`,
and `lib_container` reports `k3=4` where the golden says `-1`. A second
mutation, the wrong `Same` for a record key written in the client, is caught by
the same golden and is not catalogued, the catalogue holding mutations of
sources under `lib/` and `selfhost/`.

**What it found instead is a diagnostic cascade**, and it is not this
change's to fix. A discriminant that fails its bound is reported once, at the
type — `wordtext cannot be the type argument for 'k', which is declared 'key':
it has no implementation of 'key'` — and `BoundSchema` then answers nil, which
the pointer-domain path turns into `^integer` (`apfront.pas`, `if s = nil then
t^.elem := intType`). That is the placeholder every error path in Sema leaves,
and it is the right placeholder for a *value*; for a schema whose bodies are
instantiated against it, every generic body then reports a fault of its own,
**located in the library** — `tag values are only for a pointer to a record
with a variant part` at `pascontainer.pas:518`, `cannot select a field of a
value of type integer` six times after it, and a hundred lines of the same for
a client that also puts and gets. `tests/dialect/lib_container_bad_key.pas`
pins the first line as the claim and the cascade as a record, deliberately
small — one `MapInit` — so that the golden is eight lines; `doc/sop.md` §7
carries the row, and a fix that silences the cascade changes that golden and
should. The general shape is `nErrType`'s (ADR-0306): a *node* can say its
type is the placeholder and the assignment check keeps quiet on it, but a
*type* cannot, and a failed schema binding is where that difference is paid.

**Two goldens now pin a line number inside the library.**
`owned_container_free.err` did already, and this change moved it from 351 to
367 by inserting the trait above it; `lib_container_bad_key.err` pins six more.
Every later edit to `pascontainer.pas` above those lines regenerates both, and
the regeneration is the line number and nothing else, which is a cost the
record accepts for the sake of a diagnostic whose *location* is the finding.

**Two coverage ratchets moved by attribution and not behaviour.** `lib-coverage`
reports 381 uncovered where it reported 389, all of it in `paslsp.pas`
(79/155 → 71/147) and one line of `pasjson.pas`: a generic body's lines are
the client's (ADR-0352), the trait shifted every line of `pascontainer.pas`
below it by sixteen, and eight lines those modules never ran now share a
number with a generic body and are unmeasurable. `lsp-coverage` reports the
same thing as `ambiguous 30 → 32` and one line of `dirof` that was ambiguous
and is now measurable and uncovered. Neither is a line that ran and stopped.

## What this does not do

It does not bound the key with two traits — `Hash + Eq` was the shape
`doc/roadmap.md` wrote down and the language admits one bound (ADR-0339); one
trait with two methods is what a map needs and is what a program writes.

It does not give `MapKey` an implementation. It cannot (ADR-0341), and the
cost is two lines per client, which `doc/tour.md` says in the same breath as
the type.

It does not touch `PasSort` or `PasFile`. Their remaining routine-valued
parameters take a routine — an ordering, a visitor — and a routine is what a
procedural parameter is for.

## Alternatives considered

- **Keep the pair.** Thirty sites and fourteen parameters carrying what a type
  should carry; the whole of ADR-0341's payoff foregone for want of a client.
- **A default implementation for `MapKey` in the module.** Refused by
  ADR-0341 on ADR-0116's argument, and this record confirms the price is what
  that one said: one block per client, not one per call.
- **Fix the cascade here.** It is a Sema change to the error placeholder for a
  schema, Class B on its own, and the case that would name it is the one this
  change adds; it is recorded rather than bundled.
