# ADR-0345: A gate can answer about the wrong machine

Date: 2026-09-06

## Status

Accepted. Corrects `tests/checks/llc_check.sh`, `tests/checks/target32.sh` and
the `thirty-two-bit` job's package list. ADR-0330, ADR-0331 and ADR-0334 are
not superseded; this is the failure mode each of them was one step away from
naming.

## Context

Continuous integration on `main` was red for **thirteen consecutive pushes**,
from `3108564e` to `e5fcf97c`, and two jobs were the whole of it. Neither had
anything to do with the changes that kept landing under them, and the local
suite was green over both the entire time, which is why nobody chased them.

**`second-backend on aarch64` had never passed since ADR-0331 added it.** The
job sets `AFTERSCHOOL_PASCAL_TARGET=aarch64-linux-gnu`, and that variable is
read by `tools/pascalcc` and by nothing else — the compiler itself reads only
`AFTERSCHOOL_PASCAL_PATH` (ADR-0244). `tests/checks/llc_check.sh` drives
`pascalc` directly, being about the *compiler's* IR, so the modules it compared
carried `target triple = "x86_64-pc-linux-gnu"` on the ARM machine. `llc` reads
the triple out of the module, so it emitted x86-64 assembly, and the aarch64
assembler rejected the first comment it met: `#` begins an immediate on
AArch64, not a comment. The error read `unexpected token` under a line spelling
`.long 4714 # 0x126a`, which names nothing a reader would connect to a target.

**`thirty-two-bit` died at its own probe.** `clang --target=i386-pc-linux-gnu`
links every program against `crtbeginS.o`, `-lgcc` and `-lgcc_s`, which come
from GCC and not from the C library, and the 32-bit copies are in no package
`libc6-dev-i386` or `libc6-i386` depends on. The job's first step — a
deliberate C probe, added precisely so a missing package would be reported as
one — reported three `cannot find` lines naming files nothing in this
repository mentions.

**And when it finally ran, it disagreed with itself.** Two cases failed in the
container and passed on the machine this repository is developed on, with
nothing in the tree different between them.

## Decision

**`llc_check.sh` derives a `--target=` from `AFTERSCHOOL_PASCAL_TARGET` and
passes it to every `pascalc` invocation** — the reference modules, the
per-source acceptance sweep, and the compiler built from `llc`'s output whose
IR is compared byte for byte against the reference. It must name the *host*,
because this gate links what `llc` produced and then runs it; the two jobs that
set the variable each run on the machine they name.

**And it prints the target it proved**, beside the LLVM version it already
printed. The version was said to be "the whole of what it was"; it was half.

**The `thirty-two-bit` job installs `gcc-multilib`.** The version-independent
name is deliberate: `libgcc-14-dev:i386` supplies the same files and stops
being a package the day Debian moves to GCC 15.

**`target32.sh` names the processor: `-march=pentium4`.** The gate asks whether
a program behaves when a *pointer* is four bytes, and the floating-point unit
is no part of that question — but the default answer to it moved under us.
clang 19 compiles `i386-pc-linux-gnu` for `i686`, whose x87 registers are 80
bits wide; clang 21 compiles it for `pentium4`, which has SSE2 and rounds a
double to a double. Two cases turn on the difference:

  a) `tests/round_equivalence.pas`. §6.7.6.3 defines `round` by equivalence to
     `trunc(x ± 0.5)`, and for `x = -0.49999999999999994` that difference is
     exactly `-1.0` in double arithmetic and a shade above `-1` in an 80-bit
     register. The same C program prints the sum as `-1` and converts it to
     `0` in one statement, which is the whole of what excess precision means.

  b) `tests/trap_sqrreal.pas`, and this one is worth arguing about. D.32 makes
     `sqr(x)` yielding a value the type does not have an *error*, and the check
     is that the result is infinite where the operand was finite. An x87
     register has a fifteen-bit exponent, so `sqr(-1e200)` is an ordinary
     finite number in it and the check does not fire. **That is a missed error
     condition and not a difference of arithmetic.**

