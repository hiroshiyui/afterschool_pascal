# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Afterschool Pascal is a Pascal dialect that exists to meet modern computing
requirements, and that is the top policy** (ADR-0109, ADR-0232). It is a
dialect in the sense Turbo Pascal and Free Pascal are: the syntax is Pascal,
and no standard governs it. When two goals conflict, this is the one that
settles the order.

**It is also the test for a feature.** Not "does a standard have it" — none
governs this language — but *does a program someone would actually write today
need it*. ADR-0109 names the areas: networking, internationalisation,
concurrency, and memory safety as a property of the language rather than a
convention. `doc/roadmap.md`'s "What a daily program still cannot reach for"
was the running inventory of what is missing, and **as of v3.2.0 it is empty**:
all six library gaps and both language absences were built, and the chapter
moved to `doc/history.md`. What the roadmap keeps in its place is the lesson,
which is worth more than the list was — two of the eight rows said why they
were blocked and both reasons were wrong, so a row there should be a report
and not an estimate.

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
mode to be put into.

**That decision was taken with its cost measured** and the numbers are in
ADR-0232: 25 of 172 ISO 7185 cases become inexpressible (§6.1.2 reserves
thirteen word-symbols a conforming program may use as identifiers, so a field
called `value` is now a syntax error), and five oracles retire — the BSI suite
among them, which was the only third-party corpus this project ever had. It was
raised, measured and decided. **Don't reopen it**; note it in one line if a
decision genuinely turns on it, then proceed.

There was a second C++ implementation in `src/` from ADR-0108 — a **reference
front end** and not a compiler: lexer, parser and Sema only, no code generator,
no LLVM. It existed so `selfhost/difftest.sh` had two answers to compare, and
was deleted with difftest (ADR-0232). Read a mention of C++ below as naming
that, or as history; the code is at tag `v0.1.0` and in the log.

Bootstrapping was an earlier goal and is done; what survives of it is a
constraint on the *order* features land in — a feature must be expressible in
what `seed/*.ll` accepts, or the seed is refreshed first.

## Commands

```sh
# configure -- no LLVM_DIR: nothing links libLLVM since ADR-0085
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release   # needs clang; no C++, no LLVM
cmake --build build -j

ctest --test-dir build --output-on-failure
ctest --test-dir build -R control --output-on-failure   # a single case, by name
tests/run_test.sh tools/pascalcc tests/control.pas   # without ctest
selfhost/irtest.sh build/bin/pascalc-seed   # what pascalc *builds*, and stage 2 = stage 3
selfhost/producttest.sh build/bin/pascalc build/lib   # the built pascalc itself
cmake --install build --prefix /opt/apascal  # bin/, lib/, lib/afterschool/
seed/refresh.sh                             # regenerate the seed (release only)
tests/checks/seed_current.sh                # is the committed seed this source's? (release only)

tools/pascalcc tests/hello.pas -o /tmp/hello && /tmp/hello
tools/pascalcc -S tests/hello.pas -o /dev/stdout   # inspect IR
```

**There is one compiler, and it does not link.** `build/bin/pascalc` is the
three program-components linked together, and it writes IR and stops — no
standard Pascal program can start an assembler. `tools/pascalcc` is where the
missing half lives and is what every harness is handed; anything wanting an
executable goes through it. `build/bin/pascalc-seed` is the same compiler built
from `seed/*.ll` (matched by a glob: one module until the next refresh, one per
component after it), and exists only to bootstrap: what ships is always built
from the source in the tree (ADR-0085).

**The compiler's own build is an ordinary `.components` case.**
`selfhost/compiler.components` lists the two modules, one path per line, in
dependency order — the same sidecar `tests/run_test.sh` and `selfhost/irtest.sh`
read for a test case — and CMake, `seed/refresh.sh`, `tests/checks/*.py` and the
CI seed job all read that one file. The build order is written down once
(ADR-0233).

Adding `tests/foo.pas` + `tests/foo.out` requires **re-running `cmake`** — cases
are registered by a `file(GLOB)` at configure time, and `tests/`,
`tests/extended/` and `tests/dialect/` are globbed separately. The split used
to say which standard each was compiled under; since ADR-0232 it says only
which names the ctest cases have, and buys `tests/dialect/` the per-case
`TIMEOUT` a program that opens a socket needs.

A case may carry sidecars named after it: `foo.err` (expected diagnostics, and
a non-zero exit is then required), `foo.warn` (expected *warnings*, for a
program that compiles — and a case **without** one must produce none, which is
the half that keeps a warning added later from appearing on dozens of green
cases, ADR-0272), `foo.in` (standard input), `foo.epoch` (a
fixed `SOURCE_DATE_EPOCH`), `foo.components` (§6.13's other program-components,
one path per line), `foo.opt` (an optimisation level), and — since ADR-0244 —
`foo.importpath` and `foo.importenv`, which name *where to look* rather than
what to read, and so assert that the compiler found a component it was never
told about. **`foo.std` was one
and is gone**, along with `selfhost/compiler.std` and the second field of a
`.components` line: there is one language and nothing left to name.
`foo.opt` is the newest and the one to reach for least: the corpus compiles at `-O2` and should go on doing so, but a defect
in *storage* is invisible there, LLVM being free to hoist an alloca whose
address does not escape — see ADR-0102 and the two `-O0` cases it added.

`tests/dumps/` is a corpus apart, with its own harness and its own sidecars
(`foo.dump`, `foo.flags`, and since ADR-0246 `foo.components` and
`foo.status`) — the `--dump` flags write to standard output, so
what a case there compares is what the *compiler* wrote and not what a program
did (ADR-0103). **`lsp/` is a second one**, and further out: `lsp/pasls.pas` is
a language server written in the dialect, built by `lsp/build.sh` into a binary
an editor can be pointed at rather than into a temporary directory, and checked
by `lsp/run.sh` replaying `lsp/sessions/*.jsonl` — a *conversation*, framed by
the harness and compared byte for byte (ADR-0236). **It speaks two protocols**
(ADR-0241): the same binary answers MCP over stdio when given `--mcp`, one
message to a line instead of `Content-Length`, with two tools built on
`--dump-symbols` and on a compilation. A session says which by a `name.mcp`
marker. It answers six questions about a document — the diagnostics, the
outline (ADR-0239), go-to-definition and hover, which are one question asked
twice and come from one `--dump-uses` (ADR-0246), and folding and selection
expansion, which are a second such pair and come from one `--dump-stmts`
(ADR-0258) — and they do not cost the same: the outline and the two extent
answers stop after the parse and need no `--import`, where the diagnostics and
the two `use` answers run Sema and do. **Nothing waits on a compile that is
already stale**: the server drains the messages that have arrived and keeps
only the last `didChange` per document, which took four queued edits of a
22 900-line source from 780 ms to 340 (ADR-0257). The corpus sweeps reach it
through a second root rather than through the glob: `coverage.py` names it,
`variant_check.sh` finds it, `build.sh` honours `AFTERSCHOOL_PASCAL_OPT`, and
`heap-balance` drives `lsp/run.sh` instead of `run_test.sh` — which has to take
`PASHEAP_BALANCE` out of the environment **twice**, `pascalcc` building the
server and the server starting `pascalc` once per document.

`tools/pascalcc` shells out to `clang` to assemble and link (ADR-0009), and
finds `libpasrt.a` beside the compiler; `AFTERSCHOOL_PASCAL_RUNTIME` and
`PASCALC` override where it looks for each, which is how CMake points the tests
at their own build tree. **Two variables add flags and they are not
interchangeable**: `AFTERSCHOOL_PASCAL_CFLAGS` reaches every `clang`, which is
what a sanitizer needs and what makes `-lssl` an input clang complains about
once per translation, and `AFTERSCHOOL_PASCAL_LDFLAGS` reaches the final link
alone, after the runtime, which is where a library a program *binds* belongs
(ADR-0264).

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
half-checked tree.

This was written about the C++ code generator and holds unchanged for the
Pascal one it was ported to; that compiler is gone (ADR-0085) and the contract
is the thing that survived it. Where a document here still names a C++ file — several
entries in `doc/design-digest.md` do — read it as naming the component: the port
is line-for-line enough that the reasoning transfers, which is what ADR-0022 to
ADR-0024 were for.

Most of what Sema hands over is *per node*. Since ADR-0053 one thing is not:
`Sema::activeModules()` is a whole-program answer — which modules supply the
main-program-block, in the order their activations must commence. It is on the
same side of the contract as everything else (Sema decided it, CodeGen only
emits calls in that order), and it is worth knowing that the contract has a
shape other than an annotation on a node.

Errors: the parser sets `aborted` when it cannot make progress, and every
production and loop tests it — Pascal has no exceptions, so what was
`ap::ParseAbort` in the C++ became a flag (ADR-0023). Sema and the lexer instead
accumulate into
`Diagnostics` so one run reports many errors.

**Not every diagnostic is one** (ADR-0272). `WarnAt` stands beside `ErrorAt` and
**the only difference is `errorSeen`** — same format, same stream, same exit
status, and no `errorCount` either, that one naming a schema's domain (§6.4.7).
Three things govern a warning and each was learned by it failing: it is written
only when `warnOn`, which every `--dump` flag clears, because a dump has a
reader parsing a fixed grammar and `kind-exhaustive` stopped on the first
warning ever written; it is written only when nothing has been reported, because
a name that did not resolve records no use and five variables in
`tests/dialect/slice_escape.pas` were called unused underneath the five errors
that are the point of the file; and it is written only for `curFile = mainFile`,
because Sema checks a whole imported component and the compiler otherwise warned
about ApFront once per importer. The one warning today is **a local variable
declared and never used**, which found twelve dead declarations in this compiler
on its first run.

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
  every module) answers with a *global* without walking, because it has exactly
  one activation. Calling a procedure at level `L` passes the frame at level
  `L-1`; for a *recursive* call that is the caller's parent, not the caller.
  `tests/nesting.pas` is what distinguishes a correct implementation.
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
  never `isStructured()`, which is what refuses assignment, comparison, value
  parameters and function results for it (ADR-0021). **And anything holding a
  file, at any depth** — §6.4.6 a) is two conditions and the second is
  `ContainsFile`, which is why `Assignable` asks that and not `IsFile`
  (ADR-0150). Reading only the first made `b := a` between two records holding a
  `text` a memcpy of the file's own storage, and the block then closed one
  `struct pas_file` twice. **Ownership and representation are two questions and
  were one name until ADR-0181**: `IsAffine` is what `ContainsFile` asks — a
  file, a handle, and the dialect's `owned ^T` — while `IsOwned` is what
  `IsMemory` asks, and an owned pointer is not in it, its value being one word.
  A new affine kind joins the first and not the second. **And an affine type
  needs a move to be usable**: `take` (ADR-0182) is the one value an owned
  pointer may be assigned, in 6.4.12.2's position, and its source is emptied
  before the target's address is taken -- which is what stops a target reached
  through the source from building a cycle nothing owns.
  **A second name for an owned value exists in exactly one form and cannot
  escape** (ADR-0201): a `var` parameter bound to `o^` is a borrow for the
  duration of the call, and no pointer can ever name it, because Pascal has no
  address-of and `new` is the only producer of one. Unformable rather than
  checked — nothing in the compiler knows it — so a feature that adds a way to
  form such a value takes the property with it silently.
  **The same split, a second time, for text**: `IsVarString` asks whether
  §6.4.3.3.3's *rules* apply and `IsStringRep` asks whether the value is a
  length and that many bytes, which a text and a variable-string answer alike
  (ADR-0191). Six sites are about storage and ask the second; everything about
  indexing, substrings and the padded comparison asks the first. Asking one
  where the other was meant is how a text got `icmp` on an aggregate.
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

