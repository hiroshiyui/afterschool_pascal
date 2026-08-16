---
name: code-review
description: Perform a project-wide code review of the Afterschool Pascal compiler, covering correctness, ISO 7185 conformance, generated-code quality, bootstrap constraints, tests, documentation, and style.
---

When performing a project-wide code review, always follow these steps:

1. **Survey recent changes** — Run `git log --oneline -20` and skim the corresponding diffs to understand the scope of work before examining individual files. Note which bootstrap milestone (README's dependency list) each commit advances.

2. **The constraints that are still live** — recorded in `doc/adr/` and load-bearing; a change that violates one is a **High** finding unless it comes with a superseding ADR:
   - **Textual `.ll` stays a working output** (ADR-0006). This got *more* load-bearing when stage 0 was retired: `seed/pascalc.ll` is the committed compiler, so the textual backend is now what makes the repository buildable at all (ADR-0085).
   - **The seed is refreshed at release tags, not per commit** (ADR-0085). A change that regenerates `seed/pascalc.ll` outside a release is 6 MB of churn and a finding.
   - **`selfhost/compiler.pas` is one source file** (ADR-0024), written in Extended Pascal (ADR-0082), and is the compiler. Since ADR-0108 `src/` is back as a **reference front end** — lexer, parser, Sema, no code generator, no LLVM — so `difftest` compares two implementations again over tokens/AST/Sema. Its baseline is **empty** — it arrived red at 89 of 731 and every one of those rules has been ported — so any file it names is a disagreement the change under review introduced. **A lexer, parser or Sema change lands in both**, or `difftest` fails; a CodeGen change lands in one, because difftest never compared generated code.
   - ADR-0005's *no C++ RTTI, no new exception types* is **historical**: it constrained the C++ *compiler*, which no longer exists — `src/` is back since ADR-0108, but as a front end that builds no `llvm::Module` and needs no downcast in a code generator. It is why the AST is a tag and a variant record, and reading it explains the shape of `selfhost/compiler.pas`; it constrains nothing now.

3. **ISO 7185 conformance** — The project's design axis is conformance over convenience. Review for:
   - *Semantics that differ from the obvious C lowering:* `mod` must yield a non-negative result (not a bare `srem`); `/` is always real division; a leading sign binds to the whole term; `for` evaluates its limit exactly once and must not overflow on the final iteration; a one-character string literal is a `char`. These are pinned by `tests/arith.pas` and `tests/control.pas` — a change that "simplifies" one of them and still passes is a test gap, not a pass.
   - *Deviations:* any behaviour that departs from the standard needs its own ADR (ADR-0002). Short-circuit `and`/`or` is permitted-but-unspecified and already has one (ADR-0010).
   - *Implementation-defined choices* should match what a Turbo/FPC user expects: `maxint` = 2147483647, `TRUE`/`FALSE`, natural integer width.
   - Cite the clause when a review comment turns on the standard's wording.

4. **Formal verification** (`verify/`, ADR-0013) — a change to arithmetic, conversion, or comparison lowering is incomplete without it:
   - **Did `lowering.py` change with the code generator?** This is the first thing to check and the easiest to miss, and it got harder: the model can no longer be read line by line against C++, so `--crosscheck` and the `trap_*.pas` goldens are the whole of what ties it to the compiler (ADR-0085). The proofs reason about the model, so a changed lowering with an unchanged model means the suite is now proving things about a compiler that no longer exists — and it stays green while doing it. Treat a lowering change with no model change as a **High** finding unless the operation genuinely has no rule.
   - **Does new arithmetic arrive with a rule?** New operators, builtins, or conversions should be added to `rules.py` with their ISO clause. "Tested" is not the bar here; the existing operators are proved for all inputs.
   - **Is the specification still a property rather than a computation?** A new `iso.py` entry that computes the answer the way the compiler does makes its proof circular and the circularity invisible. This is the single most damaging mistake possible in that directory.
   - **Did a `KNOWN_GAP` get fixed without being reclassified?** The runner fails in that case by design; confirm the catalogue was updated in the same change rather than the rule being deleted.
   - **Is a new `BOUNDED` rule justified?** Bounded width is for claims the solver genuinely cannot discharge at 32 bits. Confirm `FULL` was tried and timed out, rather than bounded being chosen for speed.

5. **Generated-code correctness** — the failure mode that tests catch late:
   - Every new codegen path should be read once at `-O0` (`tools/pascalcc -S f.pas -o /dev/stdout`). Nothing verifies the module any more — the C++ backend called `verifyModule`, and what catches malformed IR now is `clang` refusing to assemble it, which catches *malformed* and never *wrong*.
   - Signed vs unsigned comparison: `integer` compares signed, `char`/`boolean` unsigned. An `ICmpSLT` on a `char` is a real bug.
   - Integer width: `integer` is `i32`, but the runtime takes `i64` — check the `SExt` is present.
   - Basic-block hygiene: every block ends in exactly one terminator, and `b_.SetInsertPoint` is restored after any helper that creates blocks (`guardNonZero` and the short-circuit path both do).
   - φ nodes must name the block the value actually arrived from — `GetInsertBlock()` *after* emitting the operand, not the block you started in.

6. **Correctness and logic** — Review for:
   - Null `Type*` or unresolved `Symbol*` reaching codegen — Sema's invariant (ADR-0008) says it cannot happen, so a new node kind added to Sema but not annotated is a latent crash.
   - Unchecked `std::stoll`/`strtod` overflow on literals; the lexer checks `ERANGE` and should keep doing so.
   - Signed overflow in constant folding (`evalConst` negation of the most negative integer).
   - `slots_` lookups with `operator[]` on a symbol that was never allocated — inserts null and crashes later.

7. **Code smells** — Flag:
   - Duplicated dispatch that should be a table entry (the keyword map and `tokenName` are the pattern to follow).
   - Functions over ~60 lines without justification; large `switch`es over `NK` or `Tok` are the accepted exception.
   - Magic numbers — field-width sentinels, `maxint`, type sizes should be named.
   - A `default:` in a `switch` over `NK`/`Tok`/`TypeKind` that hides missing cases: prefer exhaustive switches so adding an enumerator produces a warning.
   - Dead code and stale commented-out blocks.

8. **Test coverage** — Verify:
   - Each new language feature has a `tests/name.pas` + `tests/name.out` pair (ADR-0011), and the pair asserts *semantics*, not instruction selection.
   - A new test requires re-running `cmake` to register — confirm the reviewer actually ran it.
   - Diagnostics are part of the interface: a change to an error message or a new error condition should come with a case, once the negative-test form exists (noted as a gap in ADR-0011 — if the change adds errors, say so).

   **There is a coverage tool now, and it answers a narrower question than the
   one a review asks.** `gcov` went out with `src/`, but `pascalc --coverage`
   (ADR-0104) instruments the compiler with itself, and three `ctest` cases read
   it: `diagnostic-coverage`, `procedure-coverage` and `line-coverage`. Run them
   before arguing about coverage — they are seconds, and they turn "is this
   reached?" into a fact for whole procedures and whole statements.

   What they do **not** answer is the question a review usually has, which is
   about a *branch*. `line-coverage` counts a statement, so `if c then a else b`
   on one line is covered when either arm runs, and `procedure-coverage` says
   only that a procedure was entered. So coverage of the thing under review is
   still argued, and the argument has to be concrete:

   - **Name the case that reaches each new branch.** "Covered by the suite" is
     not a claim; `tests/foo.pas:12 takes the else` is. A branch you cannot name
     a case for is uncovered, and that is a **Tests** finding with the `.pas`
     file to add. The gates cannot make this claim for you — that is the gap
     `doc/sop.md` §7 records.
   - **Count, don't assume.** This project's history is a list of things nobody
     had counted: no file had a tab, no file had a parse error, Sema reached 48
     of its 85 messages, four documented `--dump` flags no case had ever passed.
     `grep -c` on the corpus for the construct under review is thirty seconds
     and has been wrong more often than not.
   - **A new procedure argued unreachable goes in a catalogue, not in a
     comment.** `tests/checks/uncovered_procedures.txt` fails in both
     directions, so an entry that starts being reached is as loud as a procedure
     that stops being. Say in the entry whether the argument is a proof or an
     observation — the two already there are one of each, and they are not worth
     the same.
   - **A diagnostic needs a case in `selfhost/badparse/` or `selfhost/badsema/`**,
     one file per message for the parser (it stops at its first) and shared
     files for Sema (it accumulates). Since ADR-0085 those are ordinary ctest
     cases with `.err` goldens, so adding one is adding a file and re-running
     `cmake`.
   - **Remember what the goldens cannot do.** A golden agrees with whatever
     wrote it, so "the tests pass" says nothing about a construct no test
     *names*. That is the gap every conformance sweep in `doc/roadmap.md` was
     opened by. `difftest` closes part of it — a second implementation disagrees
     without being asked a question someone here composed — but only for the
     **front end**, and only for *slips*: both sides are written by one author
     from one reading, which is how ADR-0073's comment rule was wrong in both.

9. **Documentation quality** — Confirm:
   - New non-obvious behaviour carries a comment naming the ISO clause or the reason (the `mod` adjustment and the `for` limit-then-step both do).
   - `README.md`'s accepted-language list and `CLAUDE.md` still describe reality.
   - A decision that constrains future work got an ADR, and existing ADRs were not edited — they are superseded, not revised (ADR-0001).

10. **Code style** — Confirm:
   - **Formatting is incremental, so check the diff and not the tree.** `.clang-format` is plain LLVM style, but the existing sources are not fully conformant — several dispatch tables are hand-aligned into columns that clang-format collapses. Run `git clang-format HEAD~1` (or `git clang-format` against pending work) and confirm it produces no changes for the lines this change touched. A whole-tree `clang-format --dry-run --Werror` will report hundreds of pre-existing violations; do not report those as findings, and do not let a change bundle a tree-wide reflow with real work — that belongs in its own `style:` commit.
   - The build is warning-free. There is no `-Werror` gate yet; if the change adds warnings, that is a finding.
   - No output from the compiler except through `ErrorAt` (which decides the diagnostic format in one place) and the dumps. A bare `writeln` in a tree walk is a finding.
   - `clang-tidy` is **not installed**; skip it or `apt install clang-tidy-21`.

11. **Report findings** — Present all identified issues grouped by category: Bootstrap Constraints, Conformance, Verification, Generated Code, Correctness, Code Smell, Tests, Documentation, Style. Assign each a severity of **Critical**, **High**, **Medium**, or **Low**. For every finding, include the file path and line number, a clear description, and a concrete recommendation for how to fix it.
