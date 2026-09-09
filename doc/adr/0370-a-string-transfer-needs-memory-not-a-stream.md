# ADR-0370: A string transfer needs memory, not a stream

## Status

Accepted. Amends ADR-0060, which decided that `readstr` and `writestr` are a
text file made of memory and built that file with `fmemopen` and
`open_memstream`. The decision stands; the two POSIX functions go.

## Context

ADR-0369 measured the runtime against a target that is not POSIX and made the
measurement a gate. It reported `runtime/pasrt.c` **blocked**, on three names:
`_longjmp`, `fmemopen` and `open_memstream`.

`runtime-isoc` had been reporting the same three for much longer, in its own
words — `pasrt.c`'s entire departure from ISO C was **five** names, and three
of them were these. The two gates were describing one fact from two sides and
nobody had put them together. `pasrt.c` is the unit every compiled program
links, so what it needs is what a port needs.

**ADR-0060's argument was right about the requirement and wrong about the
mechanism.** It says:

> `fmemopen` gives readstr a text stream over the string's characters and
> `open_memstream` gives writestr one that grows a buffer

and the record calls that "the whole feature". It is not. §6.7.5.5 requires an
auxiliary `text` *variable* backed by memory; it says nothing about a `FILE *`,
and ISO C offers no way to make one over memory — so the mechanism was borrowed
from POSIX to satisfy a requirement that never asked for it.

## Decision

**The destination of a written character stops being a `FILE *`.**

`pas_out` hands back the file rather than its stream, and three emitters sit
behind it — `pas_sputc`, `pas_swrite` and `pas_sprintf` — each branching on
`PAS_ISMEM`: to the stream for an ordinary text, into a growable buffer for a
string transfer. The read side is one branch in `pas_fill`, where the character
comes from the buffer instead of `getc`.

**The formatting is untouched.** §6.10.3.4's exact decimal expansion,
§6.10.3.6's truncating field width, the padding and every clause reading in
those functions produce the same bytes as before and merely hand them
somewhere else. That is the property that makes this a change of destination
rather than a change of behaviour, and 914 cases say so.

**`struct pas_file` got smaller, not larger.** `membuf`, `memlen` and a new
cursor are only ever used by a string transfer, and a string transfer's file is
the one object here the *runtime* allocates rather than the program — so they
moved into a `struct pas_str_file` that embeds it. Every file variable a
program declares is `PAS_FILE_SIZE` bytes, a number the compiler also states as
`fileSize` and which **the seed was built with**, so growing it is an
out-of-cycle reseed and not a field (ADR-0155). The struct went from 112 bytes
to 96 and the headroom under 120 from 8 bytes to 24.

The cursor is one field meaning two things — how far a read has got, or what
the buffer can hold — because a string transfer is being read or written and
never both. Two fields did not fit; this is not thrift for its own sake.

## Why not `tmpfile()`

It is ISO C (§7.21.4.3) and this file already uses it for an internal file, so
it would have been a fifteen-line change instead of a hundred. Measured, it
costs **17.6 µs against `open_memstream`'s 0.2 — 88 times** — and a string
transfer is not rare: the compiler's own three components use `writestr` and
`readstr` 49 times and `lib/pastext.pas` 20 more. A string operation must not
touch a disk, and `benchmark` would have said so.

## What it found

**A field width wider than the formatter's buffer.** §6.9.3.1 and §6.10.3.1
bound TotalWidth from below and not above, so a width is whatever the program
wrote. `fprintf` sized its own output; `vsnprintf` into a 256-byte buffer does
not. The overflowing case allocates rather than truncating, and
`tests/write_wide_field.pas` is the program that crosses the boundary — on both
destinations, because `writestr` grows a buffer while `write` reaches a stream.

`runtime-coverage` is what named it: the change left 13 lines of `pasrt.c` that
nothing ran, and the case retired 10 of them. **The mutation is the evidence**
— making the overflow path truncate instead of allocate fails
`write_wide_field` and `sanitizers` and **nothing else**, so before the case
that branch was held only by a sanitizer finding a memory error. Dropping a
byte in the memory emitter fails 32 cases, `stringtransfer`, `lib_text` and
`trap_writestr_capacity` among them.

**A write whose failure was ignored.** `pas_write_padded` called `fwrite` and
did not look at the result, where `pas_put` next to it did. They share
`pas_swrite` now, so both report it.

## Consequences

**`pasrt.c` is three names from ISO C and one name from Windows.** The
catalogue went from five to three — `_setjmp`, `_longjmp`, `access` — and
`runtime-isoc` failed in the *other* direction while this was being written,
which is ADR-0013's `KNOWN_GAP` rule doing its job: a catalogue describing a
runtime that no longer exists is as loud as a missing entry.

**`runtime-nonposix` still says `blocked`, and that is the honest answer.**
`access` compiles for mingw through `<io.h>`, so what is left is the non-local
goto — and it is **not** the spelling doc/roadmap.md called it. Measured:

    glibc:  setjmp(x)  ->  _setjmp(x)             one argument
    mingw:  setjmp(x)  ->  _setjmp((x), frame)    two, via __imp__setjmp

The emitted code calls `_setjmp` with one argument, so on Win64 that is a wrong
arity, which is the class ADR-0121's row says nothing here checks. SEH-based
unwinding is why. The roadmap row is corrected and the work is not started.

Also measured, because it was the reason to expect trouble: `setjmp` costs
**2.0 ns against `_setjmp`'s 3.0**. glibc's ISO `setjmp` *is* `_setjmp`, so
there is no signal-mask cost to trade against and that argument is not
available to either side.

**More of the string path is now instrumented C.** What `open_memstream` did
inside libc, this runtime does itself, so ASan, UBSan, LSan and Valgrind watch
it — which is `runtime-coverage`'s whole argument (ADR-0351), and is why the
denominator moved from 1720 lines to 1778.

**Three lines nothing runs remain**, all allocation or write failure arms.
`pasrt.c`'s ratchet goes 243 to 246.

## Alternatives rejected

**Keep `fmemopen`/`open_memstream` behind a conditional.** A `#if` for a
platform nobody ships yet, in the file most read here, to keep two names the
requirement never asked for.

**Grow `PAS_FILE_SIZE`.** The seed was built with `fileSize = 120`; a
seed-built compiler would allocate 120 bytes for a file variable that the new
runtime writes 128 into. An out-of-cycle reseed to avoid a struct definition.

**A union with `capacity`.** It would have saved the same eight bytes without a
second struct, and it is unsafe: `pas_put` reads `f->capacity` to enforce
§6.4.3.6's length bound, and a string transfer that had grown its buffer would
arrive there looking like a direct-access file with a capacity. The bug is not
hypothetical — it is one call away on the write path.
