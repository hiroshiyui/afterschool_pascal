# ADR-0375: macOS ships an archive

## Status

Accepted. Enables the `package` job's macOS leg, which has been disabled since
ADR-0296 created it. Follows ADR-0368, which made macOS a job that can fail,
and ADR-0372, which admitted the Darwin triples.

## Context

`doc/roadmap.md` has carried the macOS release leg as open since ADR-0296, and
the `package` job's own comment named what was left before it could be
enabled:

1. `APASCAL_STATIC_PASCALC` OFF and `RELEASE_REQUIRE_STATIC` unset, because
   there is no `-static` on macOS;
2. a `--check` that reports the link kind as unknown, because there is no
   `ldd`;
3. an `arch` for an archive whose compiler writes an x86-64 header,
   `--target=` admitting no Darwin triple.

It also said the right thing about order: *a platform is run before it is
shipped*, and the `macos` push job is that running. It has been green on every
push since ADR-0368 and it can fail, so a break there is a red bar rather than
a surprise at a tag.

**The third is closed.** ADR-0372 admitted `arm64-apple-macosx` and
`x86_64-apple-macosx`, so an archive built here names the machine it is for.

## Decision

**Enable the leg, and answer the other two rather than accept them.**

The first is a decision and it is taken per-leg: `static: 'OFF'` and
`require_static: ''` for macOS, `'ON'` and `'1'` for the two Linux legs. Apple
ships no static libc, so `-static` is not a thing there and
`RELEASE_REQUIRE_STATIC` asks for what the platform cannot do. Dropping the
variable everywhere would have been the lazy reading of that, and it would have
taken the claim away from the two platforms that *can* make it.

**The second is not a decision — it is a missing answer, and macOS has one.**
`ldd` is absent; `otool -L` is that platform's equivalent and it always lists
something, because a fully static executable does not exist there. So
`link_kind` reports `dynamic` where it used to report `unknown`, and the
report stops being an admission.

**And what replaces the static claim is the other half of the same worry.**
`RELEASE_REQUIRE_STATIC` exists because a Linux archive that links libc
dynamically runs on the machine that built it and not necessarily on the one
that unpacks it. The macOS version of that question is *what else* it links,
and the answer must be **nothing outside the base system**: a binary depending
only on `/usr/lib` and `/System` runs on any macOS of its architecture, and one
that picked up a Homebrew dylib runs on the builder's machine alone. Every
hosted runner has Homebrew on it, with its own clang, libssl and more, so this
is a live hazard and not a theoretical one.

That check is **unconditional wherever `otool` is, with no variable**: there is
no configuration in which shipping a Homebrew dependency is right, so there is
nothing for a job to decide. It is the first claim in `release.py` that needs
no `*_REQUIRE`, and that is the argument for it.

## Consequences

**A `v*` tag now produces three archives**, `x86_64-linux`, `aarch64-linux` and
`arm64-darwin`. The name is `host_arch()`'s own rule — `<uname -m>-<uname -s>`
in lower case — which is what the two Linux archives already follow and what
the job's "refuse to package on the wrong machine" step compares against.

**`nproc` had to go.** macOS has not got it. The matrix now spells the job
count `getconf _NPROCESSORS_ONLN`, which both platforms have; the push jobs go
on spelling it their own way, each knowing its own platform.

**The archive is dynamically linked and says so.** `--check` prints the kind on
every leg and requires `static` on two of the three. What the macOS leg
requires instead is the system-library claim, which the Linux legs also make
wherever `otool` exists — which is nowhere, today, so it costs them nothing.

**Nothing about the macOS build is new at a tag.** That is the point of the
order ADR-0296's comment insisted on: the same suite, the same compiler, the
same nine skips, on every push since ADR-0368. What the tag adds is `--archive`
and `--check`, both of which the `release-archive` ctest case has driven on
every push since ADR-0296.

## Alternatives rejected

**Drop `RELEASE_REQUIRE_STATIC` everywhere.** It would have made one matrix
instead of three keys, and taken a real claim away from the two platforms that
can keep it. A variable that means "require what this platform can do" is not
one variable.

**Ship no macOS archive and leave the leg disabled.** It has been disabled
since ADR-0296 for a reason that has been discharged: the platform is run, on
every push, in a job that can fail.

**Report the link kind as unknown on macOS and require nothing.** That was the
`package` comment's own reading, and it is the one thing here that was not a
decision at all — `otool` was there the whole time.