Twenty-seven gates make that mechanical — **count the rows below rather than
this sentence**, which has now been wrong by four in one direction and by
three in the other, the last reader to add a gate having incremented a number
that was already too big — and each fails in **both**
directions: a claim that stops being true is as loud as one that was never
true, which is `verify/`'s `KNOWN_GAP` rule (ADR-0013) applied to a dozen
catalogues. `benchmark` is that rule applied to a *duration*, and fires on a
stage that got faster for the same reason — a stage that suddenly costs a
third less is a stage that stopped doing something. Five
more stood here until ADR-0232 removed the surface they asked about: `difftest`,
`dialect-containment`, `annex-b`, `reserved-words` and `dialect-build` are all
questions about a conformance mode, and there is none. Three
say in the table that they are one-directional in part: `line-coverage`, which
is two ratchets — though the pairing half of it, that every decision emits one
counter per direction, fails in both; `buffer-headroom`, which watches a bound
rather than a claim; and
`spec-clause-traceability`, which does fail when a citation disappears and
deliberately does not when one appears:

| Gate | Catalogue | Asks |
| --- | --- | --- |
| `diagnostic-coverage` | `tests/checks/unreachable_diagnostics.txt` | is every message named by a golden? — and it could not see a third of them (ADR-0273). It found a message with `write(?:ln)?\('([^']{20,})'`, which needs an ordinary character after the opening quote; §6.1.7 writes an apostrophe inside a literal as **two**, and this compiler's commonest diagnostic writes the offending name first and starts mid-sentence — so `writeln(''' is already declared in this block')` matched nothing and **255 of 724 messages were invisible**, reported as covered by never being asked about. The literal is now *scanned* rather than matched, to the first quote that is not doubled. It found 26 diagnostics no golden named; 23 have cases and three are argued unreachable. Reading a Pascal literal with a regex is the shape, not the instance |
| `procedure-coverage` | `tests/checks/uncovered_procedures.txt` | is every procedure entered by a case? (ADR-0103) — and **did the compiler survive every invocation** (ADR-0269): the sweep read the lines reached and never what the child did, so a compiler that stopped part-way wrote a short dump and was counted as having run. A crash is not a rejection and the exit status cannot tell them apart, a third of this corpus being written to exit 1 — what separates them is a negative return code, or `runtime error:` at the start of a line of *standard error*, the compiler's own diagnostics going to `output`. Mutating `Tokenize` to store 3 into a `1..2` names 1426 of 1435 invocations where the whole suite was green before |
| `line-coverage` | `tests/checks/line_coverage.txt`, `tests/checks/branch_coverage.txt` | is every *statement* run by a case, and is every *branch* taken both ways? — two ratchets, so both fail in one direction only, and one sweep, the sweep being the expensive half. ADR-0104 counts a statement keyed on its **line**, which is blind to three ordinary shapes: two statements on one line, so `if c then a else b` is covered when either arm runs; a decision with no else-part, whose false side has no statement at all; and a short-circuit operator, whose right operand is an expression. ADR-0274 emits a second counter on each edge of every decision the *source* writes — an if, a while, a repeat, and each `and`/`or` — keyed on line **and column**, since two decisions on one line is the whole complaint. **784 of the 853 directions never taken sit on lines statement coverage calls covered**, and none of those decisions was unreached: every one was evaluated and only ever went one way. A `for`'s test is generated from its bounds and a runtime check is the compiler's branch rather than the program's, so neither is in it. The ratchet cannot see a **miswired** counter — making both edges of an if report the same direction collapses the pair, drops the denominator from 10 100 to 6995 and reports an *improvement* — so every site is separately required to emit one counter per direction, read from what the compiler wrote and not from what the corpus ran |
| `foreign-reserved` | `ReservedForeignName` in the compiler | is every global the emitter names still refused as a foreign name? (ADR-0121) — LLVM rejects a redeclared global, so a collision is an error about a file nobody wrote. It reads the emitter's own literals **and compiles a probe to harvest the `@names` its IR actually contains**, then offers each back to the compiler and requires a refusal. The second half is ADR-0144's: `@frame1` is `AppendLit('frame')` plus a counter, so no literal in the source holds it and a check over literals could never have seen it |
| `kind-exhaustive` | `tests/checks/partial_cases.txt` | does every dispatch over an enumeration name every constant? (ADR-0124, ADR-0145, ADR-0221) — a case-statement with no matching label *stops the program* (ADR-0018), so a constant left off is a compiler **crash** and not a wrong answer. No other gate can see that: a missing arm is not a statement, a crash writes nothing for a golden to hold. It has shipped twice — `tyString`, then `tyOptional`. ADR-0124 read one enumeration; ADR-0145 reads all of them — **eleven**, `stdKind` having gone with the conformance modes — and 59 case-statements, 23 of which name a subset and each of which records **how many of how many** — so a constant added to an enumeration fails every partial case over it, which is exactly the moment those two needed a reader. **ADR-0221 added the other half**: not every dispatch on a tag is a case-statement, and 37 are if-chains — `EmitString` cannot be a case at all, its arms testing a node's kind *and* its type in one condition. The failure there is the **opposite** one: a constant left off a case-statement is a crash, and a constant left off a chain takes the trailing `else` in silence, which is why a bare `else` does not excuse a chain where `otherwise` excuses a case. A chain is selected by the shape `x^.kind = c` and nothing else, so the parser's `if Check(…)` ladders are outside it by construction. Adding one node kind now fires **33 entries**. **ADR-0229 moved the case half off the source parser and onto the compiler**: `--dump-dispatch` writes every case-statement whose selector is an enumeration, with the constants its labels name, the ones they miss, and the constants no case names at all. A regex could not know which types are enumerations or how many constants each has — it recognised one by a *naming convention* — and the two readers were compared before the old one was deleted: 60 sites, same routine, enumeration, ordinal, `N of M` and missing constants on every one. 85 lines of Pascal-parsing regex went with it. **ADR-0230 moved the if-chain half too, and the gate now reads no Pascal at all** — 542 lines to 384. A chain is a *shape* and not a node, so Sema records every if-statement with its else-part and every tag test in a condition, and a head is an if that is no other's else-part. The dump reports the **field** each chain reads, which is what selects a dispatch from a lookahead: `e^.kind = nkVar` asks a value for its own kind, `t = tkSemi` asks whether a token happens to be a semicolon. ADR-0221 picked that scope by matching the text `^.kind` and so picked it by accident — its "three enumerations qualify" sentence described what the regex could see, and the criterion admits one more. The compiler finds 70 chains and 42 read a tag, against the regex's 38: the three it adds within the old scope are chains the text match simply missed |
| `predicate-kinds` | `tests/checks/predicate_kinds.txt` | what does every type predicate answer about every kind of type? (ADR-0194) — the row above reads a `case … of` and **nothing else**, and three defects in three increments lived in a *predicate* instead: `IsMemory` asking `IsVarString`, so a text was taken for a register value and the relational operators emitted `icmp` on an aggregate; the code generator's comparison dispatch; and `EmitAssign` choosing the string store with `IsStringType`, so a text target fell through to a schema tuple-comparison and stopped the program. None is a case-statement, and all three were found by writing a program that used the new type. `--dump-predicates` asks each of the 39 `function Is…(t: typePtr): boolean` about a fresh `NewType(k)` for each of the 21 kinds; `N of M` is the mechanism, as `partial_cases.txt`'s is — adding a kind moves M on all 39 rows, so each is a question nobody was asked the last three times. **A prompt and not a proof**: it records what the answers *are*, and a wrong cell written in passes. Two halves like `buffer-headroom` — the compiler answers, and the *source* says which predicates exist, so one added without a row fails rather than passing unseen. **The row that hides a defect is a correct one**, which is what `--like OLD NEW` beside it is for (ADR-0198): a text is not a string-type, so the guard asking `IsStringType` where it meant *the string path* is green in the catalogue, and `--like` lists every predicate true of the kind the new one resembles and false of the new one, with every call site of each — three predicates, 42 call sites, all three defects among them. A query and not a gate; the resemblance is a fact about why the kind was added and has to be named |
| `ast-fields` | `tests/checks/ast_fields.txt` | is every pointer field of an AST node written before it is read? (ADR-0222) — the AST is the **only** variant record here, `case kind:` appearing once in the compiler's 36,000 lines, and Pascal gives a variant record no member initialisers: a field of the arm the tag selects holds whatever `new` returned. Two things write them and the split is *who fills the field* — `NewNode` clears the 88 Sema fills, the construction site assigns the 50 the parser fills — and it was written down nowhere a reader could check. 135 assignments over 70 sites, and the catalogue is **empty**, which is the finding: the convention is not merely a convention, it is universal |
| `variant-check` | ADR-0118's guard, and the corpus | is every node read through the arm its tag selects? (ADR-0223) — §6.5.3.3 makes a wrong-arm read an error and §3.1 lets a processor leave it undetected, which this compiler did in itself: ADR-0118's check existed and was a *dialect* rule, and `compiler.std` said `extended`. ADR-0223 answered that by building the compiler a second way to arm the guards; ADR-0232 removed the modes, so the guards are in whatever this compiler emits and what is left is the sweep — compile the compiler with itself, then read the corpus with the result, which is 765 sources carrying 3144 guards as this is written and moves with both — run the gate, which prints the pair. **What it sweeps is what git tracks**, which it did not use to be: a recursive `find` counted whatever `.pas` files were on disk, so a checkout still holding the retired BSI suite (gitignored by ADR-0232) reported 224 more than a clean clone, and the number two documents quoted meant something different on every machine. **The mutation is the argument**: `nkStr`'s `(stAt, stLen)` and `nkVar`'s `(vrAt, vrLen)` share storage, so reading the wrong one yields the right value — 808 ctest cases and 323 scenarios all green, and it caught the mutation on 582 of the 1019 sources the corpus then held. It refuses to pass by asking nothing: fewer than 100 guards is a failure |
| `predicate-callers` | `Assignable`'s own refusal arms and call sites | does every caller of a shared predicate refuse what the predicate refuses? (ADR-0146) — ADR-0058's sentence, *a permission granted in a shared predicate leaks to every caller*, has cost three times: the relational operators emitting invalid IR for two slices (ADR-0139), then assignment copying one array's contents over another's, exit 0 (ADR-0143), then §6.4.6 a)'s **second** condition never read at all, so two records holding a `text` were assignable and the block closed one file twice — a double free, SIGABRT (ADR-0150). The first two fixes were each followed by a probe over the positions someone thought of. This derives the positions from the **source** — 23 of them over 17 routines, against the five type spellings `Assignable` refuses outright — and requires the program to be refused. 115 pairs; moving the slice arm one line down leaves all 625 cases green. ADR-0177's `exit(e)` is the position that changed the *gate*: it can stand only in a function-block, so the probe program's subject had to become a function with its result assigned, or §6.7.2 would have refused every probe of it whatever type it was given |
| `buffer-headroom` | `poolMax` and `tokMax` in the compiler, and what `--dump-limits` reports | how much of each array sized for this compiler's own source is still free? (ADR-0126, ADR-0148) — a one-directional watch on a bound, not a claim. Twice a fixed buffer (ADR-0012) has failed as a **build** rather than as a diagnostic, because the array that has to hold this source is the *seed's*: raising the constant here does not raise the one that matters, so the only way out is an out-of-cycle reseed. ADR-0095 cleared the string pool at 74 characters over and closed with "nothing measures the headroom"; ADR-0126 cleared the tokens at 107 left of 140000 and is that measurement — of the tokens only, the pool having no count a token stream can carry. ADR-0148's `--dump-limits` is the other half: the compiler compiles as usual and then reports both counters against both capacities, and the gate reads the capacities **twice**, from the source and from the compiler, so a stale `build/bin/pascalc` is named rather than measured. **Since ADR-0233 it is three translations and the answer is the worst of them**, and which one it is differs per array: the program holds the most tokens and ApFront the most pool. Measuring the program alone would have called a 49% pool margin a 55% one |
| `benchmark` | `tests/checks/benchmark.txt`, and the compiler's own three sources | how long does the compiler take? (ADR-0270) — nothing here had ever asked, and the three numbers `doc/roadmap.md` carried had all moved by the time they were re-measured. **A millisecond is a fact about the machine that took it**, so what is committed is six *proportions*, each divided by something measured in the same run: four stage shares of one compile of `apfront.pas` and two component scales. The stages are separated by the dump flags that stop at each one (ADR-0025) — `--dump-tokens`, `--dump-ast`, `--dump-sema`, no flag — so it is four subtractions and no profiler. **The first design was a ratio to a whole compile and it failed the mutation**: the denominator ran the code generator too, so making `EmitStmt` 4000 units slower moved numerator and denominator together and every ratio held. The tolerance is per proportion, from the measured spread of six runs, and a failure is **confirmed by a second measurement** before it is reported, a duration being the one thing here a machine can get wrong by itself. Its first answer was the finding: the **lexer cost five times the parser** — 26% of a compile against 5% — and acting on that (ADR-0271) took a third off it, because `LookupKeyword` recomputed the padded length of all forty-five word-symbols for every identifier in a source. The split is the lesson: the padding trim was 31% of lexing and stopping the scan at the match, which is the change anyone reaches for first, was 2.6%. The gate then fired in the **faster** direction and the baseline was rewritten with the record as its argument. It catches a stage made about a third slower and cannot see a compiler slowed uniformly everywhere |
| `target-sizes` | `PAS_FILE_SIZE`/`PAS_JUMP_SIZE` and `fileSize`/`jumpSize` | are the two opaque struct sizes large enough on a machine that is not this one? (ADR-0155) — it compiles `runtime/pasrt.c` itself for every target a compiler is installed for, because the two `_Static_assert`s live in that file and a copy of the struct would be a copy free to drift. Both numbers were x86-64 measurements written as constants, and `struct pas_jump` embeds a `jmp_buf` — 200 bytes on x86-64, 312 on aarch64, 392 on 32-bit arm — so `PAS_JUMP_SIZE = 256` stopped an aarch64 build at the runtime's own assert. Skips with 77 where only the host is available; `TARGET_SIZES_REQUIRE` is how CI refuses to pass by skipping |
| `stale-component` | a component's source, edited between two links | is an object built from an older module-heading refused? (ADR-0245, AP 6.13.2) — §6.11.1 makes a heading the interface and §6.13 translates components separately, so two translations may read two different headings and agree about every *name* in both: exported variables cross by linkage name and never by frame index, and a procedure's name says nothing about its parameters. It cost a **wrong answer with a zero exit status** — `a=11 b=22` written, `a=11 b=0` read back, no diagnostic from the compiler, the driver or the linker. A digest of the heading's tokens is now part of the module's activation-procedure name, so the linker refuses the mixture. It is a shell harness because **no test case can edit its own source between two compilations**, and it fails in both directions: a comment, a reflow or a change confined to a module-block must still link, since a check of this kind fails by being too strict far more easily than by being too loose |
| `markdown-tables` | every Markdown table in the tree | is every row the width of its header? — the cheapest gate here and the one whose absence damaged the most-read file. `CLAUDE.md`'s gate list had the `runtime-isoc` row **split in half by the `unicode-conformance` row wedged between its two pieces**, and `doc/sop.md` had a row broken across two lines; both render as a mangled row and an orphan paragraph, and both survived every reading since they were written. Nothing else here can see it: every other oracle reads Pascal, C or a golden. It checks two structural shapes and nothing else — a row that is not one line, and a row whose cell count differs from its header's. It does **not** reach a cell whose code span holds `\|`, which GFM renders as a bare `\|` everywhere: that was the third defect found on the same pass, the source was well formed, and only the reader was misled |
| `install-layout` | the install prefix, and `PATH` | can this compiler be put somewhere and found there? (ADR-0244) — every other harness drives the compiler out of the build tree with `PASCALC` and `AFTERSCHOOL_PASCAL_RUNTIME` saying which tree, which is exactly the configuration an installed copy does not have, so *install it anywhere and point PATH at it* was a claim no oracle here made. It installs to a prefix, unsets every variable that could point back at the checkout, puts the prefix's `bin` on `PATH` and compiles a program importing two library modules from a third directory. Four claims fail separately: the layout, `pascalc` found beside `pascalcc`, `libpasrt.a` found the same way, and the library on the search path. **A fifth is the one the convention rests on**: the search is `<directory>/<interface name>.pas` and nothing opens a file to find out what it declares, so it compiles one `import <name>;` program per installed module — 31 as this is written, and the gate prints the count rather than this sentence being trusted for it, since it moves with every module added — and each has to compile rather than merely resolve, since only Sema knows whether the file found declares the interface. Renaming a library module's export is a mutation nothing else here sees |
| `runtime-isoc` | `tests/checks/nonstandard_c.txt` | how far is the runtime from ISO C? (ADR-0161, ADR-0186) — it is the only C here and the whole of what a port has to satisfy, and the answer is now in **two parts**, because the catalogue turned out to hold only *functions*. `runtime/pasrt.c` is **five names**: `_setjmp`/`_longjmp` for ISO 7185 §6.8.2.4 / ISO/IEC 10206:1991 §6.9.2.4's non-local goto, `fmemopen`/`open_memstream` for ADR-0057's `readstr` and `writestr`, and `access` for §6.7.5.6's `bind` asking whether a name exists (ADR-0172). The file model is `fopen` and is not one. It strips every non-ISO `#include` from a copy before the strict compile, because `__STRICT_ANSI__` hides only what POSIX adds to a header ISO C has — `<unistd.h>` declared `access` through it unseen. A C library honouring `__STRICT_ANSI__` hides its POSIX declarations, so `-std=c11 -pedantic-errors` harvests the list; a second compile with only those two diagnostics silenced is what says five is the whole list. It also sweeps the two **conformance** corpora and requires every `declare`d symbol to be `pas_*`, `llvm.*` or catalogued — not `tests/dialect/`, where `external` lets a program name any C function it likes. Skips 77 on a C library that declares POSIX anyway, macOS being one. **The second part is ADR-0186's**: the mechanism above proves the list complete by stripping the includes and requiring what is left to still compile, which works for a symbol and cannot work for a *type* — an incomplete `struct stat` is an error no flag silences. So a POSIX dependency needing a type could never be catalogued there, which nobody had met in four increments because all four were functions. **And a third unit joined on the day it arrived** (ADR-0190): `runtime/pasrt_unicode.c` is held to strict ISO C11 with *no* catalogued name at all, which is a stronger claim than either of the others carries and free to make while it stays true. `runtime/pasrt_posix.c` is where a POSIX dependency goes, bounded by its **headers** rather than its names — six of them, and the gate prints the list rather than this sentence being trusted for it: `<dirent.h>`, `<netdb.h>`, `<poll.h>`, `<sys/socket.h>`, `<sys/stat.h>`, `<unistd.h>`, the last three added by ADR-0203 and ADR-0205 when a socket and `poll` arrived, required to be clean POSIX C11 under `-Werror`, and required to contain nothing but `pasx_` — so a system without those headers loses library routines and **not the language** |
| `unicode-conformance` | Unicode's own `NormalizationTest.txt` and `GraphemeBreakTest.txt` | does the runtime agree with the Unicode Character Database about what a text value *is*? (ADR-0189, ADR-0190) — **the second oracle here that nobody wrote**, and the first since the BSI suite. AP 6.4.15 rests on two properties — Normalization Form C, and where one extended grapheme cluster ends — that no reading taken here could be trusted to settle, which is exactly ADR-0072's blind spot; Unicode publishes the answers. 20 034 normalisation cases, 766 segmentation cases, and a sweep of all 1 094 978 code points the first file does not list, each required to be its own NFC. It passed on the first run, so four mutations were made and each was caught by the section it should be — the sharpest being `combines_back` made constantly false, which loses **only** the 59 composites whose second element is a starter and nothing else. It asks a second question the files cannot: regenerating the tables from the database must reproduce the committed header, or the two could drift and every case would still pass. Skips 77 without the database, which is fetched and never committed; `UNICODE_CONFORMANCE_REQUIRE` is how CI refuses to pass by skipping |
| `fpc-differential` | `tests/checks/fpc_disagreements.txt`, and Free Pascal | does a processor nobody here wrote answer these programs the same way? (ADR-0234) — the **third** oracle in this tree that this project did not write, and the first that is a *processor* rather than published data. Every program in `tests/` has exactly one reader: `difftest` and the BSI suite both retired with the conformance modes (ADR-0232), and a reading nothing can contradict is ADR-0072's blind spot. FPC under `-Miso` compiles and runs every case with a golden. **It is not an authority** — it implements neither standard completely and has never heard of this dialect — so where the two disagree the clause decides, and each disagreement is catalogued with which clause and which way. Numbers compare **by value** and blanks are dropped, because §6.9.3.1 leaves the default width to the processor and comparing padding would bury everything else: 64 of the 103 comparable cases differ byte for byte and 11 survive that. Two classes are counted rather than listed — an ISO error this compiler traps and FPC runs past, and a program whose parameters name files. It found **no defect here**, which is the result: of the eleven entries, six turn on a clause and all six are decided here, three of them corroborating a reading nothing else could challenge — ADR-0073's mixed comment delimiters above all, whose own record says no oracle here could have caught it. **`tests/dialect/` is out of reach and always will be**, and FPC refuses 141 of 244 cases, modules above all: the option shrinks with every release, which is why it was taken now. Skips 77 without `fpc`, which is not a documented dependency; `FPC_DIFFERENTIAL_REQUIRE` refuses to pass by skipping |
| `foreign-layout` | the `@cstruct`/`@cfield` comments, and `--dump-layout` | does a record declared here have the layout the C struct it claims to be has? (ADR-0185) — ADR-0184 made a record crossable because `RecordLayout` *is* C's struct rule, and registered what that leaves open: whether the fields declared **are** the members the real struct has. `struct stat` is 144 bytes with two holes, and a hole in the wrong place makes every field after it wrong with no diagnostic anywhere. The source states its claim in a **comment**, which costs the language nothing (ADR-0166's route for `{ @std:iso7185 }`); the compiler reports the offsets it computed; a C compiler holding the real header judges the two. Zipped in **order**, so a missing annotation shifts the rest and the count check fires — name-matching would silently check a subset and call it a pass. `@cplatform` reports a subject as not-checked-here rather than failing it, a skip and a defect having to look different. Skips 77 with no C compiler |
| `target-layout` | the frame types the compiler emits, and the targets `--target=` admits | do the admitted targets lay a frame out the same way? (ADR-0157) — `LlSize` and `LlAlign` are hand-written and answer with **one number for every target** (ADR-0028), which is correct only while they agree. It reads the `%frameN` definitions out of what the built compiler emits for each of its three program-components *and* for a probe carrying the types the compiler has no frame slot of — an `i256` in a record first, that being ADR-0028's segfault exactly — then folds them to offsets once per target — 9320 of them as this is written, and the gate prints the count rather than any document pinning it, because it moves with every declaration added to the compiler. The target list comes from the compiler's own `--target=` refusal, so a third target is compared without the gate being edited; admitting `i686-linux-gnu` moves 86% of them |
| `clause-citations` | `tests/checks/nonexistent_clauses.txt` | does every clause number this tree writes down name a clause of *some* standard? (ADR-0164) — a citation is the one claim here no oracle can contradict: a wrong number compiles, runs, passes every golden and is proved correct by `verify/`, which is how ADR-0072's survived in four documents and a purpose-written test. It asks the **cheap half** and says so — whether the number names a clause at all, never whether it names the right one, so it would not have caught ADR-0163, where §6.4.3.4 was cited about an ISO 7185 program and that number is *Set-types*. Over the citations it now reads — 9344 across 1537 files as this is written, against 7382 when ADR-0164 wrote it, and the gate prints the pair rather than this sentence being trusted for it — it found one number naming nothing in either standard, standing in seven places. **A clause number written in this tree is a citation**: the gate cannot tell a mention from a claim, so a document discussing a wrong number either avoids spelling it or takes an entry. An entry is a claim about the **standard**, not the inventory — the inventories are generated and ADR-0152 found 37 real clauses in none of them |
| `spec-clause-traceability` | `tests/spec/clauses/triage.tsv` and `pending.txt` | is every clause a scenario cites still cited, and does every citation name a clause the triage calls testable? (ADR-0106) — the second half is what keeps the *triage* honest, since a scenario citing a `structural` or `not-implemented` clause fails. A clause that **starts** being cited does not fail; it asks for `--write-pending`, a gate that punished progress being one people learn to avoid |
| `sanitizers` | the corpus, and `tests/checks/heap_balance.txt` | does the runtime's own C survive its own suite? (ADR-0261) — the corpus run again under AddressSanitizer, UndefinedBehaviorSanitizer and LeakSanitizer, over a second `libpasrt.a` built with the same flags, because ASan's runtime arrives at the **link** and a program compiled with it and linked without is an ordinary program that took longer to build. `heap-balance` above is the closest thing to it and counts *calls*, so a write one byte past an allocation, a read of a freed block or a signed overflow in the runtime is invisible to it and to everything else here. It is not a fuzzer: it generates no input, which is the expensive half of that gap and is still open. A leak is judged against `heap_balance.txt` rather than against a second list of its own, so the two cannot drift apart without one of them failing |
| `tls` | OpenSSL's headers, and two servers | are the numbers `lib/dialect/pastls.pas` copied out of OpenSSL still what OpenSSL says? (ADR-0264) — six of them are macros or bare `#define`s no `external` declaration can reach, so the module holds a transcription, and **a wrong one fails quietly**: `SSL_VERIFY_PEER` written as 0 is `SSL_VERIFY_NONE`, verification is off, and every behavioural case stays green. A C program including the real headers prints what they say and the Pascal source is read for what it claims — `foreign-layout`'s shape applied to numbers rather than to offsets — and the *count* is compared too, since a constant renamed in the source is one this check stops looking at. The behavioural half needs **two** servers, and that is its point: the second presents a certificate whose chain verifies perfectly and whose name is `other.example`, connected to as `localhost`, which is the case a client checking only the chain gets wrong and the one a single server cannot pose. No golden here holds anything OpenSSL wrote — a reason string is that library's wording and moves between releases — so what is compared is the ErrorCode, whether a reason was recorded, and the shape of the protocol name. A third half drives `PasHttps` -- `PasHttp`'s grammar over `PasTls`'s transport (ADR-0265) -- against the same server, and is the **only place a second transport is driven at all**, so a grammar that had quietly kept a socket in it would pass everything else in this tree. A fourth runs the probe under LeakSanitizer, eleven connections each holding three handles being something nothing else here can watch. Skips 77 without libssl or `openssl`, neither being a documented dependency; `TLS_REQUIRE` refuses to pass by skipping |
| `fuzz` | `tests/checks/fuzz_bounds.err`, and input nobody wrote | does this compiler survive what a person would not have written? (ADR-0275) — every other corpus here is hand-written and so tests what someone thought of, and a hand-written lexer and parser over **fixed buffers** (ADR-0012) is the canonical target for the other kind. Three families and each proves a different thing: **truncation**, every prefix of a real source byte by byte, which puts the parser at end-of-file in every state a source can reach and is the shape a missing `aborted` test takes; **the bounds**, one generated input per fixed buffer and per depth limit, each asserting the *message*, because ADR-0012's claim is not that a full buffer is survivable but that it is a diagnostic; and **mutation**, one to three edits of a corpus source so that a mutant starts from a real program and arrives somewhere deep with it. **The seed is fixed**, so what runs is a regression suite of hostile inputs and not a search — a fuzzer that fails randomly on someone else's commit is one people learn to ignore — and `--long N` is the search, run by hand. **It found no crash**: 3128 inputs in the suite, 41 628 in a campaign, no signal, no trap, nothing unfinished. What it did find was an *argument standing in for a case* — `too many tokens` and `out of string space` were excluded from `diagnostic-coverage` as "capacity limits, not diagnostics about a program being compiled", and both carry a file, a line and a column; reaching them takes 300 KB of semicolons and 1.2 MB of distinct identifiers, so the input is generated and `fuzz_bounds.err` is the golden, checked against the generator's own table in both directions. And a **quadratic**: `Declare` asks `LookupInScope`, which scans the scope, so *n* declarations in one block cost *n²* — 32 000 of them take 14 s, bounded by `tokMax` at about 80. Of four mutations three are killed by the family that should and the fourth is killed by nothing here, the 787-case suite included |
| `heap-balance` | `tests/checks/heap_balance.txt` | did every `new` a corpus program makes still come back through `dispose`? (ADR-0183) — **the one oracle here that reads no output**. Every other gate compares what a program *printed*, and a leak prints nothing, which is how a handle in an unowned heap record (ADR-0181) and an abandoned chain (ADR-0182) were each found by a measurement taken once, by hand, and by nothing afterwards. The runtime tallies `pas_new` against `pas_dispose` and writes the balance at exit when `$PASHEAP_BALANCE` is set — `--coverage`'s discipline, so an unmeasured program pays one `getenv`. A nonzero balance is **not** a defect: no standard obliges a program to dispose what it created, and 5 of the 39 heap-using cases legitimately end with something outstanding. So it is a catalogue, failing in both directions. Making `dispose` free nothing leaves **735 of 735 cases and 230 of 230 scenarios green** and moves nineteen balances, which is the whole argument for it. It counts no files and no handles, and takes the count at *exit*, so a leak that a loop would have balanced eventually is invisible |
| `model-drift` (CI) | the `Model-unchanged:` trailer | did CodeGen **or the constant folder** change without `verify/lowering.py`? — its *base resolution* is checked locally as `model-drift-base`, that half being a pure question about one repository and the half that has broken |

