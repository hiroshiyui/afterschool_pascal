# Standard operating procedure

How a change gets into this compiler, and what has to be true before it does.

It exists because of one repeated failure: **the suite was green and the
compiler was wrong** — a `verify/` model describing a compiler that had been
replaced, a stack leak `-O2` optimised out of sight, 32 diagnostics no test had
named. The bar had been met, and the bar was the problem. So:

> **A green suite is not evidence. Evidence is a named case that fails without
> the change.**

Everything below is that sentence applied to a kind of work. The narrative of
how each rule was learned is in [`doc/history.md`](history.md) and the record
each cites; this document keeps the rule.

## 1. The oracles, and what each cannot see

Every gate exists because of a blind spot here, and a new gate is worth adding
only if it closes one. Counts are not quoted: each gate prints its own.

| Oracle | What it checks | What it is blind to |
| --- | --- | --- |
| **`ctest` goldens**, at `-O2` and again at `-O0` | that a named program still behaves as recorded | anything **no case names**. A golden agrees with whoever wrote it. Since ADR-0232 this is the front end's primary oracle |
| **`unicode-conformance`** | that the text model agrees with the Unicode Character Database | everything that is not Unicode. The only oracle here nobody in this project wrote |
| **`verify/`** (rule count in `README.md`) | that the lowering matches a property-style statement of the standard | **drift**: it proves the *model* against the *specification*, and a lowering changed without its model stays green |
| **`verify.py --crosscheck`** | the model against the real binary, at `-O0` and `-O2` | only the points its generated program exercises |
| **`selfhost/irtest.py`**, stage 2 = stage 3 | that the compiler is a fixed point under self-application | a bug **stable** under self-application; both stages come from one binary |
| **`llc-second-backend`** (skips without `llc`) | that the compiler binary is not miscompiled: built through `llc` at `-O0` and `-O2`, it must emit byte-identical IR | a miscompilation both configurations share. It is **not** a second reader of the IR — `llc` and `clang` share LLVM's parser |
| **`selfhost/producttest.py`** | that the artefact built is the one described | anything its checks do not ask |
| **`tests/spec/`** | what the compiler does about a **named clause**, in the standard's terms | a **misreading** — the scenario is written by the same reader. What it adds is that the reading is attached to its clause (ADR-0105) |
| **ADRs, `README`, `CLAUDE.md`** | the reasoning | a **misreading**. No oracle here can contradict a reading of the standard; ADR-0072's survived in four documents and a purpose-written test |

Retired: the BSI validation suite and `selfhost/difftest.sh`, both by ADR-0232
with the conformance modes they were about. The strongest oracle this project
had — two independent implementations compared over every source — is gone,
and there is no third-party corpus. Three consequences:

- **A test closes a blind spot only if it can fail.** Verify the failure first.
- **Regenerating a golden is a heavier decision than it was**, there being no
  second implementation to be caught by.
- **`langspec-audit` is the only instrument that can contradict a reading**,
  and it is invoked deliberately rather than by a standing trigger.

## 2. Classify the change

Pick the *most demanding* class that applies; a change is often two.

| Class | Examples | Gates (§3) |
| --- | --- | --- |
| **A — Lowering** | anything CodeGen emits differently: arithmetic, conversions, comparisons, storage | A1–A6 |
| **B — Language rule** | Sema accepts or refuses something new; a new diagnostic | B1–B5 |
| **C — Runtime** | `runtime/*.c`; formatting, file handling, checks | C1–C3 |
| **D — Harness / build** | `tests/run_test.py`, `CMakeLists.txt`, CI, `seed/` | D1–D3 |
| **E — Documentation** | ADRs, README, CLAUDE.md, comments | E1–E2 |

## 3. Gates

### A — Lowering

- **A1. `verify/lowering.py` changes in the same commit**, or the commit says
  why not, as a trailer: `Model-unchanged: <why>`. Enforced by the
  `model-drift` CI job over two regions, CodeGen **and the constant folder**,
  which decides the same clauses a second time (ADR-0077). The gate cannot
  judge which changes reach a modelled lowering; it requires the judgement to
  be written down. The CodeGen region runs to end of file, so driver work
  below the banner takes the trailer too — write it rather than narrow the
  region while a build is red (§7).
- **A2. If the change alters *which* values reach a check, extend
  `--crosscheck`.** The rule keeps proving; only the crosscheck compares model
  to binary.
- **A3. Read the IR once at `-O0`** (`tools/pascalcc -S f.pas -o /dev/stdout`)
  and run the corpus there before pushing:
  `AFTERSCHOOL_PASCAL_OPT=-O0 ctest --test-dir build -j"$(nproc)"`. `clang`
  refusing to assemble catches *malformed*, never *wrong*, and `-O2` hides a
  whole class of storage defect (ADR-0102).
- **A4. No `alloca` outside a prologue** (ADR-0102). Storage that must survive
  a loop iteration is a frame slot; storage that need not is an SSA value.
- **A5. A `KNOWN_GAP` that starts holding is reclassified in the same change.**
- **A6. Mutation-check** (§4).

### B — Language rule

- **B1. Cite the clause**, in the code comment and the commit message; a rule
  with no clause behind it is a preference. **Name the standard whenever the
  surrounding text does not** — the two disagree on 45 of the 91 numbers they
  share, Extended Pascal having inserted String-types at 6.4.3.3. The number
  is checked to *exist* by `clause-citations` (ADR-0164), never to be the right
  one: a citation is the one claim no oracle here can contradict, so check it
  against the standard and not against a green run. A wrong number written
  anywhere counts as a citation, so a document discussing one avoids spelling
  it or takes a catalogue entry.
