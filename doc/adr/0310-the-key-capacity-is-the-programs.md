# 310. The key capacity is the program's

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Closes the `MapKey` half of `doc/roadmap.md`'s row *Two
smaller reports from the same pass*, in the chapter *Writing a daily program*,
and **corrects** [ADR-0295](0295-a-corpus-written-to-be-read.md)'s sixth
finding, which recorded a bound the map does not have.

## Context

ADR-0295's finding 6 reads: *a `MapKey` is 63 characters and a longer key stops
the program*, and calls itself *a bound, recorded, not a defect*.
`examples/word_freq.pas` was the evidence — it guarded `if length(word) <=
KeyMax` before every `MapPut` and carried a comment explaining why.

The map has no such bound. `PasContainer`'s `Map(K, V, cap)` has been generic
over its key type since [ADR-0254](0254-a-generic-activation-need-not-write-its-types.md),
and the ready-made `StrHash`/`StrEq` — the last thing that was declared over
`string(63)` — became schematic in
[ADR-0290](0290-one-hash-for-every-capacity.md), so one pair serves a map keyed
at any capacity. The module header has said so since that day: *`MapKey` and
`KeyMax` remain exported as a ready-made key type for a client that wants one,
and are no longer a limit on anything.*

The probe is three lines and it was not run when the finding was written:

```pascal
type BigKey = string(200); BigMap = ^Map(BigKey, integer);
…
MapPut(m, k, 7, StrHash, StrEq)      { k is 130 characters }
```

`130 7 1`. The 63 in the finding is `examples/word_freq.pas` reaching for the
ready-made key type and then guarding against the capacity that type happens to
have — the program's own choice, described as the library's.

**This is the fourth time a claim in this chapter has been half wrong**
(ADR-0297, ADR-0304, ADR-0308), and the second time *this particular* claim has
been made: `lsp/pasls.pas` kept its documents in a linearly searched vector for
the same reason and ADR-0290 struck that comment **the day before**. A retired
claim came back the next day, in a document nothing checks.

What is *not* wrong is the shape underneath it. A key type has a capacity
whichever one is picked, and a string longer than it stops the program at the
assignment — which happens in the caller's own argument list, where no library
routine can see it or report it. A program keyed by text from **outside** — a
word from a file, a header from a socket — has to answer for a length it did
not choose. Nothing in the library said what the answer is.

## Decision

**The key capacity is the client's decision, the library states the rule for
making it, and the library exports nothing new.**

Three shapes exist and they are not equally good. The rule, written in
`lib/dialect/pascontainer.pas`'s header, in `lib/dialect/README.md` and in
`doc/tour.md`:

1. **Size the key to a bound the program already has.** Almost every program
   reading outside text has one — the buffer it read the text into. A word is a
   piece of a line, so a key as wide as the line buffer cannot be overrun by a
   word, and there is nothing left to check. It costs that capacity in every
   slot, which is the trade and is usually the right one.
2. **Guard where the input has no bound the program can state**, and say what
   is dropped. Write the bound as `m^.slots[1].key.capacity` and not as a
   number: §6.4.3.3.3 gives a string schema a `capacity` discriminant, which is
   readable through the map, so the guard cannot go stale when the key type
   changes.
3. **Never clamp.** `substr(k, 1, cap)` is the only one of the three that gives
   a *wrong* answer: two long keys sharing a prefix become one key, so a count
   is added to somebody else's entry. A clamped **capacity** and a clamped
   **key** are not the same decision — this library clamps a capacity request
   (`Claimed`) because a container smaller than asked for still answers
   correctly about what is in it, and a clamped key does not.

**`examples/word_freq.pas` is rewritten to shape 1** and has no guard. One
constant, `LineMax`, is the line buffer, the word and the map's key, so the
program's single bound is stated once and a word out of a line cannot be too
long for a slot. The distinct words moved from `PasStrVec` — whose `ItemMax` is
255 and would have been a second fixed capacity, and a second guard — into
`PasContainer`'s own `Vec(WordText)`, sorted through `PasSort.SortIndexed`,
which never sees an element. **The golden is byte for byte what it was**: the
program's answer should not differ, and it does not.

