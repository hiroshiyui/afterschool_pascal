---
name: release-engineering
description: Manage the full software release process for Afterschool Pascal — version bumps, changelogs, Git tags, and (when applicable) GitHub releases.
---

When performing release engineering, always follow these steps:

1. **Verify the build is clean from scratch** — configure and build into a fresh
   directory, then run the suite:
   ```sh
   rm -rf build-rel
   cmake -S . -B build-rel -DCMAKE_BUILD_TYPE=Release
   cmake --build build-rel -j
   ctest --test-dir build-rel --output-on-failure
   ```
   No `LLVM_DIR`: nothing links libLLVM since ADR-0085. What the build needs is
   `clang` on PATH to assemble the IR the seed and the compiler emit, and
   nothing else — no C++ compiler, since ADR-0232 deleted `src/`, and the
   CMake project declares `LANGUAGES C`.
   A from-scratch build catches plumbing bugs that an incremental build hides —
   in this project specifically, a `tests/*.pas` pair added without re-running
   `cmake` is invisible until someone configures fresh, and a missing include
   shows up only when nothing is cached.

2. **Verify formatting and the warning bar** — the build must be warning-free;
   don't release with a yellow bar. Formatting is checked **incrementally**
   (`git clang-format <last-tag>` should be a no-op for the release's own
   changes) — the tree is not fully clang-format clean, so a tree-wide check
   reports pre-existing noise rather than a release blocker. If a tree-wide
   reflow is wanted, land it as its own `style:` commit *before* starting the
   release, never inside it.

3. **Sanity-check the compiler by hand** — the suite compares stdout, so it
   cannot see everything a user does. Confirm on a fresh checkout that:
   - `tools/pascalcc hello.pas -o hello` produces a runnable binary. **`pascalc`
     itself does not** — it writes IR and stops (ADR-0085), so there is no
     `--emit-llvm` flag and never was: emitting IR is the whole of what it does.
   - `llc` accepts that IR. Pass **`-relocation-model=pic`**, or link the result
     with `clang -no-pie`: `llc` defaults to a non-PIC model and the system
     linker defaults to PIE, so the mismatch produces
     `relocation R_X86_64_32 against '.bss' can not be used when making a PIE
     object` — which looks like a compiler defect and is an `llc` invocation.
     `clang` compiling the `.ll` directly is what the suite and `tools/pascalcc`
     use, and it picks the model itself, which is why this only ever bites here.
   - the `-h` output matches the flags `ParseArgs` accepts — there is a `ctest`
     case for this since v1.2.0, so it is a spot check rather than the check.
   - a deliberately broken program produces a diagnostic and **exit status 1**
     rather than a crash.

   `llc` is worth running over more than `hello.pas`, because it is a second
   reader of the emitted IR and the only one that is not `clang`: the corpus
   (both standards), the committed seed, and `selfhost/compiler.pas` itself. The
   strongest form is to link `llc`'s output into a compiler and have it
   translate every program-component — each module's IR must be byte-identical to what the
   clang-built compiler produced, since the two are the same program.

