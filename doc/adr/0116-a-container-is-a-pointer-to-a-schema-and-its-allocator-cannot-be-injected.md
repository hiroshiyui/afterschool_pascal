# ADR-0116: A container is a pointer to a schema, and its allocator cannot be injected

## Status

Accepted. Second increment of the library ADR-0114 began, and like the first it
decides nothing about the dialect mode, the memory-safety model or the
foreign-function interface.

It **corrects one row of `doc/roadmap.md`'s borrowings table**, which called
explicit allocator passing "excellent, and free — a library convention, not a
language feature — it needs no compiler change at all, and it is the cheapest
thing on this list". That row was written from Zig's side of the comparison
rather than from this language's, and it is wrong in a way worth recording: see
*Allocator passing* below.

## Context

ADR-0114 built the half of a library that needs no operating system: strings,
sorting, integer arithmetic. Everything it produced was a *function over values
the caller already had*. A container is the first thing that is not — it owns
storage, so it has to obtain it, grow it and release it, and none of those is a
question the first increment had to answer.

Three facts about this language shape the answer, and the second and third were
found by probing rather than reasoning, this project's own rule (ADR-0067):

1. **A schema is chosen once.** `var v: IntVector(n)` fixes `n` at the
   declaration. There is no way to say "the same variable, larger", so a
   growable container cannot be a schema variable.
2. **`new(p, d)` computes the tuple at the call.** §6.7.5.3 produces the type
   from the discriminants the call supplies, and `p^.cap` reads them back. So
   the heap *is* the mechanism for a run-time extent that changes.
3. **A schema may contain a string — now.** The shape a keyed container wants,
   `array [1..cap] of record key: string(k); … end`, stopped the compiler
   until the fix that landed with this increment. Sema's `StaticThroughout`
   listed fifteen of the sixteen type kinds and Pascal's case-statement traps
   on the sixteenth (ADR-0018).

## Decision

**A growable container is a pointer to a schema record whose last field is the
storage, and every routine that may grow takes `var v: VecPtr`, because growth
replaces the variable.**

```pascal
type IntVec(cap: integer) = record
       n: integer;
       a: array [1..cap] of integer   { last: ADR-0045 }
     end;
     VecPtr = ^IntVec;
```

`n` is the live length and `cap` is the discriminant, so the capacity is never
stored twice. `PasVector` and `PasMap` are both this shape.

### The element type is written out, and a caller wanting another copies the file

PasSort escaped "no generics" by phrasing itself over *positions* — `less(i, j)`
and `swap(i, j)`, never seeing an element (ADR-0114). **A container cannot use
that escape**, because it holds the elements: their type is part of its layout.
So `PasVector` holds `integer` and `PasMap` maps `string(32)` to `integer`, and
the documented answer for another element type is to copy the file and change
one line.

That is stated as the decision rather than hidden, because the alternative
designs are worse in this language and should not be re-attempted: a variant
record holding "any" element makes every access a tag check and still cannot
hold a type the module did not enumerate, and a schema parameterises a type by a
*value*, never by another type (ADR-0039).

### Allocator passing is expressible, nearly useless, and unchecked

The roadmap expected this to be free. It is not, and the reason is specific.

- **An allocator record is not expressible.** A record field may not have a
  procedure type — neither standard has general procedure types, only §6.6.3.1's
  procedural *parameters*. `procedure grab(…)` as a field is
  *expected a type, found 'procedure'*.
- **A per-type allocator parameter *is* expressible.** A routine may take
  `procedure alloc(var q: BlkPtr; n: integer)` and call it instead of `new`.
  That compiles and runs.
- **But such an allocator can only recycle.** `new` is the only origin of a
  typed pointer here; there is no pointer arithmetic and no cast between pointer
  types. So an injected allocator cannot carve one block into several — the only
  strategy it can implement is handing back blocks `new` produced earlier.
- **And the capacity it serves is unchecked.** A pool asked for capacity 9 may
  return a block of capacity 4. Nothing reports it: the block carries *its own*
  discriminant, so `p^.cap` reads 4 and the caller's request is simply lost.

The last point is the one that decides it. It is **not unsafe** — the bounds
check reads the served block's discriminant, so an access beyond it traps
exactly as any other out-of-range subscript does (`array index out of bounds
(1..4)`). It is *wrong* rather than dangerous. But a convention whose only
strategy is recycling and whose central contract is unenforced is not the Zig
mechanism the roadmap was reaching for, and shipping an `alloc` parameter on
every container would have been a costume rather than a feature.

**So no container here takes an allocator.** What the caller gets instead is
control over *when* allocation happens: `VecNew` chooses the initial capacity
and `VecReserve` grows once so that no later push reallocates. That is the part
of the idea that survives contact with the language.

## Consequences

- `lib/` gains `PasVector`, `PasMap` and `PasText`. `PasText` is here rather
  than in `PasStrings` because splitting needs somewhere to put the pieces, and
  that is a schema array of strings — the shape point 3 above had to be fixed
  for.
- **The arithmetic is written against a trapping integer type** and this is now
  a house rule with three instances: doubling is a comparison against
  `CapMax div 2` rather than `cap * 2`, the hash accumulates modulo a prime at
  every character rather than once at the end, and `TryParseInt` checks
  `acc > (maxint - digit) div 10` *before* forming the value. Each is the
  obvious formula rewritten so the trap cannot fire (ADR-0014).
- **A library may not halt.** `TryParseInt` exists because §6.9.1's read of an
  integer is an *error* when the text is not a number and stops the program
  (ADR-0076); nothing built on `readstr` can offer "parse this if it is a
  number". The same rule is why `VecNew` clamps a bad capacity instead of
  refusing, and why `MapGet` takes a `whenAbsent` value rather than reporting.
  A routine that halts is a routine no test can exercise on its failing input.
- **Iteration is over slot positions, not a cursor.** `MapSlots`/`MapLiveAt`
  hands the caller the loop rather than keeping state the module would own, and
  the order is the table's. `tests/extended/lib_map.pas` sums rather than prints
  during the walk, so the golden does not encode the hash function.
- The roadmap's borrowings table needs the allocator row rewritten; the *slice*
  row above it is unaffected and still correct.

## What this does not do

- **No install location and no resolution by name**, unchanged from ADR-0114.
- **No allocator, no arena and no ownership model.** The caller calls
  `VecFree`/`MapFree`; nothing tracks whether it did. Memory safety is ADR-0109's
  open question and this increment deliberately does not prejudge it.
- **No error handling.** `MapGet` takes a default and `TryParseInt` answers a
  boolean, which are two different ad-hoc shapes for the same missing feature.
  A `Result` type needs sum types with payloads, and whether those are variant
  records or something new is a language decision, not a library one — it was
  offered as part of this increment and deliberately left out.
- **No second element type.** See above: copying the file is the answer, and
  making that ergonomic is a dialect feature nobody has designed yet.
- **No concurrency, no I/O beyond text, nothing touching the operating system.**
  Still blocked on the FFI, still correctly ordered after it.
