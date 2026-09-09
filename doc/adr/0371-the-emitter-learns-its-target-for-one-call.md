# ADR-0371: The emitter learns its target for one call

## Status

Accepted. Admits a fourth target, `x86_64-w64-windows-gnu`, and makes the
`_setjmp` call the emitter writes depend on it. Follows ADR-0369, which
measured the runtime against a non-POSIX target, and ADR-0370, which removed
two of the three names that stopped `runtime/pasrt.c` compiling for one.

## Context

ADR-0370 left `pasrt.c` **one name** from a target that is not POSIX, and
recorded that the name is not what `doc/roadmap.md` had called it. The roadmap
said `_longjmp` differs from `longjmp` only in whether the signal mask is
restored. Measured:

    glibc, Darwin   setjmp(x)  ->  _setjmp(x)             one argument
    Win64           setjmp(x)  ->  _setjmp((x), frame)    two, via __imp__setjmp

**It is an arity and not a spelling.** Windows unwinds through SEH, and the
second argument is the frame the unwinder walks from. The emitted module calls
`_setjmp` with one argument, so on Win64 that is a wrong arity — and this is
the class `doc/sop.md` §7 records nothing here checks: LLVM does not compare a
direct call against its declaration under opaque pointers, so the module
verifies, assembles, links, and the defect is a corrupted unwind at run time.

`_setjmp` is there at all because ISO C makes `setjmp` a **macro** whose
expansion must appear in a very restricted set of contexts. What a module can
name is whatever that macro expands to, and it cannot be called through a
runtime wrapper: the wrapper would have returned by the time the jump arrived,
and its frame is what `_setjmp` recorded.

**Two shortcuts were measured and refused.**

*Call ISO C's `setjmp` symbol instead.* It exists on both platforms. It costs
**265.4 ns against `_setjmp`'s 2.4** on glibc — a `sigprocmask` syscall,
because that symbol saves the signal mask. (A first version of ADR-0370 said
these were 2.0 and 3.0 and drew the opposite conclusion; both loops had
compiled to `_setjmp`, the macro expanding to it. That correction is in the
record.)

*Have the runtime call ISO C's `longjmp` against a `_setjmp` buffer.* It works
on glibc — verified, and the mask is not restored, because glibc's `longjmp`
reads a flag the buffer carries. It is **not portable**: the BSD rule is the
opposite, `longjmp` restoring a mask that `_setjmp` never saved, and macOS is
a platform this project now requires to pass.

## Decision

**Admit `x86_64-w64-windows-gnu` as a fourth target, and emit the `_setjmp`
call in the shape that target's C library gives it.**

On Win64 the module writes

    %f = call ptr @llvm.frameaddress.p0(i32 0)
    %a = call i32 @_setjmp(ptr %env, ptr %f) #0

and declares `@_setjmp(ptr, ptr)`; on the other three it writes what it always
wrote. `llvm.frameaddress` supplies the frame, and it is the same frame the
call is made in the middle of — the reason this call is emitted here rather
than behind a wrapper is the reason the address is honest.

**The target is also the first that is LLP64.** A pointer is eight bytes and a
C `long` is four, a combination the three before it do not have: i386 is ILP32
and the other two LP64. `CLongSize` is the whole of what that costs, and it is
one line — the foreign boundary was given `clong` and `csize` by ADR-0328
precisely so a binding can say "whatever this target's is" instead of a
number. Its datalayout differs from `x86_64-pc-linux-gnu`'s in **one field**,
`m:w` against `m:e`, which is symbol mangling and not a size, so every frame
offset is identical — which makes `target-layout`'s first claim true of it by
construction rather than by luck.

## Why a target for a platform that cannot run

Nothing here runs a Windows binary, and `runtime-nonposix` still reports
`pasrt.c` blocked. A target is admissible anyway because **it is a claim about
the module the compiler writes**, and two things judge that without a Windows:
`target-layout` compares this compiler's arithmetic against LLVM's for every
admitted target, and `llc -mtriple=x86_64-w64-windows-gnu` assembles the
result — it produces COFF, and `clang --target=x86_64-w64-mingw32` compiles the
same module to an object whose only undefined symbol is `_setjmp`.

