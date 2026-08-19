# ADR-0129: A buffer crosses as the pair C already takes

## Status

Accepted. The increment ADR-0122 deferred by name, ADR-0125 built the language
half of, and ADR-0128 built the arithmetic half of. `--std=afterschool` only.

It settles what a buffer looks like at the foreign boundary. It settles nothing
about the memory-safety model, and it does not admit any pointer that outlives
a call.

## Context

**The refusal this lifts is three records old and was always a placeholder.**
ADR-0122 let a `var` parameter and a `string` cross as an address, on the
argument side, where the caller owns the storage and outlives the call — and
then refused a buffer in these words:

> Not a lifetime objection: it is a pointer *and* a length, and the length is
> not in-band the way a C string's is. That is the **slices** row of
> `doc/roadmap.md`'s table, and it is a language decision.

So the language decision was made first and on its own merits: ADR-0125's
`array of T` is a formal parameter's type, an argument travels as an address
and a count, and the count is checked where the designator is written, which is
the only place the base's own extent is still known.

**And then a probe said the decision was still one half short.** ADR-0125 closed
by quoting what `clang` emits on this target:

```
declare i64 @read(i32, ptr, i64)
declare i64 @write(i32, ptr, i64)
declare i64 @recv(i32, ptr, i64, i32)
```

Every length is a `size_t` and every one of those *answers* an `ssize_t`. A
slice could have crossed with an `i64` length that day — the compiler generates
the word and may pick its width — but the result could not have been received,
this language's `integer` being an `i32` with nothing wider behind it. ADR-0128
is the type that answers, and with it in the tree there is no missing mechanism
left: what remained was a shape decision.

## Decision

**A slice crosses as the pair `(ptr, i64)`: the address of the first component,
then how many components there are, as two arguments from one formal.**

```pascal
function PosixRead(fd: integer; var buf: array of char): int64;
  external 'read';

n := PosixRead(0, buf[1..5]);
```

emits, byte for byte, the declaration `clang` writes for `read(2)`:

```
declare i64 @read(i32, ptr, i64)
  %v27 = sext i32 %v24 to i64
  %v28 = call i64 @read(i32 0, ptr %v26, i64 %v27)
```

Three consequences are the whole of the decision.

**The program cannot write the count.** `PosixRead` has two parameters and
`read(2)` has three. The length C receives is the one this compiler computed
from the designator and checked against the array — so a buffer overrun is not
something a caller can spell, which is the property ADR-0125 exists for,
carried across a boundary where nothing else is checked at all.

**The component type is not `ForeignType`'s list.** It is that list plus
`char`, and the reason each half moves is the same sentence read in two
directions. ADR-0121 tests the type rather than `Base(t)`, and argued it as a
rule with a side: *passing* a subrange is sound, *returning* one is not,
because `checkedForSubrange` has nothing to apply to a value that arrived. A
slice is storage the callee **writes**, so every component sits on the
returning side of that argument. A subrange is refused however ordinary its
host is; so is an enumeration; so is `boolean`, of whose 256 byte patterns 254
are not values of it.

`char` is then the one addition, and it is the case the feature exists for.
ADR-0121 refused it *by value* because `clang` passes one as `i8 signext` and
the sign bit disagrees with §6.4.2.2's 0..255 — an objection about the register
convention, which an array component does not use. In memory a `char` is one
byte and **the type has no bit pattern that is not a value of it**, which is
the property every other candidate lacks and the only honest reason to let a
routine this compiler did not emit write into one.

**One formal, two arguments, and one place the counts differ.** The `declare`
list in `EmitExterns` is the only site in this compiler where a Pascal formal
does not correspond one-to-one with a foreign argument.

## Consequences

### What it buys

The POSIX data path is bindable. `read`, `write`, `recv` and `send` take
`(fd, ptr, size_t)` and answer `ssize_t`, and every word of that is now
expressible — the last one only since ADR-0128. `snprintf(ptr, size_t, ...)` is
the same shape. This is the first time a Pascal program here can move bytes to
or from something the runtime does not already wrap.