4. **Determine the release type** — review all unreleased commits since the last
   tag (`git log --oneline $(git describe --tags --abbrev=0 2>/dev/null)..HEAD`,
   otherwise `git log --oneline`) and classify as `major`, `minor`, or `patch`
   per [Semantic Versioning](https://semver.org/).

   For a compiler, the public interface is **the accepted language, the
   diagnostics, and the command line** — not the C++ API. Until self-hosting is
   reached the project stays on `0.y.z`, and:
   - accepting new syntax, or adding a flag → minor
   - a bug fix that changes what an existing valid program does → minor, and it
     must be called out prominently; silently changing a program's output is the
     one thing users cannot forgive in a compiler
   - fixing a crash or a wrong diagnostic → patch

   Present the recommendation to the user and confirm before proceeding.

5. **Update the version** — it is written in **two** places that must agree:
   the `VERSION` of `project()` in `CMakeLists.txt`, and what `pascalc
   --version` prints, which comes from `selfhost/compiler.pas`. `pascalc-product`
   compares them, so a mismatch fails the suite rather than shipping — let it
   fail rather than editing one of the two by hand and trusting your eyes.

   **Refresh the seed** — `seed/refresh.sh` — at the release commit and nowhere
   else (ADR-0085). It refuses a candidate that does not reproduce itself, and
   the `seed-is-current` job in `.github/workflows/ci.yml` checks the same thing
   at the tag: a stale seed still builds a working compiler, from the *previous*
   release's source, so nothing else would notice.

   **Run `tests/checks/seed_current.sh` before tagging.** It is the whole of
   what that job runs, and running it here is the only chance to be told
   before a tag exists — including that the seed holds a module this source no
   longer produces, which a per-module comparison alone would not see.

   **Reseed last, and freeze the compiler's sources once you have.** `seed/refresh.sh` writes **one seed module per program-component** (ADR-0233) and removes the old ones first, so a component dropped from the tree does not leave a module behind for CMake's glob to link. The seed
   is ~10 MB and 240 000 lines, so every refresh is that much churn in the
   history, and `seed-is-current` compares it to the compiler **byte for byte**
   at the tag — a single character changed in the source afterwards, even
   inside a comment that costs no IR, is only *usually* free. A reworded
   diagnostic is a string constant in the emitted module and is not. Version 3
   paid this twice: the release commit reseeded, a diagnostic naming the removed
   `--std=extended` was found afterwards, and the tree needed a second full
   refresh before the tag could be cut. The order that avoids it is: land every
   source change, *then* bump the version, *then* reseed, then tag. If a source
   change turns out to be necessary after the reseed, redo the reseed — do not
   tag over a stale seed: the job that catches it runs only at the tag, so
   `tests/checks/seed_current.sh` is the earlier chance and the release has to
   take it deliberately.

6. **Update `CHANGELOG.md`** — add a new version entry at the top following
   [Keep a Changelog](https://keepachangelog.com/), grouped under `Added`,
   `Changed`, `Fixed`, `Removed`, or `Security`. For this project:
   - **`Added` leads with language features**, in the words a user would search
     for ("`case` statements", "nested procedures") — not internal pass names.
   - Any change to the behaviour of an already-valid program goes under
     `Changed` with the old and new behaviour both spelled out.
   - Note which bootstrap milestone the release reaches.
   - Create `CHANGELOG.md` if it doesn't yet exist.

7. **Commit the release** — stage `CMakeLists.txt`, `CHANGELOG.md`, and any
   README/ADR updates together and commit as `chore: release vX.Y.Z`.

8. **Tag the release** — create an annotated tag
   (`git tag -a vX.Y.Z -m "vX.Y.Z"`) and push both the commit and the tag
   (`git push && git push --tags`). Skip if no remote is configured and report
   the local tag instead.

9. **Consider what a binary release would even mean** — *only when producing a
   downloadable artifact; the project ships source and tags today, so skip this
   for a source-only release.* `pascalc` is not self-contained: it emits IR and
   nothing else, so a user needs `clang` to assemble it (ADR-0009, ADR-0085) and
   `libpasrt.a` to link against, found through `AFTERSCHOOL_PASCAL_RUNTIME`.
   `tools/pascalcc` is the piece that ties those together and would have to ship
   with it. A binary tarball must therefore ship the runtime
   library alongside the compiler and document the `clang` and LLVM runtime
   requirements, or it will fail on the user's first compile in a way that looks
   like a compiler bug. Verify any candidate tarball by unpacking it somewhere
   with a different path and compiling `hello.pas` from there.

10. **Create a GitHub release** — if a GitHub remote is configured, use
    `gh release create vX.Y.Z --title "vX.Y.Z" --notes "..."` with the
    corresponding `CHANGELOG.md` section as the release notes. Use `--notes`
    (not `--body`). Attach any artifacts from step 9 with
    `gh release upload vX.Y.Z <file>`.
