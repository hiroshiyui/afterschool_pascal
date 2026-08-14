---
name: performance-profile
description: Profile and analyze the performance of Afterschool Pascal on both axes — how fast the compiler compiles, and how fast the code it generates runs — then report concrete, correctness-safe optimization opportunities.
---

Performance is **explicitly subordinated to correctness and to the bootstrap**: a
faster compiler that miscompiles, or that drops a Pascal semantic to save a
branch, is a regression rather than a win. Every optimization here must leave
`ctest` green and the encoded semantics (`CLAUDE.md`'s list) intact.

Know which axis you are being asked about before you measure — they have almost
nothing to do with each other:

- **Axis A — compiler throughput.** How long `pascalc` takes. This is the axis
  the bootstrap cares about: the stage-1/2/3 build compiles the compiler's own
  source three times, so throughput is paid three times per change.
- **Axis B — generated-code speed.** How fast the compiled Pascal program runs.
  This is mostly LLVM's job, and the honest answer is usually "LLVM already did
  it". Our lever is emitting IR the optimiser can work with.

When asked to profile/analyze performance, follow these steps.

## 1. Establish the baseline — always a Release build

A `Debug` build of the compiler is unoptimized and gives meaningless throughput
numbers. Configure with `-DCMAKE_BUILD_TYPE=Release` before measuring anything.

There is **no benchmark suite yet** — say so in the report rather than implying
one exists. The current measurable workloads are the `tests/*.pas` files, which
are far too small to time meaningfully on their own. Build a workload first:

```sh
# a synthetic large input, since no real one exists yet
{ echo "program Big(output); var i, s: integer; begin"
  for i in $(seq 20000); do echo "  s := s + $i * 3 div 7;"; done
  echo "  writeln(s) end."; } > /tmp/big.pas
```

Then take the four numbers that separate the stages, because they attribute cost
without a profiler:

```sh
time tools/pascalcc --emit-llvm -O0 /tmp/big.pas -o /dev/null   # front end + codegen only
time tools/pascalcc --emit-llvm -O2 /tmp/big.pas -o /dev/null   # + the pass pipeline
time tools/pascalcc -c            -O2 /tmp/big.pas              # + object emission
time tools/pascalcc               -O2 /tmp/big.pas -o /tmp/big  # + the clang link
```

Record all four as the baseline. The differences are the attribution:
front end, optimiser, backend, linker.

**Expect the link step to dominate for small inputs** — spawning `clang` costs
tens of milliseconds regardless of program size (ADR-0009), so for anything
test-sized, total wall time is mostly process startup. Reporting "the compiler is
slow" when the measurement is really `clang` starting up is the classic error on
this axis; separate them before drawing conclusions.

## 2. Attribute the cost with a sampling profiler

`perf` is available at `/usr/bin/perf`; `cargo-flamegraph`-style wrappers are
not. `perf` needs `perf_event_paranoid ≤ 2` (`sysctl kernel.perf_event_paranoid`
to check). Profile the release binary directly:

```sh
perf record -g --call-graph dwarf -- tools/pascalcc -O2 --emit-llvm /tmp/big.pas -o /dev/null
perf report --stdio
```

Attribute every self-time leader to one of these classes:

- **LLVM** — the pass pipeline, `TargetMachine`, `verifyModule`. Usually the
  majority at `-O2`, and *not ours to fix*: the lever is choosing a cheaper
  pipeline for the bootstrap build, not making LLVM faster.
- **Front end** — `Lexer::tokenize`, the parser, `Sema`. Watch for the string
  work: every identifier allocates a `std::string`, the keyword lookup hashes it,
  and `Token` is copied into a `vector`. This is the classic hot spot in a
  hand-written lexer and the one place where an obvious win exists (interning, or
  a string view over the source buffer).
- **CodeGen** — `IRBuilder` calls and the `slots_` map lookups.
- **Process overhead** — LLVM's static initializers and target registration run
  on every invocation. Real, fixed, and only worth attacking if the compiler ever
  becomes a server.

## 3. Profile the generated code (axis B) separately

Compile the Pascal benchmark, then profile *it*, not the compiler:

```sh
tools/pascalcc -O2 bench.pas -o /tmp/bench && perf stat /tmp/bench
```

Compare against the same algorithm in C compiled with `clang -O2`. That
comparison is the only meaningful reading — it says how much our lowering costs
relative to what LLVM can do with an equivalent front end's output.

Read the IR before blaming the optimiser: `pascalc -O0 --emit-llvm` shows what we
handed LLVM, and most generated-code slowness is IR that blocked an optimisation
rather than a missed pass. Known shapes to look for:

- **Every variable is an `alloca`** with no `mem2reg` at `-O0`; at `-O1`+ the
  pipeline promotes them. If a variable stays in memory at `-O2`, something took
  its address or the block structure defeated promotion — that is a real finding.
- **Short-circuit `and`/`or` emit branches and a φ** (ADR-0010). The optimiser
  folds them back to a `select` when the operands are cheap; if it does not, the
  right operand had side effects or the blocks were not simplifiable.
- **`nsw` flags on integer arithmetic** let LLVM assume no signed overflow.
  They are load-bearing for loop optimisation, and removing them to "be safe" is
  a measurable pessimisation — but see the caveat in step 4.
- **Runtime calls are opaque.** Every `write` is a call into `libpasrt.a` that
  LLVM cannot see through, so output-heavy loops will not vectorise. That is by
  design (ADR-0007), and LTO is the lever if it ever matters.

## 4. Validate any proposed change is correctness-neutral

Before recommending (or applying) an optimization, the bar is:

- **`ctest --test-dir build --output-on-failure` is green**, including the cases
  that pin Pascal semantics.
- **The IR still verifies** — `verifyModule` runs on every compile, so a green
  suite already covers this, but a codegen change should also be read once at
  `-O0`.
- **`clang-format --dry-run --Werror`** clean on touched files.
- **No semantic is traded for speed.** The `mod` adjustment, the `for`
  limit-then-step, the division-by-zero check, and short-circuit evaluation are
  each a correctness commitment with an ADR or a test behind it. "We could drop
  the check" is not a performance finding, it is a proposal to change the
  language — which needs an ADR, not a benchmark.
- **`nsw` caution:** those flags assert that signed overflow cannot happen. ISO
  7185 leaves integer overflow undefined, so they are defensible — but if the
  project ever adopts wrapping or trapping arithmetic, the flags become a
  miscompilation source. Flag any change that widens their use.

## 5. Avoid the known dead ends

- **Micro-optimising the front end while `clang`'s startup dominates** — measure
  step 1's four numbers first; for test-sized inputs the answer is the linker.
- **Making the compiler multi-threaded.** A single translation unit is the whole
  program; there is nothing to parallelise, and it would complicate the port.
- **Hand-optimising the emitted IR** (peepholes in codegen, folding constants
  ourselves beyond what Sema needs). That is what the pass pipeline is for, and
  ADR-0003 bought it deliberately. Constant folding in `Sema` exists because the
  *language* requires it for constant declarations, not for speed.
- **Optimising a met budget.** If a full `ctest` run takes under a second, the
  compiler is not the bottleneck in anyone's day. Say so and recommend no change.

## 6. Report

Present a **Performance Profile Report** with these sections:

1. **Baseline** — which axis was profiled, the host, the workload used (state
   plainly that it is synthetic if it is), and the four-number attribution table
   from step 1.
2. **Hotspot attribution** — the top self-time leaders from `perf`, each mapped
   to a cost class with its approximate %.
3. **Generated code** — if axis B was in scope: the Pascal-vs-C comparison and
   what the IR shows about any gap.
4. **Improvement opportunities** — a prioritized list. For each: the lever, the
   expected magnitude, the **correctness-safety argument**, and the rough effort.
   Order by `gain ÷ effort`. Anything that would trade a language semantic for
   speed is flagged as out of scope, not ranked.
5. **Verification plan** — which tests gate each proposed change.

Keep recommendations honest about uncertainty: "string interning should cut the
front-end share, which is currently N%" is fair; inventing a speedup number is
not. If the compiler is already fast enough for the bootstrap loop, the correct
report says so.
