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
| **`ctest` goldens** (730 cases, run at `-O2` and again at `-O0`) | that a named program still behaves as recorded | anything **no case names**. A golden agrees with whoever wrote it, so it cannot report that the recorded answer is wrong. **This is now the primary oracle for the front end**, which it was not before ADR-0232 |
| ~~**BSI validation suite**~~ (812 programs) — **retired by ADR-0232** | conformance against a corpus nobody here wrote | it validated ISO 7185, and 25 of its programs use a word-symbol §6.1.2 reserves, so this compiler cannot compile the corpus at all. It was the only third-party corpus this project ever had |
| ~~**`selfhost/difftest.sh`**~~ — **retired by ADR-0232** | that a C++ reference front end and the Pascal compiler agreed on **tokens, AST and Sema** | it was frozen at the conformance surface and skipped every dialect source; with no conformance surface there is nothing for two implementations to disagree about. It never compared the **code generator** (ADR-0025) and could never contradict a **misreading**, both sides being one author's |
| **`unicode-conformance`** (20 034 normalisation cases, 766 segmentation cases, and every unlisted code point) | that the text model agrees with the Unicode Character Database | everything that is not Unicode. It is the only oracle here that nobody in this project wrote |
| **`verify/`** (no known gaps; the rule count is in `README.md`) | that the lowering matches a property-style statement of the standard | **drift**. It proves the *model* against the *specification*; neither touches the compiler, so a lowering that changes without its model stays green |
| **`verify.py --crosscheck`** | the model against the real binary, at `-O0` and `-O2` | only the points its generated program actually exercises. It ran `succ` on enumerations alone for a long time — the one ordinal type where a wrong reading and a right one agree |
| **`selfhost/irtest.sh`** (414 programs, stage 2 = stage 3) | that the compiler is a fixed point under self-application | a bug that is **stable** under self-application. A compiler can miscompile consistently and still reproduce itself — and both stages come from *one binary*, so a `clang` that got a corner of `compiler.pas` wrong is invisible to it. The row below is what closes that half |
| **`tests/checks/llc_check.sh`** (`llc-second-backend`; skips without `llc`) | that the compiler **binary** is not miscompiled: built a second way, through `llc` at `-O0` and `-O2`, it must translate `compiler.pas` to byte-identical IR | a miscompilation **both** configurations share — within one run it is two configurations of *one* LLVM, since `llc` and `clang` come from one package set (19.1.7 in the CI container). It is **not** a second reader of the IR: the two share LLVM's parser and verifier and reject the same module with the same message. What varies is which LLVM runs the comparison, across runs rather than within one |
| **`selfhost/producttest.sh`** (12 checks) | that the artefact actually built is the one described | anything the twelve checks do not ask |
| **`tests/spec/`** (319 scenarios) | what the compiler does about a **named clause**, in the standard's terms rather than the implementation's | a **misreading**, still — the scenario is written by the same reader. What it changes is that the reading is attached to the clause it is about, so it is findable by someone holding the standard (ADR-0105) |
| **ADRs, `README`, `CLAUDE.md`** | the reasoning | a **misreading**. No oracle here can contradict a reading of the standard — which is why ADR-0072's wrong justification survived in four documents and a purpose-written test |

Two consequences worth stating plainly, because they are counter-intuitive:

- **Adding a test does not close a blind spot unless it can fail.** Two of the
  four cases written for storage defects would have passed against the broken
  compiler without their `-O0` sidecar. Verify the test fails first.
- **The strongest oracle this project ever had is gone, twice.**
  `difftest.sh` compared two independent implementations over 436 sources and
  was retired with stage 0 (ADR-0085); ADR-0108 restored `src/` as a *front
  end*; ADR-0232 retired it again, and this time permanently — `src/` answers
  conformance questions and there is no conformance. The front end is now
  guarded by goldens alone, which agree with whoever wrote them. **That makes
  regenerating a golden a heavier decision than it was**, not a lighter one:
  there is no second implementation to be caught by.
- **And the third-party corpus is gone with it.** BSI's 812 programs could not
  be replaced when they were fetched and cannot be replaced now. What is left
  that nobody here wrote is `unicode-conformance`, which covers one clause.
  `langspec-audit` is the only instrument that can contradict a *reading*, and
  it is invoked deliberately rather than by a standing trigger.

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

      AFTERSCHOOL_PASCAL_OPT=-O0 ctest --test-dir build -j"$(nproc)"

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
    is the half that *can* be mechanical: over the citations in the tree — 10 476 across 1679 files as this is written, and the gate prints the pair — it asks whether
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
- **B4a. There is no second front end to catch you.** `difftest` compared two
  implementations over every source in the tree and retired with the
  conformance modes (ADR-0232). A lexer, parser or Sema change is now guarded
  by goldens that agree with whoever wrote them, so **write the case before the
  change and watch it fail**; a golden regenerated afterwards proves nothing
  about the change that regenerated it.
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

- **The mutations are files, and `tests/mutation/run.py` runs them**
  (ADR-0207). A mutation made while fixing something goes in
  `tests/mutation/mutants/` in the same commit, the way its ADR does. What is
  written in a record is a claim about the tree on the day it was written;
  what is in that directory can be made again. The harness enforces the three
  rules below and refuses to start on a dirty tree, and it is deliberately not
  a `ctest` case — it edits the source and rebuilds.
- **Restore with plain `cp` and `touch`, and then *rebuild*.** Two halves of
  one mistake, learned four months apart. Preserving the mtime with `cp -p`
  leaves the mutated binary in the build tree and the next run reads as a
  broken feature. Restoring the mtime correctly and not rebuilding does the
  same thing and looks less like a mistake: ADR-0205's fourth mutation was
  restored, touched, and left unbuilt, so the next run measured the *mutant*,
  reported a property of the new feature as false, and a golden was taken
  against it before the cause was found. The rule is that the last thing a
  mutation run does is put the tree back and build it.
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

**A better-aimed prompt exists since ADR-0198 and does not withdraw that.**
`predicate_kinds.py --like tyString tyText` lists every predicate true of the
old kind and false of the new one -- three, over 42 call sites -- and three of
the four defects are in that list, because each was a guard the new kind fell
out of. It puts them in front of a reader and judges none of them, and it has
to be told which kind the new one resembles, which is a fact about why the kind
was added rather than anything the compiler knows. It is a sharper instrument
of the same kind, not a different kind of instrument.

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
  so what `irtest.sh`, `producttest.sh` and `verify.py` drive is
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
| Every change | §3 gates, §4 mutation, `commit-and-push`. `ctest` now carries `diagnostic-coverage`; CI carries `model-drift` and the `-O0` sweep |
| Before pushing a CodeGen change | `AFTERSCHOOL_PASCAL_OPT=-O0 ctest --test-dir build -j"$(nproc)"`, so the `-O0` job is not the first to know |
| A batch of conformance work, or before a release | `code-review`; re-run the §5 sweep |
| After conformance work whose clauses admit more than one reading | `langspec-audit` — independent readers given the behaviour and **not** the reasoning |
| Before a release | `release-engineering`: from-scratch build, seed refresh at the release commit, version agreement in two places, breaking changes called out |
| A bug resists the first few probes | `tracing-thoroughly` — **before** attempting a fix. Its rule is to fan out competing hypotheses rather than ride one thread, which is the failure mode of a long debugging session |
| Performance work is proposed | `performance-profile`. Performance is explicitly subordinate to correctness and the bootstrap here; the skill exists partly to keep it that way |
| Periodically, and after runtime or file-handling work | `security-audit` |
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

**Nothing checks that a decision reached the specification or the register.**
`doc/roadmap.md` is a queue, `doc/afterschool-pascal-spec.md` says what the
language is, and `doc/implementation-defined.md` says what this processor
decides where a clause leaves it open — and a row that closes is finished only
when the thing it decided can be looked up by somebody who never read the
roadmap. Nothing here asks whether that happened. `spec-clause-traceability`
asks whether a clause a scenario cites exists and whether the triage calls it
testable, which is a question about *citations*; `clause-citations` asks
whether a number names a clause at all. Neither can ask whether a fact was
written down, and no gate can: the question is about a document's silence, and
silence has no denominator. Three of the concurrency residue's standing shapes
were **decisions** and only one of them was in the specification until
2026-09-04, so the other two read as things nobody had got to — the shape that
gets a decision undone by somebody later "fixing" it. What is in place instead
is a rule in the roadmap's own *How this page is written*, saying which
document takes what, and a reader is the whole of the enforcement.

**Nothing enumerates this tree's sidecar conventions, and the tools that read
them drift apart** (ADR-0311). `.components`, `.importpath`, `.importenv`,
`.opt`, `.in`, `.err`, `.warn`, `.epoch`, `.status`, `.flags`, `.dump` and
`.workspace` are read by `tests/run_test.sh`, `selfhost/irtest.sh`,
`tests/dumps/run.sh`, `lsp/run.sh`, CMake, `lsp/pasls.pas` and several gates,
and no list says which reader honours which. `.importpath` was added to the
corpus by ADR-0244, grew seven users with ADR-0295 and was unread by the
language server until somebody opened one of those seven programs in an
editor — 21 diagnostics, all false, on a program that compiles. What would
close this is a gate reading each convention's readers, and nobody has
designed one; what makes it a blind spot rather than an oversight is that
every oracle here agreed, each reader being correct about the sidecars it
does read.

**Nothing checks that a quick fix compiles** (ADR-0300). The language server
offers two edits — delete an unreachable statement, add `protected` to a
formal-parameter-section — and the argument that each is safe is a reading of
the clause the warning rests on, plus one application by hand. A gate would
have to apply an edit to a case and recompile it, which is a harness this tree
does not have; what stands in its place is that both edits are decidable from
what the compiler *reported* rather than from anything read out of the source.

**Audited as a whole on 2026-08-25** (ADR-0197), for the first time in 57 rows — until
then it had only been appended to, which is the decay a register is supposed to
prevent happening to the register itself. Four rows had gone stale in a way
that mattered. Two ended "nothing is implemented yet", dating themselves from a
record whose feature had since shipped; one carried a citation count from
before four increments moved it; and one — the string-arena counter — said
"a fifth producer would have nothing looking for it" while **three** had
arrived and none had. Fixing that last one is the whole argument for reading
this file rather than only writing to it. Re-audit after a milestone, as
`docs-engineering` does for the rest of the documentation.

**Audited as a whole again on 2026-08-29**, after ADR-0243, ADR-0244 and
ADR-0245 landed in one batch. Five kinds of decay, and the two sharpest were
not in this register at all — which is the argument for reading the whole
documentation set on the same pass rather than only this file.

- **A table that had stopped being a table**, twice. `CLAUDE.md`'s gate list
  had the `runtime-isoc` row split in half by the `unicode-conformance` row
  wedged between its two pieces, and this file had a row broken across two
  lines; both render as a mangled row and an orphan paragraph. `CLAUDE.md` is
  loaded into *every* session before any work starts and the damage had
  survived however many readings since. **`markdown-tables` is the gate that
  answers it** — every row the width of its header, in 92 tables across 274
  files — and the class is why it is a gate rather than a proofread: a broken
  table renders as something that still looks like documentation.
- **And a third that the gate deliberately does not reach.** A cell held
  `grep -lic 'mutation\|mutant'` in a code span, and GFM turns `\|` into a
  literal `|` *everywhere*, code span included — so the command rendered as
  `'mutation|mutant'`, which under basic `grep` matches a pipe character rather
  than either word. The source was well formed and only the reader was misled;
  nothing can tell it from a cell that wants a literal pipe. It is rewritten
  without the alternation, and its counts had drifted too: 103 of 234 → 107 of
  246.
- **An arithmetic claim in prose, and it was false.** Two documents illustrated
  `MapKey`'s 63-character bound with a URI that is **44** characters and fits.
  The finding was true — one from this checkout's own `selfhost/` is 67 — and
  the illustration of it was not. That is the shape ADR-0072 named for clause
  numbers, met for a *number a reader could add up*: no oracle here checks
  arithmetic written in prose, and the wrong example had been copied into a
  second file.
- **Six counts quoted from a gate had moved.** `variant-check` 936 → 952
  sources and 2855 → 2935 guards; `target-layout` "four and a half thousand" →
  9320; `heap-balance` 7 of 29 → 5 of 39; `clause-citations` 9145 across 1505
  files → 9344 across 1537; `pending.txt` 187 → 188; and `procedure-coverage`
  679 of 681 → **629 of 631**, which had moved *down* and so could not have
  been explained away as growth. Every one was found by running the gate, which
  is the only way any of them is ever found.
- **A catalogue quoted as three where the gate says six.** `runtime-isoc`'s
  POSIX header list gained `<netdb.h>`, `<poll.h>` and `<sys/socket.h>` with
  ADR-0203 and ADR-0205, and the sentence naming it was never touched — a
  *porting cost* understated by half in the file a reader consults to learn it.
- **The `model-drift` CodeGen-region row met for a third and fourth time**, by
  ADR-0244 and ADR-0245. Both were driver and emitter work below the banner
  with no lowering in them, both needed the trailer, and one increment earlier
  in the same week was pushed without it. The row was right, and reading it is
  what put the trailer on these two.

**The numbers re-run on 2026-09-01, and only the numbers.** Not an end-to-end
read of every row — this was the narrower sweep the skill that governs these
audits names as its own structural blind spot: *step 2 audits what a document
says about the code, and a document quoting a gate is a different question.*
Every count in `CLAUDE.md`, this file, `README.md` and `doc/developer-guide.md`
that a gate reports was checked by **running the gate**, seventeen commits
after the last such sweep. Five had moved and one was simply wrong:

- `variant-check` 779 sources / 3144 guards → **785 / 3185**;
  `clause-citations` 9344 across 1537 files → **10 307 across 1661**;
  `format-check` 774 of 783 → **776 of 785**; `predicate-kinds` 39 predicates
  → **40**, and `doc/developer-guide.md` had it as **36**, two documents
  disagreeing about one gate's own answer.
- **`line-coverage`'s pair was not stale, it was miscast.** *784 of the 853
  directions never taken* is a **finding** ADR-0274 measured once, written in
  the present tense beside two ratchets that move with the corpus — which now
  answer 9747 of 10 608. It is now dated as a measurement, which is the repair;
  updating the numbers would have destroyed the finding.
