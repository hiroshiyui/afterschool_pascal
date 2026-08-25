# Standard operating procedure

How a change gets into this compiler, and what has to be true before it does.

This document exists because of a specific, repeated failure here: **the suite
was green and the compiler was wrong.** Not once — every conformance sweep in
`doc/history.md` was opened by it, and the most recent round found a `verify/`
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
| **`verify/`** (no known gaps; the rule count is in `README.md`) | that the lowering matches a property-style statement of the standard | **drift**. It proves the *model* against the *specification*; neither touches the compiler, so a lowering that changes without its model stays green |
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
  - **Name the standard whenever the surrounding text does not.** The two
    disagree on **45** of the 91 clause numbers they share — Extended Pascal
    inserts String-types at 6.4.3.3 and everything below shifts — so §6.4.3.4
    is Set-types in one and Record-types in the other, and §6.4.7 is an
    *example of a type-definition-part* in one and Schema-definitions in the
    other. A bare number is a coin flip. `CLAUDE.md` has the house form: "*not
    §6.8.1, which is the goto-target rule in the first and Expressions —
    General in the second*". Nothing enforces this (§7).
  - **The number is checked to exist** by `clause-citations` (ADR-0164), which
    is the half that *can* be mechanical: over 7382 citations it asks whether
    each names a clause of some standard. It cannot ask whether it names the
    right one — that is what B1 above is for, and what `langspec-audit` exists
    to attack. A clause number written anywhere in this tree counts as a
    citation, so a document discussing a *wrong* number avoids spelling it or
    takes a catalogue entry.
  - **A citation is the one claim no oracle here can contradict.** It compiles,
    runs, passes every golden, agrees with the other front end and is proved
    correct by `verify/`. ADR-0072's wrong citation survived in four documents
    and a purpose-written test; ADR-0163 found another in four places years
    later. Check the number against the standard, not against the fact that
    the tests pass.
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

## 4a. A feature with a surface needs a client, not a case

The mutation rule above is about a *point*: a defect, a fix, a test that fails
without it. Some changes are not points. A new type kind, a new parameter form,
a new directive — these have a **surface**, and every position a program can put
one in is a place the change can be wrong.

**Write a program that uses it in every position, before believing any gate.**
Not a case that pins one behaviour; a client that exercises the construct
where a program would: assigned, compared, indexed, passed, returned, nested
in a record, iterated, written. Most of the positions will be refused, and the
refusals are the point — what a gate cannot tell you is which of them should
not have been.

This is written down because it has now paid four times and no gate found any
of them:

- `take` was found by writing a list over `owned ^T`: without it a chain had
  no constant-time operation at all, and nothing in the language said so
  (ADR-0182).
- `IsMemory` answering `no` for a new type kind, so the relational operators
  emitted `icmp` on an aggregate — found by probing every operation against
  the kind by hand on the day it existed (ADR-0191).
- The code generator's comparison dispatch, the same probe.
- `EmitAssign` choosing the string store with the wrong predicate — found by
  writing the *library* the type exists to be used through (ADR-0193).

`predicate-kinds` (ADR-0194) now asks the narrow version of the question a
kind raises, and `kind-exhaustive` has asked the case-statement version since
ADR-0124. Neither would have found any of the four. A gate asks a question
somebody thought of; a client asks the questions a program asks.

