# ADR-0374: Windows runs, and Windows is deferred

## Status

**Superseded by [ADR-0380](0380-the-target-is-posix.md)**, which drops
Windows rather than deferring it. What this record *measured* is unaffected and
is the reason that decision could be taken with its cost known; what is
superseded is the disposition.

Accepted as written. Records what running a Windows program measured, and
defers the platform. Follows ADR-0369 through ADR-0373, every one of which asserted that
something *compiles*.

## Context

**Every Windows claim in this tree was `-fsyntax-only`.** ADR-0369 measured
which translation units compile; ADR-0370 removed two POSIX names from
`pasrt.c`; ADR-0371 made the emitter write the `_setjmp` its target declares
and checked the arity against clang; ADR-0373 closed the runtime's half of the
jump, and `pasrt.c` compiled. `llc` produced COFF and `clang -c` produced an
object.

None of that builds an executable, and `doc/sop.md`'s opening sentence is that
a green suite is not evidence. Four records in a row had asserted a compile, so
one was built and run under wine 10.0.

## What running measured

**A trivial program works.** `tests/hello.pas`, emitted for
`x86_64-w64-mingw32`, linked against `pasrt.c` and `pasrt_unicode.c` and run
under wine, prints what its golden says. That is the first Windows binary this
project has produced. Reproduce it with:

    pascalc --target=x86_64-w64-mingw32 tests/hello.pas -o hello.ll
    clang --target=x86_64-w64-mingw32 -std=c11 -O2 -I runtime \
        -c runtime/pasrt.c -o pasrt.o          # and pasrt_unicode.c
    clang --target=x86_64-w64-mingw32 -c hello.ll -o hello.o
    clang --target=x86_64-w64-mingw32 hello.o pasrt.o pasrt_unicode.o -o hello.exe
    wine hello.exe

**The runtime must be built by clang, not by mingw-gcc.** gcc compiles
`_Thread_local` to *emulated* TLS (`__emutls_v.pas_at`) where the emitted
module uses the native kind, and the link dies on a SECREL relocation against
`pas_at`. `tools/pascalcc` assembles and links with clang on every platform, so
this is how a port would build it anyway — but **no compile check could have
found it**, both compilers compiling the file without complaint.

**A Windows build writes CRLF where a POSIX one writes LF.** Windows stdio
translates `\n` on write. ISO 7185 leaves what a line marker *is* to the
processor, so this is not a defect — it means the corpus goldens are not
directly comparable across the two, and a port has a decision to take that
belongs in `doc/implementation-defined.md`.

**And the non-local goto crashes.** This is why the platform is deferred rather
than continued.

## The defect that decided it

`_setjmp` on Win64 saves XMM6 through XMM15 with `movdqa`, an *aligned* 16-byte
store, so its buffer must be 16-byte aligned. This compiler puts it at an
offset that is not:

    %frame1 = type { ptr, [15 x i64], i32, [128 x i64] }

places the `[128 x i64]` jump record at **offset 136**, and 136 mod 16 is 8.
`tests/goto_nonlocal` and `tests/goto_files` fault in ntdll at
`movdqa %xmm6, 0x60(%rcx)` with their own frame two lines down the backtrace.

**Proven in isolation**, so it is not an inference from a stack trace — a
`jmp_buf` placed by hand in a C program under the same wine:

    buffer at offset  16 (addr % 16 = 0): setjmp ok
    buffer at offset 136 (addr % 16 = 8): faults, same instruction address

**Aligning the frame is not the fix, and that was measured too.** Giving every
`alloca %frame*` and the level-0 global `align 16` leaves the field at +136 and
it still crashes. What has to move is the *offset*, which means the jump
record's alignment in `LlAlign` — and that moves frame offsets, which
`target-layout` compares against clang for all six admitted targets.

**Nothing else here could have found it.** `PAS_JUMP_SIZE` is 1024 against a
Win64 `jmp_buf` of 256, so the size is right and `target-sizes` has nothing to
report — and it builds for Linux triples only. `setjmp-arity` says the call has
the arity the target declares, which it does. `runtime-nonposix` says the units
compile, which they do. The defect is an *alignment*, and it is invisible until
something runs.

## Decision

**Defer Windows, and go on supporting the POSIX platforms well.**

A platform where a trivial program runs and the non-local goto faults is not a
platform this project can claim. The remaining work is a frame-layout change
measured across six targets, plus `runtime/pasrt_posix.c`'s seven missing
headers — sockets, the terminal and `posix_spawn` — and the `PasNet` question
behind them. That is a body of work, not a finish, and the platforms this
project *does* run deserve it more.

**What is kept**, because it costs nothing and is true: the six admitted
targets, `pasrt.c` and `pasrt_unicode.c` compiling for mingw, `runtime-nonposix`
and `setjmp-arity` and their catalogues. Those are measurements that hold on
every push and cost a second.

**What is not kept**: the wine harness. A gate for a deferred platform, running
in no CI job, is ADR-0282's own warning — automation with nowhere to be
exercised. The reproduction is above, and this record is what makes rebuilding
it an afternoon rather than a rediscovery.

## Consequences

**The alignment defect is real and unfixed**, and it is a defect in this
compiler rather than in Windows. It reaches no platform this project targets,
because it is `_setjmp`'s requirement on Win64 alone — but it is a latent
property of frame layout, and `doc/sop.md` §7 carries it so that a future port
does not spend a day finding it again.

**`doc/roadmap.md`'s Windows row becomes a report of a deferral** rather than a
list of unknowns, which is that file's own rule: a row saying a feature is
blocked is a row nobody has tried. This one was tried.

**And one finding was the harness's own.** The first sweep reported four
programs misbehaving; all four were the harness not passing the two scratch
paths `tests/run_test.py` passes, so programs that name their arguments
reported nothing wrong with the port. It also ran them in the repository rather
than in a directory it created — the one property CLAUDE.md says every harness
here holds — and left fourteen scratch files behind. Both are reasons the
harness would have needed work before it could have been a gate, and neither
changes what was measured.
