---
name: release-engineering
description: Manage the full software release process for Afterschool Pascal — a documentation sync via docs-engineering, version bumps, changelogs, the seed refresh, Git tags, and (when applicable) GitHub releases.
---

When performing release engineering, always follow these steps:

1. **Verify the build is clean from scratch** — configure and build into a fresh
   directory, then run the suite:
   ```sh
   rm -rf build-rel
   cmake -S . -B build-rel -DCMAKE_BUILD_TYPE=Release
   cmake --build build-rel -j
   ctest --test-dir build-rel -j"$(nproc)" --output-on-failure
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

4. **Bring the documentation up to date — invoke `docs-engineering`** and carry
   it out in full, before anything below. A release is the moment the
   documentation is *published*, and it is the last moment it can still be
   changed cheaply, for two reasons this project has paid for:

   - **The reseed freezes the compiler's sources** (step 6). Documentation
     lives in the sources too — the header comment on each program-component,
     the doc comment beside each module-heading, `Usage`'s flag list, and the
     comments in `tests/*.pas` that pin a rule. A comment corrected after the
     reseed is *usually* free and is not always: a reworded diagnostic is a
     string constant in the emitted module, and version 3 needed a second full
     15 MB refresh for exactly that. Do the documentation pass first and the
     question does not arise.
   - **A tag is what a reader arrives at.** `README.md`'s accepted-language
     blocks, the "not accepted yet" list, `doc/roadmap.md` and
     `doc/afterschool-pascal-spec.md` are the contract someone downloading the
     archive reads, and a feature landed without its `docs:` commit is
     invisible to `git log --grep='^docs'` — the cadence CLAUDE.md describes,
     which has been missed for nine features and repaired only by a sweep like
     this one.

   Two of that skill's steps are load-bearing here in particular. Its step 1
   surveys every commit since the last tag that could change what the compiler
   *accepts* — `fix:` included — which is the same survey step 5 below needs to
   classify the release, so do it once and use it twice. And its §7 rule
   applies: **read `doc/sop.md` §7 end to end and date the audit**, since a
   release is the periodic sync that rule was written for.

   Land the result as its own `docs:` commit (or commits) *before* the `chore:
   release` one — the release commit is the version bump and the changelog, and
   nothing else. Then run the suite again — `markdown-links` and
   `markdown-tables` are ctest cases, so a document edited here is checked by
   the same bar as the code — and then `tests/checks/quoted_numbers.py`, which
   is not a ctest case and cannot be (ADR-0379): it reads the summaries the
   gates just printed, so it runs *after* the suite and skips against a log
   older than what the gates measured.

5. **Determine the release type** — from the survey step 4 already ran: all
   unreleased commits since the last tag
   (`git log --oneline $(git describe --tags --abbrev=0 2>/dev/null)..HEAD`,
   otherwise `git log --oneline`), classified as `major`, `minor`, or `patch`
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

6. **Update the version** — it is written in **two** places that must agree:
   the `VERSION` of `project()` in `CMakeLists.txt`, and what `pascalc
   --version` prints, which comes from `selfhost/compiler.pas`. `pascalc-product`
   compares them, so a mismatch fails the suite rather than shipping — let it
   fail rather than editing one of the two by hand and trusting your eyes.

   **Refresh the seed** — `seed/refresh.py` — at the release commit and nowhere
   else (ADR-0085). It refuses a candidate that does not reproduce itself, and
   the `seed-is-current` job in `.github/workflows/ci.yml` checks the same thing
   at the tag: a stale seed still builds a working compiler, from the *previous*
   release's source, so nothing else would notice.

   **Run `tests/checks/seed_current.py` before tagging.** It is the whole of
   what that job runs, and running it here is the only chance to be told
   before a tag exists — including that the seed holds a module this source no
   longer produces, which a per-module comparison alone would not see.

   **Reseed last, and freeze the compiler's sources once you have.** `seed/refresh.py` writes **one seed module per program-component** (ADR-0233) and removes the old ones first, so a component dropped from the tree does not leave a module behind for CMake's glob to link. The seed
   is ~15 MB and 319 000 lines, so every refresh is that much churn in the
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
   `tests/checks/seed_current.py` is the earlier chance and the release has to
   take it deliberately.

7. **Update `CHANGELOG.md`** — `docs-engineering` has kept `Unreleased`
   honest; this step is the one edit it does not make, promoting that section
   to a version. Add a new version entry at the top following
   [Keep a Changelog](https://keepachangelog.com/), grouped under `Added`,
   `Changed`, `Fixed`, `Removed`, or `Security`. For this project:
   - **`Added` leads with language features**, in the words a user would search
     for ("`case` statements", "nested procedures") — not internal pass names.
   - Any change to the behaviour of an already-valid program goes under
     `Changed` with the old and new behaviour both spelled out.
   - Note which bootstrap milestone the release reaches.
   - Create `CHANGELOG.md` if it doesn't yet exist.

8. **Commit the release** — stage `CMakeLists.txt`, `CHANGELOG.md` and the
   refreshed `seed/` and commit as `chore: release vX.Y.Z`. Documentation is
   *not* in it: step 4 landed that as its own `docs:` commit, which is what
   keeps `git log --grep='^docs'` readable as a changelog of what the compiler
   accepts. If the documentation pass finds something after this point, land
   the `docs:` commit before the tag and redo the reseed if it touched a
   compiler source.

9. **Rehearse the archive before tagging** (ADR-0296). The tag job runs
   `tools/release.py`, and the same text runs here:
   ```sh
   tools/release.py --notes vX.Y.Z              # the CHANGELOG section, or a refusal
   tools/release.py --archive build-rel vX.Y.Z  # refuses a tag that is not --version
   tools/release.py --check afterschool-pascal-vX.Y.Z-x86_64-linux.tar.gz
   ```
   `--notes` refusing means step 7 was skipped; `--archive` refusing means
   step 6 was. `--check` is what the job runs against the archive it is about
   to upload, and `release-archive` runs both halves under `ctest` on every
   push, so a script that has stopped working is found before this step.

10. **Push the release commit — the commit alone — and wait for CI to be green
   on it.**
   ```sh
   git push                                   # the commit, and not the tag
   gh run list --limit 1                      # watch it to completion
   ```
   **Do not push the commit and the tag together.** `git push && git push
   --tags` is the shape that costs a version number, and it cost one: v3.10.0
   was tagged on a commit that was green on the machine that cut it and red on
   macOS and on ubuntu:24.04, because a gate compared against the C library's
   `wcwidth` and every platform has a different one (ADR-0398 to ADR-0400).

   The reason it is expensive is that a tag is a **published ref** and the tag
   job is the only thing that creates a release, so a red tag build leaves a
   tag with nothing attached to it and exactly two ways out, both bad: move a
   ref other people may have fetched, or burn the version number and ship the
   next one. Waiting costs one CI cycle and removes the choice.

   **A green local suite is not a green CI**, and that is not a failure of the
   suite. CI runs the corpus on a second architecture, in three container
   images, against a different C library and a different `clang` — which is
   the whole reason those jobs exist. The gates most likely to disagree are
   the ones comparing against something the *machine* supplies rather than
   something this tree carries: a libc, a locale, a sysroot, a wasm engine's
   version, ICU's Unicode version.

11. **Tag the release** — once that run is green, create an annotated tag on
   that commit and push it:
   ```sh
   git tag -a vX.Y.Z -m "vX.Y.Z" && git push --tags
   ```
   Skip if no remote is configured and report the local tag instead. If
   something has landed on the branch since the green run, tag the commit that
   was green rather than the branch tip — the tag names a state that was
   tested, not a moment in time.

12. **The tag does the rest** (ADR-0296, `.github/workflows/ci.yml`). Once
    every oracle job is green, `release` creates the GitHub release **as a
    draft** with the CHANGELOG section as its notes, `package` builds a
    statically linked compiler on an x86-64 and an arm64 runner, runs the
    whole suite over each, archives, checks, and attaches
    `afterschool-pascal-vX.Y.Z-<arch>.tar.gz` with its `.sha256`, and
    `publish` undrafts. Nothing to do by hand but watch it: a red `package`
    leaves a draft to re-run, and a release created by hand before the tag
    only gains assets. `pascalc` is not self-contained — it emits IR and
    nothing else, so a user needs `clang` (ADR-0009, ADR-0085) — and the
    archive's own `README` says so.
