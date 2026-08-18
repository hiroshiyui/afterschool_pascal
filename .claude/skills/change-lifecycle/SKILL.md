---
name: change-lifecycle
description: The standard operating procedure for landing a change in this compiler — classify it, meet the gates its class demands, mutation-check it, and route to the right specialist skill. Invoke at the start of any non-trivial change, not at the end.
---

`doc/sop.md` is this procedure written for people, with the reasoning and the
oracle table. This file is the same procedure in the order an agent executes it.
Read `doc/sop.md` §1 once before the first change of a session — the gates below
only make sense as answers to the blind spots it lists.

**The rule everything rests on:** a green suite is not evidence. Evidence is a
named case that fails without the change.

When landing a change, always follow these steps:

1. **Classify it, taking the most demanding class that applies.**

   - **A — Lowering.** CodeGen emits something different.
   - **B — Language rule.** Sema accepts or refuses something new; a new
     diagnostic.
   - **C — Runtime.** `runtime/pasrt.c`.
   - **D — Harness / build.** `tests/run_test.sh`, `CMakeLists.txt`, CI, `seed/`.
   - **E — Documentation.** ADRs, README, CLAUDE.md, comments.

   Say the class out loud in your first message about the change. A change is
   often two — a lowering that cannot be tested without a harness change is A
   and D, and both sets of gates apply.

2. **Before writing code, answer the class's *design* questions.** These are the
   ones that are expensive to discover after the fact:

   - **A:** does `verify/` have a rule for this operation? If yes, `lowering.py`
     changes in this commit. If no, say so in the commit message.
     Will the change put an `alloca` anywhere but a prologue? If so, it is
     wrong — ADR-0102: storage that must survive is a frame slot, storage that
     need not is an SSA value.
   - **B:** quote the clause. Then ask whether the violation is an *error*
     (ISO 7185 §3.1 and Annex D — a processor may leave those undetected) or a
     violation (§5.1 e) — must be reported, execution refused). And read the
     **whole** clause: §6.7.3.3 has three closing sentences and this compiler
     shipped two of them.
   - **C:** did `struct pas_file` grow? `PAS_FILE_SIZE` and `fileSize` must
     agree — two files that cannot include one another.
   - **D:** how will you demonstrate the harness change can *fail*?
   - **E:** is an accepted ADR being edited? It must not be. A new record
     supersedes; the old one's **Status** gains a forward pointer.

3. **Write the test before or with the fix, and make it fail.** Run it against
   the unfixed compiler and watch it fail for the reason you intend. A test
   written after a fix, never having failed, is a test of nothing. Where the
   defect is invisible at the default `-O2` — storage especially — the case
   needs a `name.opt` sidecar; where it needs input, a `name.in`; the full list
   of sidecars is in `CLAUDE.md`.

   New diagnostics go in `selfhost/badparse/` (one file per message — the
   parser stops at its first error) or `selfhost/badsema/` (shared files — Sema
   accumulates).

4. **Re-run `cmake`.** Cases are registered by `file(GLOB)` at configure time.
   A green bar that never ran the new case is not a green bar.

5. **Mutation-check.** This is not optional and it is not satisfied by the suite
   being green.

   1. Revert the fix, or make the smallest edit that reintroduces the defect.
   2. Rebuild. Run. **Name the test that fails.**
   3. Restore with plain `cp` and `touch` — **never `cp -p`**, which leaves the
      mutated binary in the build tree and makes the next run read as a broken
      feature.
   4. Rebuild and confirm green.

   Two fixes need two mutations killing two *different* tests. A mutation that
   breaks the build proves nothing — it has to produce a working compiler with
   the defect back in it.

6. **Count what you added.** For diagnostics this is now mechanical — the
   `diagnostic-coverage` case runs with every `ctest`, or on its own:

   ```sh
   python3 tests/checks/diagnostic_coverage.py
   ```

   Account for every message it names: write the case, or prove the branch
   unreachable, **comment it at its site** with what would have to change, and
   add it to `tests/checks/unreachable_diagnostics.txt` with that argument.
   "I could not write the program" is not the argument; "no program can be
   written" is. The check fails in both directions, so an entry that later
   acquires a golden is as loud as a message with none.

   For anything the check does not cover, count by hand and **beware the
   tools**: `grep` here is `ugrep`, whose `--include` does not filter as
   expected — a sweep written with it silently matched `compiler.pas` itself
   and reported everything covered.

7. **Run the oracles the change can reach**, not just `ctest`. Three gates are
   now mechanical and will fail without you: `diagnostic-coverage` is a `ctest`
   case, and CI carries `model-drift` (a CodeGen change with no `verify/`
   change and no `Model-unchanged:` trailer) and `unoptimised` (the corpus at
   `-O0`). Run the last one locally before pushing a CodeGen change —
   `AFTERSCHOOL_PASCAL_OPT=-O0 ctest --test-dir build` — rather than learning
   it from CI:

   ```sh
   ctest --test-dir build --output-on-failure      # 547 cases
   python3 verify/verify.py --pascalc tools/pascalcc --crosscheck
   selfhost/irtest.sh build/bin/pascalc            # stage 2 = stage 3
   selfhost/producttest.sh build/bin/pascalc build/lib
   ```

   If the BSI catalogue moved, fix `tests/bsi/expected.tsv` in this change. **A
   row that starts passing is as loud as one that starts failing** — do not
   "fix" it by accepting the new value without saying why it changed.

8. **Write the ADR if the change constrains future work**, and write it while
   the alternatives are still live — a record written afterwards justifies
   rather than explains. Include what the change does *not* do; that section
   has been the most useful one in this repository.

9. **Commit** via the `commit-and-push` skill. The message says *why*, cites the
   clause or the ADR, and names the mutation and the test that killed it. If a
   golden was regenerated, argue for it — regenerating a golden is a decision,
   not a step.

10. **Escalate when the change's shape calls for it.** These are separate skills;
    invoke them rather than approximating them:

    - **a bug that has resisted the first few probes → `tracing-thoroughly`,
      before attempting a fix.** Reach for it early rather than late: its whole
      point is fanning out competing hypotheses instead of riding one thread,
      and by the time a session feels stuck it has usually already committed to
      a wrong one
    - a batch of conformance work, or work touching many files → `code-review`
    - clauses that admit more than one reading, or a check that broke programs
      in this tree and the programs were edited → `langspec-audit`
    - a feature landed → `docs-engineering` (the `feat:` commit, then a `docs:`
      commit moving it out of README's "not accepted yet" and nothing else)
    - cutting a version → `release-engineering`
    - performance work → `performance-profile`; runtime or file-handling work,
      periodically → `security-audit`

11. **Update the blind-spot register** in `doc/sop.md` §7 if this change
    declined a gate or closed one. A known gap that nobody wrote down is
    indistinguishable from one nobody noticed.
