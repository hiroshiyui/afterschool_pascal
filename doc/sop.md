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
| **`ctest` goldens** (542 cases, run at `-O2` and again at `-O0`) | that a named program still behaves as recorded | anything **no case names**. A golden agrees with whoever wrote it, so it cannot report that the recorded answer is wrong |
| **BSI validation suite** (812 programs) | conformance against a corpus nobody here wrote | it is **fixed** — it does not grow with the language, covers ISO 7185 only, and `expected.tsv` records what *this* compiler does |
| **`selfhost/difftest.sh`** (every Pascal source in the tree — 532 committed, 756 once the BSI suite is fetched — and two independent front ends) | that the C++ reference front end and the Pascal compiler agree on **tokens, AST and Sema** | the **code generator**, which it never compared (ADR-0025) — and a **misreading**, because both sides are written by the same author from the same reading. That is how ADR-0073's comment rule came to be wrong in *both*. The baseline is **empty** — it was 89 — so any entry appearing in it is a disagreement the change under review introduced |
| **`verify/`** (43 rules, 27 at full 32-bit width, 0 known gaps) | that the lowering matches a property-style statement of the standard | **drift**. It proves the *model* against the *specification*; neither touches the compiler, so a lowering that changes without its model stays green |
| **`verify.py --crosscheck`** | the model against the real binary, at `-O0` and `-O2` | only the points its generated program actually exercises. It ran `succ` on enumerations alone for a long time — the one ordinal type where a wrong reading and a right one agree |
| **`selfhost/irtest.sh`** (414 programs, stage 2 = stage 3) | that the compiler is a fixed point under self-application | a bug that is **stable** under self-application. A compiler can miscompile consistently and still reproduce itself — and both stages come from *one binary*, so a `clang` that got a corner of `compiler.pas` wrong is invisible to it. The row below is what closes that half |
| **`tests/checks/llc_check.sh`** (`llc-second-backend`; skips without `llc`) | that the compiler **binary** is not miscompiled: built a second way, through `llc` at `-O0` and `-O2`, it must translate `compiler.pas` to byte-identical IR | a miscompilation **both** configurations share — within one run it is two configurations of *one* LLVM, since `llc` and `clang` come from one package set (19.1.7 in the CI container). It is **not** a second reader of the IR: the two share LLVM's parser and verifier and reject the same module with the same message. What varies is which LLVM runs the comparison, across runs rather than within one |
| **`selfhost/producttest.sh`** (12 checks) | that the artefact actually built is the one described | anything the twelve checks do not ask |
| **`tests/spec/`** (43 scenarios, 13 clauses) | what the compiler does about a **named clause**, in the standard's terms rather than the implementation's | a **misreading**, still — the scenario is written by the same reader. What it changes is that the reading is attached to the clause it is about, so it is findable by someone holding the standard (ADR-0105) |
| **ADRs, `README`, `CLAUDE.md`** | the reasoning | a **misreading**. No oracle here can contradict a reading of the standard — which is why ADR-0072's wrong justification survived in four documents and a purpose-written test |

Two consequences worth stating plainly, because they are counter-intuitive:

- **Adding a test does not close a blind spot unless it can fail.** Two of the
  four cases written for storage defects would have passed against the broken
  compiler without their `-O0` sidecar. Verify the test fails first.
- **The strongest oracle this project ever had is back, for half the compiler.**
  `difftest.sh` compared two independent implementations over 436 sources and
  was retired with stage 0 (ADR-0085); ADR-0108 restored `src/` as a *front end*
  and it now compares every Pascal source in the tree. Two things it still
  cannot do, and both matter:
  it says nothing about the **code generator**, which it never compared, and it
  cannot contradict a **reading**, because one author writes both sides. Keep
  `langspec-audit` for the second and running programs for the first.
- **It arrived red on purpose, and is green now.** 89 files disagreed — the
  Sema work the C++ never received — and the gate held that set as a *baseline*
  rather than waiting for zero, which would have left the 642 agreeing files
  guarded by nothing for as long as the catch-up took. The catch-up is done and
  the baseline is empty, so it is an ordinary regression gate: any file it names
  is one the change under review broke.

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

