# ADR-0103: Coverage is an IR pass and a comment

## Status

Accepted.

## Context

`doc/sop.md` §5 said coverage here was argued rather than measured, and the
blind-spot register said the same thing in one line: *"§5 is an argument, not a
number."* That was true from the moment `src/` was deleted — `gcov` measured
C++, there is no C++, and nothing instruments a Pascal program.

The gap mattered more than it looks. This project's history is a list of things
nobody had counted: no file had a tab, no file had a parse error, Sema reached
48 of its 85 messages, a conformance sweep found 32 diagnostics unreached at
once. Every one of those was found by someone counting, never by the suite. A
green suite over an uncounted corpus is exactly the failure this repository
keeps having.

Three ways to measure were available, and the choice between them is the
decision.

**Pascal line coverage** is what a reader means by "coverage": the denominator
is lines a human wrote. It needs the compiler to emit line information — either
DWARF, or a counter call per statement behind a `--coverage` flag. Every AST
node already carries `line, col`, so it is buildable; it is a feature of the
product, with an ADR, tests and runtime support of its own.

**IR basic-block coverage** needs no compiler change at all, and was measured
before being rejected: **8,304 of the compiler's own 26,655 basic blocks are the
bounds-check and nil-check failure paths CodeGen emits for its own subscripts.**
A correct run enters none of them, by design. So a third of the denominator is
unreachable, the number came out at 33%, and no one could act on it or improve
it. A metric whose ceiling is an artefact of the thing being measured is worse
than no metric, because it will be quoted.

**Procedure coverage** needs no compiler change either, saturates quickly, and
is coarse — a two-hundred-line procedure entered once counts. But it is
interpretable, and the first run answered a question nobody had asked.

## Decision

**Measure procedure coverage now, with SanitizerCoverage over the emitted IR,
and gate it with an allowlist that fails in both directions.** Pascal line
coverage is deferred, not declined.

Four things follow from that, and each is the part a reader would otherwise find
arbitrary.

**Coverage is possible here only because the backend is textual.**
`-fsanitize-coverage=` is an LLVM *IR* pass, so clang applies it to the `.ll`
this compiler emits — no front end, no source language, no debug info. ADR-0006
kept textual `.ll` a first-class output for the bootstrap and ADR-0085 made it
the only backend; this is a third thing it buys, and it is the reason the
measurement costs a script rather than a feature.

**The mapping is a comment, because the name is a counter.** A procedure's LLVM
name is `pNNN`, and `irId` follows the order CodeGen walked the tree — not the
order the source declares, so it cannot be recovered externally. An inferred
offset was tried against the declaration list and *fitted*, which is precisely
the kind of unchecked claim this project keeps being caught by, so it was
thrown away. `EmitProcBody` now writes `; <spelling> <line>` beside each
`define`. It costs no linkage, no assembler can act on it, and it makes `-S`
output readable, which is worth having on its own.

**The allowlist is the instrument, not the percentage.** A number hides which
procedure was lost. `tests/checks/uncovered_procedures.txt` carries one entry
per unentered procedure with the argument for it, and
`tests/checks/coverage.py` fails in **both** directions — a procedure that
becomes entered is as loud as one that stops being. That is `verify/`'s
`KNOWN_GAP` rule (ADR-0013) applied to a third catalogue, after
`unreachable_diagnostics.txt`.

**The instrument's own blind spot is written down.** `coverage.py` enumerates
the corpus by glob, so what `irtest.sh`, `producttest.sh`, `verify.py` and the
BSI runner drive is invisible to it — which is how `Usage` and `Version` came
out as uncovered when `--version` was in fact asserted by `producttest.sh` all
along. The script runs `-h` and `--version` itself now, and the limitation is a
row in the register rather than a surprise.

## Consequences

**The first run found the dumps.** 90.7%, and among the 52 unentered procedures
a run of 33 consecutive ones — an entire contiguous region of the source. It was
the dump walkers: `--dump-tokens`, `--dump-ast`, `--dump-sema` and `--dump-all`
are four documented flags, and **no case in the corpus passed any of them**.
Nothing checked they did not crash. `tests/dumps/` is the answer — five cases
with goldens, and a harness of their own, because a dump case compares what the
*compiler* writes to standard output where every case under `tests/` compares
what the compiled *program* writes.

Writing them found a wrong claim of the kind ADR-0073 warns about: a comment
asserting `--dump-tokens` prints `=== tokens`. It does not — the banner belongs
to `--dump-all`, which has three sections to separate, and a single-stage flag
writes its section bare. The comment was corrected before the golden was taken.

**It found dead code.** `StrIsLit` had no callers at all — the narrow
counterpart of `StrIsWide` that `LookupKeyword` had ended up inlining. Deleted.

**It found an unwritten program.** `CopyType` is entered when a schema's body
resolves to a shared singleton — `counter(limit: integer) = integer`. Every
schema in the corpus produced an array or a record, so the one place a `Type` is
duplicated rather than interned was made by nothing.
`tests/extended/schema_simple_body.pas` is that program.

**It made a manual release step mechanical.** `Usage` was entered by no case, so
nothing ran `-h`; the release checklist said "confirm the `-h` output matches
the flags that actually exist" and a person did it by eye, once a release.
`producttest.sh` now derives the accepted flags from `ParseArgs` and checks each
is documented — the two describing the same compiler being the thing worth
knowing, which a golden could not have said.

**Two procedures are argued unreachable, and the arguments are not equally
strong.** `EmitTrapLength` is *proved*: `IsCharArray` implies `IsStringOrChar`,
so the arm that would reach it with a dynamic extent is itself unreachable, and
the arm that is reachable requires static bounds on both operands.
`EmitStringValue` is *empirical* — eighteen candidate positions compiled, none
reaching it — and its entry says so rather than reading as though it were
proved. Overstating it would have been the ADR-0072 fault in a new place.

**The number is now 554 of 556, which is the argument for what comes next.**
Procedure coverage is close to saturated and will stop moving; what it cannot
see is the branch. That is the case for Pascal line coverage, and this record is
what it should be read against.

**Costs.** The instrumented build is rebuilt from stage-2 IR on every run
(`build/pascalc.ll` is the *seed's* output and predates any change being
measured), which is about two seconds. `tests/checks/covrt.c` is a second C file
in a repository whose runtime is deliberately one — it is test tooling, kept
under `tests/` so that distinction is physical, and it exists because linking
clang's own `libclang_rt` drags in a UBSan archive Debian does not ship.
