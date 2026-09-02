#!/usr/bin/env bash
# Afterschool Pascal -- an ISO 7185 / ISO/IEC 10206:1991 Pascal compiler.
# Copyright (C) 2026 Hui-Hong You
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <https://www.gnu.org/licenses/>.

# **A release archive, and the check that it is one** (ADR-0296).
#
#   release.sh --archive <build-dir> <tag> [<arch>] [<out-dir>]
#   release.sh --check   <archive.tar.gz>
#   release.sh --notes   <tag>
#
# `--archive` lays a build tree out the way `cmake --install` does, under one
# directory named `afterschool-pascal-<tag>-<arch>`, and writes that directory
# as `<out-dir>/afterschool-pascal-<tag>-<arch>.tar.gz` with a
# `.tar.gz.sha256` beside it in `sha256sum -c` form. The layout is the one
# `install-layout` checks (ADR-0244) -- bin/pascalc, bin/pascalcc,
# lib/libpasrt.a, lib/afterschool/ -- plus the two licence files and a short
# README, because a person who downloaded this has not got the repository's.
# `<arch>` defaults to `<uname -m>-<uname -s>` in lower case, which is
# `x86_64-linux` here; `<out-dir>` defaults to the working directory.
#
# `--check` is the half that fails. It reads the `.sha256` back and requires
# it to match, unpacks the archive into a fresh directory, and then hands the
# result to `tests/checks/install_layout.sh --prefix`, which is the gate that
# already knows what an installed compiler has to be able to do: PATH holding
# its bin and nothing else, every variable that could point back at a checkout
# unset, a program importing two library modules compiled and run from a third
# directory, and one `import <name>;` program per installed module. The logic
# is in that script and not copied here, so a file added to the layout is
# added in one place. What this adds is the archive's own questions -- the
# digest, the one top-level directory, the licences -- and whether `pascalc`
# is statically linked, which it reports always and *requires* only when
# `RELEASE_REQUIRE_STATIC` is set, because a developer's build tree links
# dynamically and the CI job is what configures the static one.
#
# `--notes` prints the CHANGELOG.md section for the tag, for `gh release
# create --notes-file`, and refuses a tag that has no section: a release whose
# notes are empty is one nobody wrote a changelog entry for, and
# `.claude/skills/release-engineering` says one is written before the tag.
#
# **Why a script and not `run:` blocks.** Every line of this runs at a tag and
# nowhere else if it lives in the workflow, and twice now something written
# there failed for want of anywhere to be exercised first (ADR-0233's
# `seed_current.sh`, ADR-0282). So this is a script, `tests/checks/
# release_archive.sh` drives `--archive` and `--check` as a `ctest` case on
# every run, and the workflow calls the same text with the tag's name.
#
# **The tag has to be the version.** `pascalc --version` prints what
# `CMakeLists.txt` says, `pascalc-product` holds the two together, and this
# closes the triangle: an archive named `v3.5.0` holding a compiler that says
# 3.4.0 is refused rather than uploaded.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)

die() { echo "release: $*" >&2; exit 1; }

host_arch() {
  echo "$(uname -m)-$(uname -s | tr '[:upper:]' '[:lower:]')"
}

# sha256sum is coreutils; shasum is what macOS has instead. Either way the
# digest alone, and the file this writes is in sha256sum's own `-c` format.
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  else
    die "neither sha256sum nor shasum is on PATH"
  fi
}

# `ldd` says "not a dynamic executable" of a static binary and lists the
# libraries of a dynamic one; LC_ALL=C because it says so in the machine's
# language otherwise. Where there is no `ldd` (macOS) the answer is unknown,
# and reported as that rather than as either of the other two.
#
# Captured and not piped: `ldd` exits 1 on a static binary, and under
# pipefail that status is the pipeline's whatever grep found, so the first
# version of this reported the static binary it was written for as dynamic.
link_kind() {
  local said
  if ! command -v ldd >/dev/null 2>&1; then
    echo unknown
    return
  fi
  said=$(LC_ALL=C ldd "$1" 2>&1)
  case $said in
    *'not a dynamic executable'*) echo static ;;
    *)                            echo dynamic ;;
  esac
}

version_of() {
  # `pascalc (Afterschool Pascal) 3.4.0` -- the last word.
  local line
  line=$("$1" --version 2>/dev/null) || die "$1 --version failed"
  echo "${line##* }"
}