- **A1. `verify/lowering.py` changes in the same commit**, or the change says
  why it needs no model change, as a trailer:

      Model-unchanged: emits a new statement kind; no rule covers it

  **Enforced** by the `model-drift` CI job, which fails a range that touches
  `selfhost/compiler.pas` in a modelled region without touching
  `verify/lowering.py` and without that trailer. It cannot decide *which*
  changes reach a modelled lowering — that is a judgement — so it requires the
  judgement to be written down. A lowering change with an unchanged model is
  the failure mode this project has actually suffered, and it stays green while
  suffering it.

  Two regions, not one. CodeGen is the obvious one; **the constant folder** is
  the other, because it decides the same clauses a second time for an
  expression that folds — and the two have disagreed, which is what ADR-0077
  found in `mod`. The gate watched only CodeGen until then, so a regression in
  the folder was caught by neither the rules (which model the lowering) nor
  this. It also asked only whether *something* under `verify/` changed, which
  editing `verify/README.md` satisfied.
- **A2. If the change alters *which* values reach a check, extend
  `--crosscheck`.** The rule quantifies symbolically and will keep proving
  something true; the crosscheck is the only thing comparing model to binary.
- **A3. Read the emitted IR once at `-O0`** (`tools/pascalcc -S f.pas -o
  /dev/stdout`), and run the corpus there before pushing:

      AFTERSCHOOL_PASCAL_OPT=-O0 ctest --test-dir build

  Nothing verifies the module — `clang` refusing to assemble catches
  *malformed*, never *wrong* — and the default `-O2` hides a whole class of
  storage defect, which is how ADR-0102's survived every oracle at once. CI
  runs this sweep on every push (`unoptimised`); doing it locally is what stops
  the round trip.
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
- **B4a. Run `difftest`, and expect it to be the thing that fails.** A lexer,
  parser or Sema change lands in *two* implementations now (ADR-0108), and the
  baseline is **empty**: the two front ends agree on every source in the tree,
  so any file the gate names is one this change broke. Porting the rule into
  `src/` is part of the change, not a follow-up — and if the rule is
  deliberately dialect-only, say so in the commit message and record it,
  because the C++ mirrors the conformance surface and nothing else.
- **B4. Every new diagnostic gets a case** — `selfhost/badparse/` (one file per
  message; the parser stops at its first error) or `selfhost/badsema/` (shared
  files; Sema accumulates). **Enforced** by the `diagnostic-coverage` case,
  which is part of an ordinary `ctest` run (§5).
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

Coverage here is measured at one granularity and argued at every other. The
argument has to be concrete.

- **Name the case that reaches each new branch.** "Covered by the suite" is not
  a claim; `tests/foo.pas:12 takes the else` is.
- **Count the corpus.** Thirty seconds of `grep -c` has been wrong more often
  than not here: no file had a tab, no file had a parse error, Sema reached 48
  of its 85 messages.
- **Beware the tools.** `grep` on this machine is `ugrep`, whose `--include`
  does not filter as expected — a coverage sweep silently matched the compiler
  source and reported everything covered. Pass an explicit file list.

**Diagnostic coverage is enforced, not remembered.** It is a `ctest` case —
`diagnostic-coverage` — and the tool behind it is
`tests/checks/diagnostic_coverage.py`, runnable on its own:

```sh
python3 tests/checks/diagnostic_coverage.py
```

It fails in **both directions**, which is `verify/`'s `KNOWN_GAP` rule
(ADR-0013) applied to a second catalogue. A message with no golden fails,
because coverage was lost. A message listed in
`tests/checks/unreachable_diagnostics.txt` that *acquires* a golden also fails,
because the argument for its being unreachable has stopped being true and the
list is now describing a compiler that no longer exists.

Adding an entry to that list is a decision to argue for in the commit message,
and the argument goes both there and at the branch itself. **"I could not write
the program" is not the argument; "no program can be written" is.** Four
entries are currently on it (§7).

