# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

It carries **what is true of every change** and points elsewhere for the
mechanism of any one feature: `doc/design-digest.md` for a mechanism, the cited
ADR for a decision and its cost, `doc/history.md` for what a sweep or an
increment found, `doc/sop.md` for what a gate cannot see,
`doc/developer-guide.md` for the layout and the harnesses, and `doc/tour.md` for
the language explained to a reader who knows Turbo Pascal.

## What this is

**Afterschool Pascal is a Pascal dialect that exists to meet modern computing
requirements, and that is the top policy** (ADR-0109, ADR-0232). It is a dialect
in the sense Turbo Pascal and Free Pascal are: the syntax is Pascal, and no
standard governs it. When two goals conflict, this is the one that settles the
order.

**It is also the test for a feature.** Not "does a standard have it" — none
governs this language — but *does a program someone would actually write today
need it*. ADR-0109 names the areas: networking, internationalisation,
concurrency, and memory safety as a property of the language rather than a
convention. `doc/roadmap.md`'s inventory of what a daily program could not reach
for is **empty as of v3.2.0**; what it keeps in its place is the lesson, which
is worth more than the list was — two of its eight rows said why they were
blocked and both reasons were wrong, so a row there is a report and not an
estimate.

It is a Pascal compiler **written in Pascal** and compiled by itself. The
compiler is **three ISO/IEC 10206:1991 §6.13 program-components** and no other
source (ADR-0233): `selfhost/aptypes.pas` imports nothing,
`selfhost/apfront.pas` imports it, `selfhost/compiler.pas` holds the
main-program-block and imports both, and `selfhost/compiler.components` is the
list every harness and CMake reads for that order. It emits textual LLVM IR and
links nothing (ADR-0085).

**The standards are where the language came from, not an obligation it is
under.** ISO 7185 and ISO/IEC 10206:1991 were both implemented completely, and
the dialect *contains* Extended Pascal (ADR-0117) — so every clause reading in
this tree is still true of the language, and every ADR about one is still live
design rationale. What ADR-0232 removed is the claim: `--std`, the two
conformance modes, ADR-0166's `{ @std: }` header comment and the clause 5.1 a)
compliance statement are gone. There is one language and the compiler has no
mode to be put into. **That decision was taken with its cost measured**, and the
numbers are in ADR-0232 — conforming ISO 7185 cases become inexpressible where
§6.1.2 reserves a word-symbol they use as an identifier, and five oracles
retire, the BSI suite among them. **Don't reopen it**; note it in one line if a
decision genuinely turns on it, then proceed.

There was a second C++ implementation in `src/` from ADR-0108 — a **reference
front end** and not a compiler — deleted with `difftest` by ADR-0232. Read a
mention of C++ below as naming that, or as history; the code is at tag `v0.1.0`.

Bootstrapping was an earlier goal and is done; what survives of it is a
constraint on the *order* features land in — a feature must be expressible in
what `seed/*.ll` accepts, or the seed is refreshed first.

## Commands

```sh
# configure -- no LLVM_DIR: nothing links libLLVM since ADR-0085
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release   # needs clang; no C++, no LLVM
cmake --build build -j

ctest --test-dir build -j"$(nproc)" --output-on-failure   # 86 s; 290 s without -j
ctest --test-dir build -R control --output-on-failure   # a single case, by name
tests/run_test.sh tools/pascalcc tests/control.pas   # without ctest
selfhost/irtest.sh build/bin/pascalc-seed   # what pascalc *builds*, and stage 2 = stage 3
selfhost/producttest.sh build/bin/pascalc build/lib   # the built pascalc itself
cmake --install build --prefix /opt/apascal  # bin/, lib/, lib/afterschool/
seed/refresh.sh                             # regenerate the seed (release only)
tests/checks/seed_current.sh                # is the committed seed this source's? (release only)
tools/release.sh --archive build v3.5.1     # what a tag ships; --check <archive> is what the job runs on it (ADR-0296)

tools/pascalcc tests/hello.pas -o /tmp/hello && /tmp/hello
tools/pascalcc -S tests/hello.pas -o /dev/stdout   # inspect IR
```

**Run the suite in parallel** (ADR-0281) — 290 s serially, 86 s at `-j12`. What
makes it safe is one property held by every harness here: **each works in a
directory it created for the run**, and a port is asked for rather than assumed.
Two things follow that are easy to get wrong. `benchmark` is `RUN_SERIAL`
because its answer is a *duration*, and it is the only case here whose
correctness depends on what else is running. And **declaring `PROCESSORS` makes
it slower** — the obvious fix, measured at 107 s: the wall clock is set by
`sanitizers` and `selfhost-codegen`, which are internally serial, and the three
gates that oversubscribe with `os.cpu_count()` workers are what keeps the other
cores busy while those two run.

**There is one compiler, and it does not link.** `build/bin/pascalc` writes IR
and stops, no standard Pascal program being able to start an assembler;
`tools/pascalcc` is where the missing half lives and is what every harness is
handed. `build/bin/pascalc-seed` is the same compiler built from `seed/*.ll` and
exists only to bootstrap: what ships is always built from the source in the tree
(ADR-0085).

**The compiler's own build is an ordinary `.components` case.**
`selfhost/compiler.components` is the same sidecar `tests/run_test.sh` and
`selfhost/irtest.sh` read for a test case, and CMake, `seed/refresh.sh`,
`tests/checks/*.py` and the CI seed job all read that one file — the build order
is written down once (ADR-0233).

Adding `tests/foo.pas` + `tests/foo.out` requires **re-running `cmake`**: cases
are registered by a `file(GLOB)` at configure time, and `tests/`,
`tests/extended/`, `tests/dialect/` and — since ADR-0295 — `examples/` are
globbed separately. The split no longer says which standard a case is compiled
under (ADR-0232); it says which names the ctest cases have, and buys
`tests/dialect/` and `examples/` the per-case `TIMEOUT` a program that opens a
socket needs. The sweeps that enumerate Pascal by root (`format_check.py`,
`variant_check.sh`, `coverage.py`, `heap_balance.py`, `fuzz.py`, `sanitize.sh`,
`irtest.sh`) name all four.

A case may carry sidecars named after it: `foo.err` (expected diagnostics, and a
non-zero exit is then required), `foo.warn` (expected *warnings*, for a program
that compiles — and a case **without** one must produce none, which is the half
that keeps a warning added later from appearing on dozens of green cases,
ADR-0272), `foo.in` (standard input), `foo.epoch` (a fixed
`SOURCE_DATE_EPOCH`), `foo.components` (§6.13's other program-components, one
path per line), `foo.opt` (an optimisation level), and — since ADR-0244 —
`foo.importpath` and `foo.importenv`, which name *where to look* rather than
what to read, and so assert that the compiler found a component it was never
told about. **`foo.std` was one and is gone**, with `selfhost/compiler.std` and
the second field of a `.components` line. `foo.opt` is the one to reach for
least — the corpus compiles at `-O2` and should go on doing so, but a defect in
*storage* is invisible there, LLVM being free to hoist an alloca whose address
does not escape (ADR-0102).

`tests/dumps/` is a corpus apart, with its own harness and its own sidecars
(`foo.dump`, `foo.flags`, and since ADR-0246 `foo.components` and `foo.status`):
the `--dump` flags write to standard output, so what a case there compares is
what the *compiler* wrote and not what a program did (ADR-0103). **`lsp/` is a
second one** — `lsp/pasls.pas`, a language server written in the dialect, built
by `lsp/build.sh` into a binary an editor can be pointed at, checked by
`lsp/run.sh` replaying
`lsp/sessions/*.jsonl` as a *conversation* compared byte for byte (ADR-0236),
and speaking MCP as well as LSP from the one binary (ADR-0241). `lsp/README.md`
says what it answers and from which dump; `doc/design-digest.md` holds the
mechanism. Two things about it are this file's business: the corpus sweeps reach
it through a **second root** rather than through the glob (`coverage.py` names
it, `variant_check.sh` finds it, `build.sh` honours `AFTERSCHOOL_PASCAL_OPT`),
and `heap-balance` drives `lsp/run.sh` instead of `run_test.sh`, which has to
take `PASHEAP_BALANCE` out of the environment **twice**, `pascalcc` building the
server and the server starting `pascalc` once per document.

`tools/pascalcc` shells out to `clang` to assemble and link (ADR-0009) and finds
`libpasrt.a` beside the compiler; `AFTERSCHOOL_PASCAL_RUNTIME` and `PASCALC`
override where it looks for each, which is how CMake points the tests at their
own build tree. **Two variables add flags and they are not interchangeable**:
`AFTERSCHOOL_PASCAL_CFLAGS` reaches every `clang`, which is what a sanitizer
needs, and `AFTERSCHOOL_PASCAL_LDFLAGS` reaches the final link alone, after the
runtime, which is where a library a program *binds* belongs (ADR-0264).

## Pipeline and its contracts

`Compile` runs: Tokenize → ParseProgram → RunSema → RunCodeGen, and each stage
is guarded by `errorSeen` — a stage that failed has nothing for the next one to
read. Assembling and linking are *outside* the compiler entirely
(`tools/pascalcc`), because no standard Pascal program can start another.

The contract that keeps `RunCodeGen` simple: **Sema leaves every node's `ntype`
non-null and every `nkVar`'s symbol resolved.** CodeGen therefore never inspects
names, never re-derives types, and reports no user-facing errors — if it needs a
fact about the source program, that fact belongs in Sema. On an error path Sema
still assigns a placeholder type rather than nil, so codegen cannot crash on a
half-checked tree. This was written about the C++ code generator and holds
unchanged for the Pascal one it was ported to; that compiler is gone (ADR-0085)
and the contract is the thing that survived it. Where a document here still
names a C++ file, read it as naming the component (ADR-0022 to ADR-0024).

Most of what Sema hands over is *per node*. Since ADR-0053 one thing is not:
`Sema::activeModules()` is a whole-program answer — which modules supply the
main-program-block, in the order their activations must commence. It is worth
knowing that the contract has a shape other than an annotation on a node.

Errors: the parser sets `aborted` when it cannot make progress, and every
production and loop tests it — Pascal has no exceptions, so what was
`ap::ParseAbort` in the C++ became a flag (ADR-0023). Sema and the lexer instead
accumulate into `Diagnostics` so one run reports many errors.

