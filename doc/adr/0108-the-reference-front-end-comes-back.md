# ADR-0108: The reference front end comes back

## Status

**Deprecated.** It was accepted, and is retired by
[ADR-0232](0232-afterschool-pascal-is-the-language.md)**. `src/` answered
conformance questions -- it was frozen at the conformance surface by ADR-0117
and skipped every dialect source -- and there is no conformance surface, so
difftest had nothing left to compare and the directory was deleted. The
reasoning below about what a second implementation buys, and what it cannot
see, is unchanged and is why nothing replaces it.

## Context

ADR-0085 retired stage 0 and said what it cost, in its own words: `difftest.sh`
"compared two independent implementations over 436 sources and has no
substitute". Everything left descends from one source — a golden agrees with
whoever wrote it, `tests/bsi/expected.tsv` records what *this* compiler does,
and `verify/` proves a model of the lowering against a model of the standard.

Three releases later the hole is measurable rather than theoretical. The
defects difftest caught were exactly the ones every other oracle agreed about
(ADR-0059's enumerator one apart, ADR-0073's comment-delimiter rule wrong in
*both* compilers, ADR-0074's diagnostic that named two types identically), and
the substitutes built since each carry a stated limit: the BSI suite is a fixed
corpus covering ISO 7185 only (ADR-0086), `tests/spec/` makes a reading
findable without making it checked (ADR-0105), and `langspec-audit`'s
independence was broken by the harness on all seven readers of its second run
(ADR-0107).

## Decision

**`src/` comes back as a front end, and only as a front end.** It builds as
`pascalc-s0`: lexer, parser, Sema, the AST dumper and diagnostics. No code
generator, no runtime, no driver for either.

**It links no LLVM**, which is the fact that makes this affordable and was not
obvious until it was measured: of the eight C++ translation units, only
`codegen.cpp`, `codegen.h` and `main.cpp` ever included an LLVM header, and
`main.cpp` only to drive code generation. The front end was always
dependency-free. So the build gains a C++ compiler requirement and nothing
else — no `LLVM_DIR`, no libLLVM, no version coupling.

**Dropping the code generator costs the oracle nothing**, and this is the part
a reader is most likely to doubt. `difftest.sh` compares `--dump-all`: tokens,
AST, Sema. **Code generation was never among them.** ADR-0025 settled that at
the time — two backends' assembler text is not comparable, LLVM's printer is
not a specification — so CodeGen was checked by *running* what it produced,
and still is. Reviving `codegen.cpp` would have restored 3,849 lines that
difftest never read.

**What it can and cannot catch, stated plainly.** It catches *slips*: a
transcription error, an enumerator one apart, a walk that forgot a case. It
cannot catch a *misreading*, because the same author writes both sides from the
same reading of the standard — and this repository has the proof, in ADR-0073's
comment-delimiter rule, which was wrong in both compilers and which difftest
therefore compared without complaint. **`langspec-audit` remains the only
instrument aimed at misreadings.** These two are complements, not substitutes,
and neither subsumes the other.

**The ongoing tax is smaller than the one ADR-0085 retired, and it is real.**
That record's argument was that every language feature shipped twice in the
same commit. Now only a *front-end* change does: a code generator change, a
runtime change and a coverage flag do not. Of the thirty commits touching
`selfhost/compiler.pas` since stage 0 was retired, twenty-four are Sema and two
are CodeGen, so the honest reading is that the tax falls on most changes and
not all of them.

## Consequences

**It arrives red, deliberately, and is not a `ctest` case yet.** The first run
reports **89 of 731 files disagreeing** — 67 of the tree's own corpus and 22
BSI programs — which is the drift of twenty-four Sema commits the C++ never
received. Wiring a known-red check into the suite would either train people to
ignore a red bar or force a rushed catch-up; it is a script to run until the
number is zero, and a `ctest` case on the commit that gets it there.

**The 89 are the catch-up list and they name themselves.** That is the
property worth having: nobody has to reconstruct what the C++ is missing from
thirty commit messages, because the oracle enumerates its own gaps against the
corpus. They map onto known records — `definingpoint_*` to ADR-0088,
`required_*` to ADR-0087 and ADR-0097, `packedset*` to ADR-0093 and ADR-0099,
`variant_complete` to ADR-0096, `schema_*` to ADR-0107, `trap_succ_subrange` to
ADR-0086.

**642 of 731 already agree**, over a corpus that has roughly doubled since the
C++ last saw it, which is the evidence that the port ADR-0022 to ADR-0025 made
was faithful.

**`difftest.sh` takes two binaries now.** It used to take one and *build* the
Pascal compiler with it; stage 0 cannot build anything any more, and since
ADR-0083 the seed is what builds the compiler. So both sides arrive built and
the script only compares.

**The corpus it runs over is larger than the one ADR-0085 gave up**: 731 files
against 436, because `tests/bsi/suite/` did not exist then. Those 812 programs
were written by people with no stake here, and running two implementations over
them compares two answers on a third party's questions.

**What this does not restore.** No oracle over the code generator, no second
answer about run-time behaviour, and no ability to contradict a reading. The
roadmap's third-party differential (FPC under `-Miso`, or p5) remains the only
candidate that would do the last of those, and this record does not close it.