The filter that separates diagnostics from `--help` text lives inside the
script, and it is part of the tool rather than a convenience: without it the
sweep reports thirty lines of usage text as thirty gaps, and a check that cries
wolf gets ignored — which is worse than no check.

**Procedure coverage is measured** (ADR-0103), and it is the one number this
document could previously only argue for. `procedure-coverage` is a `ctest`
case; the tool is `tests/checks/coverage.py`:

```sh
python3 tests/checks/coverage.py --report   # the breakdown, always exit 0
python3 tests/checks/coverage.py            # the gate
```

It builds an instrumented copy of the compiler with clang's SanitizerCoverage —
an **IR** pass, so it applies to the textual `.ll` this compiler emits with no
front end and no debug info — runs the whole corpus through it, and maps the
addresses reached back to the procedures `selfhost/compiler.pas` declares. That
mapping exists only because `EmitProcBody` writes each procedure's spelling and
line as a comment beside its `define`; the LLVM name is a counter following the
order CodeGen walked the tree, and cannot be recovered from the source.

Same rule as the diagnostics: it fails in **both directions**, against
`tests/checks/uncovered_procedures.txt`, and an entry there is an argument
rather than an exemption.

**Know what it does not measure.** Two things, both deliberate:

- **A procedure entered once counts as covered.** The `case` arm nobody reaches
  is invisible. Basic-block coverage was measured and rejected as the headline:
  8,304 of the compiler's own 26,655 blocks are the bounds-check and nil-check
  failure paths CodeGen emits for its own subscripts, which a correct run never
  enters *by design*, so a third of the denominator is unreachable and the
  percentage means nothing. The honest denominator is lines a human wrote, and
  reaching it needs the compiler to emit line information — a feature, not a
  script.
- **It sees the sources, not the harnesses.** The corpus is enumerated by glob,
  so what `irtest.sh`, `producttest.sh`, `verify.py` and the BSI runner drive is
  invisible to it. A procedure only those reach is reported uncovered and must
  be listed — which is how `Usage` and `Version` were found, and why the script
  runs `-h` and `--version` itself now.

**Statement coverage is measured too** (ADR-0104), and it is the first of those
two that is now answered rather than only recorded. The compiler instruments
itself:

```sh
python3 tests/checks/line_coverage.py --report --by-procedure
python3 tests/checks/line_coverage.py            # the ratchet
```

`pascalc --coverage` emits one counter per statement, so **the denominator is
the statements a human wrote** — not blocks CodeGen generated, which is what
made block coverage uninterpretable. And the compiler is the only thing that
decides what is executable: the denominator is read back out of the `.ll` that
same compilation wrote, so the two halves of a figure cannot disagree about
which lines were executable. There is no second notion of executability to
drift.

**Its gate is a ratchet, and that is weaker than an allowlist.** A per-line
argument is not writable at 650 lines. `tests/checks/line_coverage.txt` records
the count *and* the per-procedure breakdown, so a regression names the
procedures that moved; regenerating it is a decision to argue for in the commit
message. Where `uncovered_procedures.txt` fails in both directions, this one
only ratchets down — which §7 records rather than glosses.

## 6. Cadence