**Not every diagnostic is one** (ADR-0272). `WarnAt` stands beside `ErrorAt` and
**the only difference is `errorSeen`** — same format, same stream, same exit
status, and no `errorCount` either, that one naming a schema's domain (§6.4.7).
**Three guards govern a warning and each was learned by it failing.** It is
written only when `warnOn`, which every `--dump` flag clears, a dump having a
reader that parses a fixed grammar; only when nothing has been reported, because
a name that did not resolve records no use; and only for `curFile = mainFile`,
because Sema checks a whole imported component. **All three are pinned by
`tests/dumps/warnings.pas`** (ADR-0277) — until it existed no source under
`tests/dumps/` warned at all, so dropping `warnOn` left the whole suite green.

There are **four** warnings, and each found something on its first run.

- **A local variable declared and never used** — twelve dead declarations in
  this compiler.
- **A statement after one that leaves** (ADR-0277). `goto`, `halt`, `exit`,
  `break` and `continue` are the five that leave, a labelled statement is looked
  *through*, and it is a question about a **statement-sequence** — §6.9.2.1
  gives one to a compound-statement, a repeat-statement and §6.9.3.5's completer
  and to nothing else, so the arm of an if has nothing after it to be
  unreachable. Deliberately not a flow analysis: what is claimed is the
  *unconditional* transfer.
- **A function that writes its result on one path and not another** (ADR-0278).
  A sequence answers yes as soon as one statement does, an if needs **both**
  arms, a case needs every arm *and* the completer unless it has none. Silenced
  by a `goto`, by §6.8.2.2's *nested* assignment, and by §6.7.2's
  result-variable-specification.
- **A `var` parameter nothing writes through** (ADR-0283) — §6.7.3.1's
  `protected var`, and the first whose answer is a property of the **component**
  rather than of the routine. The advice is *exact* rather than a guess: §6.5.1
  forbids threatening a protected variable-identifier, §6.9.4 lists the six
  ways, and `not wasThreatened` with `Protectable` (§6.4.1 refusing a file or a
  pointer) is precisely the condition under which adding the word still
  compiles. It is **deferred** to after `CheckMutualSupply` because two guards
  need the whole component: a routine passed as a procedural actual cannot take
  the word, and an exported one cannot be judged here at all. **It is a fixed
  point and not a list** — §6.5.1 exempts a protected formal from being
  threatened, so protecting one parameter exposes the next layer. **The unit is
  the formal-parameter-section and not the parameter** (ADR-0300): §6.7.3.1 puts
  the word before the whole section, so `var b, c` takes it for both names or
  neither, and advising it for `c` while `b` is written through was advice that
  does not compile — ADR-0283's own claim, true of a parameter and false of a
  section.

### The representation, in brief

Six facts the rest of the compiler is fitted to. **`doc/design-digest.md` holds
the paragraph behind each**, and the ADR behind that; read the entry before
changing the mechanism, because most of what looks over-complicated there is
load-bearing and the entry names the test that fails without it.

- **A frame is a struct and field 0 is the static link** (ADR-0016). Locals,
  value parameters, `var` parameters and the function result are the remaining
  fields; a `var` parameter's slot holds a pointer and `addressOf` dereferences
  it. `frameAt(level)` walks the chain and `addressOf(sym)` walks then indexes,
  so there is no separate global path — but it asks for the frame of the
  symbol's **owner**, and a **level-0** owner (the program, and since ADR-0053
  every module) answers with a *global* without walking, having exactly one
  activation. Calling a procedure at level `L` passes the frame at level `L-1`;
  for a *recursive* call that is the caller's parent, not the caller.
  `tests/nesting.pas` distinguishes a correct implementation.
- **Structured types are name-equivalent** (ADR-0017). Two are the same only
  when they are the same object, so `assignable` compares with `==`; packed char
  arrays are §6.4.5's own exception and compare by length. A declaration group
  shares one type-denoter, which is why `a, b: array [1..3] of integer` is one
  type and not two alike ones.
- **A structured value has no register form** (ADR-0017). A designator of one
  yields its *address*, assignment is a memcpy, and a parameter always travels
  as an address — a `var` one binds to it, a value one is copied by the callee's
  prologue. `emitAddress` is the single path to an address and `emitLoad` reads
  through it. Every subscript is bounds-checked before the offset is computed,
  and `verify/rules.py` proves both that and the unchecked subtraction after it.
- **A subrange answers for its host** (ADR-0018). `Type::base()` is what
  `isInteger()`, `isChar()` and the rest ask, so `1..9` *is* an integer
  everywhere except where its bounds matter; code needing the distinction asks
  `isSubrange()`. `checkedForSubrange` is applied where a value *enters* a
  variable and is a no-op for every other type, so no call site is conditional.
  Two enumerated types are never compatible however alike they look.
- **Some types are values and some travel by address.** `isStructured()` grants
  whole-variable copying; `isMemory()` means "travels by address". A set is a
  value (ADR-0028) and so is a `complex` (ADR-0049); a file is `isMemory()` and
  never `isStructured()`, which refuses assignment, comparison, value parameters
  and function results for it (ADR-0021) — **and anything holding a file, at any
  depth**, §6.4.6 a) being two conditions whose second is `ContainsFile` and not
  `IsFile` (ADR-0150; reading only the first closed one `struct pas_file`
  twice). **Ownership and representation are two questions and were one name
  until ADR-0181**: `IsAffine` is what `ContainsFile` asks — a file, a handle,
  and `owned ^T` — while `IsOwned` is what `IsMemory` asks, and an owned pointer
  is not in it, its value being one word; a new affine kind joins the first and
  not the second. **An affine type needs a move to be usable**: `take`
  (ADR-0182) empties its source before the target's address is taken, which
  stops a target reached through the source from building a cycle nothing owns,
  and **two of the three kinds move, not one** (ADR-0267, AP 6.4.12.7), a file
  as much as an owned pointer. **A second name for an owned value exists in
  exactly one form and cannot escape** (ADR-0201): a `var` parameter bound to
  `o^` is a borrow for the duration of the call and no pointer can name it,
  Pascal having no address-of — unformable rather than checked, so a feature
  that adds a way to form such a value takes the property with it silently.
  **The same split, a second time, for text**: `IsVarString` asks whether
  §6.4.3.3.3's *rules* apply and `IsStringRep` whether the value is a length and
  that many bytes (ADR-0191); asking one where the other was meant is how a text
  got `icmp` on an aggregate.
- **The emitted module states its own `target datalayout`** (ADR-0028), because
  `LlSize`/`LlAlign` decide what a whole-variable copy moves and there is no
  `DataLayout` to ask. Don't drop the line; a set in a record segfaulted without
  it.

### Where to look

| Area | ADRs |
| --- | --- |
| frames, designators, ordinals, variants | 0016 – 0018, 0026, 0027 |
| pointers, files, `goto`, procedural parameters, sets | 0019, 0021, 0028 – 0032, 0050, 0070 |
| schemata and discriminants | 0039 – 0045 |
| strings, substrings, `readstr`/`writestr`, binding | 0051, 0052, 0057, 0060 |
| modules and separate translation | 0053, 0079 |
| constant-expressions, constant-accesses, structured values | 0054, 0061, 0066, 0069, 0075 |
| function results and function-accesses | 0055, 0056 |
| conformance sweeps and what they found | 0067, 0071 – 0078, 0080, 0087 – 0101, 0107, 0113, 0127, 0133, 0134 |
| the build, the seed, the oracles | 0011, 0013, 0081 – 0086, 0095, 0102 – 0108, 0126, 0138, 0142, 0144 – 0148, 0150 |
| where the language is going | 0109, 0114 – 0125, 0128 – 0141, 0143, 0149, 0151 |

`doc/adr/README.md` indexes all of them by number and title.

## How a change lands

`doc/sop.md` is the standard operating procedure: how a change is classified,
what its class has to satisfy, and — the part worth reading before anything
else — **what each oracle here cannot see**. Every gate in it exists because of
a blind spot in that table, and the table is why the gates look
disproportionate to the change they guard.

The one sentence it rests on: **a green suite is not evidence; evidence is a
named case that fails without the change.** This repository has been green over
a `verify/` model describing a compiler that had been replaced, over a stack
leak the default `-O2` optimised out of sight, over 32 diagnostics nothing
named, and over four documented `--dump` flags no case ever passed.

The gates below make that mechanical — **count the rows rather than trusting a
number in a sentence**, which has been wrong in both directions — and each fails
in **both** directions: a claim that stops being true is as loud as one that was
never true, which is `verify/`'s `KNOWN_GAP` rule (ADR-0013) applied to a dozen
catalogues. `benchmark` is that rule applied to a *duration*, and fires on a
stage that got **faster** for the same reason — a stage that suddenly costs a
third less is a stage that stopped doing something. Five more stood here until
ADR-0232 removed the surface they asked about (`difftest`,
`dialect-containment`, `annex-b`, `reserved-words` and `dialect-build` were all
questions about a conformance mode, and there is none). Three are
one-directional in part, and say so in the table: `line-coverage`, which is two
ratchets — though the pairing half of it, that every decision emits one counter
per direction, fails in both; `buffer-headroom`, which watches a bound rather
than a claim; and `spec-clause-traceability`, which fails when a citation
disappears and deliberately does not when one appears. **Where a row names a
count, run the gate**: each prints its own denominators, and they move with the
corpus. Each row's ADR carries the defect that motivated it and the mutation
that proved it.