- **B2. Ask whether the violation is an *error*.** §3.1 lets a processor leave
  an Annex D error undetected; a requirement not in Annex D falls under
  §5.1 e) and must be reported. "Shall" and "must reject" are different claims.
- **B3. Read the whole clause**, not the sentence that motivated the change.
  §6.7.3.3 has three closing sentences and this compiler implemented two for a
  release.
- **B4. Write the case before the change and watch it fail.** There is no
  second front end to catch a lexer, parser or Sema change; a golden
  regenerated afterwards proves nothing. **Every new diagnostic gets a
  case** — `selfhost/badparse/` (one file per message; the parser stops at its
  first) or `selfhost/badsema/` (shared files; Sema accumulates) — enforced by
  `diagnostic-coverage` (§5).
- **B5. Mutation-check** (§4).

### C — Runtime

- **C1. `PAS_FILE_SIZE` and `fileSize` must agree** if `struct pas_file` grew;
  the two files cannot include one another and `irtest.py` checks it.
- **C2. Nothing the compiler is responsible for moves into the runtime.** A
  width the program wrote is checked in emitted code.
- **C3. Mutation-check** (§4).

### D — Harness / build

- **D1. Show the harness change can fail.** A gate that does nothing is worse
  than none, because it reads as coverage: break the compiler, see the case
  fail, remove the harness change, see it pass. A gate that sweeps an empty
  list prints a number and passes, so **every sweep has a floor**, and a
  skip must never print like a pass — every gate that can skip has a
  `*_REQUIRE` variable and a CI job that sets it (`require-consistency`,
  ADR-0330).
- **D2. Re-run `cmake`.** Cases are registered by `file(GLOB)` at configure
  time; a green bar that never ran the new case is not a green bar.
- **D3. The seed is refreshed at release tags only**, with ADR-0095's one
  exception (capacity, not noise).

### E — Documentation

- **E1. ADRs are immutable once accepted.** A decision that stops being right
  gets a *new* record; the old one's **Status** gains a forward pointer, and
  so does the index row.
- **E2. A doc-only pass leaves `ctest` output identical.** A comment fix and a
  code change do not travel together — and a comment in `lsp/pasls.pas` keeps
  its line count, because `lsp-coverage` keys on the line.

## 4. The mutation rule

**Every fix comes with a mutation that a *named* test kills.** Apply the fix
and see green; reintroduce the defect by the smallest edit; rebuild, run, and
**name the test that fails** — if none does, the fix is untested whatever the
suite says; restore, rebuild, see green again.

- **Mutations are files** in `tests/mutation/mutants/`, run by
  `tests/mutation/run.py` (ADR-0207), committed with the fix. A claim in a
  record is about the tree on the day it was written; a file can be made
  again. The harness refuses a dirty tree and is not a `ctest` case, because it
  edits the source.
- **Restore with plain `cp` and `touch`, then *rebuild*.** `cp -p` leaves the
  mutated binary in the build tree; restoring and not rebuilding measures the
  mutant and looks less like a mistake.
- **One mutation per fix, and check *which* test fails.** One test covering
  two fixes hides the case where only one is right.
- **A mutation that breaks the build proves nothing.** It must yield a working
  compiler with the defect back in it.
- **Mutate a copy, never a tree something else is reading.** An ad-hoc
  mutation by hand in the checkout, while a sibling sweep ran, produced a
  compiler failure that took a day to rule out (ADR-0353).

## 4a. A feature with a surface needs a client, not a case

A defect is a point; a new type kind, parameter form or directive has a
**surface**, and every position a program can put it in is a place it can be
wrong. **Write a program that uses it in every position before believing any
gate** — assigned, compared, indexed, passed, returned, nested, iterated,
written. Most positions will be refused, and the refusals are the point. It has
paid four times with no gate finding any (ADR-0182, ADR-0191, ADR-0193);
`predicate_kinds.py --like OLD NEW` (ADR-0198) is a sharper prompt of the same
kind, and it must be told which kind the new one resembles.

**Order follows.** The library increment of a feature is its cheapest
enumerator, so it belongs inside the feature's work and not after. **Start at
the top rung** (ADR-0343): the first artefact of a feature with a surface is a
client program written the way a user would write it, against a compiler that
does not accept it yet — every diagnostic it produces is a design question with
the answer attached. Traits produced four records before a working compiler
because each rung — reading, probing, building, separate translation — was
climbed one record at a time.

## 4b. A hypothesis is not a record

- **Ask the compiler; do not predict it.** A record's Context may reason from
  a clause; a claim about *this processor* carries a probe or is not written.
- **One feature, one record.** ADR-0001's immutability stands, and it is what
  makes a falsified hypothesis expensive. Work a design out in a note that is
  freely rewritten; write **one** record when the feature builds, carrying the
  alternatives genuinely rejected. Records per landed feature is the metric;
  one is the process working.
- **Ask every axis at design time**, because they recur — separate translation
  was the question none of three traits records asked (ADR-0341), and no job
  ran `-O0` crossed with a 32-bit target (ADR-0334). Walking the seven costs
  an hour:

| Axis | The question to ask of the feature |
| --- | --- |
| Component | inside one program, and across §6.13's separate translations? |
| Declaration site | a program-block, a module-block, a module-heading, a procedure? |
| Optimisation | `-O2` and `-O0` — a storage defect is invisible at the first (ADR-0102) |
| Word size | LP64 and ILP32 (`target-layout`, `target32`, ADR-0325) |
| Threads | one thread of control, and two (ADR-0268) |
| Parameter form | by value, by `var`, `protected var`, schematic, procedural |
| Spelling | a word-symbol, a required identifier, or a category? |

