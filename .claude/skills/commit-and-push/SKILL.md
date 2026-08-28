---
name: commit-and-push
description: Stage, commit, and (when a remote exists) push changes with a well-formed Conventional Commits message.
---

When committing and pushing changes, always follow these steps:

1. **Verify tests pass** — run `ctest --test-dir build --output-on-failure` before committing (rebuild first if sources changed: `cmake --build build -j`). A red bar must not be committed. If a test is being deliberately disabled or its expected output changed, call that out in the commit body along with why the *new* expectation is the correct one.

   Remember that a new `tests/*.pas` pair only becomes a test after re-running `cmake` — a green bar that never ran your new case is not a green bar.

2. **Stage** all relevant changes with `git add <paths>`. Be deliberate — stage only files related to the current topic. Never blindly use `git add -A` if unrelated changes are present. `build/` is ignored; check `git status --short` for stray `.ll`/`.o` artifacts left by manual runs.

3. **Compose the message** following the [Conventional Commits](https://www.conventionalcommits.org/) standard. Use these scopes for this project:
   The compiler is three §6.13 program-components (ADR-0233), and the scope
   still names the *component* the change touches rather than the file — the
   names CLAUDE.md's "Where things live" uses. `lexer`, `parser` and `sema` are
   in `selfhost/apfront.pas`; `codegen` and `driver` are in
   `selfhost/compiler.pas`; a change to the token kinds, the AST record, the
   type records or the string pool is in `selfhost/aptypes.pas` and takes the
   scope of whatever it is *for*:
   - `lexer` — the token kinds, the lexer, the keyword tables
   - `parser` — the node kinds and the recursive-descent productions
   - `sema` — scopes, type rules, type-denoter resolution, constant folding
   - `codegen` — the sequential IR emitter and the layout rules
   - `driver` — the command line, the dumps, `ErrorAt` and the diagnostics
   - `runtime` — `runtime/`
   - `build` — `CMakeLists.txt`, `.gitignore`
   - `doc` — `doc/**`, `README.md`, `CLAUDE.md`
   - `test` — `tests/`
   - Use `feat`, `fix`, `refactor`, `test`, `docs`, `chore` as the type.

   The message should explain *why* the change was made, not just *what* changed. Specifically:
   - When the change advances a bootstrap milestone (README's dependency list), say which one and what it unblocks.
   - When the change encodes a Pascal semantic that differs from the obvious lowering, cite the ISO 7185 clause or the reasoning — that sentence is what stops the next person "simplifying" it.
   - When the change is governed by an ADR, reference it (`per ADR-0005`). When it *changes* a decision, the ADR comes with the commit.

4. **Commit** with the composed message.

5. **Push** the committed changes to the current branch on the remote — **but only if a remote is configured**. Check with `git remote -v` first. If no remote exists, stop here and report the local commit hash; do not invent or add a remote without the user's explicit instruction.

6. **Verify** that the push succeeded and the remote is in sync with the local branch (`git status` should report "up to date").
