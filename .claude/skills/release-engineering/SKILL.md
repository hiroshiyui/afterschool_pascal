---
name: release-engineering
description: Manage the full software release process for Afterschool Pascal — version bumps, changelogs, Git tags, and (when applicable) GitHub releases.
---

When performing release engineering, always follow these steps:

1. **Verify the build is clean from scratch** — configure and build into a fresh
   directory, then run the suite:
   ```sh
   rm -rf build-rel
   cmake -S . -B build-rel -DCMAKE_BUILD_TYPE=Release -DLLVM_DIR=/usr/lib/llvm-21/lib/cmake/llvm
   cmake --build build-rel -j
   ctest --test-dir build-rel --output-on-failure
   ```
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
   cannot see everything a user does. Confirm on a fresh checkout that
   `pascalc hello.pas` produces a runnable binary, `--emit-llvm` produces IR that
   `llc` accepts, the `-h` output matches the flags that actually exist, and a
   deliberately broken program produces a diagnostic and exit status 1 rather
   than a crash.

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

5. **Update the version** — **the `project()` call in `CMakeLists.txt` carries no
   `VERSION` yet, and `pascalc` has no `--version` flag.** The first release must
   add both: `project(afterschool_pascal VERSION X.Y.Z LANGUAGES C CXX)`, a
   `target_compile_definitions` carrying it into the driver, and a `--version`
   handler beside `--help`. A compiler that cannot report its own version makes
   every future bug report worse; do not ship a tag without it.

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
   for a source-only release.* `pascalc` is not self-contained: it links
   `libLLVM`, it needs `clang` on `PATH` to link programs (ADR-0009), and it
   needs `libpasrt.a` findable via the baked-in `APASCAL_RUNTIME_DIR` or
   `AFTERSCHOOL_PASCAL_RUNTIME`. A binary tarball must therefore ship the runtime
   library alongside the compiler and document the `clang` and LLVM runtime
   requirements, or it will fail on the user's first compile in a way that looks
   like a compiler bug. Verify any candidate tarball by unpacking it somewhere
   with a different path and compiling `hello.pas` from there.

10. **Create a GitHub release** — if a GitHub remote is configured, use
    `gh release create vX.Y.Z --title "vX.Y.Z" --notes "..."` with the
    corresponding `CHANGELOG.md` section as the release notes. Use `--notes`
    (not `--body`). Attach any artifacts from step 9 with
    `gh release upload vX.Y.Z <file>`.