## Evidence

`tests/dialect/lib_container_key.pas` is the case, and it pins the correction
rather than the prose. Three maps keyed at three capacities, **none of them
63** — 200, 8, and the ready-made `MapKey` beside them — each served by the
module's own `StrHash`/`StrEq`; a 131-character key put, got, asked after,
deleted and read back out of a slot at its full length, across a rehash with
keys that long in the table; a second key sharing its first 130 characters,
which is what a clamping library would have made one; and the capacity read as
`m^.slots[1].key.capacity`, so the case spells 200 once.

The mutation is `tests/mutation/mutants/0310-the-ready-made-pair-is-the-bound.mut`:
`StrHash`'s parameter declared `MapKey` again, which is what ADR-0290 widened.
It kills `lib_container_key`. It is the defect that produced *both*
misreadings, and until this case existed the only thing in the tree that would
have caught it was the language server — `tests/dialect/lib_container.pas`
keys every string-keyed map on `MapKey` itself, so a pair declared over
`MapKey` is congruent with all of them.

**And `doc/tour.md`'s generic fragment did not compile.** It was written
`VecGet(IntVec, integer, v, k)`, which is ADR-0304's argument order reversed —
`Elem` first, `Ptr` inferred — so the pointer type bound `Elem` and the compiler
reported four errors inside `pascontainer.pas`. It is `VecGet(integer, v, k)`
now, and the paragraph beside it saying *inference is all-or-nothing, so the
pointer type has to be written beside it* is the sentence ADR-0304 retired.
That is ADR-0308's *a document can be an oracle* met from the other side: the
document was the thing that was wrong, and compiling it is what said so.

## What is not done

**No helper is exported, and one was written out before being rejected.** A
`MapKeyMax(m)` answering the key's capacity was the obvious facility, and it
fails twice. The language already answers it — `m^.slots[1].key.capacity` is
§6.4.3.3.3's discriminant and needs no library — and a generic body reading
`.capacity` is meaningful for a *string* key only, so a map keyed on an integer
or a record would meet a diagnostic inside the library's body at its own call
site (ADR-0212 translates a generic body where it is instantiated). A facility
that is undefined for most of the type its container admits is worse than the
sentence it would have saved.
[ADR-0116](0116-a-container-is-a-pointer-to-a-schema-and-its-allocator-cannot-be-injected.md)
settles the rest — a facility shipped for nobody is *a costume rather than a
feature*, that record's own words about an allocator parameter — and with
`word_freq.pas` written to shape 1 there is no caller.

**No clamping put.** `MapPutClamped` would make the wrong answer of shape 3 the
library's own, and a silent collision is not a thing a container may do on its
client's behalf.

**Nothing enforces the rule**, and nothing can: the trap belongs to the
assignment of an actual, in the caller's block. `doc/sop.md` §7 gains no row for
it, because there is no claim here a gate could check — what is checkable is
that a key of any capacity works, which is the case above.

**`PasStrVec.ItemMax` is still 255**, and `word_freq.pas` no longer meets it
because it no longer uses that module. ADR-0291 already recorded the bound as
one that is right for what `PasStrVec` is; a program whose strings are wider
uses the generic vector, which is now what an example shows.

## Consequences

**A finding is a claim and needs the probe a fix needs.** ADR-0295's list is
otherwise sound — five of its seven findings have led to a change and each was
right — and the sixth is the one nobody compiled. It cost a day and a
comment in a program written to be read, which is the corpus with the widest
audience here. The record is immutable, so its Status now points here.

**The library's clamping policy has a boundary, and it is now written down.**
`Claimed` clamps a capacity and `VecFull` reports the ceiling, both under the
rule that *a library that halts is a library that cannot be tested*. A key is
where that rule stops: clamping it changes the answer rather than the size of
the answer. Nothing had said which side of the line a key was on.

**One more example reads as a program about its subject.** `word_freq.pas` is
about counting words again; the only type it names is the one standing in
`VecGet`'s result, which is §6.7.1's and not this library's.