| Gate | Catalogue | Asks |
| --- | --- | --- |
| `diagnostic-coverage` | `tests/checks/unreachable_diagnostics.txt` | is every message named by a golden? (ADR-0273) — it *scans* a Pascal literal to the first quote that is not doubled rather than matching one with a regex, which is how a third of the messages were once reported as covered by never being asked about |
| `procedure-coverage` | `tests/checks/uncovered_procedures.txt` | is every procedure entered by a case (ADR-0103), **and did the compiler survive every invocation** (ADR-0269)? A crash is not a rejection and the exit status cannot tell them apart, a third of this corpus being written to exit 1 |
| `line-coverage` | `tests/checks/line_coverage.txt`, `tests/checks/branch_coverage.txt` | is every *statement* run by a case (ADR-0104) and every *branch* taken both ways (ADR-0274)? Two ratchets, one sweep. Statement coverage keys on the **line** and is blind to two statements on one line, to a decision with no else-part and to a short-circuit operator; branch coverage keys on line **and column**. The ratchet cannot see a **miswired** counter, so every site is separately required to emit one counter per direction |
| `foreign-reserved` | `ReservedForeignName` in the compiler | is every global the emitter names still refused as a foreign name? (ADR-0121, ADR-0144) — LLVM rejects a redeclared global, so a collision is an error about a file nobody wrote. It reads the emitter's literals **and compiles a probe to harvest the `@names` its IR actually contains**, a generated name like `@frame1` being in no literal |
| `kind-exhaustive` | `tests/checks/partial_cases.txt` | does every dispatch over an enumeration name every constant? (ADR-0124, ADR-0145, ADR-0221, ADR-0229, ADR-0230) — a constant left off a **case-statement** stops the program (ADR-0018) and is a compiler crash; one left off an **if-chain** takes the trailing `else` in silence, which is why a bare `else` does not excuse a chain where `otherwise` excuses a case. Both halves come from `--dump-dispatch`, so the gate reads no Pascal |
| `predicate-kinds` | `tests/checks/predicate_kinds.txt` | what does every type predicate answer about every kind of type? (ADR-0194) — the row above reads a `case … of` and nothing else, and three defects lived in a *predicate* instead. `--dump-predicates` asks each `Is…(t: typePtr): boolean` about a fresh `NewType(k)` for every kind, so adding a kind moves the denominator on every row. **A prompt and not a proof**: a wrong cell written in passes, and **the row that hides a defect is a correct one**, which is what `--like OLD NEW` beside it is for (ADR-0198) |
| `ast-fields` | `tests/checks/ast_fields.txt` | is every pointer field of an AST node written before it is read? (ADR-0222) — Pascal gives a variant record no member initialisers, so a field of the arm the tag selects holds whatever `new` returned. The catalogue is **empty**, which is the finding |
| `variant-check` | ADR-0118's guard, and the corpus | is every node read through the arm its tag selects? (ADR-0223) — §6.5.3.3 makes a wrong-arm read an error and §3.1 lets a processor leave it undetected. **What it sweeps is what git tracks**, not what a recursive `find` sees. It refuses to pass by asking nothing: fewer than 100 guards is a failure |
| `predicate-callers` | `Assignable`'s own refusal arms and call sites | does every caller of a shared predicate refuse what the predicate refuses? (ADR-0146) — ADR-0058's sentence has cost three times (ADR-0139, ADR-0143, ADR-0150), the last a double free with SIGABRT. It derives the positions from the **source** rather than from the ones someone thought of |
| `buffer-headroom` | `poolMax`, `tokMax` and `triviaMax`, and `--dump-limits` | how much of each array sized for this compiler's own source is still free? (ADR-0126, ADR-0148, ADR-0279) — a one-directional watch on a bound. Twice a fixed buffer (ADR-0012) has failed as a **build** rather than as a diagnostic, because the array that has to hold this source is the *seed's*, so the only way out is an out-of-cycle reseed. It reads the capacities from the source **and** from the compiler, so a stale `build/bin/pascalc` is named rather than measured |
| `benchmark` | `tests/checks/benchmark.txt`, and the compiler's own sources | how long does the compiler take? (ADR-0270) — **and it abstains where it cannot answer** (ADR-0282), skipping when the baseline's `arch` is not this one and when `$CI` is set. **A millisecond is a fact about the machine that took it**, so what is committed is *proportions*, each divided by something measured in the same run, and a failure is confirmed by a second measurement before it is reported. It catches a stage made about a third slower and cannot see a compiler slowed uniformly |
| `target-sizes` | `PAS_FILE_SIZE`/`PAS_JUMP_SIZE` and `fileSize`/`jumpSize` | are the two opaque struct sizes large enough on a machine that is not this one? (ADR-0155) — `struct pas_jump` embeds a `jmp_buf`, a different size on every architecture. Skips with 77 where only the host is available; `TARGET_SIZES_REQUIRE` is how CI refuses to pass by skipping |
| `long-path` | a path a harness builds, and the compiler | can this compiler open a file whose path is longer than a name? (ADR-0291) — no oracle here could see this, because **no test case can choose its own path**: every case is compiled where it sits and every path a harness passes is short |
| `bare-source-name` | the compiler, run from another directory | does a source named with **no** directory find its neighbours? (ADR-0308) — `SourceDir` answered the empty string where the answer is `./` and `AddPath` drops an empty one on purpose, so ADR-0244's first rule held for every spelling but `pascalc prog.pas`. The row above's argument met a third time, one step over: no test case can choose how it is **named** |
| `stale-component` | a component's source, edited between two links | is an object built from an older module-heading refused? (ADR-0245, AP 6.13.2) — it cost a **wrong answer with a zero exit status** and no diagnostic from compiler, driver or linker. It is a shell harness because **no test case can edit its own source between two compilations**, and it fails in both directions: a comment or a reflow must still link |
| `require-consistency` | the `*_REQUIRE` variables, and the workflows | does every gate that can skip have a job that refuses to let it? (ADR-0330) — ctest reads 77 as success, so a skipped gate and a clean one print the same bar, and the `*_REQUIRE` convention that closes it had shipped broken **four** times. Both directions: a variable a check reads and no job sets is a gate answering only where its author was, and one a workflow sets and no check reads is a comment describing a mechanism that is not there. It matches a **mapping key** and not a mention, its own mutation having caught it passing on a name left in a comment |
| `lib-coverage` | `tests/checks/lib_coverage.txt` | how much of `lib/` does the corpus run? (ADR-0350) — `line-coverage` measures the compiler's three components and nothing else, so 11 160 lines across 32 modules were measured by nothing; every module *is* imported by a case, which is `procedure-coverage`'s question and not this one. Same attribution trick: **one module instrumented per link**, because `$PASCOV_LINES` is bare line numbers and a program linking six modules otherwise yields six sources' lines in one heap. A **generic** module cannot be measured here at all — AP 6.7.3.5 emits its body in the *client's* translation — so it reports a denominator of 0 and the run names it, that meaning *nothing to measure* and never *all covered* |
| `runtime-coverage` | `tests/checks/runtime_coverage.txt` | how much of `runtime/*.c` does the corpus run? (ADR-0351) — the runtime is the only C here, every compiled program links it, and `gcov` left with the C++ implementation (ADR-0232) with nothing to replace it. **It is the denominator the sanitizers were missing**: ADR-0342 established that AddressSanitizer never instruments compiled Pascal, so `runtime/*.c` is the whole of what ASan, UBSan, LSan and TSan watch, and an uncovered line here is a line all four looked at zero times. A third **mode** of `sanitize.sh` for ADR-0327's reason — the 120 lines that link a case's components are what must not be copied — with two floors, on programs run and on profiles written, because a sweep can build every case and run none |
| `seed-portable` | every module under `seed/` | does the committed seed name the machine that made it? (ADR-0347) — ADR-0293 puts a trap's own source path into the emitted module, and `seed/refresh.sh` was handing the compiler an absolute one, so the artefact held a stranger's home directory and `seed_current.sh` could pass only in the directory that generated it. That check asks the whole question and **cannot be a ctest case** — the seed is legitimately stale between releases — so it answered eight releases late, in the tag job. This half is a grep and holds on every push |
| `markdown-tables` | every Markdown table in the tree | is every row the width of its header? — the cheapest gate here and the one whose absence damaged the most-read file (`doc/sop.md` §7). Nothing else here can see it: every other oracle reads Pascal, C or a golden. It checks two structural shapes only — a row that is not one line, and a row whose cell count differs from its header's — and does **not** reach a cell whose code span holds an escaped pipe |
| `install-layout` | the install prefix, and `PATH` | can this compiler be put somewhere and found there? (ADR-0244) — every other harness drives the compiler out of the build tree, exactly the configuration an installed copy does not have. **The claim the convention rests on**: the search is `<directory>/<interface name>.pas` and nothing opens a file to find out what it declares, so one `import <name>;` program per installed module must *compile* rather than merely resolve |
| `release-archive` | `tools/release.sh`, and the archive it writes | does the script a tag runs still produce an archive that checks out? (ADR-0296) — the tag job is the third piece of shell here that runs only at a tag, after two that failed for want of anywhere to be exercised first (ADR-0282) |
| `runtime-isoc` | `tests/checks/nonstandard_c.txt` | how far is the runtime from ISO C? (ADR-0161, ADR-0186) — it is the only C here and the whole of what a port has to satisfy. `runtime/pasrt.c` carries a short catalogue of POSIX **functions**, proved complete by stripping every non-ISO `#include` from a copy before the strict compile. That mechanism **cannot work for a type**, which is why `runtime/pasrt_posix.c` is bounded by its **headers** instead and required to hold nothing but `pasx_` — so a system without those headers loses library routines and **not the language**. Skips 77 on a C library that declares POSIX anyway |
| `unicode-conformance` | Unicode's `NormalizationTest.txt` and `GraphemeBreakTest.txt` | does the runtime agree with the Unicode Character Database about what a text value *is*? (ADR-0189, ADR-0190) — **the only oracle here that nobody in this project wrote**. It asks a second question the files cannot: regenerating the tables from the database must reproduce the committed header. Skips 77 without the database, which is fetched and never committed; `UNICODE_CONFORMANCE_REQUIRE` refuses to pass by skipping |
| `fpc-differential` | `tests/checks/fpc_disagreements.txt`, and Free Pascal | does a processor nobody here wrote answer these programs the same way? (ADR-0234) — **it is not an authority**, so where the two disagree the clause decides and the disagreement is catalogued with which clause and which way. Numbers compare **by value**, §6.9.3.1 leaving the default width to the processor. `tests/dialect/` is out of reach and always will be. Skips 77 without `fpc`; `FPC_DIFFERENTIAL_REQUIRE` refuses to pass by skipping |
| `foreign-layout` | the `@cstruct`/`@cfield` comments, and `--dump-layout` | does a record declared here have the layout the C struct it claims to be has? (ADR-0185) — a hole in the wrong place makes every field after it wrong with no diagnostic anywhere. The source states its claim in a **comment**, the compiler reports the offsets, a C compiler holding the real header judges the two. Zipped in **order**, so a missing annotation shifts the rest and the count check fires. Skips 77 with no C compiler |
| `target-layout` | the frame types the compiler emits, and the targets `--target=` admits | does every admitted target lay a frame out the way the compiler thinks? (ADR-0157, ADR-0325) — **two claims since a target that is not LP64 was admitted**, because *do the targets agree with each other* is one a 32-bit target falsifies by existing. Targets of the same word size must lay every frame out identically, which is the old comparison unchanged; and the compiler's own size and alignment must equal LLVM's, asked of **every** target over six record shapes through `--dump-layout`. The second half is new and is the first time this gate compared the compiler's arithmetic against LLVM rather than one target's IR against another's. The target list comes from the compiler's own `--target=` refusal, so a fourth is compared without the gate being edited |
| `target32` | the corpus, and a runtime built for i386 | does a program built with those numbers *behave* when a pointer is four bytes? (ADR-0325) — the row above asks about arithmetic, and both defects the i386 port found were in neither a layout rule nor a frame: the runtime indexed an array by `sizeof` where the compiler strides a constant, and the compiler wrote a field at an offset only an LP64 target has. It passed with `select` segfaulting. `tests/checks/target32_known.txt` fails in both directions and holds **one** row — a 2 GB allocation with nowhere to go in a 32-bit address space; the five that waited on ADR-0129's foreign boundary closed with ADR-0328's `clong`/`csize`, and a sixth, invisible at `-O2`, closed with ADR-0334's second optimisation level. Skips 77 without a 32-bit libc; `TARGET32_REQUIRE` refuses to pass by skipping, at **both** levels since ADR-0334 |
| `clause-citations` | `tests/checks/nonexistent_clauses.txt` | does every clause number this tree writes down name a clause of *some* standard? (ADR-0164) — a wrong number compiles, runs, passes every golden and is proved correct by `verify/`. It asks the **cheap half** and says so: whether the number names a clause at all, never whether it names the right one. **A clause number written in this tree is a citation** — the gate cannot tell a mention from a claim, so a document discussing a wrong number either avoids spelling it or takes an entry |
| `spec-clause-traceability` | `tests/spec/clauses/triage.tsv` and `pending.txt` | is every clause a scenario cites still cited, and does every citation name a clause the triage calls testable? (ADR-0106) — the second half keeps the *triage* honest. A clause that **starts** being cited does not fail; it asks for `--write-pending`, a gate that punished progress being one people learn to avoid |
| `valgrind-corpus` | the corpus, run under Valgrind | does a compiled program touch memory it should not? (ADR-0353) — **the only oracle here for that class, and there was none until now**: ADR-0342 established that clang's sanitizer passes act on functions carrying an attribute and this emitter writes none, so `new(p); q := p; dispose(p); q^ := 5` prints 5 and exits 0 under a fully ASan-linked binary. Valgrind instruments nothing and reads the binary. A **fourth mode** of `sanitize.sh` for `thread-sanitizer`'s reason, and its detector needed a third vocabulary — the existing arms match `==pid==ERROR:` and `runtime error:`, and Valgrind writes `Invalid write of size 4`, so without an arm for it the mode would sweep 377 programs and call them all clean. 377 clean, 0 flagged; **the slowest gate here at 170 s**, and it sets the wall clock |
| `thread-sanitizer` | the programs with two threads of control | is the concurrency construct free of races? (ADR-0327) — the same harness in a second mode, because ASan and TSan cannot be combined and the 120 lines that link a case's components are what must not be duplicated. **The corpus selects itself** from what each source writes, so a concurrent program added later is swept without this row moving; eleven qualify. Unlocking the store in `pas_chan_send` flags five of them. It was `doc/sop.md` §7's longest-lived row and the one thing CLAUDE.md asked to be run by hand |
| `sanitizers` | the corpus, and `tests/checks/heap_balance.txt` | does the runtime's own C survive its own suite? (ADR-0261) — the corpus run again under ASan, UBSan and LSan over a second `libpasrt.a` built with the same flags, because ASan's runtime arrives at the **link**. `heap-balance` counts *calls*, so a write past an allocation, a read of a freed block or a signed overflow is invisible to it. It is not a fuzzer: it generates no input, which is `fuzz`'s half of the gap. It compiles the corpus at `-O1` — the level a sanitizer build wants — and **honours `AFTERSCHOOL_PASCAL_OPT` since ADR-0335**, having read it not at all before, so an `-O0` sweep of the suite reported these 383 programs green at a level it had not asked for |
| `tls` | OpenSSL's headers, and two servers | are the numbers `lib/dialect/pastls.pas` copied out of OpenSSL still what OpenSSL says? (ADR-0264) — some are macros no `external` declaration can reach, so the module holds a transcription and **a wrong one fails quietly**: `SSL_VERIFY_PEER` written as 0 turns verification off and every behavioural case stays green. The behavioural half needs **two** servers, the second's chain verifying perfectly under the wrong name. A third half drives `PasHttps` (ADR-0265), the **only place a second transport is driven at all**. Skips 77 without libssl or `openssl`; `TLS_REQUIRE` refuses to pass by skipping |
| `fuzz` | `tests/checks/fuzz_bounds.err`, and input nobody wrote | does this compiler survive what a person would not have written? (ADR-0275) — every other corpus here is hand-written and so tests what someone thought of. Three families: **truncation**, every prefix of a real source; **the bounds**, one generated input per fixed buffer and per depth limit, each asserting the *message*, because ADR-0012's claim is not that a full buffer is survivable but that it is a diagnostic; and **mutation**. **The seed is fixed**, so what runs is a regression suite and not a search — `--long N` is the search, run by hand |
| `format-check` | the corpus, through `pascalc --format` | does the formatter preserve the program it was given? (ADR-0279, ADR-0284) — and **it swept nothing on CI until ADR-0282**, having read an empty `git ls-files` answer without looking at the status. **The floor is what made it a failure rather than a silence** — a gate sweeping an empty list prints a number and passes. Three claims over every tracked source: the **token stream** unchanged but for positions, the parser seeing that and nothing else; the **comments** unchanged word for word and before the same tokens, the only claim that catches a dropped one; and formatting the output **again** returning it byte for byte, which is the claim about the *rules*. A fourth covers `--range=L:H`. What none says is that the output is *well* laid out — there is no oracle for that (ADR-0285) |
| `heap-balance` | `tests/checks/heap_balance.txt` | did every `new` a corpus program makes still come back through `dispose`? (ADR-0183) — **the one oracle here that reads no output**; a leak prints nothing. The runtime tallies `pas_new` against `pas_dispose` and writes the balance at exit when `$PASHEAP_BALANCE` is set. A nonzero balance is **not** a defect — no standard obliges a program to dispose what it created — so it is a catalogue, failing in both directions. It counts no files and no handles, and takes the count at *exit* |
| `warning-free` | this tree's own `selfhost/`, `lib/` and `lsp/` sources | does the compiler still have **nothing to say** about them? (ADR-0286) — a *test case* is held to the four warnings by its `.warn` sidecar and these have no sidecars, so a warning goes to a build log and nothing fails. Every implementation source must compile with **not one byte on either stream**, which covers every warning added after this one on the day it is written. Its **second** claim makes it fail in both directions: a source named as deliberately broken must still fail, so it cannot become a source that is skipped |
| `export-unique` | every export-part under `lib/`, read from `--dump-tokens` | do any two library modules export one spelling? (ADR-0298) — the language has no overloading and §6.11.2 puts every imported name into one scope, so a collision costs every importer an `only` or a `qualified`. The rule is absolute and the less general side takes a prefix. It has a floor of modules and exports so that it cannot pass by sweeping nothing |
| `model-drift` (CI) | the `Model-unchanged:` trailer | did CodeGen **or the constant folder** change without `verify/lowering.py`? — its *base resolution* is checked locally as `model-drift-base`, that half being a pure question about one repository and the half that has broken |

