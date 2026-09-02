# 296. A tag ships an archive

Date: 2026-09-02

## Status

Accepted, 2026-09-03. Closes the first row of `doc/roadmap.md`'s *What would
make this practical to pick up* — *No release carries a binary* — and
rewrites, rather than reverses, the cross-platform chapter's sentence that
aarch64 *works and is not supported*.

## Context

`gh release view v3.4.0 --json assets` answers `[]`, and so does every tag
before it. The first step for every newcomer has therefore been `cmake`,
`clang` and a self-hosting bootstrap, which is the right first step for a
contributor and the wrong one for a user.

Everything an archive needs was already here, separately. `cmake --install`
lays out `bin/pascalc`, `bin/pascalcc`, `lib/libpasrt.a` and `lib/afterschool/`
and `install-layout` runs that layout from a third directory with the
environment emptied ([ADR-0244](0244-an-import-that-names-no-file.md)). The
`aarch64` CI job has built the compiler and run the whole suite natively on
GitHub's arm64 runner on every push since ADR-0159. The `seed-is-current` job
already runs only at a tag. What was missing was the composition, and the
roadmap guessed it at an afternoon, most of it the CI job.

Two facts shaped the composition. **`pascalc` links nothing** (ADR-0009,
ADR-0085): it writes IR and `pascalcc` hands that to `clang`, so a user of
the archive needs `clang` at *use* time whatever the archive holds, and the
archive cannot make that go away. And **shell that runs only at a tag has
failed twice** for want of anywhere to be exercised first —
`seed_current.sh`'s record (ADR-0233) and `format-check`'s (ADR-0282) — so
none of the logic could live in a `run:` block.

## Decision

**A push of a `v*` tag produces `afterschool-pascal-<tag>-<arch>.tar.gz`,
with a `.sha256` beside it, attached to the GitHub release for the tag**, for
`x86_64-linux` and `aarch64-linux`.

1. **`tools/release.sh` is the whole of the logic**, in three modes.
   `--archive <build> <tag> [<arch>] [<out>]` runs `cmake --install` into one
   directory named as the archive is, adds `LICENSE`, `COPYING.RUNTIME` and a
   twelve-line `README` — a person who downloaded this has not got the
   repository's — and writes the tarball and a digest in `sha256sum -c` form.
   It refuses a tag that is not `v` followed by what `pascalc --version`
   prints: `pascalc-product` holds that number to `CMakeLists.txt`, and this
   closes the triangle, so an archive named `v3.5.0` holding a 3.4.0 is never
   written. `--check <archive>` reads the digest back, unpacks into a fresh
   directory, requires exactly one top-level directory named as the archive
   and the three text files, and then hands the prefix to
   **`tests/checks/install_layout.sh --prefix`** — the second form that gate
   grew for this, skipping the install and asking every other question of a
   prefix something else laid out. The layout is named in one list.
   `--notes <tag>` prints the `CHANGELOG.md` section for the version and
   refuses a tag with none.

2. **`release-archive` is a ctest case**, so both halves run on every push
   and not only at a tag. It builds an archive from the build tree under the
   version the compiler prints, checks it, and then makes two things fail:
   a tag that is not the version, and a digest with its first character
   changed. The third failure — an archive missing `lib/afterschool/` — is
   the gate's own file list and was made by hand rather than by the case,
   because repacking a mutant archive is the case's whole cost again.

3. **The workflow is three jobs and three `gh` calls.** `release` needs every
   oracle job green — `test`, `aarch64`, `seed-is-current`, `sanitizers`,
   `unoptimised`, `second-backend`, `unicode-conformance`,
   `fpc-differential` — and creates the release **as a draft** with the
   CHANGELOG section as its notes, unless one exists. `package` is a matrix of
   two runners; each leg configures with the static option, builds, runs the
   whole suite over *that* binary with `AFTERSCHOOL_PASCAL_TARGET` naming its
   machine, archives, runs `--check` with `RELEASE_REQUIRE_STATIC` set, and
   uploads. `publish` undrafts once every leg has attached. A user never sees
   a release with half its archives, and a red leg leaves a draft to re-run.
   `gh` is on every hosted runner, which is why these jobs run on the runner
   image rather than in the minimal containers and why no third-party action
   is used.

