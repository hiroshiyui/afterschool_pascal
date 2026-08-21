# ADR-0159: The port is run, not argued

Date: 2026-08-22

## Status

Accepted. Item 3 of `doc/roadmap.md`'s cross-platform chapter.

## Context

The chapter measured the platform lock rather than estimating it, and it was
smaller than `seed/README.md`'s sentence suggested — two lines of emitted text
(ADR-0156), one size constant (ADR-0155), and a seed for the new host that the
textual retarget supplies. Each of those has landed.

And the chapter closed by saying what none of it amounted to:

> The evidence stops at **links**, not **runs**. No aarch64 binary produced by
> any of this has been executed, because the machine it was measured on has no
> emulator.

That is a claim nothing checks, which is the failure mode `doc/sop.md` §7
exists for. Everything that had been shown was that clang accepted the IR: the
seed assembles for aarch64, `runtime/pasrt.c` compiles, a complete `pascalc`
binary links. An assembler accepting a module is not the same as the program
being right, and this repository's own history is the argument — ADR-0028's set
in a record assembled perfectly and segfaulted.

## Decision

A CI job, `the compiler on aarch64`, on GitHub's `ubuntu-24.04-arm` runner. It
installs what `README.md` documents, configures, builds and runs the whole
suite — natively, on a machine that is not x86-64.

**`AFTERSCHOOL_PASCAL_TARGET` is what makes it mean something.** Set to
`aarch64-linux-gnu`, it is the target `tools/pascalcc` hands to both halves, the
way `AFTERSCHOOL_PASCAL_OPT` sets an optimisation level for a whole run and for
the same reason: the harnesses drive that script one program at a time and have
nowhere to put a flag. An explicit `--target=` still wins.

Without it the job would have passed and asked nothing about ADR-0156's aarch64
arm. `clang` overrides the module's triple and datalayout with its own target's,
and does it **silently** for the datalayout — so a compiler emitting an x86-64
header on an aarch64 host produces correct aarch64 code anyway. The job would
have been green over an emission path never taken.

Two steps exist to refuse a green run that asked nothing, which is this
repository's standing shape for a check that can skip:

- **`test "$(uname -m)" = aarch64`.** `runs-on` is a request, not a guarantee,
  and a job named for an architecture that quietly ran on another one would be
  the loudest possible version of the problem.
- **`TARGET_SIZES_REQUIRE: x86_64-linux-gnu arm-linux-gnueabihf`**, mirrored:
  the host is aarch64 here, so the target `target-sizes` cannot ask about
  itself is x86-64.

The last step compiles and runs `hello.pas` with **nothing set**, because that
is the path a reader of `README.md` on an arm64 machine takes, and the silent
override has to work as well as the explicit target does.

**No z3, deliberately.** `verify/` proves properties of the lowering *model* —
the same Python file on either machine — and the two x86-64 jobs already refuse
to pass without the proofs running. Nothing about them is a question about this
host.

## Consequences

Three claims stop being arguments:

1. **The seed retargets textually.** `seed/pascalc.ll` states an x86-64 triple
   and datalayout, and this job builds a working compiler out of all 181,302
   lines of it on aarch64. That is what breaks the chicken-and-egg
   `seed/README.md` describes — a compiler for a new host without a compiler on
   the new host — and it is now a build step rather than a paragraph.
2. **`LlSize` and `LlAlign` are right for a second machine.** ADR-0157 compares
   4512 offsets without leaving x86-64; this compiles and *runs* the corpus
   whose frames those rules laid out.
3. **`PAS_JUMP_SIZE` is large enough where it was too small.** `jmp_buf` is 312
   bytes here against x86-64's 200, and the constant was 256 until ADR-0155.
   `target-sizes` predicted this from x86-64; this is the machine it was
   predicting about.

**It found a defect before it ran once.** Setting the variable over the existing
suite failed `lib_os`, whose command line was already exactly at the
twelve-argument program-parameter limit — see ADR-0158, which is the fix and
which nothing else would have surfaced.

**Local evidence, short of running.** All 156 runnable corpus cases cross-compile
to valid aarch64 objects on the x86-64 machine this was written on, which is what
a developer can check without a runner; the CI job is what executes them.

## What this does not do

- **It does not make aarch64 a supported target.** No release ships an aarch64
  binary, `seed/pascalc.ll` is still generated for x86-64, and
  `seed/README.md`'s target lock stands. What the job establishes is that the
  port *works*, not that it is maintained as a product.
- **It does not close item 4.** Nothing here transfers to a target that is not
  LP64 little-endian Linux: ILP32 breaks `LlSize` for a pointer and ADR-0129's
  `i64` count at the foreign boundary, big-endian has not been looked at, and
  macOS and Windows change the object format and the file model. The chapter
  keeps that list.
- **It does not run the second backend or the proofs on aarch64.** `llc` is not
  installed there, so `llc-second-backend` skips, and z3 is left out for the
  reason above. Both are x86-64 jobs and stay that way.
- **It does not test a cross-compiled *program* by running it.** `pascalcc
  --target=aarch64-linux-gnu` on an x86-64 machine still produces an object
  nothing here executes. What is run on aarch64 is what was compiled on
  aarch64.
