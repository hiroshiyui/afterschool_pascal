# ADR-0157: The offsets are compared on every run

Date: 2026-08-22

## Status

Accepted. The gate `doc/roadmap.md`'s cross-platform chapter said item 1 could
not supply, and half of item 3.

## Context

`LlSize` and `LlAlign` in `selfhost/compiler.pas` are hand-written, because the
emitter has no `DataLayout` to ask (ADR-0028). They decide two things — the
length a whole-variable copy moves, and the size `new` allocates — and they
answer with **one number for every target**. That is correct only while every
target the compiler admits agrees about every frame it emits.

ADR-0156 admitted a second target on the strength of a comparison that said
they do agree: 4501 sizes and offsets, identical between `x86_64-pc-linux-gnu`
and `aarch64-linux-gnu`. It was measured **once, by hand, on 2026-08-22**, and
the chapter's "What is not claimed" said so in as many words:

> What still has no gate is the **offset comparison** — the 4501 numbers above
> were measured once, by hand, and nothing re-runs them.

A claim no test names is a claim nothing checks (ADR-0067). This repository has
been green over a `verify/` model describing a compiler that had been replaced
and over four documented `--dump` flags no case ever passed; a number measured
once and written into a roadmap is the same shape.

## Decision

`tests/checks/target_layout.py` is a `ctest` case. It emits every frame type
this compiler produces as a module of `ptrtoint getelementptr` constants — one
per field offset and one per frame size — assembles that module once per
admitted target, and compares the numbers LLVM folded them to.

Four things about how, each of which is the decision rather than the mechanism:

- **The frame types come from the emitter, never from a copy.** Two sources are
  compiled by the built `pascalc` and their `%frameN = type` lines read back:
  `selfhost/compiler.pas` for breadth, and `tests/checks/target_layout.pas` for
  the types the compiler has no frame slot of. That is ADR-0144's lesson — a
  check holding both halves of its own comparison cannot fail — applied to a
  layout instead of to a name.
- **The probe exists because breadth was not enough.** The compiler's own 615
  frames contain no `i256`, and an i256 in a record is the exact shape of
  ADR-0028's segfault. A comparison drawn only from the compiler would have
  agreed 4500 times without asking the question that has actually cost this
  repository a day. The probe adds a set, a `complex`, a file, a
  variable-string, an optional, an `int64`, a conformant array and a schematic
  formal.
- **The target list is read from the compiler's own refusal.** `--target=` with
  an unknown name prints the admitted ones, and this gate parses that line. A
  third target added to `TargetIndex` is therefore compared without this file
  being edited — and the refusal already says "needs its layout compared
  against `LlSize` and `LlAlign` first", which is exactly this comparison.
- **It does not skip.** `target-sizes` needs a cross *toolchain* and skips with
  77 where there is none; this needs only a clang backend, which every clang
  has for every target it knows. So the question is asked on a developer's
  machine, not only in CI.

It fails in both directions. A field that moves between two targets fails,
which is the divergence. So does a run that compared nothing — an empty
comparison is what a clean run and a run that reached no frame at all both
produce, which is `difftest`'s lesson, so the count is asserted against a floor
rather than printed.

## Consequences

4512 offsets are compared on every `ctest`, in about half a second.

**Mutations.** Admitting `i686-linux-gnu` — a 32-bit target, which is exactly
the state the gate exists to make impossible, since `LlSize` says a pointer is
8 — reports 3878 of 4512 offsets differing. Dropping the compiler from the
source list leaves 21 offsets and fails the floor. Both were run.

**The floor is a floor and not a count.** The exact number moves with every
declaration added to the compiler, so pinning it would make this gate fail for
reasons that are not about layout at all. What it has to refuse is the *empty*
comparison.

**A target's datalayout is asked of clang and then ignored by it.** The module
states one and clang overrides it with the one for `--target=`, silently —
which is ADR-0156's own measurement. The authority for what is compared is
`--target=`; stating the line anyway costs nothing and makes the probe module
say what it means.

## What this does not do

- It does not check anything but frames. A global's alignment, a string
  constant's, and the ABI by which arguments travel are all outside it. The
  ABI in particular is LLVM's business and not this compiler's, which is the
  point of ADR-0030's and ADR-0051's "nothing that is two words may depend on
  how a struct is passed".
- It does not run anything on the second target. That is the arm64 CI job
  (ADR-0159), and the two are complementary: this one asks a question about
  every frame without leaving x86-64, and that one asks about one machine by
  executing on it.
- It does not make a third target's admission automatic. It makes the *check*
  automatic, which is the opposite: admitting a target now requires the
  comparison to pass rather than requiring somebody to remember to run it.
