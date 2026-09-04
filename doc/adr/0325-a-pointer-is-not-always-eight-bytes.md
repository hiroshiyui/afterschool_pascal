# ADR-0325: A pointer is not always eight bytes

Date: 2026-09-05

## Status

Accepted. Makes ADR-0028's layout rules target-dependent and admits a third
target. Changes what `target-layout` asks (ADR-0157) and adds `target32`.
ADR-0129's foreign-boundary question is **not** answered here and is catalogued.

## Context

`doc/roadmap.md`'s cross-platform chapter has had one row for a fortnight:

> **32-bit, which is the real work.** `LlSize` says a pointer is 8 by
> construction; `tyProc` and `tySlice` are two pointers; `tyFile`'s alignment
> is 8. All of those become target-dependent … Nothing here is blocked on
> measurement any more.

It was measured before a line was written, and **the row named four rules and
there are seven.** Asked of clang for `i386-pc-linux-gnu` against
`x86_64-pc-linux-gnu`:

| | x86-64 | i386 |
| --- | --- | --- |
| pointer, alignment | 8 | **4** |
| `i64`, alignment | 8 | **4** |
| `double`, alignment | 8 | **4** |
| two pointers, size | 16 | **8** |
| `<2 x double>`, alignment | 16 | 16 |
| `i256`, alignment | 16 | 16 |

`tyInt64`, `tyReal` and `tyHandle` are the three the row left out, and they are
the ones a reader would not have caught: a wrong alignment costs no diagnostic
anywhere, and a `real` field four bytes further along than LLVM puts it is a
whole-variable copy that reads the wrong bytes. The two the row did not
mention as unchanged — the set and the complex — were checked rather than
reasoned about, LLVM taking `i128:128` from i386's own datalayout for an `i256`
it names no alignment for.

## Decision

**`PtrSize` and `WordAlign` are two functions in ApTypes, and every layout rule
that wrote 8 asks one of them.** `--target=i386-pc-linux-gnu` is admitted, with
the triple and the datalayout taken from `clang --target=… -x c /dev/null -S
-emit-llvm` rather than transcribed.

`targetIx` **moves from the driver to ApTypes**. It was a variable of
`compiler.pas` while every layout rule was a constant; the rules are ApFront's
since ADR-0287, because a type's storage is a fact about the source program, so
the one thing both components need now lives in the one component both import.
The driver still owns the decision — `--target=` is parsed there.

## What running the corpus for it found

**Two defects, and neither is in a layout rule or a frame**, so every
arithmetic check here passed with both in place.

**`pas_select` indexed its arm array with `sizeof`** where the compiler strides
`PAS_SELECT_ARM_SIZE`. Those are one number on an LP64 target and two on i386
(24 against 16), and `runtime/pasrt.h`'s comment above the struct said *24 is
the larger and the array is indexed with it* — a sentence the C made false.
`tests/dialect/select.pas` segfaulted.

**And the compiler wrote the arm's fourth field at a literal 16**, which is
where an LP64 target puts it and four bytes past where i386 does. The two
offsets before it are ints and are 0 and 4 everywhere, which is why only the
last moved. Fixing the stride alone left the segfault exactly where it was.

Both are the same shape as the defect ADR-0185 was written for: a number agreed
between two files, and a *claim* beside it that nothing checked.

**And a third, in the coverage sweep itself.** `tests/checks/coverage.py`
appended a `.flags` file's contents as one argument, so a dump case with two
flags handed the compiler an unknown option — which it refuses, and the sweep
checks no exit status. Three cases were affected and two of them predate this
change: `format_range` and `range_refused` are ADR-0284's `--range` cases, and
the coverage sweep had **never run either**, while `format-check` ran them on
every run. `tests/dumps/run.sh` reads the file with `read -r -a`; the sweep now
splits it too, which is the property the two must have.

## Consequences

**564 of 570 corpus sources build and run for i386**, and the six are
catalogued in `tests/checks/target32_known.txt` with why. One is
`tests/index_span.pas`, which allocates 2 GB on purpose and has nowhere to put
it in a 32-bit address space — the program is 64-bit, not the compiler. The
other five are one cause: a foreign declaration naming a C `long`, `size_t` or
`time_t` as `int64`, which is right on LP64 and four bytes too wide on i386.
`strlen('hello')` answers 21474836485. That is ADR-0129's question, which the
roadmap already called *a decision rather than a lowering*, and it is not
answered here.

**`target-layout` asks a different question, and had to.** *Do the targets
agree with each other* is a claim a 32-bit target falsifies by existing, so
answering it would have meant refusing the port rather than checking it. Two
claims replace it: targets of the same word size lay a frame out identically —
the old comparison, unchanged and as strict, within each class — and **the
compiler's own size and alignment agree with LLVM's**, asked of every target
over six record shapes through `--dump-layout`. The second half did not exist
before, because nothing varied; it is also the first time this gate compared
the compiler's arithmetic against LLVM at all rather than one target's IR
against another's.

**`target32` is the new gate**, and it exists because `target-layout` passed
with a segfaulting `select`. It builds a runtime for the target, runs the whole
corpus, and compares against the catalogue in both directions. Skips 77 without
a 32-bit libc; `TARGET32_REQUIRE` refuses to pass by skipping.

**`tests/dumps/target_i386.pas` is the golden**, and it is what makes
`TargetIndex`, `PtrSize` and `WordAlign` reachable from the corpus — no other
case compiles for a third target. Both coverage ratchets are unmoved at 392 and
847 with the instrumented totals up, so every line this change added is run.

**Nothing moves for x86-64 or aarch64.** `PtrSize` and `WordAlign` answer 8 for
both, `selfhost-codegen`'s fixed point holds, and `verify/lowering.py` is
untouched — the model describes a lowering that did not change.

## What this does not do

**It does not make i386 a shipped target.** No release archive is built for it
(ADR-0296 attaches two), the seed is x86-64 and `seed/README.md`'s target lock
stands, and `target32` skips wherever a 32-bit libc is absent. What is claimed
is that the layout rules are right for a target that is not LP64 and that the
corpus runs there.

**It does not answer the foreign boundary.** Five catalogued cases wait on
ADR-0129's decision, and taking it here would have been a second feature
smuggled into a port.

**It does not touch s390x**, whose `tySet` alignment is the roadmap's other
small item: i386 does not have that problem, `i128:128` being in its
datalayout, and `target-layout`'s new claim 2 is what would catch it the day
somebody admits a target that does.

**It does not bound what a 32-bit `maxint` means.** `integer` is `i32` on every
target here and always was, so nothing about the language's arithmetic changes;
what changed is where things sit.

## Alternatives rejected

**Leave the rules constant and refuse 32-bit for ever.** It is what the
compiler did, and it is a language that cannot be built for a machine somebody
has. The refusal message already said the way out.

**Ask LLVM for a `DataLayout`.** ADR-0085's whole claim is that the build needs
nothing of LLVM's, and this compiler emits text.

**Make every rule a table per target.** Seven arms read two numbers; a table
would be twenty-one entries with twenty of them equal, and the day a target
needs a third number the two functions grow one and the table grows a column
nobody fills in.