The corollary is about **order**. The library increment of a feature is not a
tidying-up afterwards — it is the cheapest enumerator of the feature's surface,
so it belongs inside the feature's own work rather than after it. ADR-0189
staged the text model that way by accident and it found two defects.

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
| The differential oracle covers the **front end only** | `src/` is back as `pascalc-s0` — lexer, parser, Sema, no code generator and no LLVM — so `selfhost/difftest.sh` compares tokens/AST/Sema over every Pascal source in the tree again, and the baseline is now **empty**: it reported 89 disagreements when it returned, the drift of 24 Sema commits, and those are ported. What it still cannot see is the **code generator**, which it never compared (ADR-0025), and a **misreading** — both sides are written by one author from one reading, which is how ADR-0073's comment rule was wrong in both . And it covers the **conformance modes** only: a dialect source is skipped by directory, so everything `--std=afterschool` *accepts* is compared by no second implementation. What ADR-0160 recovered is the other half of that surface — what a conformance mode **says** about a dialect construct is conformance behaviour, and Annex B's ten cases are ordinary `.pas` files that difftest reads | ADR-0108, ADR-0160 |
| `langspec-audit`'s readers are **not isolated** | the harness injects `CLAUDE.md` — including the reasoning for the clauses under audit — before a reader's first turn, and it cannot decline. All seven readers of the second run disclosed it. A CONFIRMED verdict therefore means "no independent oracle contradicts it", not "an uninfluenced reader agreed"; the *disagreements* are the trustworthy part | ADR-0107 |
| A subrange whose bounds are not constants is refused as a **set's base type** | Legal under §6.2.3.8 b) and refused, and the last of a row that once said *anywhere but an array's index-type*. ADR-0133 lifted the bare subrange and ADR-0134 the record field and the file component — a record being no kind of block — leaving the one container with a representation reason: every set here is a 256-bit word whose base type must have its values in 0..255 (ADR-0028), and a bound the block evaluates cannot be checked against that before the program runs. It is the limit `set of integer` already states, reached another way | ADR-0028, ADR-0107, ADR-0113, ADR-0127, ADR-0133, ADR-0134 |
| `-O0` and `-O2` are each run, never **compared** | the whole corpus now runs at both, so a level-specific crash or wrong answer fails — but a case where the two *differ* and both look plausible passes twice. Only `--crosscheck` compares them, over its own generated program | §6 |
| `-O1` and `-O3` are unexercised | a defect at an intermediate level has nothing looking for it. Judged not worth a third and fourth sweep | — |
| BSI corpus is fixed | it does not grow with the language, and covers ISO 7185 only | ADR-0086 |
| A **permission withheld** too widely is looked for by nothing | Every gate here watches a claim that is *made*: a diagnostic that stops being reached, a rule that stops holding, a program that stops behaving. A conforming program the compiler **refuses** is a program nobody wrote, so it is in no corpus, names no golden, reaches no diagnostic and disagrees with no second front end — `src/` carries the same rule and refuses it too, which is agreement rather than evidence. `take(mk)` for a parameterless function of a structured type was refused for as long as it had been possible to write it, with 720 cases green and `difftest`'s baseline empty; it was found by hand, from a probe written for something else. `predicate-callers` is the nearest thing and looks the other way — it sweeps for a permission *granted* too widely. What would close this is a corpus of programs asserted to **compile** that no rule here says should, and nothing of the kind exists. **The same crack runs the other way**, which is ADR-0180: AP 6.4.12.2's restriction on a handle-valued call is enforced at a site that one of the construct's two spellings never reaches, so `if make = nil` compiled, ran, exited 0 and leaked the handle the type exists to own. That half is a permission *granted* too widely and no gate found it either — the question none of them asks is whether a rule reaches every way of writing the construct it is about | ADR-0146, ADR-0179, ADR-0180 |
| A **release the runtime cannot be asked to make** is watched by nothing | AP 6.4.14.3 requires an owned pointer's storage to be given back when the activation terminates by a `goto` or a `halt`, and the block epilogue is the only exit that does it. The files and handles *inside* the owned variable are released on those paths, because each is registered with the runtime individually — so the observable resource comes back and the `malloc`ed block does not. **Half of this closed with ADR-0183**: `heap-balance` counts what `new` made against what `dispose` gave back, so an ordinary leak is now caught exactly and cheaply — it was found by making `dispose` free nothing, which leaves 735 of 735 cases and 230 of 230 scenarios green and moves the balance of nineteen. What it still cannot see is this row's own subject, a `goto` out of a block, because the count is taken at **exit** and the abandoned storage is indistinguishable there from storage a program was entitled to keep. Nor does it count files or handles, the other two affine kinds | ADR-0181, ADR-0183 |
| Coverage is measured per **statement**, not per branch | `if c then a else b` on one line counts as covered when either arm runs, and a multi-statement line counts once. Statement coverage is not branch coverage | ADR-0104 |
| Clause **citation is presence, not depth** | a clause with one scenario counts as cited, though §6.8.3.9 alone has six requirements this suite checks and more it does not. The same caution statement coverage carries, one level further out | ADR-0106 |
| The statement-coverage gate is a **ratchet**, not an allowlist | it cannot fail in both directions, so a line that becomes covered says nothing, and 454 uncovered lines carry no argument between them. The per-procedure breakdown is what makes a regression nameable | ADR-0104 |
| The differential oracle never compares an **import** | `pascalc-s0` does not implement `--import`, so §6.13's separately translated components are compared only as standalone sources — each parses and analyses on its own, and the path where one component supplies another's interfaces is compared by nothing. It accepted the option and ignored it until this was written, which was worse: a harness that started passing `--import` would have compared dumps built without the imports and agreed. It refuses now, so that harness fails instead. **ADR-0114 raised the stakes**: `lib/` is now walked by `difftest.sh`, so a library module is compared as a source — but the library exists *to be imported*, and the three `tests/extended/lib_*.pas` cases are the whole of what covers it linked and running. **A conformance defect has now been found behind it**: §6.7.3.4's actual-parameter may be a *qualified* procedure-name, `i.p`, and both front ends refused one. Compiled without `--import` the interface does not exist, so both say "no interface named 'i' has been exported" and then the same thing about the argument -- two identical rejections, which compare equal and pass, exactly as ADR-0034's unanchored glob did. The fix was carried into `src/` on its merits rather than because this oracle asked | ADR-0108, ADR-0114, ADR-0034 |
| `coverage.py` sees the sources, not the harnesses that build their own compiler | it enumerates the corpus by glob, so what `irtest.sh`, `producttest.sh`, `verify.py` and the BSI runner drive is invisible; a procedure only those reach reports as uncovered. The **flags** half of this is closed: the corpus now sweeps `--dump-all` as `difftest.sh` does, which had been worth 195 statements reported unreached while an oracle reached them every run — `dumpexpr` alone read 75 of 186 rather than 1 | ADR-0103 |
| Errors listed in `doc/implementation-defined.md` §3 | deliberately unreported, under §5.1 f) 1) | ADR-0073 |
| §6.4.3.3's region is not asked of a **constant** occurrence | a type-name inside a record denoter is now asked at every occurrence (ADR-0112), but `array [1..fred]` beside a field `fred` reads the constant. Constant occurrences reach the expression checker rather than type-denoter resolution. What is left of a row that used to say the rule was enforced for a pointer domain and nothing else | ADR-0112 |
| A **tagless** variant part is outside the dialect's variant check | ADR-0118 makes the tag authoritative in `--std=afterschool` -- a write activates a variant, a read of an inactive one traps -- and §6.4.3.3 permits `case Kind of` with **no tag field**, which this compiler accepts. There is then nothing to compare against, so such a record stays an unchecked union in the dialect exactly as in the conformance modes. Deliberate: refusing it would break ADR-0117's containment by rejecting a conforming Extended Pascal program, and synthesising a hidden tag is a *layout* change reaching `LlSize`, `new(p, c1, ...)`'s variant selection and every whole-variable copy. It is registered because a safety feature with an unstated exception is worse than none -- a reader must not conclude that "the tag cannot lie" covers every variant record. **Nothing is implemented yet**: this row is dated from the record, as the dialect row above it was | ADR-0118, ADR-0027 |
| The differential oracle will not follow the **dialect** | ADR-0117 freezes `src/` at the conformance surface, so a `--std=afterschool` source is compared by no second implementation — the newest and least-exercised code gets the weakest oracle, which is the exact inverse of where one is most wanted. Deliberate, and the alternative was worse: a front-end feature shipping twice is the cost ADR-0085 retired stage 0 to escape. `difftest.sh` must **skip** dialect sources rather than compile them under `--std=extended`, because two identical rejections compare equal and pass (ADR-0034). What compensates does not need a second front end — goldens, `verify/` for a new lowering, `tests/spec/` for a clause-shaped requirement, the fixed point, which holds only while `selfhost/compiler.pas` stays an Extended Pascal source, and since ADR-0138 the `dialect-containment` sweep, which is the nearest thing to a second reading the dialect can have: the conformance corpus compiled a second way, where the *other* mode is the oracle. That sweep has a limit worth knowing — it sees a divergence only where a corpus program exercises it, so a word-symbol the dialect reserved would leave every case green unless some case used that identifier; `reserved-words` (ADR-0140) is what asks that question directly, of every spelling at once. **Nothing is written yet**: this row is dated from the record, not from the first dialect feature | ADR-0117, ADR-0109 |
| The diverse-double-compiling window can **close without anything noticing** | `seed/ddc.sh` answered the seed's provenance once (2026-08-18, PASS) and works only while the `v0.1.0` C++ compiler still accepts `selfhost/compiler.pas`. Every feature the compiler starts *using* risks ending that, and nothing runs the check — it is not a `ctest` case, deliberately: it builds an LLVM-linked C++ compiler, and it answers a question that is asked once rather than a regression that can recur. So the day it stops being possible will pass unremarked unless someone runs it. It reports that day as a skip naming it, which is the most a script can do; the dated line in `seed/README.md` is what is meant to survive | ADR-0085 |
| Case-exhaustiveness is checked over the **source**, not by asking the compiler | `kind-exhaustive` now reads all twelve enumerations rather than `typeKind` alone (ADR-0145), so the row that stood here -- the node kinds, the token kinds and the link kinds swept by hand -- is closed. What is left is the oracle it uses: it parses `compiler.pas` and cannot ask the built compiler anything, which `doc/sop.md`'s own row below calls the weaker of the two. There is no alternative here and that is the interesting part -- a crash on a case-statement is not a question a program can be written to ask, because the arm that is missing is the one no program reaches. It also does not judge whether an arm is *right*: `tyOptional: StaticThroughout := true` satisfies it and is wrong | ADR-0018, ADR-0124, ADR-0145 |
| The **string pool's** headroom is measured, and one way into it is still silent | ADR-0148 closed the row that stood here: `--dump-limits` compiles as usual and reports both counters against both capacities, so `buffer-headroom` no longer reports headroom for two arrays while measuring one. The pool needed the flag and the tokens never did -- `--dump-tokens` writes one line per token and §6.1.7 forbids a newline in a string-literal, so the line count *is* the count, while `PoolAdd` is called from Sema and from CodeGen as well as from the lexer and no count over the token stream is the pool's size. The first measurement is 491,964 of 1,000,000, against a lower bound of 442,625. What is left is `PoolPut`, the pool's other entry: it **drops a character** when the pool is full rather than reporting, so the two names Sema builds rather than reads -- a function's result slot and a `with` binding -- would come out short, and a short name can collide with another. Reachable only once the pool is within a name's length of full, which is the state the 80% gate exists to report long before; not fixed because the fix is a diagnostic no program in the corpus can reach, and the honest alternative to a golden nothing exercises is the headroom report itself | ADR-0095, ADR-0126, ADR-0148 |
| A gate that holds **both halves** of its comparison cannot fail | `foreign_reserved.py` kept `COMPOSED`, a regex copy of the rules `ReservedForeignName` applies without a list. Adding `frame[0-9]+` to it without adding it to the compiler left the gate green over a name the compiler still accepted (ADR-0144). Closed for this gate — it now compiles a probe, harvests the `@names` the IR actually contains, and offers each back to the compiler — but the shape is general and other checks here read the compiler's *source* to decide what it does: `kind_exhaustive.py` and `reserved_words.py` both parse `compiler.pas`, and `buffer_headroom.py` did until ADR-0148 gave it a second half the compiler answers: it reads each capacity from the source *and* from what `--dump-limits` reports, so a disagreement is the stale binary named rather than headroom measured against a bound this tree no longer declares. Reading the source is the weaker oracle in every case; two of these three now ask the built compiler as well | ADR-0121, ADR-0144 |
| Nothing checks an external-declaration's **name** against another component's | ADR-0147 gives one linker symbol one `external` declaration *within* a program-component, which is what closed the row that stood here -- two `declare`s of one global and LLVM's *invalid redefinition*, an error about a file nobody wrote. Across components nothing looks: two modules may each declare `external 'strerror'` and each emits its own declaration, which is 6.13 working. What is not checked is that they *mean* the same routine, and that is the row below rather than this one -- nothing checks a heading against the routine it names at all | ADR-0121, ADR-0128, ADR-0147 |
| Nothing checks that every string-arena producer is **counted** | the release CodeGen emits at the end of a statement is driven by a counter the three arms of `EmitString` bump. A new producer added to `runtime/pasrt.c` and emitted from somewhere else would allocate without bumping it, and the statement holding it would write no release — a leak that reports only once the arena is gone. The four that exist are pinned by `tests/extended/str_arena_loop.pas`, one loop each — the fourth (ADR-0171's padded actual for a fixed-string value parameter) is not in `EmitString` at all, which is the shape the row was written about, and it was added to that file in the same change. A fifth would still have nothing looking for it | ADR-0111 |
| Nothing checks an `external` declaration against the function it names | ADR-0121 lets a program name a linker symbol, and the linker checks the *name*. Nothing checks the signature -- and the emitted `declare` does not either: a mutation giving the foreign declaration a static link it does not have, `declare double @cbrt(ptr, double)` beside `call double @cbrt(double 27.0)`, assembled, linked and ran correctly, because LLVM does not check a **direct** call against the declaration's parameter list under opaque pointers. So the call site is the whole of the ABI and a wrong type, a wrong parameter count or the wrong function entirely is undefined behaviour with no diagnostic. This is what an FFI is without a header parser; the boundary is *visible* -- one directive, the foreign name written out, greppable -- and that is the only property claimed for it. **ADR-0129 confirmed it a second time, for arity rather than for types**: writing `ptr` where a slice's `ptr, i64` belongs, so the declaration and the call disagree about how many arguments there are, is a mutation that survives the whole suite. The `declare` a foreign heading emits is therefore documentary, and nothing here can make it otherwise | ADR-0121, ADR-0129 |
| Nothing checks that a foreign record's fields are the struct's fields | ADR-0184 lets a record cross as a `var` parameter, and what makes it sound is that `RecordLayout` *is* C's struct rule -- so the compiler and C agree about offsets for whatever fields are declared. That the declared fields **are** `struct stat`'s, in that order and with that padding, is the row above asked about a type instead of a signature: unchecked, and uncheckable without a header parser. What the record removes is the arithmetic, a program stating fields and never offsets, which is why it is a narrower gap than the one it sits under and not a new kind of one. `pasx_record_probe` closes the half that *can* be closed -- the two compilers meeting over a struct they both declare, asked on whatever target the tree was built for -- and closes nothing about a struct only one of them declares. **ADR-0185 closed the half that can be closed**: a source states its claim in a comment (`@cstruct`/`@cfield`), `--dump-layout` reports the offsets this compiler computed, and `foreign-layout` hands the two to a C compiler holding the real header -- so a wrong field list fails the build, naming the Pascal field. What is left is a declaration whose header is not on **this** machine: `@cplatform` reports it as not-checked rather than failed, because a skip and a defect must not look alike, and only CI on a second platform turns that skip into a check. It is also why no POSIX struct is declared in `lib/` and ADR-0185 makes that a rule rather than a preference: a module has to work where nobody here can build it, so `PasFS` asks a `pasx_` routine and lets the target's own C compiler read the header. **ADR-0187 puts a second kind of declaration under this row and one that the gate cannot reach at all**: a record naming a *prefix* of the struct's members is admitted in the result position, deliberately -- it is how `struct tm` is usable without naming the `char *` glibc puts after the nine that matter -- and `foreign-layout` compares a field-list against the **whole** struct, so a prefix cannot be a claim a C compiler confirms. A partial claim is not a weaker check but no check, which is why the annotation stays optional and why `tests/dialect/foreign_optional_record.pas`'s `Tm` carries none: what pins that one is the calendar it prints | ADR-0184, ADR-0185, ADR-0187, ADR-0121 |
| Nothing checks that a new **statement-sequence holder** runs what it armed | AP 6.9.3.11 executes an armed statement when the statement-sequence it stands in is completed, and §6.9.3 has exactly three constructs holding one — a compound-statement, a repeat-statement's body and a case-statement-completer. `EndSequence` is called from those three places and nothing derives that list: a fourth such construct added to the language would arm correctly, refuse a label and a goto correctly, and run its deferred statements **late** — at the activation's end, through the runner, which is the backstop a local `goto` already uses. So the failure is a silent change of timing rather than a crash or a leak, and no oracle here would name it. `kind-exhaustive` covers the neighbouring half: a new node kind is named by `CheckDeferBody`'s exhaustive case, which is the walk that refuses a goto inside a deferred statement | ADR-0175 |
| A **dump's exit status** is read by nothing | `tests/checks/coverage.py` drives `--dump-all` over every source in the corpus, the way `difftest.sh` does, and reads the *lines reached*; `difftest.sh` compares the text but skips a dialect source by directory. So a compiler that **stops** while dumping one — a case-statement with no matching label is a halt, ADR-0018 — writes a short dump, is counted as having run, and says nothing. `--dump-sema` crashed on every program declaring a fallible-type for three days and 714 green cases; it surfaced only because a new branch in the same walker went unreached and `line-coverage` asked why. What would close it is cheap and is not built: the sweep could read the child's status, or look for `runtime error:` in what a dump wrote, and name the source. `tests/dumps/` covers the shapes it has cases for, and `kind-exhaustive` covers the class — neither is a check that the compiler survived a dump | ADR-0103, ADR-0104, ADR-0176 |
| The clause inventory is **generated**, and nothing compared it with the triage | `tests/spec/`'s denominator is two files: an inventory extracted from the standards by a script, and a triage written by hand. Until ADR-0152 nothing checked that they named the same clauses, and they were **37 apart** — every sub-clause of §6.2.2 and §6.2.3 in both standards is a bare number on its own line with the requirement under it, and the extractor read only lines carrying a title. So the most-cited clause in this repository, §6.2.2.9, was one `spec-clause-traceability` called *not a clause of that standard*. Closed in both directions: an orphaned triage row means the extractor lost a clause, an untriaged inventory row means the denominator is short. What stays is the shape rather than the instance — **the inventory has no oracle of its own**. It is checked against the triage and the triage against it, and if the extractor silently dropped a clause that nobody had triaged either, both files would agree and both would be wrong. Only a reader holding the standard can see that, which is `.claude/skills/langspec-audit/`'s job and not a gate's | ADR-0105, ADR-0106, ADR-0152 |
| A dialect scenario cannot reach **6.13.1 or 6.11** | `doc/afterschool-pascal-spec.md` is now cited by 101 citations across a 100-scenario suite, and 46 of its 48 testable clauses have one (ADR-0135's wiring, ADR-0144's re-triage). The two that do not are 6.11 and 6.13.1, and they are the same gap: both are rules about which program-components may be *linked* together, and `tests/spec/run.py` compiles a single program with no way to ask for a second component, let alone one built under another mode. 6.11 joined the list when ADR-0144 re-triaged it out of `structural` -- it had been carrying a requirement that contradicted 6.13.1 while no scenario was permitted to cite it. Both are covered by `tests/dialect/`, by `mixed-mode-link` and by the link-time diagnostic `tools/pascalcc` translates, and both stay in `pending.txt` rather than being triaged away, because triaging a clause the harness cannot reach as `structural` would be a lie about the clause rather than about the harness. **The same limit now costs a conformance-mode scenario too**: §6.7.3.4 and §6.7.3.5 let an actual procedural or functional parameter be a *qualified* name, `i.p`, and a program demonstrating it needs the module that exports `i`. `tests/extended/procparam_qualified.pas` is the case; there is no scenario, and writing one for the unqualified form instead would file a citation under a requirement it does not check | ADR-0119, ADR-0135, ADR-0144 |
| A slice's foreign count is widened to `i64` and **nothing can see that it is** | ADR-0129 crosses a buffer as `(ptr, i64)` because every length this target's data path takes is a `size_t`. Dropping the `sext` and passing the count as an `i32` is a mutation that survives: x86-64 and aarch64 both zero the upper half of a register written 32 bits wide, and a slice's length is checked non-negative and cannot reach 2^31 without an array of two billion components. So the widening is right for a reason no program here can exhibit. Not worth a gate -- what would have to change is the architecture -- but it must not be read as covered, because the two tests that name the feature pass without it | ADR-0129, ADR-0128 |
| An `int64` result is the door AP §6.7.7.9 c) says is shut | that clause forbids an external-declaration whose result is an address of storage the callee owns, and calls itself the place where ADR-0109's memory-safety model begins. §6.7.7.8 admits an `int64` result — ADR-0128 added it for `ssize_t` — an address fits in one, and no processor can tell a count from an address. So `function ExtOpendir(path: string): int64; external 'opendir'` compiles, links and opens the directory, and because §6.4.2.6.2 makes `int64` numeric **on purpose**, the handle copies, `d := d + 8` is a legal statement about an open directory stream, and closing it twice is *double free or corruption (!prev)*, exit 134. Unfixable from here: withdrawing the `int64` result withdraws what `read` and `write` were given it for, and telling a count from an address needs a type the dialect does not have. `doc/roadmap.md` §7 had recorded this construct as the item that *forces* the memory-safety fork and as the reason the fork had not been started, so the deferral was protecting a boundary that had been open since ADR-0128 (ADR-0151). `tests/dialect/foreign_int64_handle.pas` is the program, kept as a gap that fails in both directions | ADR-0128, ADR-0151 |
| The differential oracle compares the **dump**, so a Sema fact the dump does not print is invisible | `difftest.sh` diffs `--dump-all`, and `--dump-sema` prints the frame layouts, every expression's type, every name's slot and every record's numbering — but not a symbol's **initial value**. So ADR-0168's second defect, `var t: string(4) value 'jk'` dropping the initial state on the schema branch of `CheckVarDecl`, sat identically in both front ends and difftest was green over it; the whole corpus was green over it too, because the type-name spelling worked and no case wrote the inline one. The fix was carried into `src/` on ADR-0108's merits rather than because this oracle asked — and the same is true of any Sema change whose only product is a field CodeGen later reads. Widening the dump would make the goldens churn on every field added to a symbol, which is the cost that kept it narrow; what is registered here is that "difftest agrees" covers what Sema *prints*, not what Sema *decides* | ADR-0108, ADR-0168 |
| A constant's storage may be filled **twice** and no test can see it | ADR-0170 lets a constant-access naming a structured component fill a global of its own, and keeps the guard that stops a plain alias — `const b = a` shares a's storage, so filling it again writes it once per activation of b's block, which need not be a's. That guard cannot be mutated into a failing test: the second fill writes the *same value*, so the only difference is IR nobody compares. `tests/dumps/` compares what the compiler writes to standard output and not its product, and the goldens compare what the program printed. So the alias arm is argued and unpinned, unlike the other two arms of the same `if`, which three mutations kill. Registered rather than fixed because the honest fix is a gate over emitted IR, which nothing here has | ADR-0069, ADR-0170 |
| `model-drift` is scoped to a **range**, so a sibling commit can satisfy it | it asks whether `verify/lowering.py` changed anywhere in `base..head`, which is the right question for a push and the wrong one for a commit. ADR-0167's batch changed the model in two commits and touched CodeGen in two others -- the qualified-name call site and the string value parameter's prologue -- and both of those are unmodelled for good reasons nobody had to write down, because the gate was already satisfied. Someone bisecting to either finds an unexplained CodeGen change and no trailer saying why. Not tightened here: a per-commit gate would demand a trailer on every mechanical follow-up in a batch, which is the shape that trains people to write trailers without reading them | ADR-0013, ADR-0167 |
| `model-drift` is a **CI** gate and its local half answers a different question | it compares two commits, so `git diff base..head` cannot see work that is only in the working tree — and until ADR-0153 reached CI without the trailer it owed, running it before committing answered *the compiler did not change* and looked like a pass. That is now an explicit failure naming the reason, so the trap is closed for the file it watches. What stays is the shape: **every gate that reads git history answers about committed work**, and the local run of one before a commit is not the run CI will make. `model-drift-base` is the other half and is a question about one repository rather than one change | ADR-0013, ADR-0153 |
| **`model-drift`'s CodeGen region runs to end of file, so a driver change trips it** | The regions are found by banner text, and CodeGen has no end banner "because it runs to the end of the file" — which stopped being true once `ParseArgs`, `Compile` and the rest of the driver were written below it. ADR-0166 added one line to `Compile` and the gate reported a lowering change with no model change. The right answer is a `Model-unchanged:` trailer, which is what the gate asks for; the tempting one is an end banner, and narrowing a safety gate to make a build green is how a gate stops meaning anything. If it is drawn properly later, the change should be argued on its own and not while a build is red | ADR-0013, ADR-0166 |
| **`src/` does not read the `@std:` annotation** | ADR-0166 lets a source name its own standard in a header comment, and the reference front end has no such scan. No divergence is possible today, because `difftest.sh` passes `--std=` explicitly on every file it compares and the annotation is read only when no flag was given — so neither side ever reaches it. The day difftest compiles a file without a flag, this becomes a real gap rather than a latent one | ADR-0108, ADR-0166 |
| A citation may name a **real clause of the wrong standard** | `clause-citations` (ADR-0164) asks whether a number names a clause at all, and that is the cheap half. It cannot ask whether it names the *right* one, and the two standards make that the common case: they agree on 46 of the 91 numbers they share and disagree on 45, Extended Pascal having inserted String-types at 6.4.3.3 and shifted everything below by one. So §6.4.3.4 is Set-types in one and Record-types in the other, §6.4.7 is an *example* in one and Schema-definitions in the other — and ADR-0163's defect was exactly this: a real number, cited about a program of the standard where it means something else. **825** citations name one of the 45 ambiguous numbers, most of them unambiguous in their context, so a ratchet over them would be a large standing cost for a claim it still could not verify. The convention adopted instead is §3's B1: where the surrounding text does not pin the standard, the citation names it. Nothing enforces that | ADR-0163, ADR-0164 |
| Whether **HT, VT and FF are separators** is unsettled | `IsSpace` admits ordinals 9–13 outside strings and comments. §6.1.8 gives the separators as comments, spaces, and the separations of consecutive lines; LF and CR are the third and HT/VT/FF are none of the three, while clause 4 makes the required characters those needed to form §6.1's tokens and separators. So the lexer refuses `?` on a rule it does not apply to a tab. No reader found a sentence settling it and no program breaks either way; it gets no scenario, because asserting one of two defensible readings would launder a coin-flip into a citation | ADR-0162 |
| **`bindable` in a variant-denoter is caught only where it is written on the arm** | ISO/IEC 10206:1991 §6.4.3.4's third limb reaches through a structured component for *both* the words it forbids, and this compiler applies it to `restricted` only: a record with a `bindable` field, used in a variant arm, is accepted. Bindability belongs to the type-denoter (§6.4.1) and `fieldRec` records none, so catching it needs a flag on a field. Narrow today for a second reason — `bind` is refused for any component, so a bindable field is inert here in every other respect too | ADR-0163 |
| **50 `structural` triage rows share one copied reason** and are unaudited | `tests/spec/clauses/triage.tsv` classifies every heading, and only `testable` enters the denominator and the work queue — so a requirement filed `structural` disappears and nothing ever asks for it. An independent audit of ~20 rows found four wrong, and two of them came from the single reason string "introduces the subclauses below it; states no requirement of its own", which 54 rows share. Both were Extended Pascal clauses that gained a sentence the ISO 7185 clause of the same number does not have — which is the shape to look for. The remaining 50 have not been read against the standards | ADR-0106, ADR-0152 |
| The layout comparison covers **frames and nothing else** | `target-layout` compares every frame size and field offset the compiler emits, across every admitted target, on every run (ADR-0157), which is what `LlSize`/`LlAlign` decide. It says nothing about a global's alignment, a string constant's, or the ABI by which arguments travel — the last being LLVM's business rather than this compiler's, which is what ADR-0030's and ADR-0051's "nothing that is two words may depend on how a struct is passed" was for. A divergence in one of those would go unnoticed | ADR-0028, ADR-0157 |
| Text-mode translation and other **C library semantics** are unasked | `runtime-isoc` (ADR-0161) checks that `runtime/pasrt.c` uses only ISO C plus four catalogued names, which bounds what a port must *supply*. It says nothing about what the same call **means** elsewhere: a Windows `fopen` in text mode translates line endings, which would change what `readln` sees, and `-std=c11` against glibc's headers is one implementation's idea of what is standard. A second C library would be the oracle and there is none here | ADR-0161 |
| The aarch64 job runs the **suite**, not the other oracles | ADR-0159's CI job builds and runs the whole corpus natively on arm64, which is what turns the port from links into runs. `llc-second-backend` skips there (no `llc` installed) and the SMT proofs are left out deliberately, being about the lowering *model* rather than the host. So a miscompilation of the compiler that only an aarch64 backend produces has nothing looking for it, and no release ships an aarch64 artefact | ADR-0159 |
| §6.6.3.8's bounds error is not detected where **both** ends are dynamic | ISO 7185 §6.6.3.8 closes with an error: the smallest and largest values of the actual's index-type must lie within the interval the schema's ordinal-type-identifier specifies. Where the actual is an ordinary array-type both are constants and the program is refused at compile time; where the actual is itself a conformant array parameter they arrive with *its* actual, and this compiler emits no run-time comparison. It is an error in §3.1's sense, so leaving it undetected conforms provided a document says so — `doc/implementation-defined.md` §3 does, and BSI's LEV1F44 and LEV1F49 print *ERROR NOT DETECTED*. Worth closing: the check is one comparison per bound against a constant interval, at the call site where the bounds are already being emitted as arguments. Not done in the change that added the feature, because until the feature existed the check had no test that could fail without it | ADR-0153, ADR-0014 |
| Nothing checks that a foreign routine does not keep an address it was handed | ADR-0122 lets a `var` parameter and a string cross as an address, on the argument side only, where the caller owns the storage and outlives the call. The one thing that can still go wrong is a callee that *stores* the pointer and reads it afterwards -- which is a promise rather than a lifetime, and cannot be checked here at all: the callee is a symbol in an archive. The record's claim is that the near side is sound, not that the far side behaves | ADR-0122 |
| An optional's check is not elided by a guard that has already made it | ADR-0123 makes `o^` trap when there is no value, and `if o <> nil then o^` emits the check anyway. Narrowing the type inside the guarded statement is flow-sensitive analysis in Sema and a binding form in the grammar -- Swift's `if let`, Rust's `match` -- and neither is built. The cost is a load and a compare, not correctness; what a reader must not conclude is that the type makes the trap unreachable, only that it makes it *local* to the places the source writes `^` | ADR-0123 |
| The predicate sweep does not prove a probe **reaches** its call site | ADR-0146's `predicate-callers` closed the row that stood here: for every caller of `Assignable` the source contains, and every type `Assignable` refuses outright, a program putting that type in that position must be refused -- 84 pairs -- ADR-0150 made one of those arms cover two spellings, a bare file and a record holding one -- and the mutation that moves the slice arm one line down leaves all 625 cases green. What it claims is exactly that **no program in the table is accepted**, which is the safety property; it does not claim every call site was exercised. Several probes are refused by a rule that fires first -- a slice cannot be a `for` control variable, a discriminant actual must be ordinal before its type is compared -- so those positions are covered by the outer rule and not by the predicate. Proving reach would need `pascalc --coverage` over a compiler built for the purpose, which is what `line-coverage` already does for the corpus and is not wired to this gate | ADR-0058, ADR-0125, ADR-0139, ADR-0146 |
| An **optional of a pointer** has two absent values | `?^T` is admitted, and `nil` in one expression then means two things: where `q` is `nil` and `op := q`, `op = nil` is false and `op^ = nil` is true. AP §6.4.11.2 refuses `?(?T)` — *one flag answers for a value; two would answer for each other* — and refuses `?text`, a file being no value at all; neither argument reaches a pointer, which **is** a value and whose `nil` answers a different question. Argued rather than legislated (ADR-0149): the redundancy is the program's, since a pointer is `nil` only because something assigned `nil`; the two checks compose in the order written, the optional trapping before the dereference is reached; and nothing here writes it — `lib/dialect/` holds no pointer type in seven modules. What is registered is the reading hazard rather than a defect: a mistaken count of `^` changes which check applies, and no gate can see that | ADR-0123, ADR-0149 |
| Nothing checks `lib/dialect/`'s reporting convention | ADR-0141 found the rule behind the library's four ways of saying a routine may have failed — `ErrorCode` where there is nothing to return, `?T` where absence has nothing to add, a result record where it has a reason, `boolean` for a question — and it is a **convention, not a gate**. A new module returning a result record whose tag is spelled `success` rather than `ok` would compile, link and pass every test here, and so would one answering an `ErrorCode` where the caller needed a value. Not fixed because the check worth writing is not obvious: the shapes are ordinary Pascal and a linter over a module interface is a tool this repository does not have. `lib/dialect/README.md` is the statement a reader can be pointed at, which is what a convention gets instead | ADR-0141, ADR-0120 |
| A foreign string of unstated length has no safe reception | `PasEnv.Lookup` binds C's `getenv`, whose result is a pointer to a string nobody measured. The length is discovered inside the boundary conversion, so a value longer than the receiving capacity **stops the caller's program** — an outcome the routine's `?EnvText` cannot express and the module cannot catch. `PasFS` faces the same question and answers it, because `getcwd` is *lent* a buffer and reports `ERANGE`, which becomes `errFull`; the difference is which side owns the storage. There is no result form that would hold an unmeasured string — `?string` without a capacity is a parameter form and not a result type, which was probed. Reachable: a PATH over 4096 characters is ordinary. `PasOS.ErrorNumberText` has the same shape against `strerror` and is unreachable in practice rather than guarded. **ADR-0188 shows the row is closable where the runtime holds the pointer**: `pasx_dir_next` is handed the caller's own capacity, calls `strlen` on the far side and answers `errFull`, so `PasDir` has no unmeasured reception at all -- and `Next` takes `var name: string` rather than a fixed type precisely so the bound checked is the caller's. The same routine would fix `PasEnv.Lookup` and has not been written; what it costs is a `pasx_` name for something C already has | ADR-0141, ADR-0122, ADR-0188 |
| A module exporting an **undiscriminated schema** with a tagged variant is called portable | ADR-0137 locks a module whose interface reaches a record with a tagged variant-part, and ADR-0142 fixed the parameter walk that missed one route. A route still open: a module exporting `Box(n: integer) = record pad: array [1..n] of integer; case k: Sel of …` by *name*, undiscriminated, emits the dialect aliases and links into an Afterschool Pascal program, which AP §6.13.1 forbids. **No misbehaving program was built from it** — every way of giving the module something to write re-discriminates the schema and is caught, so it looks reachable only in combination with ADR-0142's defect, which is fixed. Left alone because the fix belongs with a probe that demonstrates the harm, and installing one on a forbidden-but-harmless link spends the meaning of the other seven combinations | ADR-0137, ADR-0142 |
| A guard placed **ahead** of a predicate can silence the predicate's own test | ADR-0143's first version put a slice arm before the `Assignable` call in the assignment check, to give better words than the general message. It masked the predicate at the only site that reaches it, so removing `Assignable`'s own slice refusal changed nothing observable and **all 623 cases stayed green over a restored out-of-bounds write**. The fix is structural — ask the predicate, then choose words inside the failure — and nothing checks that a new diagnostic arm has not done this again. It is invisible to every gate here by construction: the behaviour is identical, so no golden moves, no coverage changes, and only a mutation of the *masked* code can see it | ADR-0143 |
| The model-drift gate's **judgement** runs on CI only | it needs a push range, so no local run asks whether a CodeGen change carried its model — a `git push` is the first thing that does, and it reports after the fact rather than before. Its *base resolution* is checked locally (`model-drift-base`) because that half is a pure question about one repository and is the half that has broken; the judgement half is not, and `python3 tests/checks/model_drift.py origin/main HEAD` before a push is the manual substitute | ADR-0013 |
| `runtime/pasrt_unicode.c` has **one** reader, and it skips | Every other line of runtime C is reached by corpus programs at both optimisation levels; this file is reached by nothing. No Pascal program can call it — the functions are `pas_` and so refused as foreign names (ADR-0131) — `coverage.py` sees Pascal and not C, and difftest has no second implementation to compare. `unicode-conformance` is the whole of its oracle, and it **skips (77)** when the Unicode Character Database is absent, the database being fetched and never committed. So a clone that has not run `runtime/unicode/fetch.sh` tests 5 500 lines of tables and the arithmetic over them with nothing at all, and reports green. `UNICODE_CONFORMANCE_REQUIRE` is how CI refuses to pass by skipping, which is `TARGET_SIZES_REQUIRE`'s answer to the same shape; locally there is no such protection and the skip line is the only warning. This closes when increment 2 gives the language a text-type and corpus programs start reaching it | ADR-0189, ADR-0190 |
| One claim in the text model rests on a **reading**, not on Unicode's files | AP 6.4.15.9's iteration copies an element without renormalising it, and must — the arena is released once per *statement* (ADR-0111), so a loop that allocated per element would exhaust it. That is sound only if a grapheme cluster boundary is also a boundary of normal form, which is an argument from UAX #29's GB9 and GB9a rather than something `NormalizationTest.txt` or `GraphemeBreakTest.txt` states: Unicode publishes the two properties separately and nothing published relates them. Everywhere else in the text model the oracle is theirs (ADR-0190); here it is a **property test** — `tests/dialect/text_join.pas` walks a text, joins the elements back and requires the original, so a boundary that split a normalisation segment would produce pieces that renormalise on rejoining and the comparison would fail. That is the nearest thing to an oracle available, and it is one program over one string rather than a sweep | ADR-0189, ADR-0192 |

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
  (`tests/spec/clauses/triage.tsv`), so the figure is 14 of **207 testable**
  clauses rather than 14 of 292 headings, and `spec-clause-traceability` gates
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