4. **`pascalc` is linked `-static`**, behind `APASCAL_STATIC_PASCALC`, off by
   default and on in the job. It reaches the compiler binary alone: the seed
   compiler is not shipped, and `libpasrt.a` is an archive of objects the
   user's own `clang` links against the user's own C library. So the one thing
   the static link changes is that the compiler no longer requires the
   runner's glibc or newer. Measured here: 2 770 192 bytes against 1 652 192,
   no warning, and the full suite green over it. `--check` reports the link
   kind always and requires it only when the variable is set, because a
   developer's tree links dynamically and `release-archive` runs in one.

5. **aarch64 is shipped, and what the archive claims is written down.** It
   claims what the `aarch64` job has established on every push: built and the
   whole suite passed natively on GitHub's arm64 runner, then checked with
   nothing set, which is what a user gets. It does **not** claim a seed —
   `seed/*.ll` is generated for x86-64 and `clang` retargets it, and
   `seed/README.md`'s lock stands. It does not claim the compiler writes an
   aarch64 header by default: without `--target=` or
   `AFTERSCHOOL_PASCAL_TARGET` it writes x86-64's and `clang` overrides it at
   assembly, so a program built by `pascalcc` is right and a `.ll` written by
   `pascalcc -S` names the wrong machine. And it does not claim
   `llc-second-backend` has ever run there — `doc/sop.md` §7's row stands,
   reworded to say the archive exists. The roadmap's distinction was between
   *works* and *supported*; what changes is that *shipped* is now true and
   *seeded* still is not, and both words are in the chapter.

6. **macOS is a disabled matrix entry and untried.** Nobody has built this
   compiler on one. The roadmap calls it the cheapest unknown in the tree, and
   a release leg would have been the port's first run and its release in one
   step, which is the wrong order. Two differences are known and the script
   allows for both — no `-static`, no `ldd` — and what else differs is
   exactly what a first run would find. The entry is commented out with that
   reason beside it; enabling it means a push job first.

## Evidence

Locally, from this tree: `--archive build v3.4.0` wrote an 830 029-byte
archive; `--check` unpacked it and `install-layout` reported the prefix on
PATH with 31 library modules reachable by name; `release-archive` passes under
ctest in 4 s. **The mutation**: the archive unpacked, `lib/afterschool/`
deleted, repacked with a fresh digest — `--check` stops with
`install-layout: lib/afterschool/pastext.pas was not installed`, exit 1.

**Running the script found the defect the tag would have met.** The first
`--check` printed *checks out* and then `work: unbound variable`: the `EXIT`
trap named a `local` that was gone by the time it ran, so the check passed
and left its temporary directory behind on every run. The second was in the
static check itself: `ldd` exits 1 on a static binary, and under `pipefail`
that status was the pipeline's whatever `grep` had found, so the
statically linked compiler this whole option exists for was reported as
dynamic and `RELEASE_REQUIRE_STATIC` refused it — the job would have gone red
at the tag with the archive right. Both are one line of shell nobody had run,
which is the shape both earlier records warned of and the argument for item 2
in two sentences.

**What only a tag can verify**: the three `gh` calls against a draft, the
static libc on the arm64 runner image, and the archive names as the job
composes them. The workflow validates as YAML; `actionlint` was not available.

## What is not done

**The archive is not reproducible.** GNU tar's owner and sort flags are set
where GNU tar is, and gzip's timestamp is not; two runs of `--archive` differ
in bytes. The digest is a download check and not a provenance claim.

**There is no signature.** A SHA-256 beside a file on the same server says
the download arrived whole and nothing about who built it.

**Windows is not touched**, and the cross-platform chapter still says why.

**A transient blocks the release.** `release` needs `unicode-conformance`,
which fetches from unicode.org; a fetch that fails leaves the draft unmade
until the job is re-run. That is the right side to err on.

### Rejected: a third-party release action

`softprops/action-gh-release` and its kind put a dependency into the one
workflow whose first paragraph is that the build needs nothing not named in
`README.md`. `gh` is on the runner, and three calls to it are the whole need.

### Rejected: packaging in the `test` job's container

The containers have no `gh`, and installing it there would be a package the
documented build does not name. The runner image has `clang`, `cmake` and
`gh`, and the suite is run again over the binary that ships, so nothing is
lost by building it twice.

### Rejected: a dynamically linked compiler

It would make the runner's glibc the floor for every user of the archive,
which is the failure a downloader meets as `GLIBC_2.38 not found` and reads
as a broken compiler. The runtime the user links is theirs either way.