| When | Do |
| --- | --- |
| Every change | §3 gates, §4 mutation, `commit-and-push`. `ctest` now
carries `diagnostic-coverage`; CI carries `model-drift` and the `-O0` sweep |
| Before pushing a CodeGen change | `AFTERSCHOOL_PASCAL_OPT=-O0 ctest --test-dir build`, so the `-O0` job is not the first to know |
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
| The differential oracle covers the **front end only** | `src/` is back as `pascalc-s0` — lexer, parser, Sema, no code generator and no LLVM — so `selfhost/difftest.sh` compares tokens/AST/Sema over every Pascal source in the tree again, and the baseline is now **empty**: it reported 89 disagreements when it returned, the drift of 24 Sema commits, and those are ported. What it still cannot see is the **code generator**, which it never compared (ADR-0025), and a **misreading** — both sides are written by one author from one reading, which is how ADR-0073's comment rule was wrong in both | ADR-0108 |
| `langspec-audit`'s readers are **not isolated** | the harness injects `CLAUDE.md` — including the reasoning for the clauses under audit — before a reader's first turn, and it cannot decline. All seven readers of the second run disclosed it. A CONFIRMED verdict therefore means "no independent oracle contradicts it", not "an uninfluenced reader agreed"; the *disagreements* are the trustworthy part | ADR-0107 |
| One conformance defect is **known and unfixed**: a non-constant discriminant or subrange bound is refused in a *type-definition* | §6.2.3.8 b) puts "each actual-discriminant-part **or subrange-bound** not contained by a schema-definition and closest-contained by … the block" in the block's commencement, *after* value parameters are attributed, so `type t = vector(m)` inside a procedure is legal and is refused. The **variable** half is fixed — `var a: array [1..m] of real` works under `--std=extended` since ADR-0113 — and what is left is a different decision rather than the rest of the same one: a variable's descriptor belongs to the variable, a type's would belong to the block and be shared by every variable of it, and a *named* type with a dynamic extent also breaks ADR-0055's reason a function result can always be sized. The other three findings of that audit are fixed | ADR-0107, ADR-0113 |
| `-O0` and `-O2` are each run, never **compared** | the whole corpus now runs at both, so a level-specific crash or wrong answer fails — but a case where the two *differ* and both look plausible passes twice. Only `--crosscheck` compares them, over its own generated program | §6 |
| `-O1` and `-O3` are unexercised | a defect at an intermediate level has nothing looking for it. Judged not worth a third and fourth sweep | — |
| BSI corpus is fixed | it does not grow with the language, and covers ISO 7185 only | ADR-0086 |
| Coverage is measured per **statement**, not per branch | `if c then a else b` on one line counts as covered when either arm runs, and a multi-statement line counts once. Statement coverage is not branch coverage | ADR-0104 |
| Clause **citation is presence, not depth** | a clause with one scenario counts as cited, though §6.8.3.9 alone has six requirements this suite checks and more it does not. The same caution statement coverage carries, one level further out | ADR-0106 |
| The statement-coverage gate is a **ratchet**, not an allowlist | it cannot fail in both directions, so a line that becomes covered says nothing, and 454 uncovered lines carry no argument between them. The per-procedure breakdown is what makes a regression nameable | ADR-0104 |
| The differential oracle never compares an **import** | `pascalc-s0` does not implement `--import`, so §6.13's separately translated components are compared only as standalone sources — each parses and analyses on its own, and the path where one component supplies another's interfaces is compared by nothing. It accepted the option and ignored it until this was written, which was worse: a harness that started passing `--import` would have compared dumps built without the imports and agreed. It refuses now, so that harness fails instead. **ADR-0114 raised the stakes**: `lib/` is now walked by `difftest.sh`, so a library module is compared as a source — but the library exists *to be imported*, and the three `tests/extended/lib_*.pas` cases are the whole of what covers it linked and running | ADR-0108, ADR-0114 |
| `coverage.py` sees the sources, not the harnesses that build their own compiler | it enumerates the corpus by glob, so what `irtest.sh`, `producttest.sh`, `verify.py` and the BSI runner drive is invisible; a procedure only those reach reports as uncovered. The **flags** half of this is closed: the corpus now sweeps `--dump-all` as `difftest.sh` does, which had been worth 195 statements reported unreached while an oracle reached them every run — `dumpexpr` alone read 75 of 186 rather than 1 | ADR-0103 |
| Errors listed in `doc/implementation-defined.md` §3 | deliberately unreported, under §5.1 f) 1) | ADR-0073 |
| §6.4.3.3's region is not asked of a **constant** occurrence | a type-name inside a record denoter is now asked at every occurrence (ADR-0112), but `array [1..fred]` beside a field `fred` reads the constant. Constant occurrences reach the expression checker rather than type-denoter resolution. What is left of a row that used to say the rule was enforced for a pointer domain and nothing else | ADR-0112 |
| A **tagless** variant part is outside the dialect's variant check | ADR-0118 makes the tag authoritative in `--std=afterschool` -- a write activates a variant, a read of an inactive one traps -- and §6.4.3.3 permits `case Kind of` with **no tag field**, which this compiler accepts. There is then nothing to compare against, so such a record stays an unchecked union in the dialect exactly as in the conformance modes. Deliberate: refusing it would break ADR-0117's containment by rejecting a conforming Extended Pascal program, and synthesising a hidden tag is a *layout* change reaching `LlSize`, `new(p, c1, ...)`'s variant selection and every whole-variable copy. It is registered because a safety feature with an unstated exception is worse than none -- a reader must not conclude that "the tag cannot lie" covers every variant record. **Nothing is implemented yet**: this row is dated from the record, as the dialect row above it was | ADR-0118, ADR-0027 |
| The differential oracle will not follow the **dialect** | ADR-0117 freezes `src/` at the conformance surface, so a `--std=afterschool` source is compared by no second implementation — the newest and least-exercised code gets the weakest oracle, which is the exact inverse of where one is most wanted. Deliberate, and the alternative was worse: a front-end feature shipping twice is the cost ADR-0085 retired stage 0 to escape. `difftest.sh` must **skip** dialect sources rather than compile them under `--std=extended`, because two identical rejections compare equal and pass (ADR-0034). What compensates does not need a second front end — goldens, `verify/` for a new lowering, `tests/spec/` for a clause-shaped requirement, and the fixed point, which holds only while `selfhost/compiler.pas` stays an Extended Pascal source. **Nothing is written yet**: this row is dated from the record, not from the first dialect feature | ADR-0117, ADR-0109 |
| The diverse-double-compiling window can **close without anything noticing** | `seed/ddc.sh` answered the seed's provenance once (2026-08-18, PASS) and works only while the `v0.1.0` C++ compiler still accepts `selfhost/compiler.pas`. Every feature the compiler starts *using* risks ending that, and nothing runs the check — it is not a `ctest` case, deliberately: it builds an LLVM-linked C++ compiler, and it answers a question that is asked once rather than a regression that can recur. So the day it stops being possible will pass unremarked unless someone runs it. It reports that day as a skip naming it, which is the most a script can do; the dated line in `seed/README.md` is what is meant to survive | ADR-0085 |
| Nothing checks that a `case` over a **node** kind, a token kind or a link kind is exhaustive | The `typeKind` half of this row is closed: `kind-exhaustive` is a `ctest` case and ADR-0124 has the argument, which is that the same omission shipped twice -- `StaticThroughout` missed `tyString`, and then missed `tyOptional` with every gate green. The **other** enumerations are still swept by hand. They are less exposed in practice: the parser and both walkers enumerate the node kinds in long label lists, and this compiler rejects a duplicate label at build time, which is what caught two of them during ADR-0123. That is an accident of how those lists are written and not a check. Extending the gate is cheap and is not done | ADR-0018, ADR-0124 |
| Nothing checks that every string-arena producer is **counted** | the release CodeGen emits at the end of a statement is driven by a counter the three arms of `EmitString` bump. A new producer added to `runtime/pasrt.c` and emitted from somewhere else would allocate without bumping it, and the statement holding it would write no release — a leak that reports only once the arena is gone. The three that exist are pinned by `tests/extended/str_arena_loop.pas`, one loop each; a fourth would have nothing looking for it | ADR-0111 |
| Nothing checks an `external` declaration against the function it names | ADR-0121 lets a program name a linker symbol, and the linker checks the *name*. Nothing checks the signature -- and the emitted `declare` does not either: a mutation giving the foreign declaration a static link it does not have, `declare double @cbrt(ptr, double)` beside `call double @cbrt(double 27.0)`, assembled, linked and ran correctly, because LLVM does not check a **direct** call against the declaration's parameter list under opaque pointers. So the call site is the whole of the ABI and a wrong type, a wrong parameter count or the wrong function entirely is undefined behaviour with no diagnostic. This is what an FFI is without a header parser; the boundary is *visible* -- one directive, the foreign name written out, greppable -- and that is the only property claimed for it | ADR-0121 |
| Nothing checks that a foreign routine does not keep an address it was handed | ADR-0122 lets a `var` parameter and a string cross as an address, on the argument side only, where the caller owns the storage and outlives the call. The one thing that can still go wrong is a callee that *stores* the pointer and reads it afterwards -- which is a promise rather than a lifetime, and cannot be checked here at all: the callee is a symbol in an archive. The record's claim is that the near side is sound, not that the far side behaves | ADR-0122 |
| An optional's check is not elided by a guard that has already made it | ADR-0123 makes `o^` trap when there is no value, and `if o <> nil then o^` emits the check anyway. Narrowing the type inside the guarded statement is flow-sensitive analysis in Sema and a binding form in the grammar -- Swift's `if let`, Rust's `match` -- and neither is built. The cost is a load and a compare, not correctness; what a reader must not conclude is that the type makes the trap unreachable, only that it makes it *local* to the places the source writes `^` | ADR-0123 |
| The model-drift gate's **judgement** runs on CI only | it needs a push range, so no local run asks whether a CodeGen change carried its model — a `git push` is the first thing that does, and it reports after the fact rather than before. Its *base resolution* is checked locally (`model-drift-base`) because that half is a pure question about one repository and is the half that has broken; the judgement half is not, and `python3 tests/checks/model_drift.py origin/main HEAD` before a push is the manual substitute | ADR-0013 |

