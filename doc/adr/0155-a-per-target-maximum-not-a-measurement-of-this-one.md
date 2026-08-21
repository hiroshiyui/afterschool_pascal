# ADR-0155: A per-target maximum, not a measurement of this one

Date: 2026-08-22

## Status

Accepted. Item 1 of `doc/roadmap.md`'s cross-platform chapter, and the one thing
that stopped a build for another architecture.

## Context

Two C structs have their size written down twice: in `runtime/pasrt.h` as
`PAS_FILE_SIZE` and `PAS_JUMP_SIZE`, and in `selfhost/compiler.pas` as
`fileSize` and `jumpSize`. The compiler is what allocates the bytes — a file
variable's storage and a block's jump record are opaque to it, exactly as
ADR-0021 and ADR-0032 intend — and the two files cannot include one another, so
`selfhost/irtest.sh` checks that the four numbers agree.

**Agreeing is not the same as being right.** Both were measurements of x86-64
written as constants, and one of them is wrong everywhere else:
`struct pas_jump` embeds a `jmp_buf`, which is the platform's business.
Measured with the cross toolchains a Debian box installs in one package:

| target | `jmp_buf` | `struct pas_jump` |
| --- | --- | --- |
| x86-64 | 200 | 216 |
| aarch64 | 312 | **328** |
| arm (32-bit, hard float) | 392 | **400** |
| i686 | 156 | 164 |

`PAS_JUMP_SIZE` was **256**. So the runtime's own `_Static_assert` stopped an
aarch64 build before anything else could be tried — which is the right failure
and is why nothing worse happened, but it is also the whole of the platform
lock for an LP64 little-endian target. `doc/roadmap.md`'s cross-platform
chapter has the rest of that measurement: the frame layouts are identical
between the two targets over 4501 sizes and offsets, and the seed retargets by
replacing two lines.

`PAS_FILE_SIZE` is fine and stays: `struct pas_file` is four pointers and some
ints, 112 bytes on every target above at 64 bits and less at 32.

## Decision

**1024, and it is a bound rather than a measurement.**

It clears every target in the table with room, and clears glibc's powerpc64 —
the largest one no compiler here can measure, whose `__jmp_buf` is 64 longs, so
the struct is about 648. The number is documented at both sites with the
measurements behind it, so the next person raising it has the data rather than
a fresh guess.

**The cost is paid only by a block that is the target of a non-local `goto`**,
which is the only kind that carries a record at all — `EmitFrameType` writes the
array only when `nlLabels <> nil`. `selfhost/compiler.pas` contains no `goto`,
so no frame in `seed/pascalc.ll` has one and the seed did not have to be
regenerated for this.

**2. `tests/checks/target_sizes.sh` asks the question one machine cannot.** For
every target a compiler is installed for, it compiles `runtime/pasrt.c` — the
file the two `_Static_assert`s live in. Compiling the real file rather than
re-measuring the structs here is ADR-0144's lesson: a check that holds both
halves of its own comparison cannot fail, and a copy of a struct definition is
exactly that.

It reports **which targets it reached**, always, and skips with 77 when only the
host is available — a run that asked nothing must not look like a run that
passed. CI installs `gcc-aarch64-linux-gnu` and `gcc-arm-linux-gnueabihf` for
it, which are the two that would have caught this.

**Two things about that were learned from CI rather than designed**, and both
are the same mistake in different places. Debian and Ubuntu ship a cross
compiler and its C library as separate packages, so `--no-install-recommends`
installed a driver that runs and then cannot find `<setjmp.h>` — and the first
version of this script read that as the size being too small, which is an
accusation against the wrong file. A compiler on PATH is not a usable compiler,
so every target is probed with a trivial translation unit first and one that
fails there is reported *incomplete*, naming the package.

And reporting it is not enough on a job whose purpose was to install those
compilers: a skip there is a green run that asked nothing.
`TARGET_SIZES_REQUIRE` names the targets that must be reached, CI sets it to
those two, and an absent or header-less one is then a failure. It is the
arrangement `second-backend` already has — install `llc` and refuse to pass by
skipping.

## Consequences

`runtime/pasrt.c` now compiles for aarch64, 32-bit arm (both ABIs), i686 and
x86-64. **And a complete aarch64 `pascalc` links**: retarget `seed/pascalc.ll`
by replacing its two header lines, assemble it with
`clang --target=aarch64-linux-gnu`, and link against a runtime built by
`aarch64-linux-gnu-gcc`. That is the first compiler binary this repository has
produced for another architecture.

Reverting `PAS_JUMP_SIZE` to 256 fails `target-sizes` on aarch64 and on both
arm ABIs, naming the assert.

### What it does not do

**Nothing has been run.** The aarch64 binary links and `file` says it is an
aarch64 executable; there is no emulator on the machine where this was measured,
so it has not been executed and no test here runs it. The evidence stops at
*links*.

**The compiler still emits x86-64.** That binary would be an aarch64 program
that writes `target triple = "x86_64-pc-linux-gnu"`, which is a cross compiler
by accident rather than a port. Item 2 of the chapter — `--target=` — is what
makes it emit for the machine it runs on, and it is deliberately not in this
change: this one is a latent portability defect and that one is a feature.

**It does not make the sizes derived.** They are still two numbers agreed
between two files. Deriving `jumpSize` from the target would need the compiler
to know the target, which is item 2 again, and would still need this bound as
the default. What changed is that the number is now a maximum with its evidence
attached, and something fails when it stops being one.

### Rejected: a pointer in the frame and a heap record

The frame would hold a `ptr` and the runtime would allocate, which removes the
constant entirely and is target-independent for ever. It costs an allocation
and a free on every activation of a block with a non-local label, introduces an
out-of-memory failure into a construct that has none, and puts the `jmp_buf`
somewhere the epilogue has to reclaim on a path a non-local `goto` deliberately
skips. ADR-0032 put the record in the frame so that abandoning an activation
abandons its record; that property is worth more than the constant costs.
