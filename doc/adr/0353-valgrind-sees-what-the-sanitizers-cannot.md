# ADR-0353: Valgrind sees what the sanitizers cannot

Date: 2026-09-07

## Status

Accepted. Adds a fourth mode to `tests/checks/sanitize.sh` and the
`valgrind-corpus` gate. **Closes ADR-0342's largest finding**, which had stood
as a `doc/sop.md` §7 row since 2026-09-06 with no instrument proposed that did
not change what every compilation emits.

## Context

ADR-0342 established the sharpest blind spot this project has had:
**AddressSanitizer has never instrumented compiled Pascal.** The emitted IR
carries no `sanitize_address` attribute, and clang's pass instruments only
functions that do — so `AFTERSCHOOL_PASCAL_CFLAGS=-fsanitize=address` reaches
the compilation of the `.ll` and changes nothing about a program's own loads
and stores. Reproduced then and again now:

```pascal
new(p); q := p; dispose(p); q^.v := 5; writeln(q^.v:1)
```

prints `5` and exits 0 under a fully ASan-linked binary. The same holds of
UBSan, LSan and ThreadSanitizer, and therefore of `sanitizers`,
`thread-sanitizer` and every hand-run of either: what those four watch is
`runtime/*.c`, and not one line of the Pascal.

The fix ADR-0342 measured was an attribute on every emitted function. It was
not taken, and rightly: it changes what every compilation produces and would
redden a gate over whatever 383 corpus programs turn out to contain. The row
recorded that the decision had never been put.

**Valgrind needs no decision, because it needs no instrumentation.** It reads
the binary. Given the probe above it reports an invalid write and an invalid
read where all four sanitizers report nothing.

## Decision

**`SANITIZE_MODE=valgrind` is a fourth mode of the one harness**, for ADR-0327
and ADR-0351's reason: the 120 lines that build a second runtime and link a
case's components are what must not be copied a fourth time. It is the only
mode that changes no build flag at all — `san=""` — and changes only what runs
the program.

**The detector had to learn a third vocabulary.** The existing arms match
`==pid==ERROR:` and `file:line:col: runtime error:`, and Valgrind writes
`==pid== Invalid write of size 4`. Without an arm for it the mode would have
run the whole corpus and reported every case clean — which is `format-check`
sweeping an empty list (ADR-0282) in a new place, and is why the arm is written
before the mode is believed.

**`--error-exitcode` is deliberately not used.** This harness decides by what
was *written*, as the address mode's own comment says, and a corpus case that
traps on purpose already exits non-zero. Deciding by exit status would have
called every deliberate trap a finding — which it did, once, in the first
five-program trial.

## Consequences

**The corpus is memory-clean: 377 programs, 0 flagged.** That is a statement
this project has never been able to make, and the first evidence that
`owned ^T`, `dispose`, slices and the string arena do what their records say at
run time rather than only in the model.

**It is the slowest gate here at 170 seconds** and roughly doubles the suite's
wall clock. `sanitizers` is 71 s and `selfhost-codegen` 137 s, so this is not
out of proportion, but it is the new maximum and ADR-0281's 86-second figure is
history. The price buys the only oracle in the tree for that class.

**Valgrind and the sanitizers are complements and not alternatives.** It sees a
program's own loads and stores, which they cannot; it does not see a data race,
which is ThreadSanitizer's half, and it is far slower than any of them. Neither
replaces the other and `doc/developer-guide.md` now says so in a table.

**It skips, and refuses to** (ADR-0330). Valgrind is not a documented
dependency — the build needs `clang`, `cmake`, `make` and `python3` — so
`VALGRIND_REQUIRE` is what a job sets to turn the skip into a failure, and
`require-consistency` checks in both directions that the variable and the job
exist together.

## What this does not do

**It does not detect a data race**, and `thread-sanitizer` stays exactly where
it is (ADR-0327).

**It does not make the `sanitize_address` decision unnecessary.** ASan is
orders of magnitude faster and could run on every push where this cannot
comfortably; what it does is remove the *urgency*, since the class is now
covered by something. `doc/sop.md` §7's row is narrowed rather than deleted.

**It did not find the intermittent it was installed for.** A coverage sweep
saw `tests/extended/lib_strings.pas` fail once with *unexpected character '}'*
and it has not reproduced — under Valgrind the compiler translating that file,
and all three of its own program-components, reports zero errors from zero
contexts. So the compiler is not reading uninitialised memory on the path that
failed, which removes the likeliest hypothesis and leaves the row open.

## Alternatives rejected

**Emit `sanitize_address` on every function.** ADR-0342's own proposal, and it
changes what every compilation produces to buy what a wrapper buys for nothing.
Worth revisiting only if the speed becomes the deciding factor.

**A fourth harness rather than a fourth mode.** The corpus loop, the component
linking, the trap-versus-finding distinction and the `.in` sidecar handling are
120 lines that three modes already share; a fourth copy would drift from them
the first time a sidecar convention moved.

**Run it in CI only.** It is the slowest gate and the argument is real. Against
it: this is the one oracle for a class of defect that a developer introduces
locally and would then push, and a gate whose findings arrive twenty minutes
later is one people learn to work around.