The bound C receives is one the compiler proved. That is worth stating plainly
because it is the opposite of what an FFI usually does to a safety property:
`read(fd, buf, sizeof buf)` in C is a convention, and `PosixRead(fd, buf[1..5])`
is a checked designator.

### What it costs

**The convention is assumed and cannot be checked.** The pair crosses in the
order pointer-then-length because that is the order `read`, `write`, `recv`,
`send` and `snprintf` take. A C function taking `(size_t n, void *p)` — or
`memcpy(dst, src, n)`, whose two buffers share one count — cannot be bound with
a slice at all, and there is no escape hatch: a bare address without a length
is exactly what ADR-0122 refused and what this record does not reintroduce.
`memcpy` is worth naming because it looks like it should fit and does not.

**Two mutations survived, and both are the ADR-0121 gap seen again.**

- Writing `ptr` instead of `ptr, i64` in the `declare` — so the declaration
  disagrees with the call about how many arguments there are — assembles,
  links and runs correctly. ADR-0121 found that LLVM does not check a
  **direct** call against the declaration under opaque pointers and recorded it
  for parameter *types*; this is the same finding for *arity*. The `declare`
  this record specifies is documentary, and nothing in this repository can make
  it otherwise.
- Dropping the `sext` and passing the count as an `i32` also runs correctly, on
  this target and on aarch64, because a 32-bit register write zero-extends and
  a slice's length is never negative and never large. The widening is right and
  **no test here can see that it is right**; it is in `doc/sop.md` §7 rather
  than claimed as covered.

**No slice of a packed array of char.** `p[2..5]` over one is §6.5.6's
substring designator and yields a `string`, which does not bind to a slice
formal — ADR-0125's rule, unchanged, and it means a buffer wants
`array [1..n] of char` rather than the packed spelling. Passing such an array
*whole* still works, because only the sliced designator is ambiguous.

### What it does not do

- **No returned buffer.** A `ptr` coming back is ADR-0122's open half and needs
  ownership, which is ADR-0109's undecided model. An `int64` count comes back;
  the storage was always the caller's.
- **No pointer stored anywhere.** This is the fourth feature confined to an
  argument for the reason ADR-0125 stated as a pattern: where a feature's
  danger is *lifetime*, confining it to an argument removes the danger without
  deciding anything about ownership.
- **Nothing checks that the callee respects the count.** It is a promise, like
  every other promise across this boundary. What is claimed is that the number
  handed over is correct, not that it is honoured.
- **No `errno` still.** It is `*__errno_location()`, a returned pointer, and
  this record does not move that.

## Alternatives rejected

**An address alone, with the program passing the count.** The roadmap listed
this first because it assumes no convention. It is the wrong answer, and not
narrowly: the whole reason a slice exists is that a length travelling separately
from its pointer is a length nothing relates to the storage. Admitting the
address bare would put the C hazard back at the one place ADR-0122 identified
as unable to check anything, and would make `array of T` at the boundary weaker
than `array of T` inside the language.

**A four-word shape carrying the component size as well.** It would let the
callee compute bytes rather than components. C's `read` counts bytes and this
counts components, which agree exactly when the component is a `char` and
disagree for `array of integer` — so a program binding `read` to an
`array of integer` asks for a quarter of what it means. That is a real trap and
the answer is documentation rather than a fourth word: no C function in the
target shape takes an element size, so the word would be one nothing wants,
and the house rule is that nothing here may depend on how a struct is passed.

**Admitting `boolean`.** Its representation is one byte here and `_Bool` is one
byte there, so it would work. It is refused because neither standard fixes what
byte a `false` is, so admitting it would commit this compiler's layout to a C
detail in a record about the boundary rather than about the type — and 254 of
the byte patterns a callee could leave behind are not values of the type, with
nothing to check them.

**Teaching `src/` the new refusals.** Not needed, and this is worth recording
because CLAUDE.md says a dialect feature's *refusal* is on the conformance
surface. `array of T` is already refused there — both front ends answer
`a parameter's type must be a type name` under `--std=extended`, as ADR-0125
arranged — so a program using this feature never reaches a rule `src/` would
have to have.
