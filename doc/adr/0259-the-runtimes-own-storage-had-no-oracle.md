# 259. The runtime's own storage had no oracle

Date: 2026-08-30

## Status

Accepted, 2026-08-30.

## Context

Every gate in this tree compares what a program **printed**. `heap-balance`
(ADR-0183) is the one exception and its own record says what it is: it tallies
`pas_new` against `pas_dispose` and writes the balance at exit, and *"it counts
no files and no handles"*.

`runtime/pasrt.c` is the only C here. It does the allocation, the handles, the
`setjmp` buffers, the string arena and the file bindings — and nothing was
watching any of it. A write one byte past an allocation, a read of a freed
block, a signed overflow in the runtime's own arithmetic: all invisible to
every oracle in the suite, because none of them changes what a correct program
prints.

`-fsanitize-coverage` appears in this tree already, as the *instrumentation*
`tests/checks/coverage.py` uses. AddressSanitizer appears once, in ADR-0019, as
a run somebody did by hand in 2024 and nothing repeated. Seven CI jobs and not
one is a memory checker.

## Decision

`tests/checks/sanitize.sh` builds a second runtime under AddressSanitizer,
UndefinedBehaviorSanitizer and LeakSanitizer, links every corpus case that has
a `.out` against it, runs them, and fails on a report. It is a `ctest` case and
runs in about 28 seconds.

**`tools/pascalcc` grew one seam for it**: `AFTERSCHOOL_PASCAL_CFLAGS` adds
flags to every `clang` the driver runs. A sanitizer has to reach the *link* as
well as the translations — that is where its runtime is pulled in — and there
was no way to say so. The failure mode without it is the quiet one: a program
compiled with the flag and linked without is an ordinary program that took
longer to build.

**`heap_balance.txt` is the suppression list for leaks, and that is the
design.** ADR-0183 already decided, case by case, which programs legitimately
end with something outstanding; a second list of this gate's own would be the
same claim written twice and free to disagree. So a leak on a case that file
accounts for is the catalogue being right, and a leak on a case it says
balances is a finding. The two cannot drift apart without one of them failing.

`tests/checks/sanitizer_findings.txt` is for what the gate finds and this tree
has argued for, and fails in both directions like every catalogue here.

## Consequences

**It found a defect on its first run.** `tests/dialect/defer.pas` leaks seven
bytes that `heap-balance` records as `defer 0` — balanced. The allocation is in
`pas_bind`, which copies the external name a file variable is bound to;
`pas_bind` frees the *previous* name and `pas_file_done` frees nothing, so a
bound file variable going out of scope loses its name.

Seven bytes, and unbounded in a program that binds repeatedly. **The language
server binds once per document write**, which is once per keystroke in an
editor — so the one program in this tree that runs for hours is the one that
pays. It is catalogued rather than fixed, because the gate and the finding
arrived together and a runtime change wants `heap-balance` regenerated behind
it; the fix is one `free` in `pas_file_done`.

That is the argument for the whole gate, made by the gate: **`heap-balance`
counts one allocator and the runtime has several**, which its own record said
in a sentence nobody had tested.

**Two false-positive classes had to be told apart, and both are worth
recording** because a reader will hit them again:

- **This compiler's trap and UBSan's report share four words.** `pasrt.c`
  writes `runtime error: ...` at the start of a line for a deliberate trap
  (ADR-0014, ADR-0017); UBSan writes `<file>:<line>:<col>: runtime error: ...`
  with a position in front. Matching the bare text called all thirteen
  `trap_*` cases sanitizer findings — programs doing exactly what they were
  written to do.
- **LeakSanitizer signs its summary `AddressSanitizer`.** A test for the
  absence of that string, meant to distinguish a leak from a memory error,
  suppressed nothing and reported every catalogued leak. The question has to be
  asked of the `==pid==ERROR:` line.

**What it does not do is generate input.** The corpus is what somebody already
wrote, and a hand-written lexer and parser over fixed buffers (ADR-0012) is the
canonical fuzzing target — `selfhost/torture.pas` and `selfhost/badparse/` are
hand-written corpora, which is ADR-0067's *a claim no test names is a claim
nothing checks* applied to crash-resistance rather than to conformance. This is
the cheap half; the expensive half stays open in `doc/roadmap.md`.

**220 cases are skipped and the number is printed rather than hidden.** Most
declare file parameters and want names on their command line, which
`run_test.sh` supplies from sidecars and this does not. The floor of 100 run
programs is there so a run that reaches nothing cannot pass for the same reason
a clean one does.