- **And one claim that no arithmetic would have caught.** `CLAUDE.md` said
  every testable clause of the dialect spec is cited *but for the three AP
  5.5 d) names*. `run.py --coverage` says **114 of 118**, and the four are
  6.7.7.6.1, 6.11, 6.13.1 and 6.13.2 — a different count *and* a different
  identity, the last two being the clauses `stale-component` exists for and so
  held by a harness rather than by a scenario. The sentence had a specific,
  checkable, wrong referent, which is the shape ADR-0072 named for clause
  numbers met once more.

**A fourth shape, found on 2026-09-01 by trimming `doc/roadmap.md`, and it is
not a number.** The three audits above look for a claim that has drifted from
the code. This one is a claim that never met the code at all: **ADR-0266,
ADR-0267 and ADR-0268 had landed and reached no document outside their own
records.** Two of them closed roadmap rows that were still written as open --
*`take` is refused for a handle in as many words* (ADR-0267 widened it) and
the concurrency row reading **unblocked and unbuilt** (ADR-0268 built it) --
and ADR-0267 was in no README, no digest and no `CLAUDE.md` bullet. A fourth
claim, that the terminal binding an IDE needs is small and shaped and will be
built *whenever something asks for it*, had been built by ADR-0262. And
`doc/history.md`'s increment table had stopped counting seventeen increments
earlier while its preamble said *thirty so far*.

None of these is reachable by re-running a gate, which is what the audit above
does: a gate answers a question about the compiler, and these are documents
that were never told a decision was made. The distinguishing feature is that
each was found by reading a **record** and asking where else it should appear
-- the opposite direction from every other audit here, which starts from the
document.

**A gate could ask this and none does.** Every accepted ADR whose change moved
the accepted language should be named somewhere outside `doc/adr/`, and
`grep -l "ADR-0267" -- ':!doc/adr'` answers in one command. What makes it more
than a grep is deciding which records *must* appear -- a gate over all 286
would fail on every internal one -- and that is the design question rather
than the mechanism. Not built here; recorded so the next reader does not
conclude from four repairs that the class is closed.

**A fifth shape, found on 2026-09-01 by a `security-audit` pass: a gate that
prints a claim it never evaluated.** Not a stale number and not an untold
document -- a check whose *subject* is silently empty, so it passes by asking
nothing and says so in a sentence a reader takes for a measurement. Two of
them, in one afternoon, and both were green on every run since they were
written:

- **`runtime-isoc` never bounded the concurrency unit's headers.** Pass 5
  compared each `#include` against `$ISO_HEADERS` -- **a variable assigned
  nowhere in the script**, the other four passes spelling it `iso_headers` and
  holding base names *without* the `.h`. Under `set -u` the reference killed
  the subshell it stood in, so `task_extra` came back empty whatever the file
  included, and the summary went on calling `runtime/pasrt_task.c` *bounded by
  `<pthread.h>` alone* as a fact. Adding `<sys/mman.h>` to it left the gate
  **green and silent**; the only visible trace was one line of unread stderr.
  ADR-0186 makes that list the whole of what a port has to satisfy, so the
  claim was load-bearing and unchecked.
- **`sanitizers` could not link 47 of the cases it counted.** `pascalcc`
  translates every component `--dump-imports` reports *except* what the caller
  named with `--import` -- "its object is the caller's to supply" -- and this
  harness named them and supplied none, so every case with a `.components`
  sidecar failed at the **link** and was counted as a *skip*. The runtime's
  fourth translation unit was missing from the gate's own `libpasrt.a` too
  (ADR-0268 added `runtime/pasrt_task.c` after ADR-0261 wrote the list), so
  `tests/dialect/concurrency.pas` could not link either. 288 of 346 runnable
  programs were reaching the only memory-safety oracle here, and the whole of
  `lib/` and `lib/dialect/` was reaching it through **no case at all**. Both
  are repaired -- 288 clean becomes **334**, and the 187 remaining skips are
  exactly the 175 cases with no `.out` plus the 12 wanting file names on a
  command line. The argument is the mutation: under-allocating a channel's
  buffer by one element is an ASan heap-buffer-overflow the repaired gate
  **flags**, and that the gate as it stood **passed** -- 288 clean, 0 flagged,
  exit 0, with a heap overflow live in the runtime.

The shape is `format-check`'s (ADR-0282) met twice more, and the lesson is
narrower than "test the tests": **a gate that reports a count is checkable and
a gate that reports a property is not.** `sanitize.sh` prints its four
tallies, and the skip number had been 233 in plain sight for as long as the
gate existed. What no reader could see is that a skip meant *did not link*
rather than *has no `.out`*. A denominator a gate cannot fall below is the
cheap answer -- this one has a floor of 100 and 288 cleared it comfortably --
and the repair is to make the harness say **why** it skipped, since the three
reasons were one number and only two of them are honest. It now reports
`187 skipped (175 with no .out, 12 wanting file names, 0 unbuilt)`, and says
in words that a case which cannot be linked is coverage lost rather than a
case with nothing to run. **`unbuilt` is the number to read**: removing the
fourth translation unit again makes it 1 and prints the reason, where the old
tally moved from 233 to 234 and said nothing.

**A count is now stated in one place where it was stated in four.** The
language server's findings were *twenty-one, fifteen closed, six open* in this
file's sibling documents and *twenty-six, seventeen, nine* in the section that
is actually maintained. Rather than syncing four copies, three of them now
point at the one that is kept — a fact stated twice is a fact that will
disagree with itself, and this one had, in three places at the same snapshot.

**ADR-0233's rows, added on implementation** (2026-08-28). The compiler became
three §6.13 program-components, which **narrowed** the linking row below rather
than striking it and **closed** the diverse-double-compiling window for good.
It also moved eleven gates: every one that read "the compiler's source" or ran
the compiler over it was reading or measuring a third of a compiler the moment
the split landed, and every one of them now goes through
`tests/checks/components.py`. Two ways that failure was *silent* are worth
carrying forward, because neither is peculiar to this change:
`procedure-coverage` and `line-coverage` *degraded* to a **skip** when the
compiler could not translate its own source, so a break in them read as a
missing `clang` — and both were skipping on the day the split landed. **Fixed
on review**: the two now tell a skip (nothing on this machine to run with) from
a failure (the measurement is broken) and exit 1 for the second, which is what
every other gate here does. The second hazard stands, being a property of the
language: an exported routine's header appears **twice** — §6.11.1 puts it in
the module-heading and leaves the block repeating the name alone — so a regex
anchored on `^function Name(` matches an interface entry with no body and finds
nothing to read.

**ADR-0236's row, added and struck on 2026-08-29.** The language server is the
first program here that lives outside `tests/`, so it was briefly the first
thing in the tree that every corpus sweep was blind to at once. The row was
written saying the fix was a decision rather than a chore; it was a chore, and
the row now records what closing it cost and what it bought — which was nothing
for coverage and a real check for leaks. **Writing a row down is what got it
closed**, and it is the second time in two days that has happened here: the
`fpc-differential` gate shipped with a `*_REQUIRE` variable nothing set, was
declared as a row, and had a CI job the same afternoon.

