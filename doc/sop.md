# Standard operating procedure

How a change gets into this compiler, and what has to be true before it does.

This document exists because of a specific, repeated failure here: **the suite
was green and the compiler was wrong.** Not once — every conformance sweep in
`doc/roadmap.md` was opened by it, and the most recent round found a `verify/`
model describing a compiler that had been replaced, a stack leak the default
`-O2` optimised out of sight, and 32 diagnostics no test had ever named. In
every case the bar had been met, and the bar was the problem.

So the rule this whole document rests on:

> **A green suite is not evidence. Evidence is a named case that fails without
> the change.**

Everything below is that sentence applied to a particular kind of work.

## 1. The oracles, and what each cannot see

This is the most important section. Every gate below is chosen because of a
blind spot in this table, and a new gate is only worth adding if it closes one.

| Oracle | What it checks | What it is blind to |
| --- | --- | --- |
| **`ctest` goldens** (497 cases) | that a named program still behaves as recorded | anything **no case names**. A golden agrees with whoever wrote it, so it cannot report that the recorded answer is wrong |
| **BSI validation suite** (812 programs) | conformance against a corpus nobody here wrote | it is **fixed** — it does not grow with the language, covers ISO 7185 only, and `expected.tsv` records what *this* compiler does |
| **`verify/`** (43 rules, 27 at full 32-bit width, 0 known gaps) | that the lowering matches a property-style statement of the standard | **drift**. It proves the *model* against the *specification*; neither touches the compiler, so a lowering that changes without its model stays green |
| **`verify.py --crosscheck`** | the model against the real binary, at `-O0` and `-O2` | only the points its generated program actually exercises. It ran `succ` on enumerations alone for a long time — the one ordinal type where a wrong reading and a right one agree |
| **`selfhost/irtest.sh`** (380 programs, stage 2 = stage 3) | that the compiler is a fixed point under self-application | a bug that is **stable** under self-application. A compiler can miscompile consistently and still reproduce itself |
| **`selfhost/producttest.sh`** (5 checks) | that the artefact actually built is the one described | anything the five checks do not ask |
| **ADRs, `README`, `CLAUDE.md`** | the reasoning | a **misreading**. No oracle here can contradict a reading of the standard — which is why ADR-0072's wrong justification survived in four documents and a purpose-written test |

Two consequences worth stating plainly, because they are counter-intuitive:

- **Adding a test does not close a blind spot unless it can fail.** Two of the
  four cases written for storage defects would have passed against the broken
  compiler without their `-O0` sidecar. Verify the test fails first.
- **The strongest oracle this project ever had is gone.** `difftest.sh` compared
  two independent implementations over 436 sources and was retired with stage 0
  (ADR-0085). Nothing replaced it. The BSI suite and `langspec-audit` are
  partial substitutes and are described as such.

## 2. Classify the change

The gates depend on what kind of change it is. Pick the *most demanding* class
that applies.

| Class | Examples | Gates (§3) |
| --- | --- | --- |
| **A — Lowering** | anything CodeGen emits differently: arithmetic, conversions, comparisons, storage | A1–A6 |
| **B — Language rule** | Sema accepts or refuses something new; a new diagnostic | B1–B5 |
| **C — Runtime** | `runtime/pasrt.c`; formatting, file handling, checks | C1–C3 |
| **D — Harness / build** | `tests/run_test.sh`, `CMakeLists.txt`, CI, `seed/` | D1–D3 |
| **E — Documentation** | ADRs, README, CLAUDE.md, comments | E1–E2 |

A change is often two classes. ADR-0102's was A and D: it changed a lowering
*and* the harness, because the lowering could not otherwise be tested.

## 3. Gates

### A — Lowering

- **A1. `verify/lowering.py` changes in the same commit**, or the operation
  genuinely has no rule and the commit says which. A lowering change with an
  unchanged model is the failure mode this project has actually suffered, and
  it stays green while suffering it.
- **A2. If the change alters *which* values reach a check, extend
  `--crosscheck`.** The rule quantifies symbolically and will keep proving
  something true; the crosscheck is the only thing comparing model to binary.
