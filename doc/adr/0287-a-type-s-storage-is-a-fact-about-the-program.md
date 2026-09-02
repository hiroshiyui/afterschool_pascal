# 287. A type's storage is a fact about the program

Date: 2026-09-02

## Status

Accepted, 2026-09-02.

## Context

`LlSize` answered a Pascal `integer`. Its array arm is
`TypeLength(b) * LlSize(b^.elem)` and its record path accumulates into an
`integer` too, so **any type whose storage exceeded maxint bytes overflowed the
compiler's own checked arithmetic** (ADR-0014) and stopped it with

    runtime error: integer overflow in *

— no file, no line, no column, exit 1. The boundary was exact:
`array[1..536870911] of integer` is 2 147 483 644 bytes and compiles; one
element more is 2 147 483 648 and crashes the compiler.

Three paths reached it, being the three places CodeGen needs a byte count: a
whole-variable assignment's memcpy length, `new` of a large type, and — since
ADR-0268 — a channel's element size, which is where it was found.

**It was inconsistent by use rather than by type.** The same 2.1 GB array
compiled if the program only indexed it and crashed the compiler if the program
copied it. Sema accepted the type; a *use* stopped the compiler.

That is a contract violation and not merely an ugly message. ADR-0008 makes
CodeGen report no user-facing errors — *if it needs a fact about the source
program, that fact belongs in Sema* — and a type's storage is exactly such a
fact. Sema already had the shape one bound over: §6.4.3.2's *elements* are
bounded at maxint values, with a position and a recovery type, because
`verify/`'s `accepted-index-selects-the-right-element` rule needed it. The
byte bound was its missing sibling. Sema could not state it, because
`apfront.pas` had no layout arithmetic at all: `LlSize`, `LlAlign`,
`RecordLayout` and `VariantStorageAt` were CodeGen's, and CodeGen is imported
*by* nothing — the dependency runs the other way (ADR-0233).

## Decision

**The layout arithmetic moves to ApFront and the sizes become `int64`, and
Sema bounds what is left.**

1. `RoundUp`, `LlSize`, `LlAlign`, `ArmLayoutAt`, `VariantStorageAt`,
   `ArmSlotAt`, `RecordLayout` and `SelectedSize` move from
   `selfhost/compiler.pas` to `selfhost/apfront.pas` and are exported. Nothing
   is duplicated: both components read the one copy, so the two cannot drift.
   The move is possible because ApTypes already holds `TypeLength` and all five
   size constants, and `PathAppend` — the one callee that is neither — is
   ApFront's.
2. A size is an `int64`. An alignment stays an `integer`; it is small by
   construction.
3. **The overflow is answered, not attempted.** This compiler traps on integer
   overflow, so *computing* the product to discover it does not fit would stop
   the compiler where a diagnostic belongs. `storageTooLarge` is a saturating
   answer that every arithmetic below propagates, and `CheckStorage` is the one
   place it becomes a message, reported where the type is written.

## Consequences

**A type between 2 GB and int64 now works.** `new` of a 2.4 GB record emits
`i64 2400000000` as its allocation and `@llvm.memcpy...i64 2400000000` as a
whole-variable copy; a channel of an 8 GB element emits `i64 8000000000`. None
of the three compiled before.

**And the limit that remains is stated.** Two nested `maxint` arrays of a
four-byte element need 1.8e19 bytes, which is past int64 — so the cliff moved
but did not disappear, and *the failure at the new cliff was identical to the
old one* until this bound existed. That is the whole argument for doing both
halves: widening alone moves a crash rather than removing one.

**What is deliberately not bounded is the target.** A global above about 2 GB
is refused by the linker's small code model, with `relocation truncated to
fit`, and a heap object by the machine. Neither is a fact this compiler could
state for every target `--target=` admits (ADR-0157), so the bound here is what
the *compiler* can lay out, which is a bound it can know. The linker message
is a separate and worse one, and it is not addressed here.

**Sema now computes layout, which it did not.** That is the real cost: a pass
that decided types now also decides their storage, and `LlSize` is reachable
from Sema at any point. It is bounded by the same contract as before — CodeGen
still reports nothing — and the alternative was a second size function in Sema,
which is ADR-0058's leak shape and would drift.

**`CheckStorage` reports and does not substitute**, where the elements bound
substitutes a recovery type. It does not need to: `errorSeen` stops CodeGen, so
the sentinel cannot reach an emitter. It *did* reach one during development —
`i64 -1` as a memcpy length, written into real IR — which is why the check is
at both the array and the record and not only where the first case failed.

## Alternatives rejected

**Diagnose at maxint and leave the arithmetic 32-bit.** Smaller, and it makes
the message a representation limit rather than a target one. Rejected because a
2.4 GB heap record is a thing a program on this machine can have, and refusing
it would be this compiler's limit imposed as the language's.

**Widen and do not bound.** The cliff moves to int64 and the failure there is
the same bare crash — measured, not assumed: a doubly-nested `maxint` array
still printed `runtime error: integer overflow in *` after the widening and
before `CheckStorage`.

**Keep the arithmetic in CodeGen and have it report.** One line, and it breaks
ADR-0008 for the first time. The contract is what lets CodeGen be simple, and a
size is the least defensible place to start making exceptions, being a fact
Sema can compute without looking at anything CodeGen knows.
