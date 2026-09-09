# ADR-0372: macOS is a target the compiler names

## Status

Accepted. Admits `arm64-apple-macosx` and `x86_64-apple-macosx` as this
compiler's fifth and sixth targets. Follows ADR-0371, which admitted a fourth
and made one emitted call depend on which; closes `doc/sop.md` §7's row saying
`--target=` admits no Darwin triple.

## Context

macOS has been a job that can fail since ADR-0368, and every module built there
announced itself as `x86_64-pc-linux-gnu`. It worked, and the reason it worked
is that clang overrides both the datalayout and the triple when it assembles —
which the aarch64 job has relied on since ADR-0155, so this was not new and not
peculiar to macOS.

**What it costs is that nothing may believe the header.** `doc/sop.md` §7 put
it this way: `llc-second-backend` and any `--dump-layout` claim are about a
machine the module does not name. That is a live gap on the one platform
besides Linux that this project runs, and it has now outlasted three targets
admitted for platforms it does not.

ADR-0371 made admitting one cheap. It also made it *checkable in a new way*:
`setjmp-arity` compares the emitted `_setjmp` call against what the target's
own C library declares, so the one thing about a Darwin target that could not
be settled from a Linux machine gets settled on the macOS runner.

## Decision

**Admit both Darwin triples, and let the module state the truth.**

Their datalayouts are clang's own, and each is byte-identical to the Linux
target of the same word size but for **one field**: `m:o`, the Mach-O symbol
mangling, against `m:e`. Nothing that is a size or an alignment differs, which
is what makes `target-layout`'s first claim — targets of one word size lay
every frame out identically — true of them by construction rather than by luck.
Both are LP64, so `PtrSize`, `WordAlign` and `CLongSize` are untouched; unlike
ADR-0371's Win64 this target changes no arithmetic at all.

Four spellings are read for the arm64 one and two for the x86-64 one. `arm64`
and `aarch64` name one machine to clang and both are written by people, as
`i386` and `i686` already are; `darwin` and `macosx` are the two spellings of
the system. The module states the unsuffixed canonical name.

## What had to be fixed first, and it was a real premise error

`setjmp-arity` asked what ISO C's `setjmp` expands to, because on glibc and on
mingw it is a **macro** naming `_setjmp`. **Darwin is not like that**: `setjmp`
is a function and `_setjmp` is a second one beside it. A probe calling `setjmp`
there emits `@setjmp`, so the gate would have reported that its premise did not
hold the moment this target existed.

The question it was always really asking is *what arity does `_setjmp` take
here*, that being the name the emitted module carries — so where `setjmp` is a
macro naming it the first probe answers, and where it is not a second probe
calls `_setjmp` directly. Verified before this record by feeding a
Darwin-shaped `<setjmp.h>` to one target through a clang wrapper: before, the
premise failed; after, the target compares and reports one argument.

**The emitter names `_setjmp` on every target for the reason glibc and Darwin
share**: it is the one that does not save the signal mask. ADR-0371 measured
that at 265 ns against 2.4.

## Consequences

**The macOS runner gains a gate rather than a skip.** `setjmp-arity` skipped
there because every admitted target was a Linux or a Windows triple and Apple
clang has a sysroot for neither. With a Darwin target admitted, the host target
is comparable, so the arity claim is checked against Darwin's own header on the
platform itself — the one fact about this target that a Linux machine cannot
settle. It was the only one of the macOS job's ten skips that a change to this
compiler could close.

**`--target=` is now six**, and `target-layout` compares all six against
clang's arithmetic on every run without being edited (ADR-0144).

**`line-coverage` found the cost, as it did for the fourth target.** Five
statements never run — `TargetIndex`, `TargetName` and the datalayout writer,
twice over. `coverage.py` drives an ordinary program for each, which is enough
here and was not enough for Win64: that one changes a byte the code generator
emits and needed a source with a non-local goto.

**What is *not* claimed is that anything is compiled for Darwin from here.** No
Darwin SDK is present on a Linux machine, so `setjmp-arity` reports both as not
compared and `target-layout` asks clang only about arithmetic, which needs no
sysroot. The runner is where the second half is answered.

**The `package` job's macOS leg stays disabled.** A Darwin triple was one of
the three things its comment named; the other two — `APASCAL_STATIC_PASCALC`
and `RELEASE_REQUIRE_STATIC` — are untouched, and shipping a platform is a
decision this does not make.

## Alternatives rejected

**One Darwin target rather than two.** A Mac is either, and the two datalayouts
differ. Admitting one would have made the other a wrong answer rather than an
absent one.

**Wait for the release leg.** The gap is in what the module *says* today, on
every build the macOS job makes, and it is independent of whether a macOS
archive is ever shipped.

**Make the module's header depend on the host.** It already does not, by
design: `--target=` is a claim the caller makes and ADR-0156 put it there
precisely so a module can name a machine that is not this one.
