---
name: security-audit
description: Perform a project-wide security and safety audit of the Afterschool Pascal compiler.
---

The threat model is worth stating plainly, because it is not the usual one for a
compiler: **`pascalc` parses untrusted input**. A `.pas` file is attacker-controlled
text, and the compiler is C++ with manual memory management. Malformed, hostile,
or merely enormous source must produce a diagnostic — never a crash, a hang, or
memory corruption. That is the whole audit in one sentence; the steps below are
how it gets checked.

When performing a security audit, always follow these steps:

1. **Audit dependencies** — there is deliberately almost no dependency surface: LLVM 21, libstdc++, and `clang` invoked at run time. Confirm that is still true (`grep -rn "find_package\|FetchContent\|ExternalProject" CMakeLists.txt`). Any new third-party library is a decision that needs an ADR *and* a look at its own advisory history. Check the installed LLVM against distribution security updates; the compiler inherits anything wrong in `libLLVM`.

2. **Run the test suite under sanitizers** — this is the project's equivalent of a memory-safety lint, and it is the highest-value step here. ASan and UBSan work with `g++` (clang's runtime is **not** installed on this machine):
   ```sh
   cmake -S . -B build-asan -DCMAKE_BUILD_TYPE=Debug \
         -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer -g" \
         -DLLVM_DIR=/usr/lib/llvm-21/lib/cmake/llvm
   cmake --build build-asan -j && ctest --test-dir build-asan --output-on-failure
   ```
   Then run the compiler by hand over every file in `tests/` **and** over deliberately broken input. Any ASan or UBSan report is a **Critical** finding; signed-overflow reports in constant folding and literal conversion are the expected first catches.

3. **Audit the untrusted-input boundary** — the lexer and parser are the trust boundary. Review for:
   - **Lookahead past the end.** `Lexer::peek` bounds-checks and returns `'\0'`; `Parser::peek` clamps to the final token. Both must stay that way — the EOF token is what makes the parser's `cur()` always valid, so anything that consumes past it is a bug.
   - **Unterminated constructs** — comments, string literals, and a file ending mid-declaration must each produce a diagnostic and stop, not loop. `{`, `(*`, and `'` all have explicit EOF checks; confirm new lexer states do too.
   - **Numeric conversion** — `strtoll` overflow is checked via `errno`; `strtod` is not, and a huge exponent yields `inf` silently. Malformed or out-of-range literals should be diagnosed, not propagated.
   - **Unbounded recursion — confirmed, not theoretical.** `parseExpr → parseSimpleExpr → parseTerm → parseFactor → parseExpr` recurses once per nesting level, with no depth limit. Verified 2026-08-09: a program whose `writeln` argument is wrapped in 50 000 parentheses crashes the compiler with SIGSEGV (exit 139), not a diagnostic.
     ```sh
     python3 -c "open('/tmp/deep.pas','w').write('program D(output);\nbegin\n  writeln('+'('*50000+'1'+')'*50000+')\nend.\n')"
     tools/pascalcc --emit-llvm /tmp/deep.pas -o /dev/null; echo $?   # 139
     ```
     Standing **Medium** finding (a crash on hostile input, no memory corruption). The fix is a depth counter in the parser reporting "expression nested too deeply" past a few hundred levels. Note that `Sema` and `CodeGen` recurse over the same tree, so the limit has to be low enough to protect them too — a tree the parser accepted can still overflow a later pass.
   - **Memory growth** — a very large source file is read fully into memory and tokenised fully into a `vector<Token>`. Bounded by input size, which is acceptable; note it if the compiler ever grows a mode that reads from a pipe.

4. **Audit the driver's host interaction** — `src/main.cpp` touches the filesystem and spawns a process:
   - **Command construction.** Linking builds a shell command string for `std::system` with single quotes around paths (ADR-0009). A path containing a single quote breaks out of the quoting — with the output path under user control this is command injection in the classic form. It is low-risk in the current use (the user already controls the command line) but it is the one place in the codebase where untrusted text reaches a shell. Recommend `posix_spawn`/`execvp` with an argv array; keep it as a standing **Medium** finding until fixed.
   - **Output paths.** `stripExtension` derives the object and executable paths from the input path; confirm the compiler never writes outside a path the user named.
   - **Temporary files.** The object file is written next to the input and removed unless `--keep-temps`; it is not created with `O_EXCL` in a private directory, so it can clobber an existing file of that name. Note where that matters.
   - **`AFTERSCHOOL_PASCAL_RUNTIME`** is read from the environment and interpolated into the link command — an untrusted environment can redirect which `libpasrt.a` gets linked. Correct behaviour for a compiler, worth stating.

5. **Audit the generated-code contract** — the compiler's output is a program that will be run:
   - Runtime checks that exist must not be silently droppable: `div`/`mod` by zero reaches `pas_runtime_error`. Confirm the check survives at `-O3` (the `unreachable` after the error call is deliberate and correct, since the call does not return — but verify it is not letting the optimiser delete the check itself).
   - `pas_write_str` takes a pointer and a length; confirm codegen always passes the true literal length and never relies on NUL termination.
   - Missing checks are a gap, not yet a vulnerability: no bounds checking exists because arrays do not exist. When they land, subscript checking is a security-relevant decision that needs its own ADR.

6. **Build and supply-chain check** — confirm no build step downloads anything or executes untrusted binaries, that `CMakeLists.txt` does not embed absolute paths from the developer's machine beyond the intended `APASCAL_RUNTIME_DIR`, and that nothing under `build/` is committed.

7. **Fuzz the front end** — the natural next control, not yet set up. `afl-fuzz` and `libFuzzer`'s runtime are **not installed**; the cheap version needs nothing:
   ```sh
   # random mutations of the existing corpus, looking for crashes rather than wrong output
   for i in $(seq 500); do
     f=$(ls tests/*.pas | shuf -n1)
     head -c $((RANDOM % 2000)) "$f" | tr -d '\0' > /tmp/fuzz.pas
     tools/pascalcc --emit-llvm /tmp/fuzz.pas -o /dev/null 2>/dev/null
     [ $? -gt 1 ] && cp /tmp/fuzz.pas "/tmp/crash-$i.pas"   # exit >1 means signal, not diagnostic
   done
   ```
   Truncation alone finds unterminated-construct and lookahead bugs. A **non-1 exit status is the bug signal**: 0 is success, 1 is a diagnostic, anything else is a crash.

8. **Report findings** — document all identified risks grouped by category (Dependencies, Memory Safety, Untrusted Input, Host Boundary, Generated Code, Build/Supply Chain). Classify each by severity (**Critical / High / Medium / Low**) and provide concrete remediation steps. For each finding cite the file path and line number, and include the input that triggers it — a crashing `.pas` file *is* the reproduction, and belongs in `tests/` once fixed.