## 5. Counting, not assuming

Coverage is measured at some granularities and argued at the rest, and the
argument has to be concrete.

- **Name the case that reaches each new branch.** `tests/foo.pas:12 takes the
  else` is a claim; "covered by the suite" is not.
- **Count the corpus.** A `grep -c` has been wrong more often than right here.
  `grep` on this machine is `ugrep`, whose `--include` does not filter; pass an
  explicit file list.
- **A catalogue fails in both directions** (`verify/`'s `KNOWN_GAP` rule,
  ADR-0013): a message with no golden fails, and a message listed as
  unreachable that acquires one also fails. An entry is an argument, not an
  exemption — "I could not write the program" is not it; "no program can be
  written" is. `diagnostic-coverage`, `procedure-coverage`, `heap-balance` and
  the rest of `CLAUDE.md`'s table are this rule applied to a dozen catalogues.
- **A ratchet is weaker than a catalogue** and is what a count too large for
  a per-line argument gets: `line-coverage`, `branch` and the three
  ratchets after them fail when the count rises and cannot see a line that
  stops being reached for a bad reason. The per-procedure or per-module
  breakdown is what makes a regression nameable; regenerating one is a decision
  argued in the commit message. Where a number is a property of the machine's
  load rather than the program, it is printed and not gated (ADR-0354).
- **Know the denominator.** Procedure coverage counts a procedure entered once
  as covered; statement coverage counts what a human wrote and reads the
  denominator out of the same `.ll`, so there is no second notion of
  executable to drift. Both see the corpus by glob and not the harnesses that
  build their own compiler.
- **A gate that reports a count is checkable; one that reports a property is
  not.** Twice a gate's subject was silently empty and it passed by asking
  nothing. Make a harness say *why* it skipped, and give it a floor.
- **When a document quotes a number a gate reports, run the gate.** Every
  audit here has found a quoted count wrong, in both directions.

## 6. Cadence

| When | Do |
| --- | --- |
| Every change | §3 gates, §4 mutation, `commit-and-push` |
| Before pushing a CodeGen change | the `-O0` sweep (A3), so the `unoptimised` job is not the first to know |
| A batch of conformance work, or before a release | `code-review`; re-run the §5 sweeps |
| After conformance work whose clauses admit more than one reading | `langspec-audit` — independent readers given the behaviour and **not** the reasoning |
| Before a release | `release-engineering`: from-scratch build, seed refresh at the release commit, version agreement, breaking changes called out |
| A bug resists the first few probes | `tracing-thoroughly`, **before** attempting a fix |
| Performance work is proposed | `performance-profile`; performance is subordinate to correctness here |
| Periodically, and after runtime or file-handling work | `security-audit` |
| When a feature lands | `docs-engineering`: the `feat:` commit, then a `docs:` commit moving it out of README's "not accepted yet" and nothing else |
| After a milestone, and on a clock | read §7 end to end and date it |

**Commission `langspec-audit`** when a check broke programs in this tree and
the programs were edited — the correct response when the corpus was wrong, and
exactly what defending a misreading looks like. **Never claim completeness
without a probe**: three documents asserted ISO 7185 complete while `pack`,
`unpack` and `page` sat behind a name check.

## 7. Blind-spot register

