---
name: security-audit
description: Perform a project-wide security and safety audit of the Afterschool Pascal compiler.
---

The threat model is worth stating plainly, because it is not the usual one for a
compiler: **`pascalc` parses untrusted input**. A `.pas` file is
attacker-controlled text. Malformed, hostile, or merely enormous source must
produce a diagnostic — never a crash, a hang, or memory corruption. That is the
whole audit in one sentence; the steps below are how it gets checked.

**What the compiler is made of decides where the risk lives** (ADR-0085). No
C++ is in it: `build/bin/pascalc` is `selfhost/compiler.pas` translated by
`seed/pascalc.ll`, so the front end is a Pascal program with array bounds
checked, subranges checked, and every pointer dereference nil-checked — the
class of bug this audit used to be mostly about is now diagnosed by the compiler
that compiled it. **There is no C++ left to keep out of the threat model** —
ADR-0108's reference front end went with ADR-0232 — so what a user runs is the
Pascal compiler, `runtime/pasrt.c`, `runtime/pasrt_posix.c` and
`runtime/pasrt_unicode.c`, and nothing else. What is left is where those checks
do not reach:

- **`runtime/pasrt.c`** — the one piece of C, linked into *every* program this
  compiler builds. A bug here is inherited by all of them.
- **`tools/pascalcc`** — a shell script that builds a `clang` command line.
- **Unbounded work**: recursion, memory and time are not memory-unsafe here,
  but a hang is still a denial of the tool.
- **The generated code**: the checks the compiler emits are what make the
  *output* safe, and an optimiser must not be able to delete them.

When performing a security audit, always follow these steps:

1. **Audit dependencies** — there is deliberately almost no dependency surface:
   `clang` (invoked at run time as an assembler and linker), libc, and libm.
   **LLVM is not a dependency**: nothing links `libLLVM`, and `cmake` takes no
   `LLVM_DIR`. Confirm that is still true:
   ```sh
   grep -rn "find_package\|FetchContent\|ExternalProject" CMakeLists.txt
   ldd build/bin/pascalc
   ```
   Any new third-party library is a decision that needs an ADR *and* a look at
   its own advisory history.

   Two corpora are fetched from third parties rather than committed, and
   neither is a build input. `doc/vendor/`'s standards PDFs are read by a human
   and by nothing else. The Unicode Character Database is read by
   `runtime/unicode/generate.py`, which writes a header that **is** committed
   (ADR-0190) — so the database is a supply-chain input to a *generated source
   file* even though no build step fetches it. Confirm the committed header is
   what the pinned database produces; `unicode-conformance` asks that on every
   run, and it is the check to name if it ever starts skipping.

2. **Run the runtime under sanitizers** — this is the highest-value step, and
   the target is `runtime/pasrt.c` plus the programs the compiler emits, since
   that is where the unchecked memory is. The compiler's own IR can be
   instrumented the same way, because `clang` assembles it:
   ```sh
   cmake -S . -B build-asan -DCMAKE_BUILD_TYPE=Debug \
         -DCMAKE_C_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer -g"
   cmake --build build-asan -j && ctest --test-dir build-asan --output-on-failure
   ```
   Then compile and run the corpus with the sanitizers reaching the *generated*
   program as well:
   ```sh
   for f in tests/*.pas; do
     tools/pascalcc "$f" -o /tmp/t 2>/dev/null || continue
     /tmp/t </dev/null >/dev/null 2>&1
   done
   ```
   Any ASan or UBSan report is a **Critical** finding. `runtime/pasrt.c`'s
   string, file and formatting primitives are where to expect one — they take a
   pointer and a length from generated code and trust both.

3. **Audit the untrusted-input boundary** — the lexer and parser, both in
   `selfhost/compiler.pas`. Review for:
   - **Unterminated constructs** — comments, string literals, and a file ending
     mid-declaration must each produce a diagnostic and stop, not loop. `{`,
     `(*` and `'` all have explicit end-of-file checks; confirm new lexer states
     do too. `selfhost/torture.pas` is the corpus for exactly this and should
     grow when a lexical rule changes.
   - **Recursion is bounded, and the bound is load-bearing** (ADR-0020). The
     parser counts nesting to 1000 levels and reports past it — *and* counts the
     iterations of its spine-building loops toward the same limit, because an
     operator chain is flat for the parser and deep for Sema and CodeGen. Verify
     the bound still holds rather than assuming it:
     ```sh
     python3 -c "open('/tmp/deep.pas','w').write('program D(output);\nbegin\n  writeln('+'('*50000+'1'+')'*50000+')\nend.\n')"
     tools/pascalcc /tmp/deep.pas -o /dev/null; echo $?   # a diagnostic, exit 1
     ```
     A tree the parser accepts must not overflow a later pass, so a change that
     raises the limit is a change to Sema and CodeGen's stack budget too.
   - **Numeric conversion** — the lexer accumulates and checks as it goes rather
     than converting and comparing afterwards (ADR-0036), so an over-long
     literal is diagnosed where it stops being one. A **real** literal is
     carried as its source text all the way into the IR (ADR-0025) and
     converted by LLVM's assembler; confirm nothing on that path assumes it
     parses.
   - **Memory growth** — a source file is read fully into memory and tokenised
     fully. Bounded by input size, which is acceptable; the pools and tables are
     fixed-size arrays that report rather than truncate, and *that* is the
     property to check when one is resized.