Each showed at one optimisation level and not the other, because whether the
intermediate reaches memory is the optimiser's decision — so before the
processor was pinned the gate's answer depended on **two** things it was never
about. `pentium4` is chosen because it is what a current clang already does, so
the gate measures what a user gets. The flag reaches the programs through
`AFTERSCHOOL_PASCAL_CFLAGS`, which is every clang `tools/pascalcc` starts
(ADR-0264), and the runtime and the probe are compiled with it directly.

**The catalogue stays one row.** It was about to gain two and a second field to
carry them, and both would have recorded a property of one distribution's
clang as a property of i386.

## Consequences

**Thirteen pushes of green local suites sat on top of a red bar, and the local
suite could not have said so.** `llc-second-backend` runs under `ctest` here
and passes, because on an x86-64 host the default triple *is* the host's. The
gate is correct on the machine its author had and wrong on the one it was
added for, which is the shape ADR-0331 existed to close and did not.

**What the gate no longer measures is x87-only i386, and that is now a
question about the product.** A user compiling for a processor without SSE2
gets a `round` that contradicts §6.7.6.3 and a `sqr` that does not detect
D.32's error, and nothing here would say so. Pinning the gate is right — it is
about pointer size and a floating-point unit is a second axis it never chose —
but it means the divergence is recorded in `doc/sop.md` §7 rather than
measured. **Whether this compiler supports x87-only i386 at all has never been
decided**, and the honest position is that it is untested rather than that it
works.

**A gate whose answer depends on a toolchain default is not a gate.** Both x87
cases passed for a developer on clang 21 and failed on CI's clang 19, so the
catalogue would have flapped with whichever machine last edited it — and the
both-directions property, which exists to make a moved claim loud, would have
made that flapping *look* like findings.

**The `*_REQUIRE` convention does not cover this.** ADR-0330 closed *a gate can
pass by skipping*; this is *a gate can pass by answering about something else*,
and no variable can detect it. What is in place instead is that the gate now
prints which machine it proved, so a reader of a green log can see it — which
is a reader and not a check.

## What this does not do

**It does not add an axis to any other gate.** ADR-0334 left "which of them
would pay" as a question in `doc/sop.md` §7 and it stays there. What this
change does is fix the one whose catalogue was already crossing two axes
without saying so.

**It does not make `llc_check.sh` verify the target is the host.** It could —
compare against `uname -m` — and the failure mode it would catch is a
misconfigured workflow, which is what this record is about. It is left out
because the check would be a second opinion about a triple's spelling
(`aarch64-linux-gnu` against `aarch64`), and getting *that* wrong would make a
correct job fail. The comment says the requirement instead.

**It does not fix the excess-precision divergences.** See above.

## Alternatives rejected

**Have the compiler read `AFTERSCHOOL_PASCAL_TARGET`.** It would have made this
work without touching the harness, and it is exactly what ADR-0244 refused: the
compiler binds one foreign name, and the driver is where a whole run is pointed
at a target (ADR-0156). A second variable in the compiler would make
`--dump-layout` and the seed depend on an environment nobody set.

**Catalogue the two x87 cases instead of pinning the processor.** This was
built before the cause was known — a second field on a catalogue row naming the
optimisation level it holds at, since each case failed at one level and not the
other — and it was thrown away when the host disagreed with the container. Both
rows would have been a property of clang 19 written down as a property of i386,
and the field would have been machinery with no caller. The measurement that
settled it is that `clang -### --target=i386-pc-linux-gnu` names `i686` on
clang 19 and `pentium4` on clang 21.

**Pin `-march=i686` instead, keeping the x87.** It is the more conservative
architecture and it is defensible as "what the triple says". It would make the
gate report a `sqr` that misses its error and a `round` that contradicts its
clause, on every run, as ordinary catalogued failures — which is a gate about
pointer size spending both its rows on a floating-point unit.

**Catalogue the two x87 rows as one entry.** They are one cause and the
catalogue is keyed by case, which is what makes it comparable against a run.
The shared cause is written into both rows instead.