Live, and part of the SOP rather than an appendix: what is currently known not
to be checked. Add a row when a gate is declined, in the same commit; strike
one when it closes, and move the struck row to
[`doc/history.md`](history.md#the-blind-spot-register-the-audits-and-what-closed),
where every closed row and every audit's findings are kept verbatim.

**Read it end to end after a milestone and on a clock, and date it here.**
Three shapes of decay, each found more than once: a row dating itself from a
record whose feature has since shipped; a row **naming its own closing
condition**, which the person meeting it is working on a feature and will not
re-read; and a **count quoted from a gate**, checked only by running the gate.
Two more: a record that reached no document outside itself, found by reading
the record and asking where else it belongs; and a gate that prints a claim it
never evaluated. Audits so far, each written up in history: 2026-08-25
(ADR-0197, four stale of 57), 2026-08-28 twice (six stale of 67; a row missing),
2026-08-29 (five kinds of decay, two outside this file), 2026-09-01 (the
numbers, and three records no document knew of), 2026-09-06 (a closing
condition met by a release), 2026-09-07 (a premise falsified by a new target),
2026-09-08 (`langspec-audit` over the concurrency clauses: seven defects, four
readings left unsettled, ADR-0365), 2026-09-08 (the first macOS run: nine
failures, and **five of them were this tree assuming Linux in a place nothing
had ever asked about** — three `mapfile` uses, a GNU-only regex alternation, a
Linux-only path in three test programs, an `errno` a `strerror` call may
clobber, and a socket that refuses a write after a number of tries the kernel
picks).

**Verified on each audit rather than assumed**: the string-arena producer
count — **eight** `strTemps := strTemps + 1` in `selfhost/compiler.pas` — and
the `-O1`/`-O3` row, still a judgement.

| Blind spot | Consequence | Recorded |
| --- | --- | --- |
| **The front end has no second implementation** | `difftest` compared two front ends over every source and retired with the conformance surface it was frozen at. The front end is guarded by goldens that agree with whoever wrote them, plus `tests/spec/`. **The largest blind spot here**, and nothing closes it: a second implementation of a language with no external specification is two readings by one author | ADR-0108, ADR-0232 |
| **No third-party corpus** | BSI's 812 programs cannot be compiled — 25 use a word-symbol §6.1.2 reserves. `unicode-conformance` covers one clause; `fpc-differential` is a second *processor*, not a corpus, reaches nothing in `tests/dialect/`, and shrinks every release | ADR-0086, ADR-0232, ADR-0234 |
| **Nothing checks that a decision reached the specification or the register** | The roadmap is a queue, the spec says what the language is, `implementation-defined.md` what the processor decides; nothing asks whether a closed row can be looked up by somebody who never read the roadmap. Silence has no denominator. The roadmap's *How this page is written* says which document takes what, and a reader is the enforcement | — |
| **Nothing sweeps this tree for a command built out of a value** | ADR-0362 closed the one that existed by reading the program; `command-injection` holds that program against that shape and cannot see a second caller of `Run` written tomorrow with a value in the string. Where a string came from is a question no oracle here can follow; the module says the rule at the routine | ADR-0362 |
| **`lib-coverage` cannot measure a case that takes a program-parameter** | It runs every case with no arguments, so `lib_fs.pas` stops at its first statement under the sweep. `lib_fs_tempdir.pas` is the parameterless workaround; the fix is the sweep reading `run_test.py`'s argument convention | ADR-0350, ADR-0363 |
| **`<>` on reals is not the negation of `=`, and nothing decides whether it should be** | `opNe` emits `fcmp one`, so for a NaN both `x = x` and `x <> x` are false; neither standard contemplates the value. It cost `PasJson` a trap. Changing to `fcmp une` is a class A change needing a `verify/` rule; `tests/dialect/lib_json_nan.pas` pins both answers until it is decided | ADR-0359 |
| **Nothing enumerates the sidecar conventions**, and their readers drift apart | Twelve sidecars are read by seven readers and no list says which honours which; `.importpath` was unread by the language server until a program using it was opened. Every oracle agreed, each reader being right about the sidecars it reads | ADR-0311 |
| **Nothing checks that a quick fix compiles** | The server's two edits rest on a reading of the clause and one application by hand; a gate would apply an edit and recompile, and no such harness exists. Both edits are decidable from what the compiler *reported* | ADR-0300 |
| A subrange whose bounds are not constants is refused as a **set's base type** | Legal under §6.2.3.8 b); every set is a 256-bit word whose base must lie in 0..255, and a bound the block evaluates cannot be checked against that before the program runs. The limit `set of integer` already states, reached another way | ADR-0028, ADR-0133, ADR-0134 |
| `-O0` and `-O2` are each run, never **compared** | A case where the two differ and both look plausible passes twice; only `--crosscheck` compares them, over its own program. `irtest.py` links at `-O0` unconditionally, which is how ADR-0220 was found, and must not be leaned on | §6, ADR-0220 |
| `-O1` and `-O3` are unexercised | Judged not worth a third and fourth sweep | — |
| Nothing links a component on its own **except the compiler's own build** | Every test harness compiles a program, so a valid-but-incomplete module fails in the linker, in another command, about a name no source spells (ADR-0212). The three-component build, `pascalcc` translating what the compiler resolved, and `stale-component` narrowed it; what is left is a combination the compiler's own structure does not use — a module exporting a schema, a generic across a boundary, a `to end do` | ADR-0212, ADR-0233, ADR-0244, ADR-0245 |
| A **permission withheld** too widely is looked for by nothing | Every gate watches a claim that is *made*; a conforming program the compiler refuses is in no corpus and names no golden. `take(mk)` was refused for as long as it could be written, found by hand. `predicate-callers` looks the other way. The same crack runs the other way (ADR-0180): a rule enforced at a site one spelling never reaches | ADR-0146, ADR-0179, ADR-0180 |
| A **release the runtime cannot be asked to make** is watched by nothing | AP 6.4.14.3 releases an owned pointer's storage on a `goto` or `halt` out of a block and only the epilogue does it. `heap-balance` counts at *exit*, so abandoned storage is indistinguishable there from storage kept on purpose; it counts no files or handles | ADR-0181, ADR-0183 |
| **§5.1 g) 2) permits more than this project takes** | Trapping every ISO error is a **policy** under §3.2 NOTE 2, not a requirement; a processor leaving §6.5.6's empty substring undetected and saying so would comply. No document may say a relaxation *had* to be made this way | ADR-0014, ADR-0219, ADR-0224 |
| A multi-element character-string is typed as ISO 7185 types it | §6.1.9 makes `'hello'` a canonical-string-type value; this compiler gives it `packed array [1..5] of char`. Four probes land on identical behaviour, so it is a labelling divergence a feature able to observe a type's identity would turn into a defect | ADR-0224 |
| §6.7.3.2 and §6.4.3.3.3 contradict each other for `p('')` | The schematic formal accepts with capacity 0, the value-conformant one refuses; both are readings of a hole, so **no scenario may assert either** | ADR-0224 |
| A compiler slowed **uniformly** is invisible to `benchmark` | It commits proportions, so a change slowing every stage alike moves nothing; the milliseconds are recorded beside the machine and read by a person. It cannot see a stage made a fifth slower either; the threshold is about a third | ADR-0270 |
| An `unreachable_diagnostics.txt` entry that names **nothing** is ignored | An entry matching no message is in neither set the gate computes, so an entry left by a deleted diagnostic is silently accepted. One line to fix and not built | ADR-0273 |
| A **wrong-arm read** is seen only where a corpus source reaches it | `variant-check` is dynamic, so a read on a path no source takes is invisible; `ast-fields` asks a different static question. Neither reaches a field read through a second variable | ADR-0222, ADR-0223 |
| A dispatch that is neither a case-statement nor a **tag chain** | `kind-exhaustive` reads both; a table, a lookup or a chain of predicate calls is outside it. `Assignable`'s thirteen arms are watched by `predicate-callers` from the other direction | ADR-0221, ADR-0146 |
| **Sema is quadratic in declarations per block** | `Declare` scans the scope linearly: 32 000 names in 14 s. Bounded by `tokMax` at roughly 80 s and then a diagnostic; the fix is a second structure beside the scope stack and deserves its own measurement | ADR-0275 |
| **Nothing says the formatter's output is *well* laid out** | `format-check`'s three claims are about preservation and hold of a one-line program. `tests/dumps/format.pas` is the only assertion of a style; pointing the formatter at 36 real sources found five defects it did not hold, and the next five are found only by a reformat nobody wants to keep. Whether to adopt a house style is a decision for whoever maintains the source | ADR-0279, ADR-0285 |
| **Nothing checks that the printer knows every block-structured statement** | The printer is token-driven and a dialect statement is spelled with no word-symbol, so `select`'s `end` gave back a level nothing had taken and every following line drifted left — with all three preservation claims holding. An emptiness check would not catch it. Declined; a new block-structured statement is taught to the printer in the same change, and a reformat is read | ADR-0279, ADR-0285, ADR-0313 |
| **`--coverage` under `spawn` is a data race** | Neither counter table is `_Thread_local`, and the fix is a lock or an atomic, not a per-task table nothing merges. Nothing measures a concurrent program today | ADR-0104, ADR-0268, ADR-0274 |
| Clause **citation is presence, not depth** | A clause with one scenario counts as cited, though §6.8.3.9 alone has six requirements | ADR-0106 |
| The coverage gates are **ratchets**, and two of the five hold a number no ratchet can | `line`/`branch` ratchet one way by choice; `lib` and `lsp` fail both ways, being deterministic; `runtime`'s two units holding a wait with a deadline print and are not compared, three lines running only when a deadline beats a receive | ADR-0104, ADR-0274, ADR-0350 – ADR-0354 |
| **Two library modules are exercised by one harness and no case** | `PasTls` and `PasHttps` are reached by `tls.py` alone, so `lib-coverage` reports them zero and says why; driving `tls.py` from it would make the number move with a machine's packages | ADR-0264, ADR-0350 |
| **The runtime's error paths are a third of one file and no oracle can arrange them** | `pasrt_posix.c` is the low row of `runtime-coverage`: a failed bind, a directory vanishing mid-walk. What is missing is **fault injection**, and those lines are ones ASan, UBSan, LSan and TSan have looked at zero times | ADR-0261, ADR-0342, ADR-0351 |
| **`tools/pascalcc` has no coverage instrument, and neither has `apconfig`** | The driver is shell; `apconfig` is Pascal but a program no case runs, so its ten keys are asserted by `new_project.sh` and counted by nothing | ADR-0348, ADR-0350, ADR-0361 |
| `coverage.py` sees the sources, not the harnesses that build their own compiler | What `irtest.py`, `producttest.py` and `verify.py` drive is invisible; the *flags* half is closed by sweeping `--dump-all` and `--coverage` over every source | ADR-0103 |
| Errors listed in `doc/implementation-defined.md` §3 | deliberately unreported, under §5.1 f) 1) | ADR-0073 |
| §6.4.3.3's region is not asked of a **constant** occurrence | `array [1..fred]` beside a field `fred` reads the constant; constant occurrences reach the expression checker, not type-denoter resolution | ADR-0112 |
| A **tagless** variant part is outside the variant check | §6.4.3.3 permits `case Kind of` with no tag field; there is nothing to compare against, and synthesising a tag is a layout change. `variant-check` cannot see one either — this is the row to widen when a second tagless record appears | ADR-0118, ADR-0223 |
| **The clause inventory cannot tell it was given the wrong document** | `tests/spec/clauses/extract.py` has a 50-heading floor and nothing else: fed the Free Pascal reference as `iso10206.pdf` it extracts 190 "clauses", writes the inventory and exits 0. Every citation gate then checks against a bogus authority | ADR-0164, ADR-0366 |
| **`runtime-isoc`'s fifth pass reaches a compiler nobody chose** | Four of its five strict compiles honour `APASCAL_CLANG`; the fifth spells `clang` literally, so on a machine where the two differ that pass answers about another compiler | ADR-0161, ADR-0366 |
| **`tls` reported its findings to nowhere for its whole life** | `exec 3<>/dev/tcp/… 2>/dev/null` makes the redirection permanent for the shell, so from the first successful port probe — every ordinary run — fd 2 was `/dev/null` and every later diagnostic was swallowed; the gate failed correctly and printed nothing to read. Closed by ADR-0366's conversion, which has no such construct; recorded because **nothing here detects a harness whose diagnostics go nowhere** | ADR-0264, ADR-0366 |
| **`irtest` compiles the corpus at one level regardless of a case's `.opt`** | `run_test.py` reads the sidecar and `irtest.py` does not, so `tests/for_nested_stack.pas` — which pins `-O0` because the defect is invisible at `-O2` — is built at the default by the harness that checks the fixed point | ADR-0102, ADR-0335, ADR-0366 |
| **A documented option can lose its own entry and still pass** | `producttest`'s driver-help check requires the flag to occur as a token somewhere in the text, so deleting `-c`'s own line leaves it documented by the prose of another line. It narrows the class the substring test missed rather than closing it; what it cannot ask is whether an option has an *entry* | ADR-0348, ADR-0366 |
| **A utility named by a variable is invisible to `helper-portability`** | It reads source: `run(prog, ...)` where `prog` was computed, and `shutil.which('sed')`, are not seen. `kind-exhaustive` and `foreign-reserved` answered the same limit by asking the compiler instead, and there is no equivalent for a Python helper | ADR-0367 |
| The diverse-double-compiling window **closed without anything noticing** | `seed/ddc.py` answered the seed's provenance once; `v0.1.0` cannot read three program-components, so there is no longer a way to check it from outside | ADR-0085, ADR-0233 |
| The **string pool's** headroom is measured, and one way into it is still silent | `PoolPut` drops a character when the pool is full rather than reporting, so a name Sema builds could come out short and collide. Reachable only within a name's length of full, which the 80% gate reports long before | ADR-0126, ADR-0148 |
| A gate that holds **both halves** of its comparison cannot fail | `foreign-reserved` closed its instance by compiling a probe; ten checks still read the compiler's source as text, the weaker oracle every time. `buffer_headroom.py` is the pattern to copy — capacity from the source *and* from the compiler | ADR-0144, ADR-0229, ADR-0230 |
| Nothing checks an external-declaration's **name** against another component's | Two modules may each declare `external 'strerror'` and 6.13 is working; that they *mean* the same routine is the row below | ADR-0147 |
| Nothing checks that every string-arena producer is **counted** | The end-of-statement release is driven by a counter its producers bump; a ninth producer would have nothing looking for it, and a bump removed from a producer sharing its statement with another is invisible, which is why the pinning loops compare rather than assign | ADR-0111, ADR-0197 |
| Nothing checks an `external` declaration against the function it names | The call site is the whole of the ABI: LLVM does not check a direct call against the declaration under opaque pointers, so a wrong arity, type or function is undefined behaviour with no diagnostic. **One property is held** (ADR-0364): a scalar's *width*, every `int64` in an `external` catalogued as a C type that is 64 bits everywhere — a claim a person wrote, not a header read | ADR-0121, ADR-0129, ADR-0364 |
| **Four readings of the concurrency clauses are unsettled** | A `goto` out of a task's block compiles and hangs with no diagnostic; a `send` arm on a closed channel raises its error only when the select's rotation reaches that arm, where an *empty* channel-variable is an error every time; `after` refuses an `int64`; a trailing `;` before a select's `end` is accepted. Each admits two readings, so none takes a scenario | ADR-0365 |
| **`--target=` admits no Darwin triple** | A program still builds on macOS, clang overriding the module's header as it does for the aarch64 job — but nothing there may *believe* the header, so `llc-second-backend` and any `--dump-layout` claim are about a machine the module does not name | ADR-0156, ADR-0325 |
| A task's ban on non-local variables is **not transitive** | AP 6.7.8.2 refuses a non-local in a task's own block; a task may call a procedure declared outside it that names a global. Closing it needs the call graph across component boundaries, which is why the clause states the limit | ADR-0201, ADR-0268 |
| **A `verify/` precondition stricter than the compiler's own check passes in silence** | Narrowing a hypothesis only makes a proof easier; `index_span_is_representable` said `<` where Sema said `>=`, both agreed, and `array [0..maxint]` was refused for eleven increments. A precondition must carry the sentence it restates so the two can be compared by eye | ADR-0013, ADR-0289 |
| **Nothing detects a harness that ignores a path, target or flag it is handed** | Three in a week: `sanitize.py` and `AFTERSCHOOL_PASCAL_OPT`, `llc_check.py` and the target, `seed_current.py` and an absolute path. `require-consistency` does this for `*_REQUIRE`; the same for `AFTERSCHOOL_PASCAL_*` needs a judgement about which harness should read which | ADR-0330, ADR-0335, ADR-0345, ADR-0347 |
| **Every gate but `target32` and the sanitizer modes runs at one optimisation level** | `labs` bound as `int64` passed `target32` at `-O2` for two weeks and answered garbage at `-O0`; the cell where two axes crossed was empty. The rest was measured: the gates that skip in the `unoptimised` job ask questions no optimiser can change | ADR-0334, ADR-0335 |
| **The bracket list is by hand** | Which runtime routines can trap — 72 of 127 — was read off the call graph once; a routine that starts trapping reports no position. The safe direction, and visible in the first golden to reach it; a gate over the call graph was declined | ADR-0293 |
| A **value transcribed from a C header** is checked for one library and no other | `tls.py` checks the six OpenSSL numbers; nothing derives the list, and `PasProcess.ClocksPerSec` carries the same hazard with no gate. An annotation the compiler could report, as `@cstruct` is, was not built | ADR-0185, ADR-0264 |
| Nothing checks that a foreign record's fields are the struct's fields | `foreign-layout` closes the half a C compiler on this machine can judge; `@cplatform` reports not-checked elsewhere. A record naming a *prefix* of a struct (ADR-0187) cannot be a claim a C compiler confirms, so its annotation stays optional | ADR-0184, ADR-0185, ADR-0187 |
| Nothing checks that a new **statement-sequence holder** runs what it armed | `EndSequence` is called from the three constructs §6.9.3 gives a sequence to and nothing derives that list; a fourth would run its deferred statements *late*, through the activation's runner, silently | ADR-0175 |
| Nothing holds the compiler's **dump format** and its readers together | A field added mid-line is a change the server cannot see; ADR-0253 moved the name from field 7 to 9 and one of two readers stayed on 7. A field 10 tomorrow is a golden that agrees with whoever regenerated it | ADR-0239, ADR-0246, ADR-0253 |
| **Fuzzing is a fixed corpus, and not a sanitized one** | The seed is fixed on purpose; `--long N` is the search. Hostile input into a *memory-checked* compiler, and hostile numbers into the runtime's reader (ADR-0076), were run by hand once and are repeated by nothing | ADR-0076, ADR-0261, ADR-0275 |
| The clause inventory is **generated**, and has no oracle of its own | Inventory and triage are checked against each other; a clause the extractor dropped and nobody triaged leaves both files agreeing and wrong. Only a reader holding the standard can see that | ADR-0105, ADR-0152 |
| A dialect scenario cannot reach **6.13.1, 6.13.2 or 6.11** | All three are rules about linking components and `run.py` compiles one program; they stay in `pending.txt` and are held by `stale-component` and `tests/dialect/`. `tests/spec/run.py --coverage` prints the pair rather than this row | ADR-0135, ADR-0144, ADR-0245 |
| Nothing checks that a **listening** socket is what `PasNet.Wait` reports | The one case has one listener, in slot 1, every time; a server listening on two services is the test and none exists | ADR-0205 |
| Nothing stages **two processes racing for `TemporaryPath`** | Its exclusivity is pinned inside one process; two programs started in the same second are argued and not staged. `TemporaryDirectory` is `mkdtemp` and outside this row | ADR-0243, ADR-0363 |
| The mutation catalogue is a register, not a measurement | The files are specific claims; a hundred-odd records carry mutations in prose that nothing compares. `kills:` names one test, so a mutant caught by a different test is unnoticed, and it rots — six of 48 were `NOT-APPLIED` after ADR-0232. Run it after a change to anything a mutant names | ADR-0207, ADR-0232 |
| An `int64` result is the door AP 6.7.7.9 c) says is shut | An address fits in an `int64`, so `opendir` bound with one compiles, copies, adds 8 and double-frees. Unfixable without a type that tells a count from an address; `foreign_int64_handle.pas` is kept as a gap failing both ways | ADR-0128, ADR-0151 |
| A constant's storage may be filled **twice** and no test can see it | The alias guard cannot be mutated into a failing test: the second fill writes the same value, and nothing compares emitted IR | ADR-0069, ADR-0170 |
| `model-drift` is scoped to a **range**, so a sibling commit can satisfy it | Right for a push, wrong for a commit; a bisector finds an unexplained CodeGen change. A per-commit gate would train people to write trailers without reading them | ADR-0013, ADR-0167 |
| `model-drift`'s **judgement** runs on CI only, over committed work | `python3 tests/checks/model_drift.py origin/main HEAD` before a push is the substitute; `model-drift-base` holds the half that has broken | ADR-0013, ADR-0153 |
| **`model-drift`'s CodeGen region runs to end of file** | Driver work below the banner trips it, four times so far, and a comment counts. The region is wide on purpose; write the trailer whenever a commit touches `compiler.pas` below the banner, and do not narrow a safety gate while a build is red | ADR-0013, ADR-0166 |
| A citation may name a **real clause of the wrong standard** | 825 citations name one of the 45 ambiguous numbers; a ratchet would be a standing cost for a claim it could not verify. B1's convention is the answer and nothing enforces it | ADR-0163, ADR-0164 |
| Whether **HT, VT and FF are separators** is unsettled | §6.1.8 names neither; no reader found a settling sentence and no program breaks either way, so it gets no scenario | ADR-0162 |
| **`bindable` in a variant-denoter is caught only on the arm** | §6.4.3.4's third limb reaches through a component for both forbidden words and this compiler applies it to `restricted` only; a bindable non-file field decides 6.9.3.9.1 and nothing else since ADR-0299 | ADR-0163, ADR-0299 |
| Most triage reasons are still a **title** | 51 `structural` rows share one sentence and some 340 `testable` rows carry the clause's title, so a checked row and a filled-in row look alike. Both directions were swept once; a `shall` about something a program cannot exercise is visible only to a reader | ADR-0106, ADR-0200, ADR-0204 |
| The layout comparison covers **frames and nothing else** | A global's alignment, a string constant's and the ABI arguments travel by are outside `target-layout` | ADR-0028, ADR-0157 |
| Text-mode translation and other **C library semantics** are unasked | `runtime-isoc` bounds what a port must supply, not what a call *means* elsewhere; a second C library would be the oracle | ADR-0161 |
| §6.6.3.8's bounds error is not detected where **both** ends are dynamic | A conformant actual handed to a conformant formal gets no run-time comparison; an error in §3.1's sense, documented in `implementation-defined.md` §3. One comparison per bound at the call site, not done because no test could fail without it before the feature existed | ADR-0153, ADR-0014 |
| Nothing checks that a foreign routine does not keep an address it was handed | A callee that stores a pointer is a promise, not a lifetime; the record claims the near side is sound | ADR-0122 |
| An optional's check is not elided by a guard that has already made it | `if o <> nil then o^` emits the check anyway; narrowing is flow analysis and a binding form, and neither is built. The trap is *local* to `^`, not unreachable | ADR-0123 |
| The predicate sweep does not prove a probe **reaches** its call site | `predicate-callers` claims no program in its table is accepted, not that every call site was exercised; several probes are refused by a rule that fires first | ADR-0146 |
| A guard may ask a predicate whose answer is **right** | Between `predicate-kinds` and `predicate-callers` is a guard asking the wrong *question* — `IsStringType` where "takes the string path" was meant, all three text-model defects. `--like` narrows it and judges nothing; a guard testing a flag is outside all three | ADR-0194, ADR-0198 |
| An **optional of a pointer** has two absent values | `?^T` is admitted and `nil` then means two things; argued rather than legislated, and the hazard is a miscounted `^` | ADR-0123, ADR-0149 |
| Nothing checks `lib/dialect/`'s reporting convention | Four result shapes are a convention; a module spelling its tag `success` compiles and passes. A linter over a module interface is a tool this tree lacks | ADR-0141 |
| A foreign string of unstated length has no safe reception | `PasEnv.Lookup` binds `getenv`, and a value longer than the receiving capacity stops the program; a PATH over 4096 is ordinary. `pasx_dir_next` shows the fix — the runtime measures on the far side and answers `errFull` — and it has not been written for `Lookup` | ADR-0141, ADR-0188 |
| A guard placed **ahead** of a predicate can silence the predicate's own test | A diagnostic arm before the `Assignable` call masked it at its only site, and 623 cases stayed green over a restored out-of-bounds write. Ask the predicate, then choose words inside the failure; nothing checks that a new arm has not done this again | ADR-0143 |
| `runtime/pasrt_unicode.c`'s **tables** are read only by the sweep that skips | A corpus program walks the code over a few code points; the megabyte of transcribed properties is checked only by `unicode-conformance`, which skips without the database. `UNICODE_CONFORMANCE_REQUIRE` is CI's protection and there is none locally | ADR-0189, ADR-0190 |
| One claim in the text model rests on a **reading** | AP 6.4.15.9's iteration copies an element without renormalising, sound only if a grapheme boundary is a normalisation boundary — an argument from UAX #29, not a published file. `text_join.pas` is the property test, one program over one string | ADR-0189, ADR-0192 |
| One case needs a **working loopback interface**, and fails rather than skips | `lib_net.pas` connects to itself; a machine that cannot is one where the module does not work, which is the intended answer, but the precondition is stated nowhere a reader looks first | ADR-0203 |
| The **borrow that cannot escape** is unformable, not checked | Pascal has no address-of and `new` is the only pointer producer, so the property holds by construction and nothing in the compiler knows it; a feature adding a way to form such a value takes it silently. The other direction — the owner outliving the call — is a clause and two detected forms since ADR-0317 | ADR-0201, ADR-0317, ADR-0318 |
| **Four of AP 6.4.14.7's borrow residues stand** | A release reached through a second name — a helper disposing the owner under `with`, two names one activation down, a function actual, a non-local callee — compiles, writes to freed storage and exits 0. The class ADR-0319 costed and declined; NOTE 6 no longer claims otherwise | ADR-0319, ADR-0342 |
| **Two readings of the memory model are unsettled** | Whether AP 6.4.14.7 a)'s actual must be the *same* entire-variable rests on a NOTE; AP 6.4.17.2 forbids a task as a result while adopting 6.4.12's factory. Both UNSETTLED, so neither takes a scenario | ADR-0342 |
| **Casing has no conformance file** | Unicode publishes data for folding and mapping and no test over it, so `Fold`, `Upper` and `Lower` rest on a sample where normal form and segmentation have sweeps. Nothing will close it | ADR-0190, ADR-0196 |
| A generic instantiated by **two translations** is translated into both | Each emits its own routine under its own counter; duplication, not a wrong answer. The fix is a mangled name shared across translations, a linkage decision | ADR-0211, ADR-0212 |
| A **generic body may call only what its clients can reach** | A module's internal routine called from a generic body is an undefined symbol in the client, naming a counter. `PasContainer` exports two helpers no caller wants as the workaround; the fix is external linkage for all or emitting what an instantiation reaches | ADR-0211, ADR-0212 |
| A **type-parameter category's name is a claim about an operator**, and only the answers are checked | `IsOrdered`/`IsEquatable` restate `CheckBinary`'s arms and nothing compares the two; an arm widened or narrowed without the predicate is silent both ways | ADR-0266, ADR-0194 |
| **Nothing checks that a harness works only inside the directory it made** | Every writing harness calls `mktemp -d` or `mkdtemp` and asks for a port; a grep proves the directory exists and not that nothing is written outside it — `format_check.py` shipped writing a fixed path with every gate green. Declined rather than written as a proof that is not one; every local parallel run now exercises it | ADR-0281 |
| **`lib_process_execute` case 19 holds a wall-clock bound** | The deadline case asserts that a run given one second finished in under ten, and under a full `-j12` release run on 2026-09-07 it failed once and passed on every rerun, alone and in the suite. The bound is coarse on purpose (ADR-0363) and still a fact about the machine's load; a second failure is the signal to hold the *kill* — the child gone, the pipe closed — and not the clock | ADR-0363 |
| **`benchmark` says nothing on CI, and nothing on aarch64** | A stage share is not architecture-independent and the tolerances are margins over an idle machine, so it abstains on both; closing it needs an idle aarch64 machine to calibrate on | ADR-0270, ADR-0282 |

## 8. What this document is not

It is not a substitute for the skills that do the work — `code-review`,
`release-engineering`, `langspec-audit`, `docs-engineering`,
`commit-and-push`, `tracing-thoroughly`, `performance-profile` and
`security-audit` each carry their own procedure; this says *when* to run them
and *what must be true afterwards*. `.claude/skills/change-lifecycle/` is this
document in a form an agent can follow.

It is not a promise that following it makes the compiler correct. It makes the
compiler's *claims* checkable, which is the most a process can do.