- **A3. Read the emitted IR once at `-O0`** (`tools/pascalcc -S f.pas -o
  /dev/stdout`). Nothing verifies the module — `clang` refusing to assemble
  catches *malformed*, never *wrong*.
- **A4. Storage: no `alloca` outside a prologue** (ADR-0102). Anywhere a
  statement can sit inside a loop, storage that must survive is a frame slot
  and storage that need not is an SSA value.
- **A5. A `KNOWN_GAP` that starts holding is reclassified in the same change.**
  The runner fails on this by design.
- **A6. Mutation-check** (§4).

### B — Language rule

- **B1. Cite the clause**, in the code comment and the commit message. A rule
  with no clause behind it is a preference.
- **B2. Ask whether the violation is an *error*.** ISO 7185 §3.1 makes an error
  something a processor may leave undetected and Annex D enumerates them; a
  requirement *not* in Annex D falls under §5.1 e), which obliges the processor
  to report it and refuse execution. "The standard says shall" and "the
  compiler must reject it" are different claims.
- **B3. Read the whole clause, not the sentence that motivated the change.**
  §6.7.3.3 has three closing sentences and this compiler implemented two for a
  release.
- **B4. Every new diagnostic gets a case** — `selfhost/badparse/` (one file per
  message; the parser stops at its first error) or `selfhost/badsema/` (shared
  files; Sema accumulates). Then **count** (§5).
- **B5. Mutation-check** (§4).

### C — Runtime

- **C1. `PAS_FILE_SIZE` and `fileSize` must agree** if `struct pas_file` grew.
  They live in two files that cannot include one another; `irtest.sh` checks it.
- **C2. Nothing the compiler is responsible for moves into the runtime.** A
  field width the program wrote is bounds-checked in emitted code, because the
  runtime is never told which standard it was compiled for.
- **C3. Mutation-check** (§4).

### D — Harness / build

- **D1. Show the harness change can fail.** A sidecar or a gate that does
  nothing is worse than none, because it reads as coverage. Demonstrate it:
  break the compiler, confirm the case fails, remove the harness change,
  confirm it passes.
- **D2. Re-run `cmake`.** Cases are registered by `file(GLOB)` at configure
  time. A green bar that never ran the new case is not a green bar.
- **D3. The seed is refreshed at release tags only**, with ADR-0095's one
  documented exception (capacity, not noise).

### E — Documentation

- **E1. ADRs are immutable once accepted.** A decision that stops being right
  gets a *new* record; the old one's **Status** — metadata, not Context or
  Decision — gains a forward pointer, and so does the index row.
- **E2. A doc-only pass leaves `ctest` output identical.** A comment fix and a
  code change do not travel together.

## 4. The mutation rule

**Every fix must come with a mutation that a *named* test kills.**

1. Apply the fix. Confirm the suite is green.
2. Revert the fix — or make the smallest edit that reintroduces the defect.
3. Rebuild and run. **Name the test that fails.** If none does, the fix is
   untested, whatever the suite says.
4. Restore, rebuild, confirm green again.

Rules learned the hard way:

- **Restore with plain `cp` and `touch`, never `cp -p`.** Preserving the mtime
  leaves the mutated binary in the build tree and the next run reads as a
  broken feature.
- **One mutation per fix, and check *which* test fails.** Two fixes in one
  commit need two mutations that kill two different tests; a single test that
  covers both hides the case where only one is right.
- **A mutation that breaks the build proves nothing.** It has to produce a
  working compiler with the defect back in it.

## 5. Counting, not assuming

Coverage here is argued, not measured — there is no coverage tool, `gcov`
having gone with `src/`. So the argument has to be concrete.

- **Name the case that reaches each new branch.** "Covered by the suite" is not
  a claim; `tests/foo.pas:12 takes the else` is.
- **Count the corpus.** Thirty seconds of `grep -c` has been wrong more often
  than not here: no file had a tab, no file had a parse error, Sema reached 48
  of its 85 messages.
- **Beware the tools.** `grep` on this machine is `ugrep`, whose `--include`
  does not filter as expected — a coverage sweep silently matched the compiler
  source and reported everything covered. Pass an explicit file list.

The diagnostic-coverage sweep, which is worth re-running after any batch of
new messages:

