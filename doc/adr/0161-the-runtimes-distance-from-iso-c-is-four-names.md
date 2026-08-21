# ADR-0161: The runtime's distance from ISO C is four names

Date: 2026-08-22

## Status

Accepted. The non-layout half of `doc/roadmap.md`'s cross-platform item 4.

## Context

`runtime/pasrt.c` is the only C in this project and the whole of what a port to
another platform has to satisfy. The cross-platform chapter answered how far it
is from portable by **assertion**:

> **macOS** changes the object format and the `m:` field of the datalayout, and
> `bind` and the file model are POSIX assumptions in the runtime;
> **Windows** changes the ABI, the C library and the file model together.

The first half of each sentence turned out to be wrong about layout — every
64-bit target lays this compiler's frames out identically, Mach-O and COFF
included. The second half deserved the same treatment, and it is the part the
chapter had no measurement for at all.

Measuring it is one command. A C library that honours `__STRICT_ANSI__` hides
its POSIX-only declarations, so `clang -std=c11 -pedantic-errors` turns every
non-standard use into "call to undeclared function".

**The answer is four names.** `bind` is not one of them: §6.7.5.6's binding is
`fopen`, and the file model is `fopen`, `fseek`, `ftell`, `fread`, `fwrite` and
`tmpfile` — all ISO C. So is everything else, including the time procedures
(`time`, `gmtime`, `localtime`) and `getenv`. With those four excused the
runtime compiles clean at `-std=c11 -pedantic-errors -Wall -Wextra`.

| name | why ISO C could not do it | macOS | Windows CRT |
| --- | --- | --- | --- |
| `_setjmp` | §6.8.3.11's non-local goto; called by the **generated code**, since the frame `setjmp` saves must be the one `longjmp` returns into | yes | yes |
| `_longjmp` | its other half, in the runtime | yes | yes |
| `fmemopen` | ADR-0057's `readstr` — a `FILE*` over memory, which ISO C cannot make | 10.13+ | **no** |
| `open_memstream` | ADR-0057's `writestr` — a `FILE*` whose buffer grows | 10.13+ | **no** |

So the chapter's two bullets resolve to two very different distances. **macOS
has all four**, and nothing else in the runtime is non-standard. **Windows has
the first two and neither of the last two**, and MSVC additionally has no
`_Complex`, which §6.7.6.2's complex functions are written in.

## Decision

`tests/checks/runtime_isoc.sh` is a `ctest` case, and
`tests/checks/nonstandard_c.txt` is the catalogue with an argument per name.

Three passes:

1. compile as strict C11 and harvest the undeclared names;
2. compare them against the catalogue **in both directions** — a fifth
   dependency appearing is what this exists to catch, and a catalogued name
   that stops appearing fails too, that being `verify/`'s `KNOWN_GAP` rule;
3. compile again with only those two diagnostics silenced and require a clean
   build, which is what says the four are the whole of it rather than the first
   four of a longer list.

And a fourth, over the other half of the boundary: every `.pas` in the two
**conformance** corpora is compiled and every `declare`d symbol that is neither
`pas_*` nor `llvm.*` must be catalogued. That is where `_setjmp` comes from —
the runtime never calls it. `tests/dialect/` is excluded on purpose: ADR-0121's
`external` lets a dialect program name any C function it likes, so a `declare`
there is the program's business rather than the compiler's.

**It skips (77) where the C library declares POSIX regardless.** macOS does, and
there the first pass reports nothing — which is indistinguishable from a runtime
that grew clean. A check that cannot ask its question says so.

## Consequences

The claim "the runtime is ISO C plus four names" is now checked rather than
measured once. Adding a fifth requires an entry and an argument, which is the
point: every one of them is something a port has to supply.

**It changes what a Windows port would mean.** Not "the C library and the file
model": two functions and `_Complex`. `fmemopen` and `open_memstream` are each
replaceable by a hand-written `FILE*`-over-memory, which is what a port would
have to write; the complex functions would need MSVC's `_Dcomplex` or a build
under mingw-w64.

**And what a macOS port would mean: almost nothing on this axis.** Layout is
identical, the runtime needs no change, and the emitted module names one symbol
outside its own runtime. What is untested there is everything else — no
machine, no CI, no `pascalcc` run.

**Mutations, both run.** Adding a `strdup` call to the runtime is reported as an
uncatalogued dependency; adding `mkstemp` to the catalogue is reported as an
entry describing a runtime that does not exist.

## What this does not do

- **It does not port anything.** No `fmemopen` replacement is written and no
  Windows or macOS build exists. What it establishes is the size of the job and
  keeps it from growing unnoticed.
- **It does not check the runtime against a second C library.** `-std=c11`
  against glibc's headers is one implementation's idea of what is standard.
  A musl or a Windows build would be a stronger oracle and there is none here.
- **It says nothing about semantics.** `fopen` exists everywhere and text-mode
  translation on Windows would change what `readln` sees; that is a portability
  question this gate cannot ask, and `doc/sop.md` §7 carries it.