4. **Audit the host boundary** — `tools/pascalcc`, which is where a path reaches
   a process. `pascalc` itself writes only the file `-o` names; it cannot spawn
   anything, no standard Pascal program being able to (ADR-0009).
   - **Command construction.** `pascalcc` ends in `exec clang ...` with every
     path a separate quoted word, so no shell re-parses them. Confirm that
     stays true and that no new path builds a command by concatenation or
     reaches `eval`.
   - **Output paths.** Confirm the driver never writes outside a path the user
     named, and that intermediates are removed.
   - **`AFTERSCHOOL_PASCAL_RUNTIME` and `PASCALC`** are read from the
     environment and decide which runtime is linked and which compiler runs. An
     untrusted environment can redirect both. Correct behaviour for a build
     tool, worth stating in the report rather than treating as a finding.

5. **Audit the generated-code contract** — the compiler's output is a program
   that will be run, and the checks it emits are what make that safe:
   - **The checks must survive optimisation.** Every subscript is bounds-checked,
     every subrange store range-checked, every dereference nil-checked, and
     integer `+ - *` carry no `nsw` precisely so the optimiser may not assume
     they do not overflow. Confirm at `-O3`, not only `-O0`.
   - **`verify/` proves the arithmetic ones for every input** (ADR-0013) and is
     the strongest statement available here; a lowering change with no model
     change means those proofs describe a compiler that no longer exists.
   - **Lengths, never NUL.** A string value is a pointer and a length
     (ADR-0051); confirm codegen passes the true length everywhere and that no
     runtime primitive reads to a terminator.
   - **`returns_twice` on `_setjmp` is load-bearing and LLVM does not infer it**
     (ADR-0032). Without it `-O2` will inline a function containing the call and
     the non-local `goto` corrupts the stack. No test catches its removal.

6. **Build and supply-chain check** — confirm no build step downloads anything
   or executes untrusted binaries, that `CMakeLists.txt` embeds no absolute
   paths from the developer's machine, and that nothing under `build/` is
   committed. **`seed/pascalc.ll` is a committed binary artefact in source
   form** — 153k lines of IR that nobody reads and that builds the compiler.
   That is a supply-chain surface by construction: `seed/README.md` states its
   provenance, and the release job in `.github/workflows/ci.yml` is what checks
   the committed seed is what the current source produces. Confirm that job
   still runs at tags.

7. **Fuzz the front end** — the natural next control, not yet set up.
   `afl-fuzz` and `libFuzzer`'s runtime are **not installed**; the cheap version
   needs nothing:
   ```sh
   for i in $(seq 500); do
     f=$(ls tests/*.pas | shuf -n1)
     head -c $((RANDOM % 2000)) "$f" | tr -d '\0' > /tmp/fuzz.pas
     tools/pascalcc /tmp/fuzz.pas -o /dev/null 2>/dev/null
     [ $? -gt 1 ] && cp /tmp/fuzz.pas "/tmp/crash-$i.pas"
   done
   ```
   Truncation alone finds unterminated-construct and lookahead bugs. A **non-1
   exit status is the bug signal**: 0 is success, 1 is a diagnostic, anything
   else is a crash. Fuzz the *runtime* too, by feeding hostile input to a
   compiled program that reads — `read` of a number is the one place the
   runtime parses attacker text (ADR-0076).

8. **Report findings** — document all identified risks grouped by category
   (Dependencies, Memory Safety, Untrusted Input, Host Boundary, Generated Code,
   Build/Supply Chain). Classify each by severity (**Critical / High / Medium /
   Low**) and provide concrete remediation steps. For each finding cite the file
   path and line number, and include the input that triggers it — a crashing
   `.pas` file *is* the reproduction, and belongs in `tests/` once fixed.