## The gate

`setjmp-arity` (`tests/checks/setjmp_arity.py`) is `foreign-layout`'s mechanism
applied to the one call: **the source states a claim and a C compiler holding
the real header judges it.** For every target the compiler admits it compiles
a C probe with clang and a Pascal probe with a non-local goto, and requires

- the arity of the emitted call to equal the arity clang emits for `setjmp`;
- the module's own `declare` to agree with its calls, or one function has two
  signatures in one module.

The target list is the compiler's own `--target=` refusal (ADR-0144), so a
fifth is compared without editing the check.

**Its floor is that the answers are not all the same** — a gate comparing
targets that happen to agree proves nothing about target-dependence — **and
that floor is conditional, which the first version of this record did not
say.** A target is compared only where clang has that target's headers:
asking for a triple whose sysroot is absent fails cleanly (`'setjmp.h' file
not found`) rather than falling back to the host's header and answering about
the wrong C library, which was checked before it was relied on. On a machine
with no mingw-w64 the only target with the other arity is exactly the one that
cannot be compared, so demanding two arities everywhere would fail for want of
a cross toolchain rather than for a defect. `SETJMP_ARITY_REQUIRE` demands it,
and it is set in the container job that builds and runs the suite, which
installs mingw-w64 for this and nothing else (ADR-0330). Not in `non-posix`,
which has the cross toolchain but deliberately builds nothing — the Pascal
probe has to be compiled by the compiler under test. Elsewhere the check compares what it can and says
what it could not.

Three mutations were run: reverting the Win64 call to one argument fails it on
all three counts, including the floor; leaving the *declaration* alone at one
argument fails on the signature; and both name the target. Two more cover the
conditional floor itself, through a clang wrapper that refuses the mingw
triple: unrequired it passes and reports the target as not compared, and
required it fails naming the missing toolchain.

## Consequences

**One property of the foreign boundary is now held for a function, where
ADR-0364 held one for a scalar.** `foreign-width` catalogues every `int64` in
an `external` and checks the width; this checks an arity, for the one function
the emitter itself declares. `doc/sop.md` §7's row says what is still not
checked: everything else about every other declaration.

**`line-coverage` found what admitting a target costs.** Twelve statements
were never run, then seven after a `--dump-layout` case for the new target,
because the last two arms need *code generation* and no corpus source varied
the target that far. `coverage.py` now drives `tests/goto_nonlocal.pas` for
Win64 — the sweep already drove `--target=` for aarch64, and this is the first
target whose difference reaches past the two lines at the top of the module.

**`tests/dumps/target_win64.pas` pins the LLP64 property as a golden**, beside
`target_i386.pas`: `clong` is 4 bytes there and 8 on Linux while `csize` is 8
on both, which is the whole of the difference in one record.

**The runtime is still one name short.** `runtime/pasrt.c` calls `_longjmp`,
which mingw has not got, and the portable pairing is not available for the
reason above. That is the next decision and it is not this one: it needs a
platform split in the runtime, and `runtime/pasrt.c` is bounded by a catalogue
of *names* rather than by conditional compilation today.

**Nothing asserts that a Windows program runs.** `-fsyntax-only`, `llc` and
`clang -c` are the whole of what is checked, as ADR-0369 said of its own claim.

## Alternatives rejected

**Pass the frame pointer on every target.** One shape, no branch — and a wrong
arity on the other three, which is the defect this record is about, pointed the
other way.

**Emit `setjmp` and let each platform's macro sort it out.** A module names a
symbol; there is no macro at that point. And the symbol costs 265 ns.

**Wait until the runtime compiles for Windows.** The emitter's half is
checkable today by two tools that need no Windows, and the runtime's half needs
a decision about conditional compilation that this one does not.
