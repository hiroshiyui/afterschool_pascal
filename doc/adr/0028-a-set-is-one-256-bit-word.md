# 28. A set is one 256-bit word

Date: 2026-08-10

## Status

Accepted.

## Context

Sets were the largest of the four features ISO 7185 has and this compiler did
not. The roadmap listed them as "the likeliest to be added opportunistically"
because a compiler wants them — character classes, follow sets — but nothing in
the bootstrap needed them, so they waited. The bootstrap is finished, and the
standard is now the reason on its own.

§6.4.3.4 makes a set type `set of T` for an ordinal T, with the values of the
type being the powerset of T's. It leaves the *size* to the implementation,
which is the only latitude that matters here: `set of integer` would need
2³² bits.

## Decision

**Every set is one 256-bit integer, whatever its base type.** One bit per
possible member, so a set's base type must have its values in 0..255 —
`set of integer` is refused rather than truncated. That admits `char` exactly,
and every enumeration and small subrange a compiler actually builds a set of.

The consequence worth stating is what it *avoids*. A set is a **value**: it
lives in a register, is assigned with a store, compared with `icmp`, and passed
and copied like an integer. None of the machinery that exists to move
structured values around by address applies to it, so `isStructured()` and
`isMemory()` needed no change and neither did anything that consults them. The
operators are one instruction each:

    union         or                    x in s        (s lshr x) and 1
    intersection  and                   s <= t        (s and not t) = 0
    difference    and not               s >= t        (t and not s) = 0

**Compatibility is structural, and the standard says so.** §6.4.6 makes two set
types compatible when their *base types* are — not when one identifier denotes
both, which is §6.4.5's rule for every other structured type. That is not an
exception invented here, and it is what lets `['a'..'z']`, a type no definition
ever named, be assigned to a variable at all. `[]` is a set with no base type,
compatible with every set: the same shape as `nil`, without being an exception
to anything.

**A constructor's range is built by shifting, not by looping.** `[lo..hi]` is
`(-1 lshr (255 - hi)) and (-1 shl lo)`, with `hi < lo` selected away to the
empty set — the bounds are expressions, so an empty range is a run-time
possibility rather than a compile-time one. No 256-bit literal is ever needed:
the only constants are 0, 1, −1 and 255, which matters because a 256-bit
decimal literal is a number this compiler's own source language cannot spell.

**Two range checks, because they answer different questions.** A member outside
0..255 has no bit at all, so a *constructor* traps on it. A member outside the
*target's* base type is a value the representation can hold but the type
cannot, so the **store** traps on it — `checkedForSetBase` alongside
`checkedForSubrange`, applied at the same two places a value enters a variable.
A constructor cannot make the second check, because a constructor does not know
what it is being assigned to. `x in s` makes neither: a value outside the base
type is not an error, it is simply not a member, which is what `in` is there to
report.

**A function may not return a set,** and fixing that corrected a test that was
asking the wrong question. §6.6.2 allows a *simple* type or a pointer; the code
asked `isMemory()`, which is a fact about the representation rather than the
rule, and a set passes it. The predicate now states §6.6.2 the standard's way
round.

## Consequences

**The `.ll` output now states its data layout, and had to.** The hand-written
`LlSize`/`LlAlign` of ADR-0025 model x86-64's layout; the emitted module named
no layout at all, so LLVM assembled it against its own defaults. That cost
nothing while every type was at most 8-aligned — and segfaulted on the first
record containing a set, because an i256 is 16-aligned in the target layout and
8-aligned in the default one, so the code generator emitted 16-byte moves
against an 8-aligned frame. The rules were never wrong. They were *unstated*,
which is the same thing once something else is doing the layout. `tests/
sets_records.pas` is the case that found it, and it found it on the first run.

**The C++ and Pascal compilers must try the operand kinds in the same order.**
Sema's relational chain asks "is either side a set?" somewhere among the same
questions about strings, pointers and files, and the two implementations had it
in different places — a pointer compared with a set would have reported
different messages. No file in the corpus mixed the two, so the differential
test agreed by never reaching it. `selfhost/badsema/sets.pas` now compares a
pointer with a set for exactly this reason. That is the sixth time a branch
turned out to be uncompared rather than agreed.

**Four SMT rules came with it** (§6.7.1, §6.4.6), and they are about the shift
construction rather than about sets in general: that `[lo..hi]` contains a
position exactly when the position lies between the bounds, that `[x]` contains
x and nothing else, and that the store check accepts a set if and only if every
member is a value of the base type. The bounds are symbolic, so these are
theorems about every constructor and every base type rather than about sampled
ones — the same reason ADR-0017's index rule and ADR-0018's `succ` rule
quantify over their bounds.

They are **bounded rules**, and for a new reason: a symbolic shift over 256 bits
bit-blasts into a circuit no solver will finish, so they are proved exhaustively
at set widths of 8, 16 and 32. The lowering is the same two shifts at every
width — the only place 256 appears at all is the bound Sema checks a base type
against — so the generalisation is the same argument the other bounded rules
make, and no stronger.

**Twelve mutations of the lowering are each caught**, including the three that
escaped the first version of the tests: a set measured as 16 bytes rather than
32, a set aligned to 8 rather than 16, and a universe mask built from 0..hi
rather than lo..hi. The first two needed a record with a set field to be copied
and heap-allocated, since `LlSize` and `LlAlign` are used in exactly those two
places; the third needed a base type that does not start at zero, which is why
`tests/trap_set.pas` uses `set of 5..9` and not `set of 0..9`.

**`packed set` is accepted and ignored.** §6.4.3.1 leaves packing to the
implementation, and there is nothing to pack: the representation is already one
bit per member. §6.4.6 requires compatible sets to agree on packing, and this
compiler does not check that — the two are identical here, so the check could
only reject programs that would work.

**What is not done:** `goto`, procedural and functional parameters, and
non-text files. Sets were the largest of the four and the only one that needed a
representation decision.
