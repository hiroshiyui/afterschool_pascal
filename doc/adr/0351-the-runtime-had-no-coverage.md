# ADR-0351: The runtime had no coverage

Date: 2026-09-06

## Status

Accepted. Adds `tests/checks/runtime_coverage.py`, its ratchet, and a third
mode to `tests/checks/sanitize.sh`. ADR-0261 and ADR-0327 are not superseded —
this is their harness asked a different question. ADR-0350 is the same finding
one directory over.

## Context

The coverage review ADR-0350 came out of found five bodies of code and measured
one. `runtime/*.c` was the second-largest unmeasured one:

| | lines | measured, before |
| --- | --- | --- |
| `selfhost/` | 46 718 | yes — `line-coverage` |
| `lib/` | 11 160 | no — now `lib-coverage` (ADR-0350) |
| `runtime/*.c` | 5 551 | **no** |
| `lsp/pasls.pas` | 3 814 | no |
| `tools/pascalcc` | 688 | no |

`gcov` left this tree with the C++ implementation (ADR-0232) and nothing
replaced it. What the runtime *did* have was two oracles that run it and one
that reads it: every compiled program in the corpus links `libpasrt.a`,
`sanitize.sh` runs that corpus under ASan, UBSan, LSan and TSan, and
`runtime_isoc.sh` compiles it strictly. None of the three can say which of its
2 778 executable lines ever ran.

**And that number is more interesting than it looks.** ADR-0342 established
that AddressSanitizer never instruments compiled Pascal: `pascalcc` hands clang
an already-lowered `.ll`, and `-fsanitize=address` on an IR input adds nothing
to it. So `runtime/*.c` is not merely *part* of what the sanitizers watch — it
is the whole of it. An uncovered line here is a line all four checkers looked
at zero times, and `sanitizers` and `thread-sanitizer` have been reporting
clean over it since ADR-0261 with no denominator attached.

## Decision

**`runtime-coverage` measures `runtime/*.c` over the corpus that links it**,
and answers **2 342 of 2 778 lines, 84.3%**, per translation unit:

| | uncovered | executable | |
| --- | --- | --- | --- |
| `runtime/pasrt.c` | 248 | 1 720 | 85.6% |
| `runtime/pasrt_posix.c` | 111 | 353 | 68.6% |
| `runtime/pasrt_task.c` | 28 | 291 | 90.4% |
| `runtime/pasrt_unicode.c` | 49 | 414 | 88.2% |

Branch coverage is reported beside it — 1 007 of 1 474, 68.3% — and not
ratcheted. `line-coverage` ratchets both for the compiler because ADR-0274
found a defect the statement half could not see; here the line count is what
the review asked for and a second ratchet over the same sweep would be a second
number to justify for no second question.

**It is a third mode of `sanitize.sh` and not a fourth harness.** That script
already builds a second `libpasrt.a` with extra flags and links every case
against it, reading each case's `.components`, `.importpath`, `.importenv`,
`.opt` and `.in` sidecars. Those 120 lines are the part that took the defects
out — 47 cases were silently unlinked once, which is the whole of `lib/`
reaching the only memory-safety oracle here through no case at all. ADR-0327
refused to copy them for ThreadSanitizer and this refuses for the same reason.
`SANITIZE_MODE=coverage` swaps the flag string; `SANITIZE_RT_DIR` is the one
addition, because llvm-cov reads the coverage mapping out of the instrumented
**objects** and those have to outlive a sweep that removes its own work
directory.

**Clang's source-based coverage instruments where the sanitizers do**, which is
what makes the two questions the same shape: `-fcoverage-mapping` is a front
end pass, so the compiled Pascal's `.ll` reaches clang with no
`llvm.instrprof` intrinsics and acquires none. Nothing had to be arranged for
that; it is ADR-0342's asymmetry read the other way round.

**The whole corpus runs and there is no subset.** 377 programs, 47 s wall
clock, against the 2 400 s `sanitizers` is allowed. A documented subset was the
fallback if it had been slow, and the reason to prefer none is that a subset is
a thing someone can quietly choose to flatter a number.

## Consequences

**A ratchet, with the weakness `doc/sop.md` §7 already records for the other
three.** It fails when the uncovered count rises and says nothing when a line
becomes covered, and 436 uncovered lines carry no argument between them. The
per-file breakdown is what makes a regression nameable. This is the fourth such
number in the tree and the cost compounds — it is accepted knowingly rather
than unnoticed.

**Two floors, and they answer different questions.** `sanitize.sh`'s own floor
of 100 programs refuses a sweep that reaches nothing; this gate counts
`.profraw` files and refuses below 300, because a sweep can *build* every case
and run none. Cutting the corpus to `tests/` trips the first at 84 programs;
cutting it to `tests/` and `tests/extended/` gets past that and trips the
second at 249 profiles.

**`RUNTIME_COVERAGE_REQUIRE` refuses to pass by skipping** (ADR-0330).
`llvm-profdata` and `llvm-cov` are Debian's `llvm` package, separate from
`clang` exactly as compiler-rt is, so the gate skips 77 without them; the
`sanitizers` job installs `llvm` and sets the variable. The gate also passes
its own requirement down as `SANITIZE_REQUIRE`, so a job that asked for the
real answer cannot be handed a 77 from one layer down.

**What it does not cover**, none of it fixable here:

- compiled Pascal, deliberately — `line-coverage` and `lib-coverage` own that;
- the 195 cases with no `.out`, which are meant to fail at compile time and
  never reach the runtime, and the 12 that want file names on their command
  line, which is `sanitize.sh`'s own documented limit;
- `tests/dumps/`, `lsp/`, `tests/spec/` and `selfhost/`, which have harnesses
  of their own, and the gate harnesses — `tls.sh` most of all, for
  `lib_coverage.txt`'s reason: a number that moves with whether a machine has
  libssl is not a ratchet;
- a program killed by a signal, the profile being written by an `atexit`
  handler. `pas_runtime_error` goes through `exit()`, so every deliberate trap
  in the corpus is counted.

**`pasrt_posix.c` is the low row and its name is the reason.** It is the
sockets, the directory walk, the process and the clock, and their error paths
ask for what a corpus running on a working machine cannot arrange — a bind that
fails, a directory that vanishes mid-walk. That is a fault-injection question
and belongs to whoever answers it, not to this gate.

## Alternatives rejected

**A separate harness that compiles and links the corpus itself.** It is the
same 120 lines, and a copy of them is a copy free to drift — ADR-0327's
argument, and the 47-case defect is what it costs when they do.

**gcov.** It needs a second toolchain's conventions and writes `.gcda` beside
the objects; clang's source-based coverage is exact about lines and regions,
comes from the compiler this tree already requires, and merges 389 profiles in
26 ms.

**Ratcheting branches as well.** ADR-0274 earned that for the compiler by
finding something. Here it would be a second one-directional number over the
same sweep, and `doc/sop.md` §7's complaint is precisely that there are already
too many of those.

**Instrumenting the runtime in the normal build.** Every program in the corpus
would then carry profile output, `heap-balance` and the goldens would see it,
and the flags would reach an installed compiler. The second runtime the
sanitizers already build is the right place, and it is already built.