```sh
python3 - <<'PY'
import re, pathlib
src = pathlib.Path('selfhost/compiler.pas').read_text()
msgs = {m.group(1) for m in re.finditer(r"write(?:ln)?\('([^']{20,})'", src)}
blob = '\n'.join(p.read_text() for p in
                 list(pathlib.Path('tests').rglob('*.err')) +
                 list(pathlib.Path('selfhost').rglob('*.err')))
# --help text, driver messages and the two capacity limits are not diagnostics
# about a program and have no .err golden by design. Everything else printed
# here is either a case to write or a branch to prove unreachable.
noise = re.compile(r"^ {4,}"                      # --help, which is indented
                   r"|^\s*(-|clang out|It writes|not link|output, and"
                   r"|assembling|tools/pascalcc|usage:|Afterschool|pascalc:"
                   r"|pascalc \(|out of string space|too many tokens)")
for t in sorted(m for m in msgs if m not in blob and not noise.match(m)):
    print(t)
PY
```

The filter is part of the tool, not a convenience: without it the sweep prints
thirty lines of `--help` text and reads as thirty gaps, and a check that cries
wolf gets ignored, which is worse than not having it.

Anything it prints is either a case to write or a branch to prove unreachable
**and comment as such at its site**, with what would have to change for it to
fire. Four are currently in the second category (§7).

## 6. Cadence

| When | Do |
| --- | --- |
| Every change | §3 gates, §4 mutation, `commit-and-push` |
| A batch of conformance work, or before a release | `code-review`; re-run the §5 sweep |
| After conformance work whose clauses admit more than one reading | `langspec-audit` — independent readers given the behaviour and **not** the reasoning |
| Before a release | `release-engineering`: from-scratch build, seed refresh at the release commit, version agreement in two places, breaking changes called out |
| A bug resists the first few probes | `tracing-thoroughly` — **before** attempting a fix. Its rule is to fan out competing hypotheses rather than ride one thread, which is the failure mode of a long debugging session |
| Performance work is proposed | `performance-profile`. Performance is explicitly subordinate to correctness and the bootstrap here; the skill exists partly to keep it that way |
| Periodically, and after runtime or file-handling work | `security-audit` |
| When the BSI catalogue moves | fix `expected.tsv` in the change that moved it. **A row that starts passing is as loud as one that starts failing** |
| When a feature lands | `docs-engineering`: the `feat:` commit, then a `docs:` commit moving it out of README's "not accepted yet" and nothing else |

**When to commission an audit.** `langspec-audit` is expensive and is for
*readings*, not code. Trigger it when a check broke programs in this tree and
the programs were edited — that is the correct response when the corpus was
wrong, and it is also exactly what defending a misreading looks like.

**Never claim completeness without a probe.** Three documents asserted ISO 7185
was complete while `pack`, `unpack` and `page` sat unimplemented behind a name
check. Before asserting anything is done, compile a program for the clause.

## 7. Blind-spot register

Live, and part of the SOP rather than an appendix: these are the things
currently known not to be checked. Add to it when a gate is declined; remove
from it when one is closed.

| Blind spot | Consequence | Recorded |
| --- | --- | --- |
| `-O0` is two cases wide | a codegen bug visible only without the optimiser has very little looking for it | ADR-0102 |
| No differential oracle | nothing can contradict a reading except `langspec-audit` | ADR-0085 |
| Four diagnostics unreachable | counted, uncovered, commented at their sites | §5 sweep |
| BSI corpus is fixed | it does not grow with the language, and covers ISO 7185 only | ADR-0086 |
| No coverage measurement | §5 is an argument, not a number | — |
| Errors listed in `doc/implementation-defined.md` §3 | deliberately unreported, under §5.1 f) 1) | ADR-0073 |

## 8. What this document is not

It is not a substitute for the skills that do the work. `code-review`,
`release-engineering`, `langspec-audit`, `docs-engineering`, `commit-and-push`,
`tracing-thoroughly`, `performance-profile` and `security-audit` each carry
their own procedure; this document says *when* to run them and *what must be
true afterwards*. `.claude/skills/change-lifecycle/` is this document in a form
an agent can follow.

It is also not a promise that following it makes the compiler correct. It makes
the compiler's *claims* checkable, which is the most a process can do.