All but `model-drift` are `ctest` cases, so they run before a push rather than
reporting after one. **What none of them sees** is the corpus being enumerated
by glob, so the harnesses that build a compiler of their own — `irtest.sh`,
`producttest.sh`, `verify.py` — are invisible to it; that is a row in
`doc/sop.md` §7. The *flags* half of it is closed: the coverage corpus sweeps
`--dump-all` over every source, worth 195 statements reported unreached while an
oracle reached them on every run, and since ADR-0274 it sweeps `--coverage` too,
which had been driven by a gate on every run and by no case ever.

`pascalc --coverage` is the product feature behind that gate (ADR-0104,
ADR-0274), and it works on any Pascal program: one counter per statement and one
on each edge of every decision, the lines reached appended to `$PASCOV_LINES`
and the directions taken to `$PASCOV_BRANCHES`, and both *denominators* readable
from the same `.ll` the compilation wrote — so nothing keeps a second idea of
what was executable.

`.claude/skills/change-lifecycle/` is the same procedure in the order an agent
executes it, and dispatches to the specialist skills — `code-review`,
`langspec-audit`, `tracing-thoroughly`, `release-engineering`,
`docs-engineering`, `commit-and-push`, `performance-profile`, `security-audit`.
`doc/sop.md` §7 is a live register of what is currently *not* checked; add to it
when a gate is declined.

## Decisions

`doc/adr/` holds the architecture decision records — one file per decision, what
it costs, and the alternatives that were rejected. Read them before undoing
something that looks over-complicated. Add a record when a choice constrains
future work or deviates from the standard. **`doc/design-digest.md` is the
condensed form**: a paragraph per mechanism, grouped as the compiler is, for
when you know the area but not the number. It is not a substitute for the
record — it says what was decided, and the ADR says why and at what cost.