**Closed since this document was written**, kept here because a register that
only grows is a register nobody trusts:

- *A `forward`-declared function could not name its own result.* §6.7.2 puts
  the result identifier's defining-point in "the block of the function-block,
  **if any**, associated with the identifier of the function-heading" — the same
  words the next paragraph uses of the formal-parameter-list, which has always
  reached a forward body. The asymmetry was literal: parameters bound from the
  *symbol*, the result variable from the *declaration node*, and a forward
  body's node carries no specification. §6.11.1 makes every exported function a
  `forward`, so this reached every module in `lib/`;
  `tests/extended/forward_resultvar.pas` is the case. It was recorded here as
  the first question for the next `langspec-audit` and did not need one.
- *The model-drift gate could not survive a force-push.* Its base resolution
  lived in the workflow's shell and asked `git rev-parse --verify`, which exits
  0 for a full 40-hex string without ever looking the object up — so the
  discarded SHA a force-push reports was waved through and the job died in
  `git diff` a line later (run 32131932455). The rule now lives in
  `model_drift.resolve_base`, one copy rather than one per caller, and
  `model-drift-base` is a `ctest` case over a repository built for the purpose.
  What is left of that gap is the row above.
- *`-O0` was two cases wide.* The `unoptimised` CI job now runs the whole
  corpus at `-O0`, and `AFTERSCHOOL_PASCAL_OPT=-O0 ctest` does it locally. What
  is left of that gap is the first two rows above.
