---
name: code-review
description: Perform a project-wide code review of the Afterschool Pascal compiler, covering correctness, ISO 7185 conformance, generated-code quality, bootstrap constraints, tests, documentation, and style.
---

When performing a project-wide code review, always follow these steps:

1. **Survey recent changes** — Run `git log --oneline -20` and skim the corresponding diffs to understand the scope of work before examining individual files. Note which bootstrap milestone (README's dependency list) each commit advances.

2. **Bootstrap constraints** — These are recorded in `doc/adr/` and are load-bearing; a change that violates one is a **High** finding unless it comes with a superseding ADR:
   - **No C++ RTTI in the AST** (ADR-0005). Grep for `dynamic_cast` and `typeid`. New AST nodes must add an `NK` enumerator *and* `static constexpr NK NodeKind`.
   - **No new exception types** (ADR-0005). `ap::ParseAbort` is the only one, thrown by the parser and caught in `main`. Pascal has no exceptions; anything else has to be unwound during the port.
   - **Textual `.ll` stays a working output** (ADR-0006). If codegen starts depending on something with no textual spelling, the stage-1 backend dies with it.
   - C++ constructs with no Pascal equivalent (templates beyond `as<T>`, lambdas capturing by reference across calls, RAII tricks) in the tree walks — flag with the porting cost named.

3. **ISO 7185 conformance** — The project's design axis is conformance over convenience. Review for:
   - *Semantics that differ from the obvious C lowering:* `mod` must yield a non-negative result (not a bare `srem`); `/` is always real division; a leading sign binds to the whole term; `for` evaluates its limit exactly once and must not overflow on the final iteration; a one-character string literal is a `char`. These are pinned by `tests/arith.pas` and `tests/control.pas` — a change that "simplifies" one of them and still passes is a test gap, not a pass.
   - *Deviations:* any behaviour that departs from the standard needs its own ADR (ADR-0002). Short-circuit `and`/`or` is permitted-but-unspecified and already has one (ADR-0010).
   - *Implementation-defined choices* should match what a Turbo/FPC user expects: `maxint` = 2147483647, `TRUE`/`FALSE`, natural integer width.
   - Cite the clause when a review comment turns on the standard's wording.

4. **Formal verification** (`verify/`, ADR-0013) — a change to arithmetic, conversion, or comparison lowering is incomplete without it:
   - **Did `lowering.py` change with `codegen.cpp`?** This is the first thing to check and the easiest to miss. The proofs reason about the model, so a changed lowering with an unchanged model means the suite is now proving things about a compiler that no longer exists — and it stays green while doing it. Treat a lowering change with no model change as a **High** finding unless the operation genuinely has no rule.
   - **Does new arithmetic arrive with a rule?** New operators, builtins, or conversions should be added to `rules.py` with their ISO clause. "Tested" is not the bar here; the existing operators are proved for all inputs.
   - **Is the specification still a property rather than a computation?** A new `iso.py` entry that computes the answer the way the compiler does makes its proof circular and the circularity invisible. This is the single most damaging mistake possible in that directory.
   - **Did a `KNOWN_GAP` get fixed without being reclassified?** The runner fails in that case by design; confirm the catalogue was updated in the same change rather than the rule being deleted.
   - **Is a new `BOUNDED` rule justified?** Bounded width is for claims the solver genuinely cannot discharge at 32 bits. Confirm `FULL` was tried and timed out, rather than bounded being chosen for speed.

5. **Generated-code correctness** — the failure mode that tests catch late:
   - Every new codegen path should be read once at `-O0` (`pascalc-s0 -O0 --emit-llvm f.pas -o /dev/stdout`). `verifyModule` catches malformed IR, not *wrong* IR.
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

   **Measure coverage with `gcov`** — don't eyeball it. Configure a separate coverage build so it never pollutes the normal one:
   ```sh
   cmake -S . -B build-cov -DCMAKE_BUILD_TYPE=Debug \
         -DCMAKE_CXX_FLAGS="--coverage -O0 -g" \
         -DLLVM_DIR=/usr/lib/llvm-21/lib/cmake/llvm
   cmake --build build-cov -j && ctest --test-dir build-cov
   gcov -o build-cov/CMakeFiles/pascalc-s0.dir/src src/*.cpp | grep -A1 "File 'src"
   ```
   `lcov`/`gcovr` are **not installed** — for an HTML report, `apt install gcovr` first (`gcovr -r . --html-details -o cov.html`); otherwise read the `.gcov` files directly.
   - **Confirm the diff is covered, not just the totals.** Cross-check the `#####` lines in `src/<changed>.cpp.gcov` against the lines this change added — every new production line should be executed by some test. A high file percentage hides one untested new branch.
   - **Read totals in context:** `main.cpp`'s object-emission and linking paths are exercised by every test but its error branches are not, and diagnostic paths in `sema.cpp` are uncovered until negative tests exist. Judge `lexer/parser/sema/codegen` on their own.
   - **When a finding is "extract a helper", prefer the independently-testable version** — pulling inline logic into a named function is a net coverage win even if the call site stays uncovered. Note the trade-off in the finding.
   - **State the coverage delta** for touched files in the report (step 11), and raise new uncovered code as a **Tests** finding with the concrete `.pas` case to add.

9. **Documentation quality** — Confirm:
   - New non-obvious behaviour carries a comment naming the ISO clause or the reason (the `mod` adjustment and the `for` limit-then-step both do).
   - `README.md`'s accepted-language list and `CLAUDE.md` still describe reality.
   - A decision that constrains future work got an ADR, and existing ADRs were not edited — they are superseded, not revised (ADR-0001).

10. **Code style** — Confirm:
   - **Formatting is incremental, so check the diff and not the tree.** `.clang-format` is plain LLVM style, but the existing sources are not fully conformant — several dispatch tables are hand-aligned into columns that clang-format collapses. Run `git clang-format HEAD~1` (or `git clang-format` against pending work) and confirm it produces no changes for the lines this change touched. A whole-tree `clang-format --dry-run --Werror` will report hundreds of pre-existing violations; do not report those as findings, and do not let a change bundle a tree-wide reflow with real work — that belongs in its own `style:` commit.
   - The build is warning-free. There is no `-Werror` gate yet; if the change adds warnings, that is a finding.
   - No `printf`/`iostream` output from the compiler except through `Diagnostics` (user-facing errors) or the driver's explicit `fprintf(stderr, "pascalc-s0: ...")`.
   - `clang-tidy` is **not installed**; skip it or `apt install clang-tidy-21`.

11. **Report findings** — Present all identified issues grouped by category: Bootstrap Constraints, Conformance, Verification, Generated Code, Correctness, Code Smell, Tests, Documentation, Style. Assign each a severity of **Critical**, **High**, **Medium**, or **Low**. For every finding, include the file path and line number, a clear description, and a concrete recommendation for how to fix it.