**Audited again on 2026-08-28**, after version 3, over 67 rows. Six had gone
stale and the release is why five of them did — a register describing what is
*not* checked is exactly what a change that deletes five gates falsifies. Two
rows closed: case-exhaustiveness is no longer read over the source (ADR-0229,
ADR-0230 — and the row still said it was, having been rewritten around the
gate's other half while its own title stayed false), and the
mode-portability row is moot, its mechanism deleted rather than fixed. Three
carried a **count a gate answers** — 1019 sources, 2821 guards, 368 citations
across 331 scenarios — every one of them wrong, and every one of them checked
by running the gate rather than by reading the sentence, which is the only way
this shape is ever caught. One named `reserved_words.py` as the last gate
parsing the compiler's source, and that file is deleted; the shape it stood for
is not, so the row keeps it with ten live examples instead of one dead one.

**Read end to end a third time on 2026-08-28**, after ADR-0233 landed and
ADR-0234 was written — the same date as the audit above and a different tree,
which is itself the finding: two of the four stale rows below were falsified by
changes made *that day*, and a register re-read only after a milestone would
have carried them for weeks. What it found:

- **A row whose closing condition arrived.** "No third-party corpus" ended
  *there is no replacement and none is available*. `fpc-differential` is not a
  corpus and the title stands, but an external answer of some kind became
  available that morning. This is ADR-0197's third shape exactly, and the
  second time this register has been caught by it.
- **A closed row describing a sandbox that had changed underneath it.** The
  `langspec-audit` row said readers get the standards and *the BSI suite*;
  ADR-0232 removed the suite and `sandbox.sh` says so in a paragraph where the
  copy used to be. A struck-through row is still read — that is what struck
  through means here — so it goes stale like any other.
- **Two counts a gate answers.** `variant-check` says 936 sources where the row
  said 934, the split having added two; the guard count was right. And the
  mutation row's *two hundred records carry a mutation in their prose* is 103
  of 234 by the only grep that can be written for it, which is an upper bound.
  Both were checked by running the gate, which is the only way this shape is
  ever caught.
- **A row that was missing, which is the one worth the whole read.**
  `fpc-differential` shipped that morning with a `FPC_DIFFERENTIAL_REQUIRE`
  nothing set, so the only gate here answering the corpus with a second
  processor ran on one machine and no CI job. Every comparable skipping oracle
  had that covered years-equivalent ago. The row went in and was closed the
  same day by the job that installs `fpc`; it is kept struck below because
  what it records is that the gap was *shipped*.
- **One row verified rather than assumed**, and it is the one ADR-0197 was
  written about: the string-arena row says there are **eight** producers and
  that a ninth would have nothing looking for it. There are eight
  (`strTemps := strTemps + 1` in `selfhost/compiler.pas`). It is current, and
  it is the row most likely to be stale next.

| Blind spot | Consequence | Recorded |
| --- | --- | --- |
| **The front end has no second implementation** | `difftest` compared `src/`'s tokens/AST/Sema against the Pascal compiler's over every source in the tree, and ADR-0232 retired it: `src/` is frozen at a conformance surface that no longer exists, and it skipped every dialect source anyway. So the whole front end is now in the position the dialect was already in — guarded by goldens that agree with whoever wrote them, plus `tests/spec/` for a clause-shaped requirement. **This is the largest blind spot on this page**, and nothing here closes it: a second implementation of a language with no external specification would be two readings by one author, which is what difftest could never contradict either. What it *did* catch was drift between two ports of one reading, and that is what is lost | ADR-0108, ADR-0232 |
| ~~`langspec-audit`'s readers are **not isolated**~~ — closed by ADR-0228 | The harness injected `CLAUDE.md` — the reasoning for the clauses under audit included — before a reader's first turn, and it could not decline; all seven readers of the second run disclosed it, so a CONFIRMED verdict meant "no independent oracle contradicts it" and not "an uninfluenced reader agreed". Readers now run **out of process** against a sandbox built outside the repository, with the standards, a `pascalcc` and a **comment-stripped** compiler source and nothing else — the BSI suite was in it until ADR-0232, and `sandbox.sh` now carries a paragraph where the copy was, because 812 programs this compiler cannot compile would fail a reader for one reason having nothing to do with the clause under audit. Asked whether it was given project documentation, a reader in the repository names Afterschool Pascal and its path; one in the sandbox answers no. What is *not* closed: a reader is still a reader of the same family as the implementer, so a shared blind spot in reading English is untouched | ADR-0107, ADR-0228 |
| A subrange whose bounds are not constants is refused as a **set's base type** | Legal under §6.2.3.8 b) and refused, and the last of a row that once said *anywhere but an array's index-type*. ADR-0133 lifted the bare subrange and ADR-0134 the record field and the file component — a record being no kind of block — leaving the one container with a representation reason: every set here is a 256-bit word whose base type must have its values in 0..255 (ADR-0028), and a bound the block evaluates cannot be checked against that before the program runs. It is the limit `set of integer` already states, reached another way | ADR-0028, ADR-0107, ADR-0113, ADR-0127, ADR-0133, ADR-0134 |
| `-O0` and `-O2` are each run, never **compared** | the whole corpus now runs at both, so a level-specific crash or wrong answer fails — but a case where the two *differ* and both look plausible passes twice. Only `--crosscheck` compares them, over its own generated program. **The second sweep is a step someone runs** (§6's A3, `AFTERSCHOOL_PASCAL_OPT=-O0`) and the default `ctest` is `-O2`, which is what a `foo.opt` sidecar exists to work around for a case known to need it. One harness varies it without being asked: `selfhost/irtest.sh` links at `-O0` unconditionally, so a level-sensitive defect shows up as the two harnesses disagreeing about one program — which is how ADR-0220 was found, `ctest` green and `irtest` reporting "output differs". That is not a designed check and must not be leaned on: it covers the golden corpus only and says nothing about which level was wrong | §6, ADR-0220 |
| ~~**`lsp/` is outside every corpus sweep**~~ — closed the day it was written | `line-coverage`, `procedure-coverage`, `heap-balance`, `variant-check` and the `--dump-all` sweep were all globbed over `tests/`, and `lsp/pasls.pas` is not there — it lives in `lsp/` because a server has to be a binary an editor can be pointed at rather than one compiled into a temporary directory and thrown away (ADR-0236). The row said the fix was a decision between two shapes; **it was the first shape and it was four lines**. `coverage.py` gained a group, `variant_check.sh` gained a `find` root, and `build.sh` learned `AFTERSCHOOL_PASCAL_OPT` so the corpus-wide `-O0` sweep reaches a program whose whole shape is a loop (ADR-0102). `heap-balance` needed more than a root and is the one worth reading: the server has no `.out` and cannot have one, so `run_test.sh` cannot drive it and `lsp/run.sh` does — which meant that harness had to take `run_test.sh`'s care about `PASHEAP_BALANCE` **twice over**, since `pascalcc` builds the server and the server then starts `pascalc` once per document, and both are Pascal programs on this runtime whose allocations are not the server's. Without that the first measurement read 16 324 outstanding variables; with it, four sessions balance at 0 and `pasls` is a catalogue line. **What the coverage half bought is nothing, and that is the result**: 446 statements never run before and after, so the server reaches no compiler statement the corpus did not already. What is *not* closed is not peculiar to `lsp/` — nothing measures any corpus program's own statement coverage, `pascalc --coverage` notwithstanding, and `fpc-differential` and `diagnostic-coverage` do not reach it by construction rather than by omission | ADR-0236, ADR-0102, ADR-0183 |
| `-O1` and `-O3` are unexercised | a defect at an intermediate level has nothing looking for it. Judged not worth a third and fourth sweep | — |
| **No third-party corpus** | BSI's 812 programs were the only artefact here nobody in this project wrote, and they are ISO 7185: 25 of them use a word-symbol §6.1.2 reserves, so this compiler cannot compile the suite at all. `unicode-conformance` is the one oracle left that nobody here wrote, and it covers one clause. **No replacement corpus is available and the title stands** — but the sentence that stood here, *none is available*, was about an external answer of any kind and ADR-0234 falsified it: `fpc-differential` is a second **processor**, and it answers 103 of the 244 cases that have a golden. It is not a corpus, it reaches nothing in `tests/dialect/`, and it shrinks every release — so what it narrows is the consequence and not the gap | ADR-0086, ADR-0232 |
| ~~**`fpc-differential` is run by no CI job**, so in practice it runs where someone has Free Pascal~~ — closed the same day it was opened | it skips 77 without `fpc`, which is right — `fpc` is not a documented dependency and must not become one. Every other gate here that skips is covered by a job that *refuses* to: `target-sizes` has `TARGET_SIZES_REQUIRE` set in two jobs and `unicode-conformance` has `UNICODE_CONFORMANCE_REQUIRE` in one, precisely so a skip cannot pass for a check. `FPC_DIFFERENTIAL_REQUIRE` exists and **nothing sets it**, so the second processor answers the corpus only on a machine that happens to have one — which today is the machine ADR-0234 was written on. The catalogue fails in both directions, so what is at risk is not a wrong entry but a **silent** one: a disagreement that appears or disappears between releases would be seen by whoever next runs it and by nobody else. The fix was a job that installs `fpc` and sets the variable, which is what the two rows above did for their oracles, and it exists: `a second processor answers the corpus`. The row is kept struck rather than deleted because what it records is that the gap was **shipped** — ADR-0234 landed with a `*_REQUIRE` nothing set, and it took reading this register end to end to notice. **It has happened three more times** (`target32`, `TLS_REQUIRE` since ADR-0264, and a `SANITIZE_REQUIRE` named by a comment and read by nothing), so ADR-0330 made it mechanical: `require-consistency` compares the variables the checks read against the variables the workflows set, in both directions, and its own mutation caught it matching a name in a *comment* — the same defect it exists to refuse | ADR-0234 |
| Nothing links a component on its own **except the compiler's own build** | every *test* harness here compiles a program, and a §6.13 component is only ever translated as one input to that. So a component that assembles to a *valid but incomplete* module — a call emitted, its definition not — passes the compiler, passes LLVM's parser, and fails in the linker, in a different command, about a name no source spells. That is exactly how AP 6.7.3.10's instantiation bodies came to be emitted in one of `RunCodeGen`'s two arms: the loop naming their frame types is shared and the loop emitting their bodies was not, so a module-only translation was internally consistent and missing a function, and what caught it was a case whose `.components` sidecar happened to write that combination — the corpus had a program importing a generic and a module declaring one, and no module importing one. **ADR-0233 narrowed this row rather than striking it.** The compiler is three program-components now, so every build translates a module alone, translates a module that imports another, and links all three: the build *is* the test, and it runs on every commit rather than when someone writes a case. What it does not reach is a combination the compiler's own structure does not use — a module exporting a schema, a generic across a component boundary, a module supplying `to end do` — and for those the `.components` corpus is still the whole of it. **ADR-0244 and ADR-0245 narrowed it again.** `tools/pascalcc` now translates and links whatever the compiler resolved, so `import_by_name` and `import_by_env` link a chain of components no sidecar named; and `stale-component` links two objects that deliberately *disagree*, which is the first thing here to assert that a link must **fail**. What is left is the same sentence about combinations the compiler's own structure does not use | ADR-0212, ADR-0216, ADR-0233, ADR-0244, ADR-0245 |
| A **permission withheld** too widely is looked for by nothing | Every gate here watches a claim that is *made*: a diagnostic that stops being reached, a rule that stops holding, a program that stops behaving. A conforming program the compiler **refuses** is a program nobody wrote, so it is in no corpus, names no golden, reaches no diagnostic and disagrees with no second front end — `src/` carries the same rule and refuses it too, which is agreement rather than evidence. `take(mk)` for a parameterless function of a structured type was refused for as long as it had been possible to write it, with 720 cases green and `difftest`'s baseline empty; it was found by hand, from a probe written for something else. `predicate-callers` is the nearest thing and looks the other way — it sweeps for a permission *granted* too widely. What would close this is a corpus of programs asserted to **compile** that no rule here says should, and nothing of the kind exists. **The same crack runs the other way**, which is ADR-0180: AP 6.4.12.2's restriction on a handle-valued call is enforced at a site that one of the construct's two spellings never reaches, so `if make = nil` compiled, ran, exited 0 and leaked the handle the type exists to own. That half is a permission *granted* too widely and no gate found it either — the question none of them asks is whether a rule reaches every way of writing the construct it is about | ADR-0146, ADR-0179, ADR-0180 |
| A **release the runtime cannot be asked to make** is watched by nothing | AP 6.4.14.3 requires an owned pointer's storage to be given back when the activation terminates by a `goto` or a `halt`, and the block epilogue is the only exit that does it. The files and handles *inside* the owned variable are released on those paths, because each is registered with the runtime individually — so the observable resource comes back and the `malloc`ed block does not. **Half of this closed with ADR-0183**: `heap-balance` counts what `new` made against what `dispose` gave back, so an ordinary leak is now caught exactly and cheaply — it was found by making `dispose` free nothing, which leaves 735 of 735 cases and 230 of 230 scenarios green and moves the balance of nineteen. What it still cannot see is this row's own subject, a `goto` out of a block, because the count is taken at **exit** and the abandoned storage is indistinguishable there from storage a program was entitled to keep. Nor does it count files or handles, the other two affine kinds | ADR-0181, ADR-0183 |
| **§5.1 g) 2) permits more than this project takes** | ADR-0014 makes every ISO error condition trap, and ADR-0219 relaxes exactly one of them -- §6.5.6's empty substring. §5.1 g) offers a *second* compliant treatment — leave the error undetected and say so in an accompanying document — so a processor returning the null-string for `s[i..i-1]` with a line in `doc/implementation-defined.md` §3 would, on the face of the clause, have complied. Trapping is the better choice under §3.2 NOTE 2 and it is a **policy**, not a requirement. No document here may say a relaxation *had* to be made this way | ADR-0014, ADR-0219, ADR-0224 |
| A multi-element character-string is typed as ISO 7185 types it | §6.1.9 says unconditionally that a character-string of other than one string-element denotes a value of the **canonical**-string-type; this compiler gives `'hello'` a `packed array [1..5] of char`. Four places that could distinguish the readings were probed — §6.4.5 d), §6.4.6 f), §6.7.3.7.2's conformant arrays and a `string` schematic formal — and all four land on identical observable behaviour, so it cannot presently be convicted. It is a **labelling** divergence that a feature able to observe a type's identity would turn into a defect overnight | ADR-0224 |
| §6.7.3.2 and §6.4.3.3.3 contradict each other for `p('')` | The parameter clauses require a formal to possess a type produced from `string` with the actual's length as the tuple — 0 for the null-string — and §6.4.3.3.3 with §6.4.2.4 say no such type exists. This compiler resolves it two ways: the schematic formal accepts with capacity 0, the value-conformant one refuses. Both are defensible readings of a hole in the standard, so **no scenario may assert either** — the suite states what the standard requires | ADR-0224 |
| A compiler slowed **uniformly** is invisible to `benchmark` | `benchmark` (ADR-0270) commits proportions and not milliseconds, because a millisecond is a fact about the machine that took it -- four stage shares of one compile and two component scales, each divided by something measured in the same run. That is what makes it machine-independent and is exactly what it cannot see: a change that slows every stage of every component in the same proportion -- a pool lookup they all make, a slower `Peek` -- moves both denominators with both numerators and no proportion at all. The milliseconds are recorded in `tests/checks/benchmark.txt` beside the machine that took them, and are read by a person rather than compared, because comparing them is the design that goes red on a slow machine and green on a 2x regression on a fast one. It also cannot see a stage made a *fifth* slower: measured against the mutation, the threshold is about a third | ADR-0270 |
| An `unreachable_diagnostics.txt` entry that names **nothing** is ignored | The gate computes two sets -- messages no golden names, and listed messages a golden now names -- and an entry matching no message at all is in neither, so it is silently accepted. ADR-0273 added three entries in the wrong spelling (without the leading apostrophe, which was the old matcher's shape) and nothing said so; what caught it was the three messages staying *unnamed*, which is the same fact arriving the long way round and only works while the message still exists. An entry left behind by a deleted diagnostic has no such second signal. The fix is one line -- require every entry to name a message -- and is not built | ADR-0273 |
| A **wrong-arm read** is seen only where a corpus source reaches it | `variant-check` (ADR-0223) compiles the whole corpus -- 779 sources as this is written, which is what git tracks and no longer whatever `.pas` files are on disk, and the gate prints the figure -- with ADR-0118's guards armed, which is the only thing here that can see a node read through an arm its tag does not select -- every other oracle agreed with the mutation that proved it, including both front ends, because the value read was right by accident. It is a *dynamic* check, so a wrong-arm read on a path no corpus source takes is invisible to it, and `ast-fields` (ADR-0222) answers a static question about the same record rather than the same question statically. Neither reaches a field read through a second variable or filled by a routine the node is handed to | ADR-0222, ADR-0223 |
| A dispatch that is neither a case-statement nor a **tag chain** | `kind-exhaustive` now reads both (ADR-0221), and the shape that selects a chain is `x^.kind = c` -- a value asked for its own tag. A dispatch written as a table, a lookup, or a chain of predicate calls is outside it. `Assignable` is the live example: 43 type-predicate calls in thirteen arms, watched by `predicate-callers` (ADR-0146) from the other direction and by nothing from this one | ADR-0221, ADR-0146 |
| ~~Coverage is measured per **statement**, not per branch~~ — closed by ADR-0274 | `if c then a else b` on one line counted as covered when either arm ran, a decision with no else-part had nothing on its false side to count, and a short-circuit operator's right operand is an expression and had no counter at all. `--coverage` now emits a second counter on each edge of every decision the *source* writes — an if, a while, a repeat, and each `and`/`or` — keyed on line **and column**, and `line-coverage` gates a second ratchet over it. The census is the size of what was missing: **784 of the 853 directions never taken sit on lines statement coverage calls covered**, and every one of those decisions was reached and evaluated and only ever went one way. What does *not* close: a `for`'s test and every runtime check are outside the boundary on purpose, the first being generated from the bounds rather than written and the second being the compiler's branch rather than the program's; and a decision inside a schema's body is counted once however many tuples instantiate it, §6.4.7 re-emitting the body per tuple while the key is a source position — which is ADR-0104's own property, stated rather than found later | ADR-0104, ADR-0274 |
| **Sema is quadratic in declarations per block** | `Declare` asks `LookupInScope`, which is a linear scan of the scope's entries, so *n* names declared in one block cost *n²* pool comparisons: 1000 in 0.03 s, 8000 in 1.00, 32 000 in 14.31. Found by `fuzz`'s bounds family and by nothing else — every other corpus here is hand-written, and the largest block a person writes has a few dozen locals. It is **bounded**: `tokMax` admits about 75 000 such declarations, so the worst case is roughly 80 seconds and then a diagnostic, not a hang. Not fixed, because it is a performance property rather than a crash and the fix is a second structure beside the scope stack — a change to how Sema resolves names in a compiler that must self-host, which deserves its own measurement rather than a line in a fuzzing record | ADR-0275 |
| **Nothing says the formatter's output is well laid out** | `format-check` (ADR-0279) makes three claims about `--format` and every one of them is about *preservation*: the same tokens, the same comments, and the same text on a second pass. All three would hold of a formatter that put the whole program on one line. There is no oracle for layout and there cannot be one -- this tree has no agreed Pascal style, which is the same reason nothing here is checked in formatted -- so what stands in its place is `tests/dumps/format.pas`, one file written deliberately badly whose golden is the only assertion of a style in the repository. A layout rule changed without regenerating it fails; a layout rule changed *and* regenerated is a decision to argue for in the commit message, as every golden is | ADR-0279 |
| **`--coverage` under `spawn` is a data race** | Neither the statement table nor the branch table is `_Thread_local`, where ADR-0268 made that decision for the four runtime globals a task really owns. Nothing measures a concurrent program today — every sweep here runs the compiler, which is one thread — so this is a limit of the product feature and not of the gate. The fix is not a `_Thread_local` table, which would give each task one that nothing merges at exit; it is a lock or an atomic, and neither has been asked for | ADR-0104, ADR-0268, ADR-0274 |
| Clause **citation is presence, not depth** | a clause with one scenario counts as cited, though §6.8.3.9 alone has six requirements this suite checks and more it does not. The same caution statement coverage carries, one level further out | ADR-0106 |
| The statement-coverage gate is a **ratchet**, not an allowlist | it cannot fail in both directions, so a line that becomes covered says nothing, and 462 uncovered lines carry no argument between them. The per-procedure breakdown is what makes a regression nameable | ADR-0104 |
| `coverage.py` sees the sources, not the harnesses that build their own compiler | it enumerates the corpus by glob, so what `irtest.sh`, `producttest.sh`, and `verify.py` drive is invisible; a procedure only those reach reports as uncovered. The **flags** half of this is closed: the corpus sweeps `--dump-all` over every source, which is how `difftest.sh` drove it before ADR-0232 retired that harness, which had been worth 195 statements reported unreached while an oracle reached them every run — `dumpexpr` alone read 75 of 186 rather than 1 | ADR-0103 |
| Errors listed in `doc/implementation-defined.md` §3 | deliberately unreported, under §5.1 f) 1) | ADR-0073 |
| §6.4.3.3's region is not asked of a **constant** occurrence | a type-name inside a record denoter is now asked at every occurrence (ADR-0112), but `array [1..fred]` beside a field `fred` reads the constant. Constant occurrences reach the expression checker rather than type-denoter resolution. What is left of a row that used to say the rule was enforced for a pointer domain and nothing else | ADR-0112 |
| A **tagless** variant part is outside the variant check | ADR-0118 makes the tag authoritative -- a write activates a variant, a read of an inactive one traps -- and §6.4.3.3 permits `case Kind of` with **no tag field**, which this compiler accepts. There is then nothing to compare against, so such a record stays an unchecked union. Deliberate: refusing it would reject a conforming Extended Pascal program, which this language contains, and synthesising a hidden tag is a *layout* change reaching `LlSize`, `new(p, c1, ...)`'s variant selection and every whole-variable copy. It is registered because a safety feature with an unstated exception is worse than none -- a reader must not conclude that "the tag cannot lie" covers every variant record. **The check this is an exception to is built**, so the row is no longer dated from its record -- and the exception has not narrowed: a `case Sel of` with no tag field, written to through one arm and read through the other, prints the other arm's reinterpretation of the bytes and exits 0, checked again on 2026-08-25. **Since ADR-0223 this row also bounds an oracle**: `variant-check` compiles the corpus with 2855 guards armed, and what it therefore cannot see is a *tagless* variant record. The AST's variant part has a tag, so it is covered; a second variant record added without one would be outside that check in silence, and this is the row to widen when one is | ADR-0118, ADR-0027, ADR-0223 |
| The diverse-double-compiling window can **close without anything noticing** | `seed/ddc.sh` answered the seed's provenance once (2026-08-18, PASS) and works only while the `v0.1.0` C++ compiler still accepts `selfhost/compiler.pas`. Every feature the compiler starts *using* risks ending that, and nothing runs the check — it is not a `ctest` case, deliberately: it builds an LLVM-linked C++ compiler, and it answers a question that is asked once rather than a regression that can recur. So the day it stops being possible will pass unremarked unless someone runs it. It reports that day as a skip naming it, which is the most a script can do; the dated line in `seed/README.md` is what is meant to survive. **That day was ADR-0233**: `v0.1.0` has no `--import`, so it cannot read a compiler that is three program-components, and the check now says THE WINDOW HAS CLOSED and exits 0. The row stays because the *gap* it names does — the seed's provenance is a claim about this repository's history and there is no longer any way to check it from outside | ADR-0085, ADR-0233 |
| ~~Case-exhaustiveness is checked over the **source**, not by asking the compiler~~ — closed by ADR-0229 and ADR-0230 | This row closed in two halves and the second was written while the row still said the opposite. `kind-exhaustive` first grew from `typeKind` alone to every enumeration (ADR-0145), which closed the row that had stood here; what was left was the *oracle* -- it parsed `compiler.pas` and could ask the built compiler nothing. ADR-0229 moved the case-statements onto `--dump-dispatch` and ADR-0230 moved the chains, so it reads no Pascal at all and the question is put to the compiler. **What does not close with it** is that the gate still cannot judge whether an arm is *right*: `tyOptional: StaticThroughout := true` satisfies it and is wrong, and that belongs to the row about a predicate rather than to this one. Nor is a crash on a case-statement a question a program can be written to ask, the arm that is missing being the one no program reaches -- which is why the gate exists at all | ADR-0018, ADR-0124, ADR-0145, ADR-0229, ADR-0230 |
| The **string pool's** headroom is measured, and one way into it is still silent | ADR-0148 closed the row that stood here: `--dump-limits` compiles as usual and reports both counters against both capacities, so `buffer-headroom` no longer reports headroom for two arrays while measuring one. The pool needed the flag and the tokens never did -- `--dump-tokens` writes one line per token and §6.1.7 forbids a newline in a string-literal, so the line count *is* the count, while `PoolAdd` is called from Sema and from CodeGen as well as from the lexer and no count over the token stream is the pool's size. The first measurement is 491,964 of 1,000,000, against a lower bound of 442,625. What is left is `PoolPut`, the pool's other entry: it **drops a character** when the pool is full rather than reporting, so the two names Sema builds rather than reads -- a function's result slot and a `with` binding -- would come out short, and a short name can collide with another. Reachable only once the pool is within a name's length of full, which is the state the 80% gate exists to report long before; not fixed because the fix is a diagnostic no program in the corpus can reach, and the honest alternative to a golden nothing exercises is the headroom report itself | ADR-0095, ADR-0126, ADR-0148 |
| A gate that holds **both halves** of its comparison cannot fail | `foreign_reserved.py` kept `COMPOSED`, a regex copy of the rules `ReservedForeignName` applies without a list. Adding `frame[0-9]+` to it without adding it to the compiler left the gate green over a name the compiler still accepted (ADR-0144). Closed for this gate — it now compiles a probe, harvests the `@names` the IR actually contains, and offers each back to the compiler — but the shape is general and other checks here read the compiler's *source* to decide what it does: `kind_exhaustive.py` and `reserved_words.py` both parse `compiler.pas`, and `buffer_headroom.py` did until ADR-0148 gave it a second half the compiler answers: it reads each capacity from the source *and* from what `--dump-limits` reports, so a disagreement is the stale binary named rather than headroom measured against a bound this tree no longer declares. Reading the source is the weaker oracle in every case. **ADR-0229 closed most of the third**: `kind_exhaustive.py` now takes the case-statements from `--dump-dispatch`, so what a regex could not know — which types are enumerations, how many constants each has, what a selector's type is — the compiler answers. The two were compared before the old reader was deleted and agreed on all 60 sites, every count and every missing constant. **ADR-0230 closed the rest of it**: the chains come from the compiler too, so `kind_exhaustive.py` reads no Pascal at all and the three `symKind` chains the text match had been missing are now caught. `reserved_words.py` was named here as the last gate still parsing the compiler's source and is **deleted** (ADR-0232), which closes that sentence and not the shape: ten checks here still read `compiler.pas` as text for something -- `ast_fields.py`, `predicate_callers.py`, `diagnostic_coverage.py`, `predicate_kinds.py` and `buffer_headroom.py` among them -- and each is the weaker oracle for exactly the reason above. `buffer_headroom.py` is the pattern to copy: it reads the capacity from the source *and* from the compiler, so a disagreement names the stale binary | ADR-0121, ADR-0144, ADR-0229, ADR-0230, ADR-0232 |
| Nothing checks an external-declaration's **name** against another component's | ADR-0147 gives one linker symbol one `external` declaration *within* a program-component, which is what closed the row that stood here -- two `declare`s of one global and LLVM's *invalid redefinition*, an error about a file nobody wrote. Across components nothing looks: two modules may each declare `external 'strerror'` and each emits its own declaration, which is 6.13 working. What is not checked is that they *mean* the same routine, and that is the row below rather than this one -- nothing checks a heading against the routine it names at all | ADR-0121, ADR-0128, ADR-0147 |
| Nothing checks that every string-arena producer is **counted** | the release CodeGen emits at the end of a statement is driven by a counter its producers bump. A new producer added to `runtime/pasrt.c` and emitted from somewhere else would allocate without bumping it, and the statement holding it would write no release — a leak that reports only once the arena is gone. There are **eight**, and each is now pinned by a loop moving megabytes through a one-megabyte arena, every one of the eight mutation-checked on 2026-08-25: `tests/extended/str_arena_loop.pas` has four of them — one being ADR-0171's padded actual for a fixed-string value parameter, which is not in `EmitString` at all and is the shape this row was written about — `tests/dialect/foreign_string.pas` has ADR-0122's NUL-terminated copy, and `tests/dialect/text_arena_loop.pas` has the three AP 6.4.15 added, which **arrived while this row still said a fifth would have nothing looking for it**. Two things stay open. A ninth would again have nothing; and pinning one is not merely writing a large loop, because the counter decides whether a *statement* releases — so a bump removed from a producer that shares its statement with another is invisible. `t := a + b` over texts holds the join and the store, and dropping the join's bump changes nothing observable, which is why the loop that pins it compares instead of assigning. That a pinning loop **isolates** its producer is a property of the test, and nothing checks it | ADR-0111, ADR-0197 |
| Nothing checks an `external` declaration against the function it names | ADR-0121 lets a program name a linker symbol, and the linker checks the *name*. Nothing checks the signature -- and the emitted `declare` does not either: a mutation giving the foreign declaration a static link it does not have, `declare double @cbrt(ptr, double)` beside `call double @cbrt(double 27.0)`, assembled, linked and ran correctly, because LLVM does not check a **direct** call against the declaration's parameter list under opaque pointers. So the call site is the whole of the ABI and a wrong type, a wrong parameter count or the wrong function entirely is undefined behaviour with no diagnostic. ADR-0264 added twenty-four more such declarations in one module and closed none of this: what its gate judges is the *constants* the module transcribed, which is the row above and a different question. This is what an FFI is without a header parser; the boundary is *visible* -- one directive, the foreign name written out, greppable -- and that is the only property claimed for it. **ADR-0129 confirmed it a second time, for arity rather than for types**: writing `ptr` where a slice's `ptr, i64` belongs, so the declaration and the call disagree about how many arguments there are, is a mutation that survives the whole suite. The `declare` a foreign heading emits is therefore documentary, and nothing here can make it otherwise | ADR-0121, ADR-0129 |
| ~~A **missing join** is not caught by any case~~ — closed by ADR-0312 | AP 6.9.3.12.1 joins every task a block spawned before releasing anything of that block's, and the emitter puts the join first in the epilogue. Removing it entirely left `tests/dialect/concurrency.pas` **green**: every task in it finishes before its block ends, so nothing observed the difference. The row said what would close it -- a task still running when its block ends *and* whose continued running is observable -- and called it a race to write deliberately; `tests/dialect/task_join.pas` is that program and it needed the new construct's client to be written before anybody wrote it. The spawn is inside a procedure, so the join is at that procedure's `end` and no statement in the program performs it; the task sleeps a second and writes to a stream it owns, which its block flushes and closes; the program then reads that file by name. **Mutation confirms it**: with the block-end join removed the new case fails and `concurrency.pas` stays green, exactly as this row predicted. Three things do **not** close with it. The oracle a channel offers is still the wrong one -- a value the task *sent* has already been synchronised, so any case written that way passes with the join deleted, and this row's replacement is one case and not a property of the corpus. The case's margin is a **one-second sleep** and not a construction that cannot race, so on a machine slow enough it could fail for the other reason. And the row below is untouched: AP 6.7.8.2's ban is still not transitive, and ThreadSanitizer over every concurrent program -- including the claim that a task record's join is claimed once when `wait` and the block's join both arrive -- is still run by hand and is still not a gate | ADR-0201, ADR-0268, ADR-0312 |
| A task's ban on non-local variables is **not transitive** | AP 6.7.8.2 refuses a variable-access in a task's own block, and in any routine declared inside it, that names a variable of an enclosing block. A task may still *call* a procedure declared outside it, and that procedure may name whatever its own scope admits -- so a global is reachable from two tasks through one call. Closing it needs a walk over the whole call graph, which this processor does not do and which a separately translated component makes harder still. It is the honest boundary of a rule that is otherwise exact, and it is why the clause states the limit rather than claiming share-nothing outright | ADR-0201, ADR-0268 |
| **A `verify/` precondition stricter than the compiler's own check passes in silence** | A rule's precondition is a *hypothesis*, and narrowing a hypothesis only makes the proof easier — so nothing in `verify/` compares one against the Sema check it claims to restate. It cost eleven increments: `index_span_is_representable` said `hi - lo < maxint` where its own docstring gave the `<=` reason, Sema refused at `>=`, **the two agreed**, and `array [0..maxint] of T` was refused at 2 147 483 648 bytes while a 2 400 000 000-byte record was accepted. ADR-0289 fixed both halves and measured the gap that remains: with the model returned to `<` and the compiler left relaxed, `verify.py` still reports 48 rules and no gaps. Declined rather than missed — a gate would have to read a Pascal condition and a Z3 expression and decide they say the same thing, which is a second reader of the compiler's source, the shape ADR-0229 and ADR-0230 spent two records moving `kind-exhaustive` *off*. What stands in its place is that a precondition must carry the sentence it restates, so the two can be compared by eye | ADR-0013, ADR-0288, ADR-0289 |
| **The langspec-audit sandbox cannot run its own compiler** | ADR-0228 builds the reader a sandbox holding the standards, a working `pascalcc` and comment-stripped source, and the skill asks for **compiled probes, not reasoning about what the compiler would do**. On the 2026-09-02 run the reader could invoke neither `bin/pascalcc` nor `pdftotext`, and could not write into `probes/` — the tool layer refused all three — so it returned a documentary verdict. Its findings were reproduced by hand before any were believed, and one was real, so the audit was still worth running; but the step that separates this skill from guessing did not execute. Nothing checks that the sandbox is usable before readers are launched | ADR-0107, ADR-0228, ADR-0288 |
| ~~**ThreadSanitizer is not a gate**~~ — closed 2026-09-05 (ADR-0327) | The concurrency construct's real oracle is TSan: it found the runtime's global handle list being unlinked by two threads on the *first run of the first program that spawned two tasks*, and then the string arena's cursor -- and neither is a defect any golden could hold, both orders producing the same output nearly always. It was run by hand. `sanitizers` (ADR-0261) builds the corpus under ASan and UBSan and does **not** build it under TSan, so a race introduced tomorrow has nothing watching for it. What would close it is a fourth pass in that harness over the cases that spawn, which is cheap and is not built. **Two changes have widened what it is being asked to watch and neither armed it.** ADR-0312 made the task record reference-counted and its join *claimed* under a mutex, so that `wait` and the block's own join -- whichever arrives first -- call `pthread_join` exactly once and the loser waits on a condition variable. ADR-0313 then added the select-statement, whose correctness is stated as an invariant about two mutexes: *no thread ever holds a channel's mutex and the activity mutex at the same time*, which is what makes the design deadlock-free and a wakeup impossible to lose. `tests/dialect/select_contended.pas` is the program to run TSan over -- four workers selecting on two shared channels while the program feeds both -- and its own oracle is a deterministic **total**, which is all a golden can be here: every value sent is received once and forwarded once, so the sum is the same however the schedule fell out. **A total cannot see an ordering defect**, and TSan remains the only thing that can. Eight concurrent programs were clean under it by hand on 2026-09-03, three runs each; nothing made that happen again. **`thread-sanitizer` is what does**, and it is the fourth pass this row asked for, arrived at as a *mode* of `sanitize.sh` rather than a second script: the 120 lines that translate a case's components and read its sidecars are the part that took the defects out — 47 cases were silently unlinked once — and a copy of them is a copy free to drift. ASan and TSan cannot be combined, clang refusing the pair, so it is a second invocation. **The corpus is chosen by what each source writes** and not from a list, so a concurrent program added later is swept without the gate being edited; eleven qualify today and all eleven are clean. Two things this row said are now measured rather than asserted: unlocking the store in `pas_chan_send` flags five of the eleven, which is the mutation that proves it watches; and moving `pas_select_turn++` outside the activity mutex flags **nothing**, which says the corpus contends on `select` less than `select_contended.pas`'s name suggests and is a gap of the corpus rather than of the gate. **And it is required in CI in the same commit**, the `sanitizers` job gaining a step that refuses a skip — this row's own lesson applied at the moment the gate landed rather than the third time. AP 6.7.8.2's ban is still not transitive, and that half of the row above is untouched | ADR-0261, ADR-0268, ADR-0312, ADR-0313, ADR-0327 |
| **Nothing checks that the printer knows every block-structured statement** | `pascalc --format` is token-driven: it takes a level on `begin`, `record`, `repeat`, a case's `of` and `otherwise`, and gives one back on `end` and `until`. A dialect statement is spelled with no word-symbol (ADR-0140), so the printer cannot see one without a positional rule of its own -- and ADR-0313's `select` opens a block. Until it was taught, a select's `end` gave a level back that nothing had taken: **the depth went negative**, every line after the first select in a source was indented one level too far left, and the one after that another. `format-check` was blind to it and structurally so -- all three of its claims are about what the output *contains*, and every one held: the token stream unchanged but for positions, the comments unchanged and before the same tokens, and re-formatting the misindented output reproducing it byte for byte. ADR-0285's sentence that there is no oracle for whether the output is *well* laid out turns out to cover a correctness defect and not only a matter of taste; this was found by reading a reformat by eye. An emptiness check on the printer's stack would **not** catch it -- with the opener unrecognised the select's `end` pops the enclosing `begin` instead, so the count still balances and the stack still ends empty; what is wrong is *which* opener each `end` gave back. Closing it needs an oracle for the printer's depth that is not the printer, which is a second reader of Pascal-shaped source -- the shape ADR-0229 and ADR-0230 spent two records moving `kind-exhaustive` *off*. So it is declined, and what stands in its place is that a new block-structured statement is taught to the printer in the same change, and that a reformat is read | ADR-0279, ADR-0285, ADR-0313 |
| **The bracket list is by hand** | ADR-0293 brackets every call into a runtime routine that can trap with `EmitAt`/`EmitAtDone`, and which routines those are -- 72 of 127 -- was read off the runtime's call graph once, by a script in nobody's tree. A routine that starts trapping tomorrow, or an emit site added without the bracket, reports its message with no position. The direction is the safe one -- the clear after each call is what keeps it from being the *previous* call's position -- and it is visible in the golden of the first case to reach it, which is why a gate comparing the emitter's brackets against the runtime's call graph (`clang -emit-llvm` over `runtime/pasrt*.c`, `runtime-isoc`'s shape) was declined rather than written. If a positionless message ever reaches a golden, that is the row to close | ADR-0293 |
| **A seed-built compiler's own traps name no position** | The seed calls `pas_index_error(i32, i32)` and three siblings, kept as wrappers that pass no position; `build/bin/pascalc` is seed-built, so a trap *in the compiler* -- a crash, which `procedure-coverage` and `fuzz` watch for -- says where nothing. Closes itself at the next reseed, when the wrappers can go; `procedure-coverage`'s instrumented subject is built by `build/bin/pascalc` and is not in this class | ADR-0293 |
| A **value transcribed from a C header** is checked for one library and for no other | `lib/dialect/pastls.pas` copies six numbers out of OpenSSL's headers because each is a macro or a bare `#define` no `external` declaration can reach, and a wrong copy fails **quietly** -- `SSL_VERIFY_PEER` written as 0 is `SSL_VERIFY_NONE`, verification is off, and every behavioural case stays green. `tests/checks/tls.sh` closes that instance the way `foreign-layout` closes a record's: a C program including the real headers prints the numbers and the Pascal source is read for what it claims. **The class is open.** Nothing derives the list of transcribed values -- the gate names its eight by hand, in a C source and a `sed`, and a seventh constant added to that module with no row in either is a constant nobody compares. Nor does anything look for the shape elsewhere: `PasProcess` carries `CLOCKS_PER_SEC` under the same hazard and has no such gate, and any module binding a library with `#define`d parameters would start the same way. What would close it is an annotation the compiler could report, as `@cstruct` is for a record -- which is ADR-0185's shape and was not built here, one site being an anecdote (ADR-0116) | ADR-0185, ADR-0264 |
| Nothing checks that a foreign record's fields are the struct's fields | ADR-0184 lets a record cross as a `var` parameter, and what makes it sound is that `RecordLayout` *is* C's struct rule -- so the compiler and C agree about offsets for whatever fields are declared. That the declared fields **are** `struct stat`'s, in that order and with that padding, is the row above asked about a type instead of a signature: unchecked, and uncheckable without a header parser. What the record removes is the arithmetic, a program stating fields and never offsets, which is why it is a narrower gap than the one it sits under and not a new kind of one. `pasx_record_probe` closes the half that *can* be closed -- the two compilers meeting over a struct they both declare, asked on whatever target the tree was built for -- and closes nothing about a struct only one of them declares. **ADR-0185 closed the half that can be closed**: a source states its claim in a comment (`@cstruct`/`@cfield`), `--dump-layout` reports the offsets this compiler computed, and `foreign-layout` hands the two to a C compiler holding the real header -- so a wrong field list fails the build, naming the Pascal field. What is left is a declaration whose header is not on **this** machine: `@cplatform` reports it as not-checked rather than failed, because a skip and a defect must not look alike, and only CI on a second platform turns that skip into a check. It is also why no POSIX struct is declared in `lib/` and ADR-0185 makes that a rule rather than a preference: a module has to work where nobody here can build it, so `PasFS` asks a `pasx_` routine and lets the target's own C compiler read the header. **ADR-0187 puts a second kind of declaration under this row and one that the gate cannot reach at all**: a record naming a *prefix* of the struct's members is admitted in the result position, deliberately -- it is how `struct tm` is usable without naming the `char *` glibc puts after the nine that matter -- and `foreign-layout` compares a field-list against the **whole** struct, so a prefix cannot be a claim a C compiler confirms. A partial claim is not a weaker check but no check, which is why the annotation stays optional and why `tests/dialect/foreign_optional_record.pas`'s `Tm` carries none: what pins that one is the calendar it prints | ADR-0184, ADR-0185, ADR-0187, ADR-0121 |
| Nothing checks that a new **statement-sequence holder** runs what it armed | AP 6.9.3.11 executes an armed statement when the statement-sequence it stands in is completed, and §6.9.3 has exactly three constructs holding one — a compound-statement, a repeat-statement's body and a case-statement-completer. `EndSequence` is called from those three places and nothing derives that list: a fourth such construct added to the language would arm correctly, refuse a label and a goto correctly, and run its deferred statements **late** — at the activation's end, through the runner, which is the backstop a local `goto` already uses. So the failure is a silent change of timing rather than a crash or a leak, and no oracle here would name it. `kind-exhaustive` covers the neighbouring half: a new node kind is named by `CheckDeferBody`'s exhaustive case, which is the walk that refuses a goto inside a deferred statement | ADR-0175 |
| ~~A **dump's exit status** is read by nothing~~ — closed by ADR-0269 | `tests/checks/coverage.py` drove `--dump-all` over every source in the corpus and read the *lines reached*, and nothing read what the child did. So a compiler that **stopped** while dumping one — a case-statement with no matching label is a halt, ADR-0018 — wrote a short dump, was counted as having run, and said nothing. `--dump-sema` crashed on every program declaring a fallible-type for three days and 714 green cases; it surfaced only because a new branch in the same walker went unreached and `line-coverage` asked why. `sweep()` now reports every invocation the compiler did not survive and `procedure-coverage` fails on it — a **negative return code**, which is a signal, or `runtime error:` at the start of a line of *standard error*, which separates a trap from the exit 1 a third of this corpus is written to produce. Matching that text anywhere would match a dump of the compiler's own source, whose emitter carries the literal on standard output; `variant_check.sh` met that on its first run. Mutating `Tokenize` to store 3 into a `1..2` makes it name 1426 of 1435 invocations where the whole suite was green before. **This row named its own closing condition and then sat for five records**, which is ADR-0197's second shape exactly. What does not close: the *content* of a dump. A walker that writes the wrong thing without stopping is caught by `tests/dumps/`'s goldens for the shapes those cases have and by nothing else | ADR-0103, ADR-0104, ADR-0176, ADR-0269 |
| Nothing holds the compiler's **dump format** and its readers together | `--dump-symbols` and `--dump-uses` are a wire format between two programs, and only one end is in the compiler. `lsp/pasls.pas` is the reader, and a field added in the middle of a line is a change the reader cannot see: ADR-0253 widened the `symbol` line from six numbers to eight, the name moved from field 7 to field 9, and the server's *second* reader of that line -- the MCP outline, beside the LSP one -- was left on 7. Nothing failed, because both readers overwrite the folded name with a slice of the source and every session named a file they could slice, so what broke was exactly the fallback. `lsp/sessions/mcp_wideline.jsonl` closes the instance by putting a declaration past the 4096 characters `DiagLine` holds, and the two readers are one routine now, so the *name* field is pinned in both. **The class is open**: no gate compares the emitter's field list with the reader's, so a field 10 added tomorrow is a golden that agrees with whoever regenerated it. What would close it is the compiler writing the format's own version, or a case per field rather than per line | ADR-0239, ADR-0246, ADR-0253 |
| **Fuzzing is a fixed corpus rather than a search, and it is not a sanitized one** | ADR-0275 built the generator this row used to ask for, one day after the row was written -- and the row was left standing, which is this register's own second decay shape met by the person who closed it. What is *actually* open is narrower and is two things. The **seed is fixed**, so the suite runs the same 3129 inputs every time and finds a new class only when somebody runs `--long N` by hand; a fuzzer that failed randomly on someone else's commit is one people learn to ignore, so this is a deliberate trade and not an oversight. And the fuzz gate drives the **ordinary** compiler while `sanitizers` drives the ordinary corpus, so *hostile input into a memory-checked compiler* is a combination no gate here has ever run -- nor is the runtime's own number reader fuzzed by anything, which is the one place `runtime/pasrt.c` parses attacker text (ADR-0076). Both were run by hand in a `security-audit` pass on 2026-09-01 -- a sanitized `pascalc` over all 789 tracked sources and 3200 generated inputs, and 3000 hostile inputs into the reader under ASan and UBSan -- and both found nothing. Neither is repeated by anything | ADR-0012, ADR-0067, ADR-0076, ADR-0261, ADR-0275 |
| The clause inventory is **generated**, and nothing compared it with the triage | `tests/spec/`'s denominator is two files: an inventory extracted from the standards by a script, and a triage written by hand. Until ADR-0152 nothing checked that they named the same clauses, and they were **37 apart** — every sub-clause of §6.2.2 and §6.2.3 in both standards is a bare number on its own line with the requirement under it, and the extractor read only lines carrying a title. So the most-cited clause in this repository, §6.2.2.9, was one `spec-clause-traceability` called *not a clause of that standard*. Closed in both directions: an orphaned triage row means the extractor lost a clause, an untriaged inventory row means the denominator is short. What stays is the shape rather than the instance — **the inventory has no oracle of its own**. It is checked against the triage and the triage against it, and if the extractor silently dropped a clause that nobody had triaged either, both files would agree and both would be wrong. Only a reader holding the standard can see that, which is `.claude/skills/langspec-audit/`'s job and not a gate's | ADR-0105, ADR-0106, ADR-0152 |
| A dialect scenario cannot reach **6.13.1 or 6.11** | `doc/afterschool-pascal-spec.md` is cited by 360 citations across a 319-scenario suite, and 98 of its 101 testable clauses have one (ADR-0135's wiring, ADR-0144's re-triage) -- run `tests/spec/run.py --coverage` rather than trusting those three numbers, which have gone stale here twice and are quoted only to say that the uncited remainder is small. Three of the four that do not are 6.11, 6.13.1 and 6.13.2, and they are the same gap: both are rules about which program-components may be *linked* together, and `tests/spec/run.py` compiles a single program with no way to ask for a second component at all. 6.11 joined the list when ADR-0144 re-triaged it out of `structural` -- it had been carrying a requirement that contradicted 6.13.1 while no scenario was permitted to cite it. 6.13.2 joined them when ADR-0245 put a digest of the module-heading into the same name, and it is the sharpest of the three for this purpose: the requirement is precisely that two *objects* disagree, and a harness that compiles one program has no way to make two. All three are covered by `tests/dialect/`, by `stale-component` — which edits a component's source between two links, and is a shell harness for exactly that reason — and by the link-time diagnostic `tools/pascalcc` translates -- `mixed-mode-link` was the third and went with the conformance modes (ADR-0232), which also rewrote 6.13.1 around the requirement that survives them -- and both stay in `pending.txt` rather than being triaged away, because triaging a clause the harness cannot reach as `structural` would be a lie about the clause rather than about the harness. The third, 6.7.7.6.1, is uncited for an unrelated reason AP 5.5 d) states: it is a rule about which types cross a foreign boundary, and `foreign-layout` is what checks it. **The same limit costs a second scenario**: §6.7.3.4 and §6.7.3.5 let an actual procedural or functional parameter be a *qualified* name, `i.p`, and a program demonstrating it needs the module that exports `i`. `tests/extended/procparam_qualified.pas` is the case; there is no scenario, and writing one for the unqualified form instead would file a citation under a requirement it does not check | ADR-0119, ADR-0135, ADR-0144 |
| A slice's foreign count is widened to `i64` and **nothing can see that it is** | ADR-0129 crosses a buffer as `(ptr, i64)` because every length this target's data path takes is a `size_t`. Dropping the `sext` and passing the count as an `i32` is a mutation that survives: x86-64 and aarch64 both zero the upper half of a register written 32 bits wide, and a slice's length is checked non-negative and cannot reach 2^31 without an array of two billion components. So the widening is right for a reason no program here can exhibit. Not worth a gate -- what would have to change is the architecture -- but it must not be read as covered, because the two tests that name the feature pass without it | ADR-0129, ADR-0128 |
| Nothing checks that a **listening** socket is what `PasNet.Wait` reports | ADR-0205 makes `ready[k]` true for a socket that can be read *or accepted from*, which to `poll` is one question -- and `tests/dialect/lib_net_wait.pas` has one listening socket, in slot 1, every time. A `Wait` that reported slot 1 for some other reason would pass it. The client that would settle it is a server listening on two services at once, and no program here has one. Worth knowing rather than worth a gate: what a gate would need is the second listener, which is the test | ADR-0205 |
| Nothing stages **two processes racing for a temporary name** | ADR-0243's `PasFS.TemporaryPath` composes a name from a counter seeded by the clock and claims it with C11 7.21.5.3's exclusive `fopen`, and the retry loop exists for the case where two programs started in the same second walk the same names. No program here runs two programs at once and compares what each was given, so that case is argued and not staged. What *is* staged is the exclusivity itself, inside one process: stopping the counter makes every one of the second call's 4 096 tries find the file the first call created, which fails the case. So the mechanism is pinned and the concurrency is not -- the same shape as the listening socket above, and the client that would settle it is the same kind of thing, a second process | ADR-0243 |
| The mutation catalogue is a register, not a measurement | ADR-0207 makes each recorded mutation re-runnable, and 45 of them are files. What it does **not** do is measure how much of the compiler a mutation would reach: a hundred-odd records carry mutations in their prose, most naming code that has since moved, and nothing compares the catalogue against them — `grep -lic mutat doc/adr/*.md` finds 107 of 246 and is an upper bound, catching a record that merely refers to the harness. "The mutation suite passes" therefore means *these 45 specific claims still hold*, and reading it as coverage is the mistake this row exists to prevent. It is also one-directional -- `kills:` names one test, so a mutant that starts being caught by a **different** test is not noticed. **And it rots, which was measured rather than feared**: after ADR-0232 six of 48 answered `NOT-APPLIED`, their anchors having been edited away -- two of those had already been dead since ADR-0215, months before, because the harness is deliberately not a `ctest` case and nobody had run it. One more had lost its killer and nothing said so. Run it after a change to anything a mutant names, which is the only thing that reads this register | ADR-0207, ADR-0232 |
| An `int64` result is the door AP §6.7.7.9 c) says is shut | that clause forbids an external-declaration whose result is an address of storage the callee owns, and calls itself the place where ADR-0109's memory-safety model begins. §6.7.7.8 admits an `int64` result — ADR-0128 added it for `ssize_t` — an address fits in one, and no processor can tell a count from an address. So `function ExtOpendir(path: string): int64; external 'opendir'` compiles, links and opens the directory, and because §6.4.2.6.2 makes `int64` numeric **on purpose**, the handle copies, `d := d + 8` is a legal statement about an open directory stream, and closing it twice is *double free or corruption (!prev)*, exit 134. Unfixable from here: withdrawing the `int64` result withdraws what `read` and `write` were given it for, and telling a count from an address needs a type the dialect does not have. `doc/roadmap.md` §7 had recorded this construct as the item that *forces* the memory-safety fork and as the reason the fork had not been started, so the deferral was protecting a boundary that had been open since ADR-0128 (ADR-0151). `tests/dialect/foreign_int64_handle.pas` is the program, kept as a gap that fails in both directions | ADR-0128, ADR-0151 |
| A constant's storage may be filled **twice** and no test can see it | ADR-0170 lets a constant-access naming a structured component fill a global of its own, and keeps the guard that stops a plain alias — `const b = a` shares a's storage, so filling it again writes it once per activation of b's block, which need not be a's. That guard cannot be mutated into a failing test: the second fill writes the *same value*, so the only difference is IR nobody compares. `tests/dumps/` compares what the compiler writes to standard output and not its product, and the goldens compare what the program printed. So the alias arm is argued and unpinned, unlike the other two arms of the same `if`, which three mutations kill. Registered rather than fixed because the honest fix is a gate over emitted IR, which nothing here has | ADR-0069, ADR-0170 |
| `model-drift` is scoped to a **range**, so a sibling commit can satisfy it | it asks whether `verify/lowering.py` changed anywhere in `base..head`, which is the right question for a push and the wrong one for a commit. ADR-0167's batch changed the model in two commits and touched CodeGen in two others -- the qualified-name call site and the string value parameter's prologue -- and both of those are unmodelled for good reasons nobody had to write down, because the gate was already satisfied. Someone bisecting to either finds an unexplained CodeGen change and no trailer saying why. Not tightened here: a per-commit gate would demand a trailer on every mechanical follow-up in a batch, which is the shape that trains people to write trailers without reading them | ADR-0013, ADR-0167 |
| `model-drift` is a **CI** gate and its local half answers a different question | it compares two commits, so `git diff base..head` cannot see work that is only in the working tree — and until ADR-0153 reached CI without the trailer it owed, running it before committing answered *the compiler did not change* and looked like a pass. That is now an explicit failure naming the reason, so the trap is closed for the file it watches. What stays is the shape: **every gate that reads git history answers about committed work**, and the local run of one before a commit is not the run CI will make. `model-drift-base` is the other half and is a question about one repository rather than one change | ADR-0013, ADR-0153 |
| **`model-drift`'s CodeGen region runs to end of file, so a driver change trips it** | The regions are found by banner text, and CodeGen has no end banner "because it runs to the end of the file" — which stopped being true once `ParseArgs`, `Compile` and the rest of the driver were written below it. ADR-0166 added one line to `Compile` and the gate reported a lowering change with no model change. The right answer is a `Model-unchanged:` trailer, which is what the gate asks for; the tempting one is an end banner, and narrowing a safety gate to make a build green is how a gate stops meaning anything. If it is drawn properly later, the change should be argued on its own and not while a build is red. **It happened a second time on 2026-08-28**, and the shape is worth recording because it was milder than ADR-0166's and still cost a red job: `6d14a2e` and `4477d48` edited **four comments** in the region — one of them beside the substring check, three of them in `Compile` and the dispatch dump, which is to say in the driver — and were pushed without the trailer, so the `model-drift` job failed over a range in which no lowering had changed at all. The gate cannot tell a comment from a lowering and should not try. What this row now says twice is that the region is wide on purpose and the trailer is cheap: write it whenever a commit touches `selfhost/compiler.pas` below CodeGen's banner, before deciding whether it was needed  **And a third and fourth time on 2026-08-29**, by ADR-0244 and ADR-0245: an import search and a linkage-name digest, both written below the banner because the component reader and `PutModulePart` live there, and neither touching a lowering. The pattern is now established rather than anecdotal — *most* work in this file's lower two thirds is driver work — and the trailer is the answer every time. | ADR-0013, ADR-0166, ADR-0232 |
| A citation may name a **real clause of the wrong standard** | `clause-citations` (ADR-0164) asks whether a number names a clause at all, and that is the cheap half. It cannot ask whether it names the *right* one, and the two standards make that the common case: they agree on 46 of the 91 numbers they share and disagree on 45, Extended Pascal having inserted String-types at 6.4.3.3 and shifted everything below by one. So §6.4.3.4 is Set-types in one and Record-types in the other, §6.4.7 is an *example* in one and Schema-definitions in the other — and ADR-0163's defect was exactly this: a real number, cited about a program of the standard where it means something else. **825** citations name one of the 45 ambiguous numbers, most of them unambiguous in their context, so a ratchet over them would be a large standing cost for a claim it still could not verify. The convention adopted instead is §3's B1: where the surrounding text does not pin the standard, the citation names it. Nothing enforces that | ADR-0163, ADR-0164 |
| Whether **HT, VT and FF are separators** is unsettled | `IsSpace` admits ordinals 9–13 outside strings and comments. §6.1.8 gives the separators as comments, spaces, and the separations of consecutive lines; LF and CR are the third and HT/VT/FF are none of the three, while clause 4 makes the required characters those needed to form §6.1's tokens and separators. So the lexer refuses `?` on a rule it does not apply to a tab. No reader found a sentence settling it and no program breaks either way; it gets no scenario, because asserting one of two defensible readings would launder a coin-flip into a citation | ADR-0162 |
| **`bindable` in a variant-denoter is caught only where it is written on the arm** | ISO/IEC 10206:1991 §6.4.3.4's third limb reaches through a structured component for *both* the words it forbids, and this compiler applies it to `restricted` only: a record with a `bindable` field, used in a variant arm, is accepted. Bindability belongs to the type-denoter (§6.4.1) and `fieldRec` records none, so catching it needs a flag on a field. Narrower still since ADR-0299 — a bindable *file* field never reaches the question, §6.4.3.6 keeping a file out of a variant here (ADR-0070), and a bindable non-file field is refused by `bind` by design, so the word on such a field decides 6.9.3.9.1 and nothing else | ADR-0163, ADR-0299 |
| Both triage directions are read once; **most reasons are still a title** | `tests/spec/clauses/triage.tsv` classifies every heading, and only `testable` enters the denominator and the work queue — so a requirement filed `structural` disappears, and a clause filed `testable` that states none sits in `pending.txt` for ever as work nobody can do. Both directions were swept on 2026-08-25 against the clause text itself: `structural` by looking for a `shall` that should not be there (ADR-0200, four reclassified and nine reasons corrected), `testable` by looking for the absence of one (ADR-0204, four reclassified of six candidates). What is left is the thing that made both sweeps necessary. **A reason is not an argument**: 51 `structural` rows share one copied sentence and roughly 340 `testable` rows carry the clause's own title, so a reader cannot tell a row somebody checked from a row somebody filled in. Neither sweep can see the shape it is blind to either — a `shall` about something a program cannot exercise, which is what both 5.2 *Programs* turned out to be, and which only a reader holding the standard distinguishes | ADR-0106, ADR-0152, ADR-0200, ADR-0204 |
| The layout comparison covers **frames and nothing else** | `target-layout` compares every frame size and field offset the compiler emits, across every admitted target, on every run (ADR-0157), which is what `LlSize`/`LlAlign` decide. It says nothing about a global's alignment, a string constant's, or the ABI by which arguments travel — the last being LLVM's business rather than this compiler's, which is what ADR-0030's and ADR-0051's "nothing that is two words may depend on how a struct is passed" was for. A divergence in one of those would go unnoticed | ADR-0028, ADR-0157 |
| Text-mode translation and other **C library semantics** are unasked | `runtime-isoc` (ADR-0161) checks that `runtime/pasrt.c` uses only ISO C plus four catalogued names, which bounds what a port must *supply*. It says nothing about what the same call **means** elsewhere: a Windows `fopen` in text mode translates line endings, which would change what `readln` sees, and `-std=c11` against glibc's headers is one implementation's idea of what is standard. A second C library would be the oracle and there is none here | ADR-0161 |
| ~~`target32` runs where a 32-bit libc happens to be, and **no CI job requires it**~~ — closed the same day it was opened | ADR-0325 admits `i386-pc-linux-gnu` and `tests/checks/target32.sh` builds a runtime for it and runs the whole corpus, catching what `target-layout` cannot — the two defects the port found were in neither a layout rule nor a frame, and that gate passed with `select` segfaulting. It skips 77 without a 32-bit libc, which is a separate package on most distributions, and `TARGET32_REQUIRE` existed with **nothing setting it** — precisely the shape the `fpc-differential` row above records as having been *shipped*. The `a pointer is four bytes` job installs the multiarch packages and sets the variable. **A job of its own rather than a step of `test`**, for `second-backend`'s reason: a 32-bit libc is not a documented dependency and adding it to the container every other job shares would make the documented list a lie. It carries a C probe before the build, so a package name that is wrong on some future image reddens with an obvious cause rather than as a Pascal failure. The row is kept struck rather than deleted because what it records is that the gap was **shipped**: the gate landed the same day with a `*_REQUIRE` nobody set, which is the second time that has happened here | ADR-0325 |
| The aarch64 job runs the **suite**, not the other oracles | ADR-0159's CI job builds and runs the whole corpus natively on arm64, which is what turns the port from links into runs. `llc-second-backend` skips there (no `llc` installed) and the SMT proofs are left out deliberately, being about the lowering *model* rather than the host. So a miscompilation of the compiler that only an aarch64 backend produces has nothing looking for it — and since ADR-0296 a release *does* ship an aarch64 archive built and suite-tested by that job, so this row is now what that archive does not claim | ADR-0159, ADR-0296 |
| §6.6.3.8's bounds error is not detected where **both** ends are dynamic | ISO 7185 §6.6.3.8 closes with an error: the smallest and largest values of the actual's index-type must lie within the interval the schema's ordinal-type-identifier specifies. Where the actual is an ordinary array-type both are constants and the program is refused at compile time; where the actual is itself a conformant array parameter they arrive with *its* actual, and this compiler emits no run-time comparison. It is an error in §3.1's sense, so leaving it undetected conforms provided a document says so — `doc/implementation-defined.md` §3 does, and BSI's LEV1F44 and LEV1F49 print *ERROR NOT DETECTED*. Worth closing: the check is one comparison per bound against a constant interval, at the call site where the bounds are already being emitted as arguments. Not done in the change that added the feature, because until the feature existed the check had no test that could fail without it | ADR-0153, ADR-0014 |
| Nothing checks that a foreign routine does not keep an address it was handed | ADR-0122 lets a `var` parameter and a string cross as an address, on the argument side only, where the caller owns the storage and outlives the call. The one thing that can still go wrong is a callee that *stores* the pointer and reads it afterwards -- which is a promise rather than a lifetime, and cannot be checked here at all: the callee is a symbol in an archive. The record's claim is that the near side is sound, not that the far side behaves | ADR-0122 |
| An optional's check is not elided by a guard that has already made it | ADR-0123 makes `o^` trap when there is no value, and `if o <> nil then o^` emits the check anyway. Narrowing the type inside the guarded statement is flow-sensitive analysis in Sema and a binding form in the grammar -- Swift's `if let`, Rust's `match` -- and neither is built. The cost is a load and a compare, not correctness; what a reader must not conclude is that the type makes the trap unreachable, only that it makes it *local* to the places the source writes `^` | ADR-0123 |
| The predicate sweep does not prove a probe **reaches** its call site | ADR-0146's `predicate-callers` closed the row that stood here: for every caller of `Assignable` the source contains, and every type `Assignable` refuses outright, a program putting that type in that position must be refused -- 23 positions against five type spellings, 115 pairs -- ADR-0150 made one of those arms cover two spellings, a bare file and a record holding one -- and the mutation that moves the slice arm one line down leaves all 625 cases green. What it claims is exactly that **no program in the table is accepted**, which is the safety property; it does not claim every call site was exercised. Several probes are refused by a rule that fires first -- a slice cannot be a `for` control variable, a discriminant actual must be ordinal before its type is compared -- so those positions are covered by the outer rule and not by the predicate. Proving reach would need `pascalc --coverage` over a compiler built for the purpose, which is what `line-coverage` already does for the corpus and is not wired to this gate | ADR-0058, ADR-0125, ADR-0139, ADR-0146 |
| A guard may ask a predicate whose answer is **right** | `predicate-kinds` sweeps what each predicate answers about each kind and `predicate-callers` sweeps one predicate's call sites; between them is a guard asking the wrong *question*, which is what all three of the text model's defects were. `EmitAssign` selected the string store with `IsStringType`, and a text is not a string-type — so the catalogue row is correct, the sweep is green, and the guard means "does this take the string path?" while spelling it "is this a string?". The two were the same sentence until a second kind shared the representation. ADR-0198 narrows it rather than closing it: given the kind a new kind resembles, `--like` lists every predicate the new one falls out of and every call site of each — three predicates and 42 call sites for a text against a string, with all three defects among them. It judges none of them, it has to be *told* the resemblance because nothing in the compiler records why a kind was added, and nothing makes anyone run it except `predicate-kinds` firing on the same day. A reader who scrolls past 42 lines still gets the defect. And a guard testing a **flag** rather than a kind — `hiDisc = nil`, packedness — is outside all three | ADR-0194, ADR-0198 |
| An **optional of a pointer** has two absent values | `?^T` is admitted, and `nil` in one expression then means two things: where `q` is `nil` and `op := q`, `op = nil` is false and `op^ = nil` is true. AP §6.4.11.2 refuses `?(?T)` — *one flag answers for a value; two would answer for each other* — and refuses `?text`, a file being no value at all; neither argument reaches a pointer, which **is** a value and whose `nil` answers a different question. Argued rather than legislated (ADR-0149): the redundancy is the program's, since a pointer is `nil` only because something assigned `nil`; the two checks compose in the order written, the optional trapping before the dereference is reached; and nothing here writes it — `lib/dialect/` holds no pointer type in seven modules. What is registered is the reading hazard rather than a defect: a mistaken count of `^` changes which check applies, and no gate can see that | ADR-0123, ADR-0149 |
| Nothing checks `lib/dialect/`'s reporting convention | ADR-0141 found the rule behind the library's four ways of saying a routine may have failed — `ErrorCode` where there is nothing to return, `?T` where absence has nothing to add, a result record where it has a reason, `boolean` for a question — and it is a **convention, not a gate**. A new module returning a result record whose tag is spelled `success` rather than `ok` would compile, link and pass every test here, and so would one answering an `ErrorCode` where the caller needed a value. Not fixed because the check worth writing is not obvious: the shapes are ordinary Pascal and a linter over a module interface is a tool this repository does not have. `lib/dialect/README.md` is the statement a reader can be pointed at, which is what a convention gets instead | ADR-0141, ADR-0120 |
| A foreign string of unstated length has no safe reception | `PasEnv.Lookup` binds C's `getenv`, whose result is a pointer to a string nobody measured. The length is discovered inside the boundary conversion, so a value longer than the receiving capacity **stops the caller's program** — an outcome the routine's `?EnvText` cannot express and the module cannot catch. `PasFS` faces the same question and answers it, because `getcwd` is *lent* a buffer and reports `ERANGE`, which becomes `errFull`; the difference is which side owns the storage. There is no result form that would hold an unmeasured string — `?string` without a capacity is a parameter form and not a result type, which was probed. Reachable: a PATH over 4096 characters is ordinary. `PasOS.ErrorNumberText` has the same shape against `strerror` and is unreachable in practice rather than guarded. **ADR-0188 shows the row is closable where the runtime holds the pointer**: `pasx_dir_next` is handed the caller's own capacity, calls `strlen` on the far side and answers `errFull`, so `PasDir` has no unmeasured reception at all -- and `Next` takes `var name: string` rather than a fixed type precisely so the bound checked is the caller's. The same routine would fix `PasEnv.Lookup` and has not been written; what it costs is a `pasx_` name for something C already has | ADR-0141, ADR-0122, ADR-0188 |
| ~~A module exporting an **undiscriminated schema** with a tagged variant is called portable~~ — moot since ADR-0232 | ADR-0137 locks a module whose interface reaches a record with a tagged variant-part, and ADR-0142 fixed the parameter walk that missed one route. A route still open: a module exporting `Box(n: integer) = record pad: array [1..n] of integer; case k: Sel of …` by *name*, undiscriminated, emits the dialect aliases and links into an Afterschool Pascal program, which AP §6.13.1 forbids. **No misbehaving program was built from it** — every way of giving the module something to write re-discriminates the schema and is caught, so it looks reachable only in combination with ADR-0142's defect, which is fixed. It was left alone because the fix belonged with a probe demonstrating the harm, and installing one on a forbidden-but-harmless link would have spent the meaning of the other seven combinations. **ADR-0232 dissolved it rather than fixing it**: `ComputeModePortable`, the alias and the mode in the linkage name are all deleted, every translation writes one tag, and there is no second language for a module to be wrongly called portable *to*. The rule it was an exception to survives as AP 6.13.1's NOTE 3, which is why this row is struck rather than removed | ADR-0137, ADR-0142, ADR-0232 |
| A guard placed **ahead** of a predicate can silence the predicate's own test | ADR-0143's first version put a slice arm before the `Assignable` call in the assignment check, to give better words than the general message. It masked the predicate at the only site that reaches it, so removing `Assignable`'s own slice refusal changed nothing observable and **all 623 cases stayed green over a restored out-of-bounds write**. The fix is structural — ask the predicate, then choose words inside the failure — and nothing checks that a new diagnostic arm has not done this again. It is invisible to every gate here by construction: the behaviour is identical, so no golden moves, no coverage changes, and only a mutation of the *masked* code can see it | ADR-0143 |
| The model-drift gate's **judgement** runs on CI only | it needs a push range, so no local run asks whether a CodeGen change carried its model — a `git push` is the first thing that does, and it reports after the fact rather than before. Its *base resolution* is checked locally (`model-drift-base`) because that half is a pure question about one repository and is the half that has broken; the judgement half is not, and `python3 tests/checks/model_drift.py origin/main HEAD` before a push is the manual substitute | ADR-0013 |
| `runtime/pasrt_unicode.c`'s **tables** are read only by the sweep that skips | This row stood for having *no* reader at all: no Pascal program could call the file, the functions being `pas_` and so refused as foreign names (ADR-0131), and it named its own closing condition — corpus programs reaching it once the language had a text-type. That happened four increments ago and the row was not re-read, which is the failure this register is audited against. What closes: every dialect text case now reaches validation, normal form and segmentation at both optimisation levels, and `lib_unicode.pas` reaches the case tables through `pasx_`. What is left is narrower and does not close. A corpus program exercises the code over the handful of code points it writes, and the **tables** — a megabyte of transcribed Unicode properties — are checked only by `unicode-conformance`, which **skips (77)** when the Unicode Character Database is absent, the database being fetched and never committed. So a fresh clone still runs the arithmetic and checks none of the data it walks. `UNICODE_CONFORMANCE_REQUIRE` is how CI refuses to pass by skipping, which is `TARGET_SIZES_REQUIRE`'s answer to the same shape; locally there is no such protection and the skip line is the only warning | ADR-0189, ADR-0190, ADR-0197 |
| One claim in the text model rests on a **reading**, not on Unicode's files | AP 6.4.15.9's iteration copies an element without renormalising it, and must — the arena is released once per *statement* (ADR-0111), so a loop that allocated per element would exhaust it. That is sound only if a grapheme cluster boundary is also a boundary of normal form, which is an argument from UAX #29's GB9 and GB9a rather than something `NormalizationTest.txt` or `GraphemeBreakTest.txt` states: Unicode publishes the two properties separately and nothing published relates them. Everywhere else in the text model the oracle is theirs (ADR-0190); here it is a **property test** — `tests/dialect/text_join.pas` walks a text, joins the elements back and requires the original, so a boundary that split a normalisation segment would produce pieces that renormalise on rejoining and the comparison would fail. That is the nearest thing to an oracle available, and it is one program over one string rather than a sweep | ADR-0189, ADR-0192 |
| One case needs a **working loopback interface**, and fails rather than skips | `tests/dialect/lib_net.pas` listens on `localhost`, connects to itself and reads what it wrote (ADR-0203). Every other environmental dependency here skips when what it needs is absent — `unicode-conformance` without the character database, `target-sizes` without a cross compiler, `llc-second-backend` without `llc`, `verify-lowering` without z3 — and each has a `*_REQUIRE` variable or a CI job so that skipping cannot pass for checking. This one does not: a machine that cannot connect to itself is a machine where the module does not work, so the case fails there and that is the intended answer. What is registered is that the suite now has an environmental precondition it does not state anywhere a reader will look before running it, and that a sandbox denying `AF_INET` sockets will report a defect in `PasNet` rather than in itself | ADR-0203, ADR-0190 |
| The **borrow that cannot escape** is unformable, not checked | ADR-0201 found that a `var` parameter naming what an owned pointer owns is a borrow whose lifetime is the call, and that it cannot outlive one because Pascal has no address-of and `new` is the only thing producing a pointer — so `kept := n` is a type error and that is the whole enforcement. Nothing in the compiler *knows* this. A future feature adding a way to form such a value — an address-of, a closure capturing by reference, a field of a reference type, a foreign routine keeping an address it was handed — would break the property in silence, and every gate here would stay green, because what is lost is a thing no program in the corpus can currently write. The property is worth more than a check for as long as it holds by construction, and this row is what says it is held that way rather than watched. **The row was one direction of a two-directional argument and said so nowhere**, which ADR-0317 found by probing: a borrow that cannot outlive the call is safe only while what it borrows outlives the call too, and AP 6.4.14.3 gives the callee three ways to end it — `dispose`, `new` and an assignment. That half is now a clause and two detected forms, and what is left of it is the row below. ADR-0318 adds the *other* borrow — a protected variable parameter, which may be read through and releases nothing — and that one is checked rather than unformable, so the two halves of this row are now enforced by different means and only the first is held by construction. ADR-0319 then closed the row below, so what remains here is the original property alone: the borrow cannot **escape**, and nothing checks that | ADR-0201, ADR-0151, ADR-0317, ADR-0318, ADR-0319 |
| ~~A release of an owned pointer reached through a **further activation** is not detected under a borrow~~ — closed by ADR-0319, and the reason is worth more than the row was | AP 6.4.14.7 requires an owned pointer not to be released while something it owns is bound elsewhere, and this processor detects the two forms one activation can be asked about: the actual-parameters of one call, and a with-statement's own binding. What it cannot see is `Bump(g^)` → `Clear` → `ClearIt(g)` → `dispose` — the callee reaching the owner as a non-local, or being handed it by something other than the activation-point that made the borrow. **No local rule can**, which is why the cheap refusal was shipped as a narrowing and said so: closing it needs either a per-routine summary of the non-local owned pointers it may release, closed over the call graph and carrying across a program-component boundary the module-heading has no room for (§6.13.2), or a borrow flag beside the variable and a trap at the three release points — the second is sound, complete and survives separate compilation, and is a lowering rather than a rule. Every oracle here was green over the defect this row is the residue of: `heap-balance` counts `new=1 dispose=1` and is right, ASan reports nothing, and the corpus case for the construct exercised every borrow shape but this one. Annex C.12 was the clause's own entry and is withdrawn. **The row was an artefact of where the question was asked.** Both mechanisms it named — a per-routine summary closed over the call graph, or a dynamic borrow flag — answer *may this release happen*, and both are expensive for the reason it gives. AP 6.4.14.9 asks instead *may this borrow be formed*, which is a question about **scope**: a borrow is refused where the activated block can name the owner, and a block can name a variable of the outermost block or one declared in a block containing it. That is available where the program is translated and across a component boundary in both directions, and it needs no summary, no flag and no word of storage. What it costs is that an owned structure held in a variable of the outermost block cannot be lent at all — measured over the corpus before it was written: twelve such borrows, every one in a test written for the construct, none in `lib/` or `examples/` (ADR-0319). **The lesson is the one the row did not know it was carrying**: a gap can be an artefact of the question, and two records costed mechanisms for the wrong one before anybody re-read the requirement | ADR-0317, ADR-0201, ADR-0181, ADR-0318, ADR-0319 |
| **Casing has no conformance file**, where the rest of the text model has two | ADR-0189 chose the grapheme model partly because Unicode publishes the answers: `NormalizationTest.txt` and `GraphemeBreakTest.txt` settle normal form and segmentation by a document written elsewhere, which is the one thing every other check here lacks (ADR-0190). Unicode publishes the *data* for case folding and case mapping and **no test over it**. So `PasUnicode.Fold`, `.Upper` and `.Lower` rest on a transcription and a fifteen-line table walk, and what checks them is `tests/dialect/lib_unicode.pas` pinning the cases a reader would think to check — the sharp s both ways, a digraph, the declined final sigma, an overflow, ill-formed input. That is a **sample** where the other two properties have a sweep of 20 034 and 766 cases. Nothing will close this: there is not going to be such a file, and declining casing until there is would leave the text model permanently one increment short for a reason that cannot change | ADR-0190, ADR-0196 |
| ~~A generic's diagnostic **names the generic and not the call that asked for it**~~ | **Closed** (ADR-0261). One more diagnostic is reported at the activation's own position -- `this activation is what asked for that instantiation of 'add'` -- in the ordinary `file:line:col: error:` format, so every reader of a diagnostic already parses it. One per *tuple* and not per activation, which is AP 6.7.3.10.2 working: a second activation naming the same types finds the instantiation in the cache and has nothing new to report. A generic activating a generic produces one line per level, innermost first, which is the backtrace this row said the machinery for did not exist -- and it did not need to: the recursion already knows which activation it is inside. The row became a demand rather than a grumble when ADR-0254 landed, an inferred activation naming no type at all | ADR-0211, ADR-0254, ADR-0261 |
| A generic instantiated by **two translations** is translated into both | AP 6.7.3.10 produces an instantiation in the translation that named the types (ADR-0212), so two programs importing one module and both calling `Swap(integer, …)` each emit a routine for it. Nothing links the two and nothing here notices: the linkage name is each translation's own counter, so they do not collide, and what it costs is duplication rather than a wrong answer. It is what C++ needs `inline` linkage and a COMDAT for. Registered rather than fixed because the fix is a naming scheme shared across translations -- a mangled name derived from the generic and the tuple -- and that is a decision about linkage, not an oversight | ADR-0212, ADR-0211 |
| A **generic body may call only what its clients can reach** | AP 6.7.3.10 translates an instantiation in the translation that named the types (ADR-0212), so for an imported module that is the *client*. A module's own routines are internal to its object file under a name that is that translation's own counter, so a generic body calling one emits a call the client cannot link -- an undefined symbol at link time, naming a counter (`p3`) that means nothing to a reader. Nothing in the compiler checks it: Sema resolves the call correctly, because the body *is* checked in the module's scope where the routine is visible. `lib/dialect/pascontainer.pas` met it twice and exports two helpers that no caller wants, which is the workaround and is commented as such. The fix is either to give such a routine external linkage automatically -- the module cannot know which of its routines a future client's instantiation will call, so that means all of them -- or to emit what an instantiation reaches into the client alongside it, which is what C++ needs `inline` linkage for. Both are decisions rather than oversights | ADR-0212, ADR-0211 |
| A **type-parameter category's name is a claim about an operator, and only the answers are checked** | AP 6.7.3.10.5 (ADR-0266) says `ordered` admits exactly what `<`, `<=`, `>` and `>=` accept and `equatable` exactly what `=` and `<>` accept, and `IsOrdered` and `IsEquatable` are second statements of the arms `CheckBinary` already has. `predicate-kinds` records what those two predicates answer about each of the 21 kinds and `kind-exhaustive` reads the comparison dispatch, but **nothing compares the two**: an operator arm widened without the predicate leaves a category that refuses a call the body would have compiled, and one narrowed without it leaves a category that accepts a call the body will then refuse — the second being exactly the failure the clause exists to remove. Both directions are silent, and what would close it is a probe that, for each kind, compiles the operator and asks the category, which is the shape `predicate-callers` has for `Assignable`. Not built: the two predicates are four lines and were written against the dispatch on the same afternoon, and a generator would have to know which kinds can be *constructed* by a program, which `NewType(k)` does not answer | ADR-0266, ADR-0146, ADR-0194 |
| ~~A **field selection** is answered by no dump, where a discriminant is~~ — closed by ADR-0247 | ADR-0246's `--dump-uses` reported every applied occurrence that resolves to a *symbol*, and a record field is a `fieldPtr`: `r.x` produced no line, while `v.cap` — a schema's discriminant, identical in the source — did. The asymmetry was visible in `tests/dumps/uses.dump` and explained nowhere in it. It cost **one integer**: §6.4.3.3 makes a record a region and gives every field-identifier a defining-point in it, and `fieldRec` was already recording `line` and `col` for a diagnostic (ADR-0045) — what was missing is which *file*, a record declared in an imported module having fields whose positions are that module's. §6.8.3.10's bare form answers the field too, not the with-statement that gave it a nearer defining-point. The row is struck rather than removed because the two rows beside it look alike and are not: each of those needs a fact nothing records, where this one needed a fact already recorded | ADR-0247, ADR-0246 |
| ~~An **interface** has a name and no position~~ — closed by ADR-0248 | `ifaceRec` held a name, an owner and its constituents, and never where the `export` clause was written, so §6.11.3's `M.x` hovered on `M` and jumped nowhere. An interface is found by *spelling* — `FindInterface` walks a list comparing the pool — so no question the compiler asks about one had ever needed a position. Three integers on that record, set at the one site §6.11.1 puts a defining-point. **The occurrence that mattered turned out not to be the qualifier**: `import Middle;` is where a module says where it gets things from and is the line a reader most wants to follow, and it was reported by nothing at all | ADR-0248, ADR-0246 |
| ~~A **defining** occurrence answers `null`, where an editor answers the declaration itself~~ — closed by ADR-0250 | ADR-0246's dump reported *applied* occurrences only, so a position on a `var` line or a procedure heading had no line over it. Every name a block declares is on the scope chain at that block's depth, so one walk after `CheckDeclarations` reports them all — after, because at `Declare` a variable has no type yet and the hover this is for would have shown `?`. **The half that is not a no-op** is §6.6.1's `forward` and §6.11.1's heading: the completing block is the same routine, so the name at the implementation resolves to the interface that promised it. The *interface's* own export-part followed in ADR-0251, along with a module's declarations — §6.11.1 puts them in a heading and §6.2.2.12 makes them the block's too, so the walk takes a boundary and each name is reported once | ADR-0251, ADR-0250, ADR-0246 |
| ~~A name inside a **schema's body** resolves in no file the dump can name~~ — closed by ADR-0249 | §6.4.7 keeps a schema's *syntax* and re-resolves the body once per distinct tuple, **where the type is written** — so `curFile` names the writer's file while the line and column being reported are the schema's, and for anything out of `lib/` those are two different files. ADR-0246 excluded productions for that and paid with `cap` in `array [1..cap]`, resolved nowhere else and so reported nowhere. What closed it is a fact that record created for another purpose: a schema is a symbol and a symbol carries `declFile`, so a production reports exactly when the schema is the document's own. The **negative** half is asserted rather than assumed — `tests/dumps/uses_module.pas` produces a schema declared in its component on every run, and the golden shows no line from that body, because a rule that silently reports nothing and one that correctly reports nothing look identical from outside | ADR-0249, ADR-0246 |
| **Nothing checks that a harness works only inside the directory it made** | The suite runs in parallel (ADR-0281) and what makes that safe is that each of the 31 harnesses here that writes anything calls `mktemp -d`, `mkdtemp` or `TemporaryDirectory`, and that a test wanting a port asks for one -- `Listen(srv, 'localhost', '0')`, and `tls.sh` scanning a range. A grep proves a private directory *exists*; it cannot prove nothing is written outside it, and `format_check.py` shipped in ADR-0279 writing a fixed path under the build tree with every gate green, which is what a proxy misses. The gate was declined rather than written badly: this tree does not keep checks that look like proofs and are not, which is ADR-0013's objection to a rule restating the lowering and the thing `clause-citations` answers by saying out loud that it asks the cheap half. What stands instead is exposure -- the property is now exercised by every local run as well as by every push, where before it was exercised only by CI | ADR-0281 |
| **Nothing says the formatter's output is *well* laid out** | `format-check` proves `--format` preserves a program and says nothing about whether the result reads well; `tests/dumps/format.pas` is the substitute and is a case someone wrote, so it holds the shapes someone thought of. ADR-0285 measured the gap by pointing the formatter at 36 real sources and found **five** layout defects that case did not hold -- a blank line inside a parenthesised list, a comment before an `else`, `^` as a prefix, a binary `!`, and the empty statement after a case-label. All five preserve the token stream, so every oracle here was green on all five. The five shapes are in the case now; the next five are not, and the only instrument that finds them is a reformat nobody wants to keep. **The `style:` gate that would keep it is a decision and not a task**, and it moved here on 2026-09-03 when `doc/roadmap.md`'s *What would make this easier to work on* was archived: a full reformat of `selfhost/`, `lib/` and `lsp/` rewrites 25 070 lines and grows the source 6.8%, and fixing the five real defects the attempt found moved that number *up*. Whether to adopt a house style belongs to whoever maintains this source; until it is adopted the diff is a disagreement about style and not a list of bugs | ADR-0279, ADR-0285 |
| **`benchmark` says nothing on CI, and nothing at all on aarch64** | It is the one gate here whose answer is a *duration*, and ADR-0282 made its two unstated preconditions explicit after the first push that carried it failed on two of four platforms: a stage share is not architecture-independent -- aarch64 put `share:parse` 36% off a baseline on a compiler that had not changed -- and the tolerances are margins over a spread measured on an *idle* machine, which a shared runner is not. It abstains for both, so no push is guarded by it and a stage made a third slower is caught only by whoever runs the suite locally. Closing it needs an idle aarch64 machine to calibrate on, which is not the shared runner that exposed the gap; a baseline taken there would commit the noise as the standard | ADR-0270, ADR-0282 |
| ~~**Nothing fails when this tree's own source acquires an unprotected read-only `var` parameter**~~ -- closed by ADR-0286, and **the reason this row gave for declining a gate was wrong** | The gap was real: a `.warn` sidecar makes a *test case* fail, `selfhost/`, `lib/` and `lsp/` have no sidecars, and every harness that compiles them reads the exit status rather than what the compiler said -- so the build printed the warning and succeeded. What was wrong is the second sentence, *it is a fixed point rather than a count, so a gate would have to iterate to convergence*: iterating is what **reaching** zero needed, and *holding* zero needs one sweep. `warning-free` makes the broader claim instead of ADR-0283's narrow one, and it is cheaper -- the compiler is quiet on success, so **every implementation source must compile with nothing on either stream**, which covers all four warnings and every message added after them without matching a wording. Removing one `protected` leaves 798 of 798 green. Its second claim, that every source named as deliberately broken still is, found `selfhost/badsema/components/exporter.pas` on the first run | ADR-0283, ADR-0286 |

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
- *And a second time, in the same file.* `seed-is-current` runs only at a
  release tag, so the fourteen lines of shell that were its whole check had
  nowhere to be exercised first — and they were written in bash, while a
  `run:` block in a container is `sh -e {0}`. The job died on a syntax error
  at the tag, having translated nothing (run 33178547669). The answer is
  ADR-0233's second commit and the same one as before: the check is
  `tests/checks/seed_current.sh`, run by hand at a release and by the job at
  the tag, so the text CI runs is the text a release ran. What is left is that
  a `run:` block still has no local exercise, and the way to keep one honest
  is to keep it to a line.