- *Four diagnostics counted but unenforced.* `tests/checks/unreachable_diagnostics.txt`
  is now a catalogue with an argument per entry, and the `diagnostic-coverage`
  case fails in both directions (§5).
- *Clause coverage had an untriaged denominator.* All 292 headings are now
  classified testable, structural or not-implemented
  (`tests/spec/clauses/triage.tsv`), so the figure is 13 of **207 testable**
  clauses rather than 13 of 292 headings, and `spec-clause-traceability` gates
  it in both directions (ADR-0106). What is left of that gap is the row above.
- *"§5 is an argument, not a number."* There is a number now —
  `procedure-coverage`, 554 of 556 — and the two rows above are what is left of
  that gap rather than the gap itself. Measuring it found the dumps: four
  documented flags whose thirty-one walker procedures were entered by no case
  at all, so nothing checked they did not crash (ADR-0103).

## 8. What this document is not

It is not a substitute for the skills that do the work. `code-review`,
`release-engineering`, `langspec-audit`, `docs-engineering`, `commit-and-push`,
`tracing-thoroughly`, `performance-profile` and `security-audit` each carry
their own procedure; this document says *when* to run them and *what must be
true afterwards*. `.claude/skills/change-lifecycle/` is this document in a form
an agent can follow.

It is also not a promise that following it makes the compiler correct. It makes
the compiler's *claims* checkable, which is the most a process can do.