All but `model-drift` are `ctest` cases, so they run before a push rather than
reporting after one. **What none of them sees** is the corpus being enumerated
by glob, so the harnesses that build a compiler of their own — `irtest.sh`,
`producttest.sh`, `verify.py` — are invisible to it; that is a row in
`doc/sop.md` §7. The *flags* half of it is closed: the coverage corpus sweeps
`--dump-all` over every source, which was worth 195 statements reported
unreached while an oracle reached them on every run, and since ADR-0274 it
sweeps `--coverage` too, which had been driven by a gate on every run and by
no case ever.

`pascalc --coverage` is the product feature behind that gate (ADR-0104,
ADR-0274), and it works on any Pascal program: one counter per statement and
one on each edge of every decision, the lines reached appended to
`$PASCOV_LINES` and the directions taken to `$PASCOV_BRANCHES`, and both
*denominators* readable from the same `.ll` the compilation wrote — so nothing
keeps a second idea of what was executable.

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
future work or deviates from the standard.

**`doc/design-digest.md` is the condensed form**: a paragraph per mechanism,
grouped as the compiler is, for when you know the area but not the number. It is
not a substitute for the record — it says what was decided, and the ADR says
why and at what cost.

**A landed feature is two commits**, and the split is not tidiness: the `feat:`
one, then a `docs:` one that moves the feature out of README's "not accepted
yet" list and into the accepted block, and nothing else. That cadence is what
makes the language's growth greppable from `docs:` alone — `git log
--oneline --grep='^docs'` is meant to read as a changelog of what the compiler
accepts. The rule is written out in `.claude/skills/docs-engineering/SKILL.md`,
which is loaded only when that skill is invoked; it is repeated here because
that is exactly how it came to be missed.

It *was* missed, for the eight Extended Pascal features from `5df95d7`
(protected parameters) through `e710d3a` (modules): each carried its README
edit inside the `feat:` commit. Those features are documented — the grep is
what is incomplete, not the docs — and the gap is recorded here so the next
reader does not conclude otherwise from an empty search. Don't try to repair it
by rewriting published history.

**And a ninth, `de4f206`** (a variable-string may be a value parameter), which
is worth its own sentence because it failed differently: it is a `fix:`. The
rule above says "feature" and the skill's survey step read `feat(...)` commits
only, so a *conformance fix that changes what the compiler accepts* fell
between them — and this one struck a whole limitation from README and from
`doc/roadmap.md`, which is as much language growth as any `feat:`. **The test
is whether a program that did not compile now does, not what the type prefix
says.** The survey step has been widened; the commit stands as it is.

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
holds the three-stage plan and the dependency ordering; `doc/history.md`
records how it went, and `doc/roadmap.md` is what is still open.

**All six bootstrap items are now settled**, and both standards are complete
besides — so the bar for a new feature has *moved* twice rather than risen.
During the bootstrap a feature needed a reason beyond "the standard has it";
conformance then made that exactly the reason; and now that neither standard has
anything left to implement, a new feature belongs to the dialect ADR-0109 is
aiming at and needs a reason of its own again.

## The two standards

**ISO 7185 is complete** — and the last four arrived only because someone went
looking, in two separate rounds. §6.6.5.4's `pack`/`unpack` and §6.9.5's `page`
were *missed*, not declined, while three separate documents asserted
completeness: the names were in `isRequiredName` so §6.6.3.7 could refuse
passing one as a parameter, and nowhere else. Then §6.3's **string constant** —
`const s = 'hello'`, refused under both standards — was found the same way
hours after the tag was moved to say the standard was done (ADR-0068).

No corpus program had ever written any of the four, so every oracle agreed. The
lesson is about the oracles rather than the gaps — a claim no test names is a
claim nothing checks (ADR-0067) — and the second round is the evidence that
learning it once is not enough. **Before asserting completeness of anything,
compile a probe for the clause.**

ADR-0080 is that rule applied to the list that broke it: all 94 of
ISO/IEC 10206:1991's required identifiers (Annex C) are probed by
`tests/extended/required_identifiers.pas`, one program using every one of them
for its purpose. It is the first sweep here to find nothing — and its own first
design would have reported a false all-clear, because it asked whether a name
*resolves* rather than whether it works, which is the same mistake that let
`pack` and `page` sit in `isRequiredName` with no implementation behind them.

**Both standards were implemented, and there is one language now** (ADR-0232).
`--std` is gone, and so are ADR-0166's `{ @std: }` header comment and the
`.std` sidecars. What survives of the split is worth knowing, because the tree
is laid out by it:

- **`selfhost/compiler.pas` was converted to Extended Pascal** (ADR-0082),
  which reversed the example ADR-0033 gave: it *had* a field named `value`, and
  that one identifier was quoted here for a long time as the reason the stage-1
  compiler was ISO 7185. Renaming it and `bindable` — by *token position*, not
  by text, since both words also appear in the keyword tables the lexer matches
  against — was the whole of the conversion. The reason to do it is ADR-0081:
  only Extended Pascal lets a program read its own command line, so only an
  Extended Pascal compiler can take a flag. ADR-0232 made that rename the
  ordinary case: the ten word-symbols §6.1.2 adds are reserved for every
  source, so nine more corpus programs were renamed the same way.

- **`tests/`, `tests/extended/` and `tests/dialect/` are three globs and no
  longer three languages.** The directory used to tell every harness which flag
  to use; the names are kept because 493 ctest cases and every document
  referring to them are keyed on the path, and because moving a case renames it.
- **`tests/extended/components/` holds §6.13's separately translated
  components**, and the subdirectory is load-bearing: the CMake glob is not
  recursive, so a source declaring no program is never registered as a case
  that fails to run. A case that needs one lists it in `name.components`, one
  path per line relative to the case's own directory, and `run_test.sh` and
  `irtest.sh` each translate it separately and link the objects. The two
  harnesses must read that file the same way, or a case means two things.
  - `irtest.sh` skips a source with **no `.out` and no `.err`**, which is what
    keeps a component from being run as a program.
- **Every word-symbol is reserved.** §6.1.2 adds ten to ISO 7185's 35, and
  `and then`/`or else` are reserved by the lexer joining two tokens rather than
  from a table (ADR-0038). Adding an eleventh is what `reserved-words` used to
  refuse and nothing refuses now — the argument against it is ADR-0140's and
  is about the *dialect's* spellings, which are positions rather than words.

**Every clause of both was implemented, and each feature's record is in
`doc/design-digest.md`** — what the clause asked for, what it cost, and what was
refused or deferred and why. Recurring answers worth carrying into a new
feature, because each was arrived at more than once:

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
  variable-string **value parameter** is the fifth, and the first where the
  shape was forced rather than chosen: an actual of a different capacity has a
  different layout, so no address would have served and the callee's prologue
  converts the pair into its own slot (ADR-0115). ADR-0125's **slice** is the
  sixth, and the one that makes the shape a language feature rather than a
  lowering: `array of T` is a formal parameter's type and what travels is an
  address and a count, so the bounds a callee checks against are the ones it
  was handed.
- **A permission granted in a shared predicate leaks to every caller.**
  `assignable` is asked by the relational operators too, which is why
  ADR-0058 had to write the comparison refusal out separately.
- **Refusal by construction beats an enumerated list of what is forbidden.**
  A restricted type refuses arithmetic through the diagnostic arithmetic already
  had; a discriminant-selected variant has no designator to attribute a value
  to. Where a check would have gone, the code says why it is not there.

**Two threads of control exist** (ADR-0268), and every alias rule above is
written for one. `task`, `spawn`, `channel [n] of T`, `send` and `receive`
reserve no word-symbol; a task takes only transferable values and channels
(AP 6.7.8.1) and may name only its own variables (AP 6.7.8.2), which is the
half a probe found after the first looked sufficient; and every task a block
spawned is joined **before** that block releases anything, which is what makes
ADR-0201's *a borrow cannot outlive the call* true again. The compiler is one
thread and must stay so — the seed compiles it.

**`doc/implementation-defined.md` is still the register of what this processor
decides** where a clause leaves it open, and the two extensions listed there are
still listed. What it no longer carries is the clause 5.1 a) compliance
statement: ADR-0232 withdrew it rather than reword it, because a processor that
cannot compile BSI's CONF005 does not conform and saying otherwise would be the
one kind of false claim this project has been most careful about.

**`doc/afterschool-pascal-spec.md` is the specification of this language,
clause by clause** (ADR-0135, ADR-0232) — an amendment to
ISO/IEC 10206:1991 in that standard's own numbering, so AP §6.4.11 is the
optional type because clause 6.4 ends at 6.4.10. Two rules govern it: it is
derived from the decision records and verified by probe and **never from
`selfhost/compiler.pas`**, because a specification describing an implementation
agrees with it by construction and can contradict nothing; and where it and an
ADR disagree, it wins and the divergence goes in its Annex E. A dialect feature
now lands with a clause as well as a record.

Four things about the dialect are worth knowing before adding anything:

- **It reserves no word-symbol, and that is a decision** (ADR-0140), not the
  accident it looked like for four features. A dialect feature is spelled in a
  *position* where a conforming program could not have written it — `external`
  in the directive slot, `array of` in a juxtaposition that was a syntax error,
  `?` in a character no program can spell, `int64` in a scope §6.1.3 lets any
  program shadow, `handle external '…'` in a three-token juxtaposition where a
  type-denoter ends, `owned ^T` where a denoter is already complete after the
  type-name so no caret can follow it (ADR-0181). The test for a new spelling is whether a conforming program
  could have written it **in that position**; for a statement that is one token
  of lookahead, a statement-initial identifier admitting only `(`, `:=`, `[`,
  `.`, `^` or a terminator. **`defer` is the first to use that last sentence**
  (ADR-0175): `defer S` is the case where the token after the identifier is
  none of those six, so `defer;`, `defer(x)` and `defer := 3` all still belong
  to a program that declared one. `reserved-words` enforced it until ADR-0232
  retired the gate — there is no second reservation list to compare against, so
  what keeps this true is the rule and the review rather than a check.
  **`exit` is the shape where no position works** (ADR-0177): a
  procedure-statement is something ISO/IEC 10206:1991 admits, so what makes
  the name the dialect's is only that it is *nobody's* under a conformance
  mode. That is `int64`'s and `argcount`'s answer — a required identifier,
  shadowable by §6.1.3 — and it is now the third of the two shapes rather
  than an exception to the first. **`try` is where that was measured**
  (ADR-0178): the statement rule does not transfer to a *factor*, because a
  factor may be a variable-access and `try (x)`, `try [x]`, `try + x`,
  `try - x`, `try.f` and `try^` all belong to a program that declared one. So
  ADR-0176's sketched `try X` was unwritable and the parentheses are the
  construct. Before spelling a new expression by position, write out what may
  follow a factor — the six-token list above is the *statement* list and says
  nothing about this one. **And the first question is one earlier than either
  shape**: does the feature need a spelling at all? ADR-0184 admits a record as
  the type of a `var` parameter at an `external` heading, and spells nothing —
  it is a *rule* about what is admitted at a position the dialect already
  holds, not a construct, and a marker for it would have been a second place
  for the truth to live. It does not escape ADR-0140; it **inherits**
  `external`'s position, which is why `grep external` still finds it. `exit` is
  the same premise failing one step earlier — no position works, and a required
  identifier answers instead. ADR-0184's consequences carry both, because
  ADR-0140's "a feature with no position has found the real limit" assumes
  every feature needs a spelling, and twice now none has.
- **It contains Extended Pascal, and that containment is now the language
  itself.** ADR-0117 made the dialect a superset where ADR-0033's two modes were
  disjoint, and `stdKind`'s order was what carried it — `HasExtended(s)` was
  `s >= stdExtended` at 40 sites. ADR-0232 removed all three constants and the
  predicate: there is nothing to compare, so nothing to get wrong.
  `tests/dialect/inherits_extended.pas` is still the readable statement that
  every Extended Pascal construct means what it meant, and `dialect-containment`
  — the whole of `tests/extended/` compiled a second way — retires with the
  second way. A feature that adds a **required identifier** still has to write a
  paragraph in that file rather than leave it alone: §6.2.2.10 puts one in a
  scope enclosing the program, so it takes a spelling away from any program that
  does not shadow it, and §6.1.3's shadowing is what makes that survivable
  (ADR-0128's `int64`).
- **A feature needs a reason of its own** — "the standard has it" is
  unavailable, since none governs this language — and should still be spelled
  the way a standard spells it wherever one does. It must be expressible in what
  `seed/*.ll` accepts, or the seed is refreshed first.
- **It is specified, and the specification is enforced.** `tests/spec/` takes
  `@afterschool:<clause>` beside the two standards' tags, and every testable
  clause of the spec is cited by a scenario but for the three AP 5.5 d) names. The clause table is **generated
  from the document** (`tests/spec/clauses/extract_afterschool.py`), not
  transcribed, so a renamed clause fails the traceability gate rather than
  drifting. Regenerate it when the spec gains or renames one. **A clause may
  also run ahead of the compiler** (AP 5.6, ADR-0189): it is marked
  `[not yet implemented]` and its rows in `triage.tsv` say `not-implemented`,
  which makes the traceability gate *refuse* a scenario citing it — so the
  specification cannot come to claim a feature is there by way of a passing
  test. AP 6.4.15, the text model, was the whole of that list and is implemented; nothing is marked today, and `spec-clause-traceability` checks the marker against the triage in both directions (ADR-0195).
- **No second implementation follows it.** `src/` was frozen at the conformance
  surface (ADR-0117), so a dialect source was compared by nothing; ADR-0232
  removed the conformance surface, so *every* source is now in that position,
  and `difftest` and `src/` are both gone. What is left is the goldens, `verify/` for a new lowering,
  `tests/spec/` for a clause-shaped requirement, the stage-2/stage-3 fixed point
  and `llc-second-backend`. `doc/sop.md` §7 carries the gap, which is now the
  largest one here.

## Where things live

**The compiler is three files and they are §6.13 program-components**
(ADR-0233), which is a change of *linkage* and not of shape — the file order
was already a topological order, all 66 `forward` declarations being inside one
stage, so no mutual recursion had to be broken:

| Component | What is in it | Imports |
| --- | --- | --- |
| `selfhost/aptypes.pas` | the shared data — token kinds, the AST's node kinds and its variant record, the type and symbol records — the string pool, the character sink, `ErrorAt`, the type arena and `WriteTypeName`/`WriteOrdinalName` | nothing |
| `selfhost/apfront.pas` | the lexer, the parser, Sema | ApTypes |
| `selfhost/compiler.pas` | CodeGen and the driver, and the main-program-block | both |

**Three, and the count is the argument**: it is the smallest number that makes
every build translate a module alone, translate a module that imports another,
and link the result — which is what closed `doc/sop.md` §7's row saying nothing
here linked a component and checked the result. Two would have missed the
middle shape, and that is exactly the shape the corpus was missing when
ADR-0212's defect got through. **The driver cannot move**: a module-parameter is
bound to nothing (§6.11.1 NOTE 6), so only a program can read a command line.

Each interface is a module-heading and nothing else (ADR-0079): what is not
written there cannot be reached, so ApFront exports 19 routines and one
variable. **A module initialises its own state** — §6.2.3.6 commences a
supplying module before the program-block — so the 47 assignments that used to
open the main program body are now three `to begin do` parts, which is most of
why that interface is small. ADR-0024 made this one file because neither
standard had an include mechanism; ADR-0053 and ADR-0079 expired that reason
and ADR-0233 collected the debt. Where a bullet below names a `src/*.cpp` file
it is naming the component that file used to be: the port is close enough that
the reasoning transfers, and the C++ is at tag `v0.1.0` if you want to read
it.

The **lexer** case-folds identifiers and reserves all 45 word-symbols, ISO
7185's 35 and ISO/IEC 10206:1991's ten. Which of them were reserved used to be
the one thing `--std` decided in the lexis (ADR-0033); ADR-0232 made the table
whole. The **parser** is recursive
descent shaped like the ISO grammar (`expression` → `simple-expression` →
`term` → `factor`) — note a leading sign binds to the whole *term*, so
`-7 mod 3` is `-(7 mod 3)`.
It bounds the depth of the tree it builds at 1000 levels (ADR-0020);
the spine-building loops count their iterations toward the same limit, because
an operator chain is flat for the parser but deep for Sema and CodeGen — a
call-depth-only limit would miss it.
`DumpProgram` writes the tree before and after Sema, behind `--dump-ast` and
`--dump-sema`; the format was a specification while two compilers wrote it and
is now a debugging aid, which is the one thing ADR-0085 made *less* load-bearing.
**Sema** owns scopes, type rules, type-denoter resolution, constant
folding, and — since ADR-0039 — the schema intern table, which is the one place
a type's *identity* is decided by something other than the denoter that built
it. Since ADR-0053 it also owns the interface table and the module records: an
interface is not a scope (§6.2.2.2), so it lives beside the scope stack rather
than in it, and a module's scope is *kept* between program-components because
§6.2.2.12 makes the heading's defining-points the block's as well. Since
ADR-0069 `checkDeclarations` walks the constant, type and variable parts
**merged by source position** rather than one part at a time, because
ISO/IEC 10206:1991 §6.2.1 lets them interleave and §6.2.2.9 then makes written
order the only correct one. A type-denoter is a `TypeExpr`, deliberately not an `Expr`, and a
declaration group shares one — which is what makes `a, b: array [1..3] of
integer` the *same* type rather than two alike ones. The one exception is a
parameter group naming a schema (ADR-0040): each name there gets its *own*
type, because each reads its own descriptor. `runtime/pasrt.c`
holds anything not expressible in IR — formatted output and runtime checks —
where `width < 0` / `prec < 0` mean "not given", and nothing else: a width the
program *wrote* is checked against §6.9.3.1's or §6.10.3.1's least value
before it gets there, so the runtime never sees a negative one (ADR-0064). `runtime/pasrt_task.c` is the **fourth** translation unit (ADR-0268): AP
6.4.16's channel and AP 6.9.3.12's task set, bounded by one header beyond ISO
C — `<pthread.h>` — as `pasrt_posix.c` is bounded by six, so a system without
it loses the concurrency construct and not the language. It holds `pas_` names
rather than `pasx_` ones because what it implements is what the *compiler
emits* and not what a program may bind. **And it made four of the runtime's
globals `_Thread_local`** — the open files, the live handles, the armed
deferred statements and the string arena with its cursor — because each is a
stack of what the current chain of activations owns and a task is a second
chain. ThreadSanitizer found the first of them on the first run of the first
two-task program, which is a defect no golden could hold. The arena's cursor
is named by the emitted module, so that change is one the **seed** could not
declare: it forced the first reseed outside a release.
`runtime/pasrt_unicode.c` is the third translation unit: AP 6.4.15's Normalization Form C and grapheme segmentation, strict ISO C11 over tables `runtime/unicode/generate.py` transcribes from the Unicode Character Database into `runtime/pasrt_unicode_data.h`. **The database is fetched and never committed**, the generated header is committed, and `unicode-conformance` checks both directions of that (ADR-0189, ADR-0190). It was landed first, before anything called it, so Unicode's own conformance files could judge it before any language rested on it; since AP 6.4.15 landed, `runtime/pasrt.c` calls it — the **compiler** never does, naming only the `pas_text_*` entry points in `pasrt.c` itself.

Adding a language feature usually touches, in order, the components of
`selfhost/compiler.pas`: the token kinds and the lexer → the node kinds and the
parser → Sema → CodeGen → a `tests/` pair, plus `runtime/pasrt.c` if it needs
library support, and `selfhost/badparse/` or `selfhost/badsema/` if it adds a
diagnostic. It used to touch that list *twice*, once in C++ and once in Pascal,
in the same commit; halving that is what retiring stage 0 bought (ADR-0085).

The three sources are the stage-1 compiler, written in Afterschool Pascal, and
since ADR-0083 they are **the compiler this repository produces**: CMake
translates each with the seed compiler, in the order
`selfhost/compiler.components` gives, and links the three modules into
`build/bin/pascalc`. The lexer (ADR-0022), the parser (ADR-0023), Sema
(ADR-0024) and CodeGen (ADR-0025) are all done, and **the bootstrap closes**:
the compiler compiles itself and stage 2 equals stage 3 — in **every** module
since ADR-0233, because comparing only the program's would let a change in
ApTypes or ApFront reproduce itself unnoticed.
`selfhost/producttest.sh` is what checks the built artefact — the other three
harnesses build a stage-1 compiler of their own in a temporary directory, so
`build/bin/pascalc` could be missing or stale with every one of them green.

It takes a **command line** — `pascalc [options] file.pas`, with `-o`,
`--import` (repeatable), `--import-path` (repeatable), `--target=`,
`--coverage`, `--dump-*` and `-h` (ADR-0083). **And it reads one environment
variable**, `AFTERSCHOOL_PASCAL_PATH`, which is the one foreign name this
compiler binds and the reason it can be installed anywhere (ADR-0244): an
`import` naming an interface no `--import` supplied is looked for as
`<directory>/<folded interface name>.pas`, in the source's own directory, then
in each `--import-path`, then in each `:`-separated entry of that variable. The
search is transitive and post-order, so what it produces is the activation
order §6.2.3.6 requires; `--dump-imports` is how `tools/pascalcc` learns what
to translate and link, resolution finding an *interface* and not an object. It is quiet
on success and writes `file:line:col: error: message` on failure, to `output`,
because no standard Pascal program has a second stream. The dumps go to standard output; the IR goes to the file `-o`
names, because it is the compiler's *product* rather than a dump and has to be
assembled. It is written on every run, which is what keeps the coverage sweep
exercising the code generator on every file in the corpus even though it reads
none of it.

**A program may ask before it writes** (AP 6.4.3.4.7, ADR-0240).
`BindingType` has a third field, `writable`, which ISO/IEC 10206:1991
§6.4.3.4 NOTE 7 admits as an extension — so the feature has **no spelling**,
which is the second time none was needed after ADR-0184 and the first where
the standard itself named the extension point. It exists because `bound`
answers the read side and the write side had nothing: §6.7.5.2 leaves the
activity on the external entity implementation-defined and this processor's
choice on a failure to create is to stop the program, so `rewrite` at a bad
path was unrecoverable, unreportable and unforeseeable. It is a probe and not
a promise, exactly as `bound` is. Two things follow that are easy to get
wrong. It is **false for a variable bound to nothing**, as `bound` is — an
unbound `rewrite` goes to a processor-supplied temporary and this says nothing
about that. And a **directory** answers false, which needs asking without
`struct stat`: POSIX makes a trailing slash require a directory, so a second
`access` is the whole of it (ADR-0186's catalogue holds a function and never a
type).

**A bindable file cannot cross a parameter**, and it is worth knowing before
factoring one out. §6.4.1 makes `bindable` part of a *variable-declaration*
and not of a type-denoter, so no formal parameter accepts one — `var f: text`
compiles and `bind(f, b)` inside it is then refused. `lib/pasfile.pas`'s four
writers are one routine with two flags for exactly that reason.

**How a Pascal program has a command line at all** is the part worth knowing.
§6.5.1 makes every program-parameter possess "the bindability that is
bindable", and §6.7.6.8's NOTE 2 makes `binding(f)` report the binding §6.12
made *before the program was activated* — so `binding(argk).name` is argument
*k*. The compiler declares twelve program-parameters, opens none of them, and
reads their bindings; an unbound one is how the list ends, there being no other
way to count arguments (ADR-0081). The files it then works on are `bind`-ed to
names it computed, which is the same clause's other half.

That retires ADR-0033's constraint **for this compiler only**: "ISO 7185 gives
a program no access to its command line beyond its program parameters, and
those are files" is still every word true of ISO 7185, and this compiler is
simply no longer written in it (ADR-0082). Until then the standard arrived in a
file holding one word and §6.13's components arrived *concatenated* into a
fifth, because a program that cannot name a file cannot open several — the
shape ADR-0079 had to defend against the language rather than on its merits.
**Seventy-two arguments and thirty-two `--import`s are array bounds, and one of
them needed an extra parameter to be a bound at all.** `maxImports` reports because a
counter can be compared; the argument list could not, and for a long time did
not — an unbound program-parameter being the only end-of-list there is, a
compiler with *n* of them cannot tell *n* arguments from *n* + 9. It was twelve,
which was exactly what `tests/dialect/lib_os.pas` needs, so one more flag
silently pushed the `-o` file name off the end and the complaint named the wrong
argument. `argOver` is declared beyond the last usable one and never read for
its name: bound exactly when an argument had nowhere to go, which is what turns
"the list ended" into "the list ended because it ran out" (ADR-0158). **The two
numbers are one number** (ADR-0235): an import costs two words, so a bound on
imports is only real as far as the argument list can express it, and `argMax` is
*derived* from `maxImports` in the comment that declares it. They were 24 and 8
until `lsp/pasls.pas` — whose import chain is ten modules and none of them
optional — could not be compiled at all.

**The first three components are checked by golden files, and by nothing
else.** `pascalc --dump-all` writes three sections (`=== tokens`, `=== ast`,
`=== sema`). `selfhost/difftest.sh` used to diff them against a second front
end's over every `.pas` in the tree — the strongest oracle here; ADR-0085 gave
it up with stage 0, ADR-0108 brought it back, and ADR-0232 retired it for good,
because `src/` was frozen at a conformance surface that no longer exists.

**Know what that means when you change a stage.** A golden agrees with whatever
wrote it, so a change that is wrong in the dump *and* wrong in the goldens you
regenerate is invisible. Regenerating a golden is a decision to be argued for in
the commit message, not a step — and there is no longer a second implementation
to catch you at it, which is exactly why the rule matters more than it did.

**And no oracle here can contradict a *reading*.** The goldens agree with
whoever wrote them and `verify/` proves the lowering matches a model of the
lowering — so a misread clause is invisible to all of them at once, which is
how ADR-0072's set-packing deviation survived in four documents and a
purpose-written test.
`.claude/skills/langspec-audit/SKILL.md` is the substitute: independent readers
given the behaviour and not the reasoning, told to prove the compiler wrong from
the standards text. ADR-0101 is what it found the first time — eleven readings
confirmed and three under-strict gaps.

**`tests/spec/` is the one suite whose unit is a clause rather than a program**
(ADR-0105). Every other oracle here starts from the compiler and asks whether it
still does what it did; a scenario starts from §6.8.3.9 and asks what the
compiler does about it, phrased as the requirement rather than as the lowering.
It is a subset of Gherkin parsed by `tests/spec/run.py` — no framework, because
`cmake`, `make` and `clang` are the whole of what this repository needs — and an
unrecognised step is an **error**, since a step that silently does nothing is a
scenario that asserts nothing.

- It does **not** close the misreading blind spot; the scenario is written by
  the same reader. What it changes is that a reading is attached to the clause
  it claims to be about, so it is findable by someone holding the standard.
- **No text of either standard is in this repository and none may be.** The
  copies under `doc/vendor/` say "Do not include this document in another
  software product"; `tests/spec/clauses/*.tsv` holds clause numbers and
  headings, which is what a citation needs, regenerated by `tests/spec/clauses/extract.sh`.
  `doc/vendor/` is gitignored — the rule used to live only in
  `.git/info/exclude`, so no clone had it.
- **The denominator is triaged** (ADR-0106): every one of the 480 headings is
  classified `testable`, `structural` or `not-implemented` in
  `tests/spec/clauses/triage.tsv`, so coverage is counted against the **testable** clauses
  rather than against every heading — `run.py --coverage` prints both, and no
  document pins the pair, because both move. `spec-clause-traceability` gates it — a clause that stops
  being cited fails, and so does a scenario citing a clause the triage says
  cannot carry one, which is what keeps the triage itself honest. A clause that
  *starts* being cited does not fail; it asks for `--write-pending`, because a
  gate that punished progress would train people to avoid it.
  - **The triage and the inventory must name the same clauses, both ways**
    (ADR-0152). The inventory is generated from the standards and the triage is
    written by hand, and until that record nothing compared them: every
    sub-clause of §6.2.2 and §6.2.3 in both standards is a bare number on its
    own line with the requirement under it, the extractor read only lines
    carrying a *title*, and so 37 real clauses were in no inventory, no triage
    and no work queue. §6.2.2.9 is among the most-cited clauses in this
    repository — 88 occurrences of the `§6.2.2.9` spelling across tracked files
    as this is written, against the 56 the record counted, and the count moves,
    so take the shape and not the number — and `spec-clause-traceability`
    answered "not a clause of that standard" about it. Reverting the extractor now fails the gate 37 times.
- `tests/spec/clauses/pending.txt` is the **work queue**: the testable clauses no
  scenario cites yet — 188 as this is written, and the file itself is the
  count (`grep -vc '^#\|^$'`), because a number written here goes stale on
  its own and this one had, by twenty.

**The one oracle nobody here wrote was the BSI Pascal Validation Suite**
(ADR-0086), 812 programs from 1982 tied to clauses of ISO 7185. It found three
defects on its first run and it is **gone** (ADR-0232): its programs are
conforming ISO 7185 and 25 of them use a word-symbol §6.1.2 now reserves, so
the corpus cannot be compiled by this compiler at all. That is the sharpest
single cost of the dialect decision, and `unicode-conformance` — Unicode's own
`NormalizationTest.txt` and `GraphemeBreakTest.txt` — is now the only oracle
here that nobody in this project wrote.

- The dumps are **opt-in** — `--dump-tokens`, `--dump-ast`, `--dump-sema`,
  `--dump-all`, `--dump-symbols`, `--dump-stmts`, `--dump-imports`, `--dump-uses` — and each stops at the stage it names. They were unconditional
  while there was a second binary to compare them against, which is the reason
  ADR-0025 gave for having no mode to select; it expired with stage 0. Each
  section reports what its own stage found and shows its result only when
  nothing was found — a stage that failed has nothing to show, and the stages
  after it do not run.
  - **`=== tokens` belongs to `--dump-all`**, which has three sections and so
    needs them separated; a single-stage flag writes its one section bare. A
    test comment asserted the opposite and was believed until the golden was
    taken (ADR-0103).
  - **`tests/dumps/` is their corpus, and it exists because they had none.**
    Until ADR-0103 measured procedure coverage, no case in the tree passed any
    `--dump` flag — thirty-one walker procedures entered by nothing, four
    documented flags, and no check that they did not crash. A dump case
    compares what the *compiler* writes to standard output, so it needs its own
    harness (`tests/dumps/run.sh`): every case under `tests/` compares what the
    compiled *program* writes. Sidecars are `name.dump` (the golden),
    `name.flags` (the flag, `--dump-all` by default), `name.components` (an
    `--import` per line) and `name.status` (an expected exit status, when it
    is not 0); there was another, `name.std`, and ADR-0232 removed it with the
    modes. The last two arrived with ADR-0246 and each answers a shape this
    corpus had never met — a dump with a **cross-file** answer, and a dump of
    a program the compiler **rejects**.
- **`--dump-symbols` is where a *tool* asks about a program**, and the decision
  is bigger than the flag (ADR-0239). `--dump-sema` was the only structured
  thing this compiler wrote about a source, and ADR-0085 demoted it from a
  specification to a debugging aid the day there was no second front end to
  diff it against — so a caller reading it would be a second reader of
  Pascal-shaped output outside the compiler, which is the shape that broke
  `foreign-reserved` and that ADR-0229 and ADR-0230 moved `kind-exhaustive`
  off. It writes
  `symbol <depth> <kind> <line> <col> <len> <endline> <endcol> <name>`, in
  **Pascal's** words and not any protocol's numbers — the two extra positions
  are the declaration's *extent* (ADR-0253), which a block gives and a
  constant answers with the end of its own name; it stops after the *parse*
  because an outline is what an editor draws while a file is wrong, which also
  means it needs no `--import`; and the name is the **folded** spelling, the
  position and length beside it being how a caller holding the source recovers
  what was typed. `lsp/pasls.pas` is the caller, and the first one here that is
  not a gate.
- **`--dump-uses` is the second question, and the surface generalised**
  (ADR-0246). ADR-0239 closed saying *hover wants a type, which is Sema's*,
  and it turned out to be two questions with one answer: `use <line> <col>
  <len> <declfile> <declline> <declcol> <decllen> <kind> <type>`, preceded by
  a `file <index> <path>` table, serves go-to-definition and hover together
  because Sema knows a defining-point and a type at the same moment. Three
  things about it are the ones to know. **Sema records a use where it resolves
  one** — not a walk over the finished tree, which is ADR-0111's counter
  argument and ADR-0230's dispatch argument met a third time: a hand-written
  walker over the AST's variant record can miss a node kind in silence and no
  gate here can see that. **A `symbol` carries its defining-point** now, three
  integers set in `Declare` from the numbers it already had for its duplicate
  message; 0 means there is nowhere to go, which is the answer for a required
  identifier. And **it is the one dump not guarded by `errorSeen`** — Sema
  accumulates rather than stopping, so a file with three mistakes has resolved
  everything else, and an editor asks where a name is declared exactly while
  the file does not compile. The outline reaches that by stopping *before*
  Sema; a defining-point cannot, so it carries on instead. It needs the
  `--import`s, unlike the two flags above. A **field** is the one applied
  occurrence here that resolves to no symbol — §6.4.3.3 makes a record a
  region and puts a defining-point in it, but a selection is resolved by
  asking the record's *type* — so `fieldPtr` carries the position itself and
  there is a second reporter for it (ADR-0247); §6.8.3.10's bare form inside
  a `with` answers the field too, not the statement that gave it a nearer
  defining-point. An **interface** answers too (ADR-0248): §6.11.1 makes the
  export-part the defining-point, and the occurrence that mattered turned out
  to be `import Middle;` rather than the qualifier of `M.x`. A name inside a **schema's body** answers
  too (ADR-0249), and the shape of that one is worth carrying: §6.4.7
  re-resolves a body once per distinct tuple *where the type is written*, so
  `curFile` is the wrong question there and the schema's own `declFile` is the
  right one. A **declaration** answers too, as an
  occurrence of itself (ADR-0250) — reported from the *scope* after the
  declarations are checked, which is one site where the kinds are eight and is
  late enough that a variable has its type. §6.6.1's `forward` and §6.11.1's
  heading are where that is not a no-op: the completing block is the same
  routine, so the name at the implementation resolves to the interface. An **interface**'s own export-part follows
  (ADR-0251) — §6.11.1 registers one beside the scope rather than in it, so
  the walk cannot see it and it has a reporter of its own — and a module
  declares in *two* places, §6.2.2.12 making the heading's defining-points the
  block's as well, so the walk takes a boundary and reports each name once.
  Nothing on ADR-0246's list is left.
- `--dump-ast` runs **before Sema**, so it shows only what the parser decided,
  and prints `@line:col` only where the tree really records a position.
  `--dump-sema` walks the same tree through the same walker with an `annotate`
  flag, adding the frame layouts, the type of every expression, the frame slot
  every name resolved to, and every record's field/variant numbering. Sharing
  the walker is deliberate: the shape is then the same question asked twice.
- `selfhost/torture.pas` is deliberately **not** a valid program: it carries the
  error paths and lexical corner cases a valid program never reaches. Add to it
  when a lexical rule changes.
- `selfhost/badparse/` is its parser equivalent, spread over one file per
  message because the parser stops at its first error. `selfhost/badsema/` is
  Sema's, and is only thirteen files because Sema *accumulates* errors rather than
  bailing. Add to them when you add a message, and don't assume the corpus
  reaches a branch — **count it**. Every time anyone has, something turned out
  to be uncompared: no file had a tab, no file had a parse error, Sema reached
  48 of its 85 messages, and then sets, congruity, non-text files and the
  non-local goto each had mutations survive a green suite (ADR-0022 to -0024,
  -0028, -0030 to -0032). Don't look for a running total — the records
  disagree, because they are immutable and the count moved on without them.
**CodeGen is the exception, and had to be** (ADR-0025). Two backends' assembler
text is not comparable — the C++ builds an `llvm::Module` and LLVM's printer is
not a specification — so it is checked by *running* what it produces against the
same `tests/*.out` and `tests/*.err` the C++ compiler is held to, and then by
compiling the compiler with itself twice and requiring the results to match.

**That fixed point cannot see a miscompilation of the compiler**, and
`llc-second-backend` is what does. Stage 2 and stage 3 come from *one binary*,
so a `clang` that got a corner of `compiler.pas` wrong would build a wrong
compiler that reproduced itself exactly — and every golden would agree, having
been written by it. So `tests/checks/llc_check.sh` builds the compiler a second
way, through `llc` at `-O0` and at `-O2`, and requires both to translate
`compiler.pas` to byte-identical IR. It **skips without `llc`**, as
`verify-lowering` does without z3, because ADR-0085's claim is that the build
needs nothing of LLVM's; the `second-backend` CI job installs it and refuses to
pass by skipping. Don't file it as "a second reader of the IR" — `llc` and
`clang` share LLVM's parser and verifier and reject the same module with the
same message, so what it varies is the *backend configuration* and nothing else.

- The emitter is **sequential**, with no instruction list: the C++ builder never
  returns to a block it has left, so the order it emits in is the order text can
  be printed in. Don't add buffering to "fix" something; if a block needs
  revisiting, that is a change to the C++ side too.
- Types print structurally and inline, because opaque pointers make every Pascal
  type non-recursive once printed. **Activation records are the exception** —
  one would be spelled at every variable access — so they get a name apiece,
  emitted before the first function that indexes one.
- Globals are deferred to the end of the module: a string constant is numbered
  where it is used and its text written after the last function.
- **A real literal is carried as its source text all the way into the IR.**
  LLVM's assembler is the `strtod`. The one adjustment is that LLVM's float
  syntax needs a decimal point where Pascal's `1e6` has none. Three ADRs
  deferred a conversion that turned out never to be needed.
- **An `alloca` is only safe where the emitter reaches it once per activation**
  — a prologue (ADR-0102). The emitter is sequential and cannot go back to the
  entry block, so an `alloca` written for a statement that may sit inside a
  loop is claimed again on every iteration, and at `-O0` the stack runs out.
  Storage that must survive the iteration is a **frame slot** (the shape a
  `with` binding has); storage that need not is an **SSA value**, which
  dominates the loop because it is defined before the loop's blocks exist.
  ADR-0043 wrote this rule for `new` and the `for` statement broke it in both
  its forms for a long time — with the whole suite green, because `-O2` hoists
  such an alloca away and the corpus compiles at `-O2`. The two cases that can
  see it are `tests/for_nested_stack.pas` and
  `tests/extended/forin_nested_stack.pas`, and each needs a `name.opt` sidecar
  saying `-O0` to mean anything at all.
- **A string temporary lives for one statement, and CodeGen is what says so**
  (ADR-0111). The runtime's arena is a stack; it cannot see when a value dies,
  so `@pas_str_at` is read in every prologue and stored back at the end of any
  statement that took storage — and after a `while` or `repeat` condition,
  which is the one expression a statement evaluates more than once. Which
  statements need it is a *counter* the three allocating arms of `EmitString`
  bump, not a predicate over the tree: the emitter already knows what it
  emitted, and a predicate would be a second opinion free to drift. **Add an
  arena producer and you must bump the counter** — nothing checks it
  (`doc/sop.md` §7). It was a ring that wrapped in silence until a security
  audit's follow-up probe; `a + a = b + b` over two 512K strings called two
  different values equal and exited 0.
- The layout rules are written out (`LlSize`/`LlAlign`) because there is no
  `DataLayout` to ask. They are needed in exactly two places — a whole-variable
  copy's length and the size `new` allocates. `fileSize` must equal
  `PAS_FILE_SIZE`; `irtest.sh` checks it, because the two files cannot include
  one another.
- **The module states its `target datalayout`**, so the assembler lays things
  out the way `LlSize`/`LlAlign` say it does. It did not, until a set in a
  record segfaulted: LLVM's defaults align an i256 to 8 and the target's to 16,
  and 16-byte moves landed on an 8-aligned frame (ADR-0028). The rules were
  never wrong, only unstated — which is the same thing once something else is
  doing the layout. Don't drop the line.
- `WriteTypeName`/`WriteOrdinalName` write through the `Put` sink, which either
  goes to output or into `msgBuf`. A trap message is a string constant *in the
  generated program*, so it has to be assembled before it is emitted — and a
  second copy of those routines would be a copy free to drift.

## Pascal semantics already encoded (keep them)

`mod` yields a non-negative result (not C's truncating remainder); `and`/`or`
short-circuit; `/` is always real division; `for` evaluates its limit once and
tests `= limit` before stepping so the last iteration cannot overflow; a
one-character string literal is a `char`; and a statement may be **empty**
(ISO 7185 §6.8.2.1, ISO/IEC 10206:1991 §6.9.2.1 — *not* §6.8.1, which is the
goto-target rule in the first and `Expressions — General` in the second), which
means every token that can *follow* a statement also starts one — `;` and
`end`, but also `else` and `until`, so `if c then ; else s` is legal, and under
Extended Pascal **`otherwise`** as well, §6.9.3.5 making the separator before a
case-statement-completer optional. `tests/empty_statements.pas` and
`tests/extended/case_empty_otherwise.pas` pin the two halves.

**A number read takes the longest prefix that *is* a number** (§6.9.1 c) and
d), ADR-0076), which is one character more than a file's lookahead can decide:
`1.` is the integer 1 and then a point, `.5` is not a number at all, and `2e+`
is the integer 2 and then two characters. `struct pas_file` carries a
two-character give-back for it, and the order is a stack because the sign has
to come back out before whatever followed it. `tests/readlongest.pas` includes
`8.5.5`, which was already right, so a fix in the wrong direction fails too.

**`(.` and `.)` are `[` and `]`**, not a second spelling — §6.1.9 says "the
corresponding tokens or separators shall not be distinguished", so nothing
after the lexer is told which arrived and `a[2.)` is a legal subscript. Only
the *reference* tokens and the alternative `@` are implementation-defined
there; every other alternative representation is required, which is the same
sentence that requires `(*` and `*)`. `@` is refused, in `torture.pas`.

An array subscript outside its bounds traps (ADR-0017), and a `for` loop over an
array's own bounds optimises the check away; where the bounds arrived with the
actual (ADR-0040) the message is built by the runtime and says the same words. Storing outside a subrange traps,
and so does a `case` whose selector matches no label (ADR-0018) — unless it has
an Extended Pascal `otherwise`, which is the only thing that gives that arm
something to do (ADR-0033) — a dereference of `nil` (ADR-0019), the reading of an
optional that has no value (ADR-0123, and it is spelled `^` for exactly that
reason), and a set whose
members are not values of the target's base type (ADR-0028). That last check
fires at the **store**, because a constructor does not know what it is being
assigned to — except for §6.8.7.4's set-value, which names its type and is
therefore checked where it is written (ADR-0066). `tests/extended/trap_setvalue.pas`
is the program with no assignment in it.

**A subrange's bounds may be discriminants, and the check reads them.**
§6.2.3.8 b) evaluates a bound written in a variable-declaration or a
type-definition of the block at that block's commencement, so `var x: 1..m` is
legal in a procedure — and `CheckedForSubrange` calls `BoundValue` for each end
rather than reading the two numbers on the type, which for such a subrange are
placeholders (ADR-0133). Two things follow that are easy to get wrong. The
comparison moves to i32 where a bound is dynamic, that being the width a
discriminant is loaded to; and the trap message names the bounds as **values**,
not the type, because a bound the block evaluated has no spelling in the
source — the compile-time path exists, produces `value out of range (1..)`, and
is the defect's own message. An **empty** such subrange is reported at the
declaration, §6.4.2.4's other requirement having nowhere else to be said.

**A direct-access file is at most as long as its index-type** (§6.4.3.6,
ADR-0134). Only a write at the end grows a file, so the check is in `put` and
nowhere else: `update` overwrites in place, a seek past the end is already
refused, and seeking to the append position of a full file stays legal right up
until something is written there.

`date(t)` traps when the day, month and year of a `TimeStamp` are not a
calendar date (§6.7.6.9) — February the 30th, and a year outside 1..9999, that
bound being what keeps the result fixed-width (ADR-0065). The six subranges of
§6.4.3.4 do the rest of the enforcement, which is why the check is that small.

**ISO error conditions trap** (ADR-0014, ADR-0015). Integer `+ - *` and `sqr` go
through `checkedArith` and stop the program on overflow rather than wrapping —
they carry no `nsw`. `chr` outside 0..255, `succ`/`pred` at the ends of their
type, `div` by zero, `INT_MIN div -1`, and `trunc`/`round` of a real outside the
integer range (or of a NaN) all reach `pas_runtime_error` (stderr, exit 1).
The integer type is **-maxint..maxint**, narrower than the `i32` behind it, so
`INT_MIN` is not a value of the type and a literal above `maxint` is a
compile-time error.

**Annex D is the checklist** (ADR-0077), and probing it found six errors that
were answered with a value: `ln` of a number that is not positive, `sqrt` of a
negative one, `x/y` with a zero divisor for real *and* complex, `i mod j` with
j negative, and `dispose` of nil. Two are worth remembering rather than
looking up:

- **`mod` is where the compiler disagreed with itself.** §6.7.2.2 makes a
  divisor that is zero *or negative* an error; Sema's folder had always said
  so for a constant, with a comment claiming the emitted code followed the
  same rule. It did not. The run-time check now uses the folder's words, which
  is what makes one rule one answer — and it turns `rules.py`'s `j > 0`
  precondition from an assumption into something the compiler enforces.
- **`dispose` of nil was checked only for a schema domain**, where stepping
  back over a tuple header made it a free of an address never allocated.
  Elsewhere it was a *harmless* error, and harmless is not the test §6.6.5.3
  sets. Same comparison; only the reason to report it differed.

**A `for` statement's control variable must be declared in its own block**
(§6.8.3.9, ADR-0077). Not merely "a variable": a procedure looping over the
program's `i` is refused. The message names where it must be declared rather
than saying "must be a variable", because a value parameter *is* one — the
complaint was never about what it is.

**And it may not be *threatened*** (§6.8.3.9, ADR-0089) — assigned to, passed as
an actual `var` parameter, read into, or reused as the control variable of a
nested `for`. §6.9.4's list of threats is the one ADR-0046 already walks for a
protected parameter, so `Threatened` gained a second reason to answer yes and
the call sites needed nothing; the reason is keyed on the **symbol**, because a
procedure's own local `i` is not the `i` an enclosing block loops over.
The clause also reaches "any procedure-and-function-declaration-part of the
block", where the threat may sit in a procedure that is **never called** — so a
threat made from a nested block is *recorded on the symbol* when it is seen and
the for-statement asks afterwards, which works because `CheckBlock` walks every
nested body before the statement part that loops. Ask the threat questions only
of a name that could be a control variable: the nested-`for` test calls
`Threatened` on the control variable itself, and without that guard a loop
records a threat against itself and then reports it.

**A variant part's labels are exactly its tag-type's values** (§6.4.3.3,
ADR-0096) — no value outside the type, and none of the type left unnamed. This
is the one that surprises: `case tag: integer of 1: …; 2: …` is **refused**,
because `integer` has other values, and the conforming spellings are a covering
tag-type (`type sel = 1..2`) or Extended Pascal's `otherwise`. It was audited
because it looks over-strict, and BSI's own DEV073 header settles it — that
test was *reclassified from CONFORMANCE to DEVIANCE by DP7185*. An `otherwise`
discharges coverage and never membership.

**A string-type is four properties at once** (§6.4.3.2, ADR-0090): packed, an
index-type that is an integer subrange, a smallest *value* of 1 — not a
smallest ordinal, which is why an enum index fails even when `ord` of its lower
bound is 1 — and a component that is `char` and not a subrange of one. ISO 7185
added a largest value above 1; ISO/IEC 10206:1991 §6.4.3.3.2 drops that clause
and nothing else, and this language takes the later reading. Dropping it is
what lets the compiler compile itself, its schema strings having a discriminant
bound.

**Packing decides set compatibility and does not propagate** — two rules that
read alike and are not. §6.4.5 c) makes two set-types compatible only when they
agree on packing, while §6.7.1 leaves a *set-constructor* uncommitted so
`p := [true]` fits either (ADR-0093). §6.4.3.1 then says packing affects one
type's representation only, so §6.6.3.3's "component of a packed variable" is
the **immediate** container: `pa[1].f` over a `packed array of rec` is legal
because `pa[1]` is an unpacked record (ADR-0099).

**Where a goto may land is three conditions, not a prefix test** (§6.8.1,
ADR-0094 and ADR-0101). Only a compound-statement, a repeat-statement and
Extended Pascal's `otherwise` completer hold a *statement-sequence*; a branch of
an if, a loop body, a with body and a case arm are each a single statement, so a
label in one is reachable only from inside it. The completer has no node of its
own, so `stmtPathRec` carries a flag rather than the rule asking a node's kind.

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
beside a field `fred` names no type — and neither does `a: fred`, `array [fred]`,
`set of fred` or `fred(3)`. Asked of the *denoter*, because the field does not
exist on the type yet, and of the **whole** denoter, because the region is the
record and not the text before the point. Asked **before** the lookup: a field's
defining-point is nearer than the region enclosing the program, so a field named
`integer` takes that spelling inside its own record. One function, three call
sites; a *constant* occurrence is still not asked (`doc/sop.md` §7). **Declarations interleave by source position** — constants,
types, variables *and procedures* (ADR-0100) — which is what lets §6.2.2.9 see a
body using a variable declared after it.

A check is omitted only where its absence is *proved* sound — the `for` step and
unary negation are unchecked, and `verify/` carries the theorems saying they
cannot overflow. Don't add a check there, and don't remove one elsewhere.

Most of these are not merely tested — they are **proved** in `verify/` for every
input. Changing one breaks a theorem, not a sample.

## Formal verification (`verify/`)

`verify/verify.py` proves each lowering rule against a property-style statement
of ISO 7185 using Z3, then cross-checks the real binary at the adversarial
points. It runs under `ctest` and skips when z3 is missing
(`pip install z3-solver`). ADR-0013 has the rationale; `verify/README.md` has the
mechanics.

Three things to know before touching it:

- **`lowering.py` is a model of the code generator and must be maintained with
  it.**
  A drifted model keeps passing and proves nothing. When you change a lowering,
  change the model in the same commit.
- **Specifications state properties, never computations.** Writing `iso.py` so it
  computes the answer the way the compiler does would make every proof circular
  and the circularity invisible.
- **A `KNOWN_GAP` that starts holding fails the build.** That is intentional: it
  means the compiler was fixed and the catalogue is now describing a compiler
  that no longer exists. Flip it to `MUST_HOLD` in the same change.

New arithmetic, conversion, or comparison lowering should arrive with a rule.
The catalogue currently has **no known gaps** — 48 rules, 32 of them for every
32-bit input and seven of those at 64 bits too since ADR-0128 — so any gap that appears is something this change introduced.

Don't add a rule that restates the lowering. A check whose ISO condition *is*
the emitted test (the nil check) proves nothing and dilutes what "no known gaps"
means. Cross-check or sanitiser-check those instead, and say which in the ADR.

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