- *`-O0` was two cases wide.* The `unoptimised` CI job now runs the whole
  corpus at `-O0`, and `AFTERSCHOOL_PASCAL_OPT=-O0 ctest` does it locally. What
  is left of that gap is the first two rows above.
- *Four diagnostics counted but unenforced.* `tests/checks/unreachable_diagnostics.txt`
  is now a catalogue with an argument per entry, and the `diagnostic-coverage`
  case fails in both directions (§5).
- *Clause coverage had an untriaged denominator.* Every heading is classified
  testable, structural or not-implemented (`tests/spec/clauses/triage.tsv`), so
  the figure is counted against the **testable** clauses and not against the
  headings, and `spec-clause-traceability` gates it in both directions
  (ADR-0106). It was 14 of 207 testable rather than 14 of 292 headings when
  this was written and the file holds 467 rows now; no document pins the pair,
  because both move. What is left of that gap is the row above.
- *"§5 is an argument, not a number."* There is a number now —
  `procedure-coverage`, 554 of 556 when it was measured and 629 of 631 today —
  and the two rows above are what is left of
  that gap rather than the gap itself. Measuring it found the dumps: four
  documented flags whose thirty-one walker procedures were entered by no case
  at all, so nothing checked they did not crash (ADR-0103).

**A sixth shape, found on 2026-09-02 by ADR-0291: a constant the seed decides
rather than the source.** ADR-0126 recorded this for a fixed *buffer* — the
array that has to hold this source is the seed's, so raising the constant here
does not raise the one that matters — and it is not only true of buffers. It is
true of a constant that shapes a type the compiler **synthesises** and then
**uses on itself**. `BindingType` is the whole of that class today and cost an
out-of-cycle reseed: the compiler declares `b: BindingType` to read its own
arguments (ADR-0081), and that variable's layout was decided by whatever
compiled `compiler.pas` — the seed. `dateLen` and `timeLen` are *not* in it,
though they look alike: the compiler emits them into the program it compiles
and declares no `TimeStamp` of its own, so the value it uses is the one its own
source gave it.

Nothing checks it, and the failure is silent in the worst direction: the source
says 4096, every reader believes it, the suite is green, and the shipped
compiler behaves as though it still said 255 — while every program that
compiler *builds* gets the new number, which is what makes it look fixed. An
ordinary array bound written in the source does not have this property at all.
The two look identical in the source and differ in who evaluates them, so the
test to apply by hand, until something can apply it, is: **does this constant
shape a type this compiler synthesises and also declares a variable of?**

## 8. What this document is not

It is not a substitute for the skills that do the work. `code-review`,
`release-engineering`, `langspec-audit`, `docs-engineering`, `commit-and-push`,
`tracing-thoroughly`, `performance-profile` and `security-audit` each carry
their own procedure; this document says *when* to run them and *what must be
true afterwards*. `.claude/skills/change-lifecycle/` is this document in a form
an agent can follow.

It is also not a promise that following it makes the compiler correct. It makes
the compiler's *claims* checkable, which is the most a process can do.