**A landed feature is two commits**, and the split is not tidiness: the `feat:`
one, then a `docs:` one that moves the feature out of README's "not accepted
yet" list and into the accepted block, and nothing else. That cadence is what
makes the language's growth greppable from `docs:` alone — `git log --oneline
--grep='^docs'` is meant to read as a changelog of what the compiler accepts.
The rule is written out in `.claude/skills/docs-engineering/SKILL.md`, which is
loaded only when that skill is invoked; it is repeated here because that is
exactly how it came to be missed — for the eight Extended Pascal features from
`5df95d7` (protected parameters) through `e710d3a` (modules), and for a ninth,
`de4f206`, which failed differently: it is a `fix:`, and the survey step read
`feat(...)` commits only, so a *conformance fix that changes what the compiler
accepts* fell between them. **The test is whether a program that did not compile
now does, not what the type prefix says.** Those features are documented — the
grep is what is incomplete — so don't try to repair it by rewriting published
history.

## Bootstrap constraints (what is left of them)

The bootstrap is over and stage 0 is retired (ADR-0085), so two of the three
constraints below constrain nothing any more. They are kept because they explain
the shape of `selfhost/compiler.pas`, which a reader will otherwise find
arbitrary.

1. **No C++ RTTI in the AST** — *historical*. `ast.h` tagged nodes with `NK` and
   cast via `as<T>(n)`, because Debian's LLVM is built without RTTI and because
   the Pascal compiler has no `dynamic_cast`. That is why the AST here is a tag
   plus a variant record, and why the port needed nothing redesigned.
2. **Textual `.ll` output stays a first-class path** — *live, and more so*. It
   was the backend that had to survive the rewrite; it is now the only backend,
   and `seed/*.ll` makes it what lets this repository build itself.
3. **Prefer constructs that map onto Pascal** — *satisfied by construction*.
   There is no other language here to prefer them over.

Feature priority follows what a compiler is written in (procedures, records,
pointers, text files, a usable string type), not ISO chapter order. README.md
holds the three-stage plan and the dependency ordering; `doc/history.md` records
how it went, and `doc/roadmap.md` is what is still open.

**All six bootstrap items are now settled**, and both standards are complete
besides — so the bar for a new feature has *moved* twice rather than risen.
During the bootstrap a feature needed a reason beyond "the standard has it";
conformance then made that exactly the reason; and now that neither standard has
anything left to implement, a new feature belongs to the dialect ADR-0109 is
aiming at and needs a reason of its own again.

## The two standards

**ISO 7185 is complete** — and the last four arrived only because someone went
looking, in two separate rounds (ADR-0068). No corpus program had ever written
any of the four, so every oracle agreed: the lesson is about the oracles rather
than the gaps (ADR-0067), and the second round is the evidence that learning it
once is not enough. **Before asserting completeness of anything, compile a probe
for the clause.** ADR-0080 is that rule applied to the list that broke it: every
one of ISO/IEC 10206:1991's required identifiers (Annex C) is probed by
`tests/extended/required_identifiers.pas`, one program using each for its
purpose — and its own first design would have reported a false all-clear,
because it asked whether a name *resolves* rather than whether it works.

**Both standards were implemented, and there is one language now** (ADR-0232).
What survives of the split is worth knowing, because the tree is laid out by it:

- **`selfhost/compiler.pas` was converted to Extended Pascal** (ADR-0082),
  reversing ADR-0033's own example: it *had* a field named `value`. Renaming it
  and `bindable` — by *token position*, not by text, since both words also
  appear in the keyword tables the lexer matches against — was the whole of the
  conversion, and the reason to do it is that only Extended Pascal lets a
  program read its own command line (ADR-0081).
- **`tests/`, `tests/extended/` and `tests/dialect/` are three globs and no
  longer three languages.** The names are kept because hundreds of ctest cases
  and every document referring to them are keyed on the path.
- **`tests/extended/components/` holds §6.13's separately translated
  components**, and the subdirectory is load-bearing: the CMake glob is not
  recursive, so a source declaring no program is never registered as a case that
  fails to run. **`run_test.sh` and `irtest.sh` must read a `.components` file
  the same way, or a case means two things**; `irtest.sh` skips a source with
  **no `.out` and no `.err`**, which keeps a component from being run as a
  program.
- **Every word-symbol is reserved.** §6.1.2 adds ten to ISO 7185's 35, and
  `and then`/`or else` are reserved by the lexer joining two tokens rather than
  from a table (ADR-0038). Adding an eleventh is what `reserved-words` used to
  refuse and nothing refuses now — the argument against it is ADR-0140's.

**Every clause of both was implemented, and each feature's record is in
`doc/design-digest.md`.** Recurring answers worth carrying into a new feature,
because each was arrived at more than once:

- **Ask the symbol, not the syntax.** A qualified name against a field
  selection, a variant-selector against a tag-type, a set-value against a
  subscript, a schema's second name, a redefined `write` — five constructs the
  parser cannot tell apart and Sema can, because it can look the name up
  (ADR-0044, ADR-0053, ADR-0066, ADR-0071, ADR-0087).
- **A parser that has already decided leaves a husk.** Sema moves the real
  operands out of the node the parser built and every later pass reads the field
  first, rather than the tree being rewritten — `checkExpr` takes a raw pointer
  and cannot replace the node its parent holds.
- **Nothing that is two words may depend on how a struct is passed.** A
  procedural parameter's code-and-link pair, a schematic formal's
  address-and-discriminants, a string's pointer-and-length and `complex`'s two
  doubles all travel as separate arguments, so the textual `.ll` backend needs
  no opinion about the C ABI (ADR-0030, ADR-0040, ADR-0049, ADR-0051). A
  variable-string **value parameter** is the fifth and the first where the shape
  was forced rather than chosen (ADR-0115); ADR-0125's **slice** is the sixth
  and makes the shape a language feature — `array of T` travels as an address
  and a count, so the bounds a callee checks against are the ones it was handed.
- **A permission granted in a shared predicate leaks to every caller.**
  `assignable` is asked by the relational operators too, which is why ADR-0058
  had to write the comparison refusal out separately.
- **Refusal by construction beats an enumerated list of what is forbidden.** A
  restricted type refuses arithmetic through the diagnostic arithmetic already
  had; a discriminant-selected variant has no designator to attribute a value
  to. Where a check would have gone, the code says why it is not there.

**Two threads of control exist** (ADR-0268), and every alias rule above is
written for one. `task`, `spawn`, `channel [n] of T`, `send` and `receive`
reserve no word-symbol; a task takes transferable values, channels and — since
ADR-0303 — **a handle, moved in** (AP 6.7.8.1), and may name only its own
variables (AP 6.7.8.2), which is the half a probe found after the first looked
sufficient; and every task a block spawned is joined **before** that block
releases anything, which is what makes ADR-0201's *a borrow cannot outlive the
call* true again. The compiler is one thread and must stay so — the seed
compiles it.

**A channel is lent and a handle is moved, and that is one position with two
rules.** A channel is the only object here with a lock in it, so two
activations may name it; a socket has none, so what crosses is ownership — the
actual is `take(v)` and the variable is empty from there on. The join is what
makes the *channel* safe and is not what makes this safe, a moved handle being
the spawning activation's no longer.

**A release the program *wrote* closes a channel** (AP 6.4.16.4, ADR-0302),
where the one the end of a block performs drops the reference and does not,
because a worker that has finished must not close what its colleagues are
draining. All three spellings close: `release(c)`, `c := nil`, `c := take(d)`.
**ThreadSanitizer is the oracle this construct rests on and `thread-sanitizer`
is the gate** (ADR-0327) — a *mode* of `sanitize.sh`, because ASan and TSan
cannot be combined and the harness's component-linking is the half that must
not be copied. It sweeps what each source **writes** rather than a list, so a
concurrent program added later is covered without the gate being edited.

**`doc/implementation-defined.md` is the register of what this processor
decides** where a clause leaves it open. It no longer carries the clause 5.1 a)
compliance statement: ADR-0232 withdrew it rather than reword it, a processor
that cannot compile BSI's CONF005 not conforming, and saying otherwise would be
the one kind of false claim this project has been most careful about.

**`doc/afterschool-pascal-spec.md` is the specification of this language, clause
by clause** (ADR-0135, ADR-0232) — an amendment to ISO/IEC 10206:1991 in that
standard's own numbering, so AP §6.4.11 is the optional type because clause 6.4
ends at 6.4.10. Two rules govern it: it is derived from the decision records and
verified by probe and **never from `selfhost/compiler.pas`**, a specification
describing an implementation agreeing with it by construction and contradicting
nothing; and where it and an ADR disagree, it wins and the divergence goes in
its Annex E. A dialect feature lands with a clause as well as a record.

Five things about the dialect are worth knowing before adding anything:

- **It reserves no word-symbol, and that is a decision** (ADR-0140). A dialect
  feature is spelled in a *position* where a conforming program could not have
  written it — `external` in the directive slot, `array of` in a juxtaposition
  that was a syntax error, `?` in a character no program can spell, `int64` in a
  scope §6.1.3 lets any program shadow, `handle external '…'` where a
  type-denoter ends, `owned ^T` where a denoter is already complete after the
  type-name (ADR-0181). The test for a new spelling is whether a conforming
  program could have written it **in that position**; for a statement that is
  one token of lookahead, a statement-initial identifier admitting only `(`,
  `:=`, `[`, `.`, `^` or a terminator, which is what `defer S` uses (ADR-0175).
  `reserved-words` enforced this until ADR-0232 retired it, so what keeps it
  true now is the rule and the review. **Two shapes stand beside it.** `exit` is
  where no position works (ADR-0177), and the answer is a *required identifier*
  shadowable by §6.1.3, as `int64` and `argcount` are. And `try` is where the
  statement rule was measured and does **not** transfer to a *factor*
  (ADR-0178): a factor may be a variable-access, so `try (x)`, `try [x]`,
  `try + x`, `try - x`, `try.f` and `try^` all belong to a program that declared
  one, and the parentheses are the construct. **Before spelling a new expression
  by position, write out what may follow a factor** — the six-token list above
  is the *statement* list and says nothing about this one. **And the first
  question is one earlier than either shape**: does the feature need a spelling
  at all? **Three times now none has** — ADR-0184's record at an `external`
  heading, which *inherits* `external`'s position; ADR-0240's
  `BindingType.writable`, where §6.4.3.4 NOTE 7 named the extension point
  itself; and ADR-0290's congruity rule, being about no position at all, so that
  one `Hash(key: string)` serves a map keyed at any capacity.
- **It contains Extended Pascal, and that containment is now the language
  itself.** ADR-0117 made the dialect a superset where ADR-0033's two modes were
  disjoint; ADR-0232 removed `stdKind` and `HasExtended` altogether, so there is
  nothing to compare and nothing to get wrong.
  `tests/dialect/inherits_extended.pas` is still the readable statement that
  every Extended Pascal construct means what it meant. A feature that adds a
  **required identifier** still has to write a paragraph in that file: §6.2.2.10
  puts one in a scope enclosing the program, so it takes a spelling away from
  any program that does not shadow it, and §6.1.3's shadowing is what makes that
  survivable (ADR-0128's `int64`).
- **A feature needs a reason of its own** — "the standard has it" is
  unavailable, since none governs this language — and should still be spelled
  the way a standard spells it wherever one does. It must be expressible in what
  `seed/*.ll` accepts, or the seed is refreshed first.
- **It is specified, and the specification is enforced.** `tests/spec/` takes
  `@afterschool:<clause>` beside the two standards' tags. The clause table is
  **generated from the document**
  (`tests/spec/clauses/extract_afterschool.py`), not transcribed, so a renamed
  clause fails the traceability gate rather than drifting; regenerate it when
  the spec gains or renames one. **A clause may also run ahead of the compiler**
  (AP 5.6, ADR-0189): it is marked `[not yet implemented]`, its triage row says
  `not-implemented`, and the traceability gate then *refuses* a scenario citing
  it — so the specification cannot come to claim a feature is there by way of a
  passing test. Nothing is marked today, and the marker is checked against the
  triage in both directions (ADR-0195).
- **No second implementation follows it.** `src/` was frozen at the conformance
  surface (ADR-0117) and ADR-0232 removed that surface, so *every* source is now
  in the position a dialect source was. What is left is the goldens, `verify/`
  for a new lowering, `tests/spec/` for a clause-shaped requirement, the
  stage-2/stage-3 fixed point and `llc-second-backend`. `doc/sop.md` §7 carries
  the gap, which is now the largest one here.

## Where things live

**The compiler is three files and they are §6.13 program-components**
(ADR-0233), a change of *linkage* and not of shape — the file order was already
a topological order, all 66 `forward` declarations being inside one stage, so no
mutual recursion had to be broken:

| Component | What is in it | Imports |
| --- | --- | --- |
| `selfhost/aptypes.pas` | the shared data — token kinds, the AST's node kinds and its variant record, the type and symbol records — the string pool, the character sink, `ErrorAt`, the type arena and `WriteTypeName`/`WriteOrdinalName` | nothing |
| `selfhost/apfront.pas` | the lexer, the parser, Sema, and **the data layout** — `LlSize`, `LlAlign`, `RecordLayout` and the rest were CodeGen's until ADR-0287 moved them, because a type's storage is a fact about the source program and only Sema may report one | ApTypes |
| `selfhost/compiler.pas` | CodeGen and the driver, and the main-program-block | both |

**Three, and the count is the argument**: it is the smallest number that makes
every build translate a module alone, translate a module that imports another,
and link the result — which is what closed `doc/sop.md` §7's row saying nothing
here linked a component and checked the result. Two would have missed the middle
shape, and that is exactly the shape the corpus was missing when ADR-0212's
defect got through. **The driver cannot move**: a module-parameter is bound to
nothing (§6.11.1 NOTE 6), so only a program can read a command line.

Each interface is a module-heading and nothing else (ADR-0079): what is not
written there cannot be reached. **A module initialises its own state** —
§6.2.3.6 commences a supplying module before the program-block — so the
assignments that used to open the main program body are now `to begin do` parts.

The **lexer** case-folds identifiers and reserves all 45 word-symbols. The
**parser** is recursive descent shaped like the ISO grammar (`expression` →
`simple-expression` → `term` → `factor`) — note a leading sign binds to the
whole *term*, so `-7 mod 3` is `-(7 mod 3)`. It bounds the depth of the tree it
builds at 1000 levels (ADR-0020), and **the spine-building loops count their
iterations toward the same limit**, because an operator chain is flat for the
parser but deep for Sema and CodeGen.

**Sema** owns scopes, type rules, type-denoter resolution, constant folding, and
— since ADR-0039 — the schema intern table, the one place a type's *identity* is
decided by something other than the denoter that built it. Since ADR-0053 it
also owns the interface table and the module records: an interface is not a
scope (§6.2.2.2), so it lives beside the scope stack, and a module's scope is
*kept* between program-components because §6.2.2.12 makes the heading's
defining-points the block's as well. Since ADR-0069 `checkDeclarations` walks
the constant, type and variable parts **merged by source position**, because
ISO/IEC 10206:1991 §6.2.1 lets them interleave and §6.2.2.9 then makes written
order the only correct one. A type-denoter is a `TypeExpr`, deliberately not an
`Expr`, and a declaration group shares one — the exception being a parameter
group naming a schema (ADR-0040), where each name gets its *own* type because
each reads its own descriptor.

The runtime is **four translation units**, each bounded by what it may depend on
(`runtime-isoc` above). `runtime/pasrt.c` holds anything not expressible in IR,
where `width < 0` / `prec < 0` mean "not given" and nothing else — a width the
program *wrote* is checked against §6.9.3.1's or §6.10.3.1's least value before
it gets there (ADR-0064). `runtime/pasrt_posix.c` holds what needs POSIX.
`runtime/pasrt_unicode.c` holds AP 6.4.15's Normalization Form C and grapheme
segmentation over tables transcribed from the Unicode Character Database —
**the database is fetched and never committed, the generated header is
committed** (ADR-0189, ADR-0190). `runtime/pasrt_task.c` is AP 6.4.16's channel
and AP 6.9.3.12's task set (ADR-0268), bounded by `<pthread.h>`, and it made
four of the runtime's globals `_Thread_local` — the open files, the live
handles, the armed deferred statements and the string arena with its cursor,
each a stack of what the current chain of activations owns and a task being a
second chain. ThreadSanitizer found the first on the first run of the first
two-task program, a defect no golden could hold.

Adding a language feature usually touches, in order: the token kinds and the
lexer → the node kinds and the parser → Sema → CodeGen → a `tests/` pair, plus
`runtime/pasrt.c` if it needs library support, and `selfhost/badparse/` or
`selfhost/badsema/` if it adds a diagnostic.

**The bootstrap closes**: the compiler compiles itself and stage 2 equals
stage 3 — in **every** module since ADR-0233, because comparing only the
program's would let a change in ApTypes or ApFront reproduce itself unnoticed.
`selfhost/producttest.sh` is what checks the built artefact; the other three
harnesses build a stage-1 compiler of their own in a temporary directory, so
`build/bin/pascalc` could be missing or stale with every one of them green.

It takes a **command line** — `pascalc [options] file.pas`, the flags being in
`-h` and in `Usage` (ADR-0083) — **and it reads one environment variable**,
`AFTERSCHOOL_PASCAL_PATH`, the one foreign name this compiler binds and the
reason it can be installed anywhere (ADR-0244): an `import` naming an interface
no `--import` supplied is looked for as `<directory>/<folded interface
name>.pas`, in the source's own directory, then in each `--import-path`, then in
each `:`-separated entry of that variable. The search is transitive and
post-order, so what it produces is the activation order §6.2.3.6 requires;
`--dump-imports` is how `tools/pascalcc` learns what to translate and link,
resolution finding an *interface* and not an object. The compiler is quiet on
success and writes `file:line:col: error: message` on failure, to `output`,
because no standard Pascal program has a second stream. The dumps go to standard
output; the IR goes to the file `-o` names and is written on every run, which is
what keeps the coverage sweep exercising the code generator on every file in the
corpus even though it reads none of it.

**How a Pascal program has a command line at all** is the part worth knowing.
§6.5.1 makes every program-parameter possess "the bindability that is
bindable", and §6.7.6.8's NOTE 2 makes `binding(f)` report the binding §6.12
made *before the program was activated* — so `binding(argk).name` is argument
*k*, and an unbound parameter is how the list ends, there being no other way to
count arguments (ADR-0081). That retires ADR-0033's constraint **for this
compiler only**: "ISO 7185 gives a program no access to its command line beyond
its program parameters, and those are files" is still every word true of ISO
7185, and this compiler is simply no longer written in it (ADR-0082). **The
argument count and the `--import` count are array bounds, and are one number**
(ADR-0158, ADR-0235): an import costs two words, so `argMax` is *derived* from
`maxImports`, and `argOver` is a parameter declared beyond the last usable one
and never read for its name — bound exactly when an argument had nowhere to go,
which is what turns "the list ended" into "the list ran out".

**The first three stages are checked by golden files, and by nothing else.**
`pascalc --dump-all` writes three sections (`=== tokens`, `=== ast`,
`=== sema`), and `selfhost/difftest.sh` used to diff them against a second front
end's — the strongest oracle here, retired for good by ADR-0232. **Know what
that means when you change a stage.** A golden agrees with whatever wrote it, so
a change that is wrong in the dump *and* wrong in the goldens you regenerate is
invisible. Regenerating a golden is a decision to be argued for in the commit
message, not a step.

**And no oracle here can contradict a *reading*.** The goldens agree with
whoever wrote them and `verify/` proves the lowering matches a model of the
lowering — so a misread clause is invisible to all of them at once, which is how
ADR-0072's set-packing deviation survived in four documents and a
purpose-written test. `.claude/skills/langspec-audit/SKILL.md` is the
substitute: independent readers given the behaviour and not the reasoning, told
to prove the compiler wrong from the standards text (ADR-0101).

**`tests/spec/` is the one suite whose unit is a clause rather than a program**
(ADR-0105). Every other oracle here starts from the compiler and asks whether it
still does what it did; a scenario starts from §6.8.3.9 and asks what the
compiler does about it, phrased as the requirement rather than as the lowering.
An unrecognised step is an **error**, since a step that silently does nothing is
a scenario that asserts nothing. It does **not** close the misreading blind
spot, the scenario being written by the same reader; what it changes is that a
reading is attached to the clause it claims to be about. **No text of either
standard is in this repository and none may be** — `doc/vendor/` is gitignored,
and `tests/spec/clauses/*.tsv` holds the clause numbers and headings a citation
needs. **The denominator is triaged** (ADR-0106) and coverage is counted against
the **testable** clauses; `run.py --coverage` prints the ratios and
`pending.txt` is the work queue, and no document pins either, because both move.
`tests/spec/README.md` has the mechanics.

**The one oracle nobody here wrote was the BSI Pascal Validation Suite**
(ADR-0086), 812 programs from 1982 tied to clauses of ISO 7185. It is **gone**
(ADR-0232), 25 of its programs using a word-symbol §6.1.2 now reserves — the
sharpest single cost of the dialect decision — and `unicode-conformance` is now
the only oracle here that nobody in this project wrote.

**The dumps are opt-in** — `--dump-tokens`, `--dump-trivia`, `--dump-ast`,
`--dump-sema`, `--dump-all`, `--dump-symbols`, `--dump-stmts`, `--dump-imports`,
`--dump-uses`, `--dump-words` — and each stops at the stage it names, reporting what its own
stage found and showing its result only when nothing was found. **`=== tokens`
belongs to `--dump-all`**, which has three sections and so needs them separated;
a single-stage flag writes its one section bare — a test comment asserted the
opposite and was believed until the golden was taken (ADR-0103). Four things
about them are true of every change rather than of one flag; the mechanism of
each is in `doc/design-digest.md`.

- **`tests/dumps/` is their corpus, and it exists because they had none.** Until
  ADR-0103 measured procedure coverage, no case in the tree passed any `--dump`
  flag — thirty-one walker procedures entered by nothing and no check that they
  did not crash. A dump case compares what the *compiler* writes to standard
  output, so it has its own harness (`tests/dumps/run.sh`); every case under
  `tests/` compares what the compiled *program* writes.
- **A dump is where a *tool* asks about a program** (ADR-0239, ADR-0246): a
  caller reading `--dump-sema` would be a second reader of Pascal-shaped output
  outside the compiler, the shape that broke `foreign-reserved` and that
  ADR-0229 and ADR-0230 moved `kind-exhaustive` off. `--dump-symbols` answers in
  **Pascal's** words and not any protocol's numbers and stops after the *parse*,
  an outline being what an editor draws while a file is wrong, and reports a
  formal `parameter` since ADR-0301, a completion list inside a body being
  nothing else; **`--dump-words` is the one dump not about the source at all**
  (ADR-0301), the word-symbols and required identifiers walked out of the
  lexer's table and the outermost scope, so a caller offering names to a person
  typing one holds no copy of either list; `--dump-uses`
  carries a defining-point and a type in one row, needs the `--import`s, and is
  **the one dump not guarded by `errorSeen`**, an editor asking where a name is
  declared exactly while the file does not compile.
- **Sema records a use where it resolves one**, not from a walk over the
  finished tree — ADR-0111's counter argument and ADR-0230's dispatch argument
  met a third time: a hand-written walker over the AST's variant record can miss
  a node kind in silence and no gate here can see that.
- `--dump-ast` runs **before Sema**, so it shows only what the parser decided;
  `--dump-sema` walks the same tree through the same walker with an `annotate`
  flag. Sharing the walker is deliberate: the shape is then the same question
  asked twice.

`selfhost/torture.pas` is deliberately **not** a valid program: it carries the
error paths and lexical corner cases a valid program never reaches, and is where
a lexical rule change goes. `selfhost/badparse/` is its parser equivalent, one
file per message because the parser stops at its first error;
`selfhost/badsema/` is Sema's, and is smaller because Sema *accumulates*. Add to
them when you add a message, and don't assume the corpus reaches a branch —
**count it**. Every time anyone has, something turned out to be uncompared: no
file had a tab, no file had a parse error, Sema reached barely half its
messages, and then sets, congruity, non-text files and the non-local goto each
had mutations survive a green suite (ADR-0022 to -0024, -0028, -0030 to -0032).
Don't look for a running total — the records disagree, because they are
immutable and the count moved on without them.

**CodeGen is the exception, and had to be** (ADR-0025). Two backends' assembler
text is not comparable — LLVM's printer is not a specification — so it is
checked by *running* what it produces against the same `tests/*.out` and
`tests/*.err`, and then by the stage-2/stage-3 fixed point. **That fixed point
cannot see a miscompilation of the compiler**, both stages coming from *one
binary*: a `clang` that got a corner of `compiler.pas` wrong would build a wrong
compiler that reproduced itself exactly, and every golden would agree, having
been written by it. `tests/checks/llc_check.sh` is what does — the compiler
built a second way, through `llc` at `-O0` and at `-O2`, required to translate
`compiler.pas` to byte-identical IR. It **skips without `llc`**, as
`verify-lowering` does without z3, because ADR-0085's claim is that the build
needs nothing of LLVM's; the `second-backend` CI job installs it and refuses to
pass by skipping. Don't file it as "a second reader of the IR" — `llc` and
`clang` share LLVM's parser and verifier and reject the same module with the
same message, so what it varies is the *backend configuration*.

Five things about the emitter are true of every change to it; the rest is in
`doc/design-digest.md`.

- The emitter is **sequential**, with no instruction list: it never returns to a
  block it has left, so the order it emits in is the order text can be printed
  in. Don't add buffering to "fix" something. Activation records are the one
  type given a name rather than printed inline, because one would otherwise be
  spelled at every variable access.
- **An `alloca` is only safe where the emitter reaches it once per activation**
  — a prologue (ADR-0102). An `alloca` written for a statement that may sit
  inside a loop is claimed again on every iteration, and at `-O0` the stack runs
  out. Storage that must survive the iteration is a **frame slot**; storage that
  need not is an **SSA value**, which dominates the loop because it is defined
  before the loop's blocks exist. ADR-0043 wrote this rule for `new` and the
  `for` statement broke it in both its forms for a long time with the whole
  suite green, because `-O2` hoists such an alloca away —
  `tests/for_nested_stack.pas` and `tests/extended/forin_nested_stack.pas` are
  the two cases that can see it, and each needs a `name.opt` sidecar saying
  `-O0` to mean anything at all.
- **A string temporary lives for one statement, and CodeGen is what says so**
  (ADR-0111). Which statements need the arena reset is a *counter* the
  allocating arms of `EmitString` bump, not a predicate over the tree, which
  would be a second opinion free to drift. **Add an arena producer and you must
  bump the counter** — nothing checks it (`doc/sop.md` §7). It was a ring that
  wrapped in silence until a security audit's follow-up probe; `a + a = b + b`
  over two 512K strings called two different values equal and exited 0.
- The layout rules are written out (`LlSize`/`LlAlign`) — **in ApFront since
  ADR-0287** — because there is no `DataLayout` to ask, and are needed in
  exactly two places: a whole-variable copy's length and the size `new`
  allocates. `fileSize` must equal `PAS_FILE_SIZE`; `irtest.sh` checks it,
  because the two files cannot include one another. **The module states its
  `target datalayout`** so the assembler lays things out the way those two say
  it does; it did not, until a set in a record segfaulted (ADR-0028). Don't drop
  the line.
- `WriteTypeName`/`WriteOrdinalName` write through the `Put` sink, which either
  goes to output or into `msgBuf`. A trap message is a string constant *in the
  generated program*, so it has to be assembled before it is emitted — and a
  second copy of those routines would be a copy free to drift.

## Pascal semantics already encoded (keep them)

Each entry is the rule, the clause, the record and the case that pins it; the
mechanism behind any of them is in `doc/design-digest.md`.

`mod` yields a non-negative result (not C's truncating remainder); `and`/`or`
short-circuit; `/` is always real division; `for` evaluates its limit once and
tests `= limit` before stepping so the last iteration cannot overflow; a
one-character string literal is a `char`; and a statement may be **empty**
(ISO 7185 §6.8.2.1, ISO/IEC 10206:1991 §6.9.2.1 — *not* §6.8.1, which is the
goto-target rule in the first and `Expressions — General` in the second), which
means every token that can *follow* a statement also starts one — `;` and `end`,
but also `else` and `until`, so `if c then ; else s` is legal, and `otherwise`
as well, §6.9.3.5 making the separator before a case-statement-completer
optional. `tests/empty_statements.pas` and
`tests/extended/case_empty_otherwise.pas` pin the two halves.

**A number read takes the longest prefix that *is* a number** (§6.9.1 c) and
d), ADR-0076), which is one character more than a file's lookahead can decide:
`1.` is the integer 1 and then a point, `.5` is not a number at all, and `2e+`
is the integer 2 and then two characters. `struct pas_file` carries a
two-character give-back, and the order is a stack because the sign has to come
back out before whatever followed it. `tests/readlongest.pas` includes `8.5.5`,
which was already right, so a fix in the wrong direction fails too.

**`(.` and `.)` are `[` and `]`**, not a second spelling — §6.1.9 says "the
corresponding tokens or separators shall not be distinguished", so nothing after
the lexer is told which arrived and `a[2.)` is a legal subscript. Only the
*reference* tokens and the alternative `@` are implementation-defined there;
every other alternative representation is required, which is the same sentence
that requires `(*` and `*)`. `@` is refused, in `torture.pas`.

An array subscript outside its bounds traps (ADR-0017), and a `for` loop over an
array's own bounds optimises the check away; where the bounds arrived with the
actual (ADR-0040) the message is built by the runtime and says the same words.
Storing outside a subrange traps, and so does a `case` whose selector matches no
label (ADR-0018) — unless it has an `otherwise` (ADR-0033) — a dereference of
`nil` (ADR-0019), the reading of an optional that has no value (ADR-0123, and it
is spelled `^` for exactly that reason), and a set whose members are not values
of the target's base type (ADR-0028). That last check fires at the **store**,
because a constructor does not know what it is being assigned to — except for
§6.8.7.4's set-value, which names its type and is checked where it is written
(ADR-0066); `tests/extended/trap_setvalue.pas` is the program with no assignment
in it.

**A subrange's bounds may be discriminants, and the check reads them.**
§6.2.3.8 b) evaluates a bound written in a variable-declaration or a
type-definition at the block's commencement, so `var x: 1..m` is legal in a
procedure, and `CheckedForSubrange` calls `BoundValue` for each end rather than
reading the two numbers on the type, which are placeholders there (ADR-0133).
Two things follow that are easy to get wrong: the comparison moves to i32 where
a bound is dynamic, that being the width a discriminant is loaded to, and the
trap message names the bounds as **values**, a bound the block evaluated having
no spelling in the source. An **empty** such subrange is reported at the
declaration, §6.4.2.4's other requirement having nowhere else to be said.

**A direct-access file is at most as long as its index-type** (§6.4.3.6,
ADR-0134). Only a write at the end grows a file, so the check is in `put` and
nowhere else: `update` overwrites in place, a seek past the end is already
refused, and seeking to the append position of a full file stays legal right up
until something is written there.

`date(t)` traps when the day, month and year of a `TimeStamp` are not a calendar
date (§6.7.6.9) — February the 30th, and a year outside 1..9999, that bound
being what keeps the result fixed-width (ADR-0065). The six subranges of
§6.4.3.4 do the rest of the enforcement.

**ISO error conditions trap** (ADR-0014, ADR-0015). Integer `+ - *` and `sqr` go
through `checkedArith` and stop the program on overflow rather than wrapping —
they carry no `nsw`. `chr` outside 0..255, `succ`/`pred` at the ends of their
type, `div` by zero, `INT_MIN div -1`, and `trunc`/`round` of a real outside the
integer range (or of a NaN) all reach `pas_runtime_error` (stderr, exit 1) —
**and every trap names its position** (ADR-0293): `... at file:line:col` after
the message, the construct's own. An inline check passes it as three arguments;
a call into a runtime routine that can trap is bracketed with
`EmitAt`/`EmitAtDone`, a store and a clear of the runtime's thread-local
`pas_at`, so **a new call into a routine that can trap needs the bracket** or
its message names nothing — never the wrong place, which is what the clear is
for. The integer type is **-maxint..maxint**, narrower than the `i32` behind it,
so `INT_MIN` is not a value of the type and a literal above `maxint` is a
compile-time error.

**Annex D is the checklist** (ADR-0077), and probing it found six errors that
were answered with a value: `ln` of a number that is not positive, `sqrt` of a
negative one, `x/y` with a zero divisor for real *and* complex, `i mod j` with j
negative, and `dispose` of nil. Two are worth remembering. **`mod` is where the
compiler disagreed with itself**: §6.7.2.2 makes a divisor that is zero *or
negative* an error, Sema's folder said so for a constant, and the emitted code
did not — the run-time check now uses the folder's words, which makes one rule
one answer and turns `rules.py`'s `j > 0` precondition from an assumption into
something the compiler enforces. And **`dispose` of nil was checked only for a
schema domain**, where stepping back over a tuple header made it a free of an
address never allocated; elsewhere it was a *harmless* error, and harmless is
not the test §6.6.5.3 sets.

**A `for` statement's control variable must be declared in its own block**
(§6.8.3.9, ADR-0077) — not merely "a variable", so a procedure looping over the
program's `i` is refused, and the message names where it must be declared rather
than saying "must be a variable", because a value parameter *is* one. **And it
may not be *threatened*** (§6.8.3.9, ADR-0089) — assigned to, passed as an
actual `var` parameter, read into, or reused as the control variable of a nested
`for`. §6.9.4's list of threats is the one ADR-0046 already walks for a
protected parameter, so `Threatened` gained a second reason to answer yes; the
reason is keyed on the **symbol**, because a procedure's own local `i` is not
the `i` an enclosing block loops over. The clause also reaches "any
procedure-and-function-declaration-part of the block", where the threat may sit
in a procedure that is **never called** — so a threat made from a nested block
is *recorded on the symbol* when it is seen and the for-statement asks
afterwards, which works because `CheckBlock` walks every nested body before the
statement part that loops. Ask the threat questions only of a name that could be
a control variable, or a loop records a threat against itself and reports it.

**A variant part's labels are exactly its tag-type's values** (§6.4.3.3,
ADR-0096) — no value outside the type, and none of the type left unnamed. This
is the one that surprises: `case tag: integer of 1: …; 2: …` is **refused**,
because `integer` has other values, and the spellings that work are a covering
tag-type (`type sel = 1..2`) or `otherwise`. It was audited because it looks
over-strict, and BSI's own DEV073 header settles it — that test was
*reclassified from CONFORMANCE to DEVIANCE by DP7185*. An `otherwise` discharges
coverage and never membership.

**A string-type is four properties at once** (§6.4.3.2, ADR-0090): packed, an
index-type that is an integer subrange, a smallest *value* of 1 — not a smallest
ordinal, which is why an enum index fails even when `ord` of its lower bound is
1 — and a component that is `char` and not a subrange of one. ISO 7185 added a
largest value above 1; ISO/IEC 10206:1991 §6.4.3.3.2 drops that clause and
nothing else, and this language takes the later reading, which is what lets the
compiler compile itself, its schema strings having a discriminant bound.

**Packing decides set compatibility and does not propagate** — two rules that
read alike and are not. §6.4.5 c) makes two set-types compatible only when they
agree on packing, while §6.7.1 leaves a *set-constructor* uncommitted so
`p := [true]` fits either (ADR-0093). §6.4.3.1 then says packing affects one
type's representation only, so §6.6.3.3's "component of a packed variable" is
the **immediate** container: `pa[1].f` over a `packed array of rec` is legal
because `pa[1]` is an unpacked record (ADR-0099).

**Where a goto may land is three conditions, not a prefix test** (§6.8.1,
ADR-0094 and ADR-0101). Only a compound-statement, a repeat-statement and the
`otherwise` completer hold a *statement-sequence*; a branch of an if, a loop
body, a with body and a case arm are each a single statement, so a label in one
is reachable only from inside it. The completer has no node of its own, so
`stmtPathRec` carries a flag rather than the rule asking a node's kind.

**The required identifiers are symbols in a scope enclosing the program**
(§6.2.2.10, ADR-0097), so `type integer = char` takes effect and §6.2.2.9 can
see an applied occurrence of one. `LookupUser` answers nil for them, which is
the convention every "did the program declare one?" branch was written against.
A name that resolves to something **not invocable** must not fall back to a
builtin lookup by spelling — that is §6.2.2.11, and it let `var ord: …` and
`ord('a')` mean two things in one block (ADR-0101). The required *procedures*
are still not symbols.

**A record type is a region** (§6.4.3.3, ADR-0098, ADR-0112): inside a record's
denoter a name spelled like one of its fields denotes the field, so `^fred`
beside a field `fred` names no type — and neither does `a: fred`,
`array [fred]`, `set of fred` or `fred(3)`. Asked of the *denoter*, because the
field does not exist on the type yet; of the **whole** denoter, because the
region is the record and not the text before the point; and **before** the
lookup, because a field's defining-point is nearer than the region enclosing the
program. One function, three call sites; a *constant* occurrence is still not
asked (`doc/sop.md` §7). **Declarations interleave by source position** —
constants, types, variables *and procedures* (ADR-0100) — which is what lets
§6.2.2.9 see a body using a variable declared after it.

**Every file variable is bindable, and the word `bindable` decides nothing about
a file** (AP 6.5.1, ADR-0299). §6.4.1 puts the word in a type-denoter and
§6.7.5.6 made `bind` of a file without it a dynamic-violation, so a `text` in a
heading, a `text` field, a `text` element and `p^` for `p: ^text` were all
refused or accepted by accident; `bind`, `unbind` and `binding` now ask only
`IsFile`. What the word still decides is a **non-file**: `bindable integer` is
accepted, refused as a `for` control variable, and refused by `bind` by design.
This is the first dialect decision that admits a program the standard requires
rejected rather than adding a construct; the test it passes is AP 6.0.1's, that
no conforming program changes meaning.

A check is omitted only where its absence is *proved* sound — the `for` step and
unary negation are unchecked, and `verify/` carries the theorems saying they
cannot overflow. Don't add a check there, and don't remove one elsewhere. Most
of these are not merely tested — they are **proved** in `verify/` for every
input. Changing one breaks a theorem, not a sample.

## Formal verification (`verify/`)

`verify/verify.py` proves each lowering rule against a property-style statement
of ISO 7185 using Z3, then cross-checks the real binary at the adversarial
points. It runs under `ctest` and skips when z3 is missing
(`pip install z3-solver`). ADR-0013 has the rationale; `verify/README.md` has
the mechanics.

Three things to know before touching it:

- **`lowering.py` is a model of the code generator and must be maintained with
  it.** A drifted model keeps passing and proves nothing. When you change a
  lowering, change the model in the same commit.
- **Specifications state properties, never computations.** Writing `iso.py` so
  it computes the answer the way the compiler does would make every proof
  circular and the circularity invisible.
- **A `KNOWN_GAP` that starts holding fails the build.** That is intentional: it
  means the compiler was fixed and the catalogue is now describing a compiler
  that no longer exists. Flip it to `MUST_HOLD` in the same change.

New arithmetic, conversion, or comparison lowering should arrive with a rule.
The catalogue currently has **no known gaps** — the rule count is in `README.md`
and the run prints it — so any gap that appears is something this change
introduced. Don't add a rule that restates the lowering: a check whose ISO
condition *is* the emitted test (the nil check) proves nothing and dilutes what
"no known gaps" means, so cross-check or sanitiser-check those instead and say
which in the ADR.

Keep bounds **symbolic** where the lowering treats them symbolically. The array,
subrange and `succ` rules quantify over the bounds as well as the value, so they
say something about every array and every enumeration rather than about a
sampled one; the integer-only `succ` rule they replaced could not have caught
the generalisation because it had `maxint` written into it.

A rule may also state why a check is *unnecessary* (`negation-cannot-overflow`,
`accepted-index-selects-the-right-element`). Those are the ones that pay: the
index rule failed on first run and made Sema reject arrays spanning more than
`maxint` values. When a rule's precondition names a restriction the compiler
enforces, the check and the assumption are the same statement written twice, and
neither can drift without the other failing.

For floating-point rules, state the specification inside FP theory
(`fpRoundToIntegral`, `fpLEQ`) rather than via `fpToReal`: mixing FP and Real
does not solve in practice, and the same property expressed FP-internally proves
in under a second (ADR-0015).
