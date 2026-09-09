# ADR-0373: One conditional, and it is catalogued

## Status

Accepted. Closes the runtime's half of the non-local goto for a target that is
not POSIX, after ADR-0371 closed the emitter's. `runtime/pasrt.c` now compiles
for mingw-w64.

## Context

ADR-0369's gate reported `runtime/pasrt.c` blocked on three names. ADR-0370
removed two of them — `fmemopen` and `open_memstream`, neither of which
§6.7.5.5 had ever asked for. ADR-0371 closed the emitter's half of the third:
`_setjmp` is an *arity* and not a spelling, and the compiler now writes
whichever its target wants.

What was left is the runtime's call. `runtime/pasrt.c` calls `_longjmp`,
because that is the jump that pairs with the `_setjmp` the emitter writes —
the one that does **not** restore a signal mask. mingw-w64 declares no
`_longjmp` at all: its `<setjmp.h>` has `longjmp`, `_longjmpex` for i386 and
`__mingw_longjmp` for arm, and nothing by that name. There `longjmp` is the
counterpart, its `setjmp` macro expanding to the same two-argument `_setjmp`.

**No portable spelling exists, and both directions were measured.** Calling
`longjmp` everywhere works on glibc — verified, and no mask is restored,
because glibc's reads a flag the buffer carries — and breaks on Darwin, where
the BSD rule is the opposite and `longjmp` would restore a mask `_setjmp` never
saved. macOS is a platform this project requires to pass.

**The tidier shape is unavailable, and the reason is the bootstrap.** `_setjmp`
is emitted by the compiler; the jump could be too, leaving `pasrt.c` with
neither name and making the emitter target-aware for both halves, which is
plainly the better design. `seed/*.ll` declares and calls `@pas_jump_go`, so
that cannot land without an out-of-cycle reseed — a release operation, and this
is not a release. It is written down here so the next reader does not
rediscover it.

## Decision

**One preprocessor conditional, in `runtime/pasrt.c`, and it is catalogued.**

    #if defined(_WIN32)
    #  define PAS_LONGJMP longjmp
    #else
    #  define PAS_LONGJMP _longjmp
    #endif

**No translation unit here held a conditional before this one.** That is a
discipline worth keeping and not an accident: each unit is bounded by what it
may depend on — `pasrt.c` to ISO C plus a catalogue of names, `pasrt_posix.c`
to eleven headers, `pasrt_task.c` to `<pthread.h>` (ADR-0186) — and a `#if`
makes that bound depend on who is compiling.

So the door is made narrow by the same mechanism every other bound here uses.
`runtime-isoc` reads the `#if`, `#ifdef` and `#ifndef` conditions across all
four units and compares the set against `tests/checks/nonstandard_c.txt`, in
**both** directions: one that appears without a row is a bound nobody argued
for, and a row whose condition is gone is describing a runtime that no longer
exists, which is `verify/`'s `KNOWN_GAP` rule (ADR-0013).

Both arms were run. Striking the row while the code holds the conditional
fails; adding a second `#ifdef __GLIBC__` fails and names it.

## Consequences

**`runtime/pasrt.c` compiles for a target that is not POSIX.** Two of four
units now do, and `runtime-nonposix` demanded the catalogue record it:

| Unit | For mingw-w64 |
| --- | --- |
| `pasrt.c` | **compiles** |
| `pasrt_unicode.c` | **compiles** — the whole of AP 6.4.15 |
| `pasrt_task.c` | wants only UCRT, a build configuration and not this source |
| `pasrt_posix.c` | blocked, seven headers: sockets, the terminal, `posix_spawn` |

So the core runtime is portable and the remaining question is exactly the one
`doc/roadmap.md` has been asking: whether a first Windows target ships
`PasNet`. Nothing else blocks.

**A mingw-w64 version difference stops mattering.** `runtime-nonposix` found
`pasrt.c` compiling on Ubuntu 24.04's mingw and blocked on Debian trixie's,
because the older one declares `_longjmp`. The catalogue pins the toolchain for
that reason; this makes the difference irrelevant to whether the unit compiles,
which is the better place for it to be.

**The `#if` is not a licence.** The catalogue holds one row and the gate holds
it both ways. A second conditional is a decision with a record, and the row
above it has to carry the argument — which is what `nonstandard_c.txt` already
demands of a name.

**Nothing runs on Windows.** `-fsyntax-only` is the whole of the claim, as it
has been since ADR-0369. `pasrt_posix.c` does not compile, so nothing links,
and no Windows binary has been produced or executed by anything here.

## Alternatives rejected

**Call `longjmp` everywhere.** Correct on glibc and wrong on Darwin, measured
both ways. It would have needed no conditional and no record, which is exactly
why it is worth writing down that it was tried.

**Move the jump into the emitted code.** The right shape, and it needs a
reseed. Deferred to one, where it costs nothing extra.

**Put the jump in a per-platform translation unit.** `pasrt_posix.c` is for
what needs a POSIX *type* (ADR-0186), and a jump needs none; a new
`pasrt_win32.c` would be a fifth unit existing for four lines, and the build
would have to choose between units per platform — a larger conditional than the
one it avoids, spelled in CMake instead of C.