archive() {
  local build=$1 tag=$2 arch=${3:-$(host_arch)} out=${4:-.}
  [[ -d $build ]] || die "no build directory '$build'"
  [[ -x $build/bin/pascalc ]] || die "$build/bin/pascalc is missing; build first"
  [[ $tag == v* ]] || die "a tag starts with 'v', not '$tag'"
  local version
  version=$(version_of "$build/bin/pascalc")
  [[ $tag == "v$version" ]] ||
    die "tag $tag does not name the compiler's version ($version)"

  local name=afterschool-pascal-$tag-$arch
  local stage
  stage=$(mktemp -d "${TMPDIR:-/tmp}/release.XXXXXX")
  # Expanded now: the trap runs after this function's locals are gone.
  trap "rm -rf '$stage'" EXIT

  if ! cmake --install "$build" --prefix "$stage/$name" >"$stage/install.log" 2>&1
  then
    cat "$stage/install.log" >&2
    die "cmake --install failed"
  fi
  cp "$root/LICENSE" "$root/COPYING.RUNTIME" "$stage/$name/"
  cat >"$stage/$name/README" <<EOF
Afterschool Pascal $version, for $arch.

    export PATH=\$PWD/bin:\$PATH
    pascalcc hello.pas -o hello

bin/pascalc writes LLVM IR and stops; bin/pascalcc assembles and links it
with clang, which must be on PATH (clang 15 or later), and links
lib/libpasrt.a beside it. The library under lib/afterschool is source, and
pascalcc puts it on the search path when AFTERSCHOOL_PASCAL_PATH says
nothing. Nothing here needs to be installed anywhere in particular.

The compiler is under the GNU General Public License version 3 or later
(LICENSE); the runtime a compiled program links carries the exception in
COPYING.RUNTIME. Sources: https://github.com/hiroshiyui/afterschool_pascal
EOF

  mkdir -p "$out"
  local tarball=$out/$name.tar.gz
  local tarflags=()
  # Owner and group are the machine's otherwise, and nothing about a release
  # is a fact about who ran it. GNU tar only; bsdtar spells these differently
  # and the archive is no less an archive without them.
  if tar --version 2>/dev/null | grep -q GNU; then
    tarflags=(--owner=0 --group=0 --numeric-owner --sort=name)
  fi
  tar -C "$stage" ${tarflags[@]+"${tarflags[@]}"} -czf "$tarball" "$name" ||
    die "tar failed"
  printf '%s  %s\n' "$(sha256_of "$tarball")" "$name.tar.gz" \
    >"$tarball.sha256"
  echo "release: wrote $tarball"
  echo "release: wrote $tarball.sha256"
}

check() {
  local tarball=$1
  [[ -f $tarball ]] || die "no archive '$tarball'"
  local base name
  base=$(basename "$tarball")
  name=${base%.tar.gz}
  [[ $name != "$base" ]] || die "'$base' is not a .tar.gz"
  [[ $name == afterschool-pascal-v*-* ]] ||
    die "'$base' is not named afterschool-pascal-<tag>-<arch>.tar.gz"

  # The digest first: it is what a downloader checks, and an archive whose
  # sidecar names another file or another hash is wrong before it is opened.
  [[ -f $tarball.sha256 ]] || die "no $base.sha256 beside the archive"
  local want got
  want=$(cut -d' ' -f1 "$tarball.sha256")
  got=$(sha256_of "$tarball")
  [[ $want == "$got" ]] || die "$base.sha256 says $want; the archive is $got"
  grep -q " $base\$" "$tarball.sha256" ||
    die "$base.sha256 names a file other than $base"

  local work
  work=$(mktemp -d "${TMPDIR:-/tmp}/release-check.XXXXXX")
  trap "rm -rf '$work'" EXIT
  tar -C "$work" -xzf "$tarball" || die "could not unpack $base"

  # One directory, named as the archive is. A tarball that unpacks into the
  # working directory, or into a directory named for another release, is the
  # kind of mistake a user meets first and a build log never does.
  local entries
  entries=$(ls -A "$work" | wc -l)
  [[ $entries -eq 1 && -d $work/$name ]] ||
    die "$base does not unpack into exactly one directory named $name"
  local prefix=$work/$name

  for f in LICENSE COPYING.RUNTIME README; do
    [[ -f $prefix/$f ]] || die "$base does not carry $f"
  done

  # The layout, and everything an installed compiler has to be able to do,
  # asked by the gate that already asks it (ADR-0244). Its own message names
  # the file or the step that failed.
  "$root/tests/checks/install_layout.sh" --prefix "$prefix" || exit 1

  local kind
  kind=$(link_kind "$prefix/bin/pascalc")
  case $kind in
    static)  echo "release: bin/pascalc is statically linked" ;;
    dynamic) echo "release: bin/pascalc is dynamically linked" ;;
    *)       echo "release: no ldd here, so how bin/pascalc is linked is unknown" ;;
  esac
  if [[ -n ${RELEASE_REQUIRE_STATIC:-} && $kind != static ]]; then
    die "RELEASE_REQUIRE_STATIC is set and bin/pascalc is $kind"
  fi
  echo "release: $base checks out"
}

notes() {
  local tag=$1
  [[ $tag == v* ]] || die "a tag starts with 'v', not '$tag'"
  local version=${tag#v}
  local changelog=$root/CHANGELOG.md
  # From the line after `## [X.Y.Z]` to the line before the next `## `.
  local body
  body=$(awk -v v="$version" '
    /^## \[/ { if (found) exit; if (index($0, "## [" v "]") == 1) { found = 1; next } }
    found { print }
  ' "$changelog")
  [[ -n ${body//[[:space:]]/} ]] ||
    die "CHANGELOG.md has no section for $version; write one before tagging"
  printf '%s\n' "$body"
}

case ${1:-} in
  --archive) [[ $# -ge 3 ]] || die "usage: release.sh --archive <build-dir> <tag> [<arch>] [<out-dir>]"
             archive "$2" "$3" "${4:-}" "${5:-.}" ;;
  --check)   [[ $# -eq 2 ]] || die "usage: release.sh --check <archive.tar.gz>"
             check "$2" ;;
  --notes)   [[ $# -eq 2 ]] || die "usage: release.sh --notes <tag>"
             notes "$2" ;;
  *)         die "usage: release.sh --archive <build-dir> <tag> [<arch>] [<out-dir>] | --check <archive> | --notes <tag>" ;;
esac
