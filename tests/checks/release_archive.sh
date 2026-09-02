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

# **Does the release script still produce an archive that checks out?**
# (ADR-0296)
#
#   release_archive.sh <build-directory>
#
# `tools/release.sh` runs at a tag and nowhere else if nothing drives it
# between tags, and this tree has learned twice what happens to shell that
# only a tag exercises (ADR-0233's seed_current.sh, ADR-0282). So this is the
# `ctest` case that drives both halves on every run: build an archive from
# the build tree under the version the compiler prints, then check it the way
# the tag job will -- digest, one directory, licences, and every question
# `install-layout` asks of a prefix.
#
# Three claims fail separately, and each has been made to: `--archive`
# refuses a tag that is not the compiler's version, `--check` refuses an
# archive whose `.sha256` says something else, and `--check` refuses an
# archive missing `lib/afterschool/` -- that last through `install_layout.sh
# --prefix`, whose file list names `lib/afterschool/pastext.pas`.
#
# Not RELEASE_REQUIRE_STATIC: a developer's tree links dynamically and this
# case runs in one. The tag job sets it, having configured the static link.
set -u

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
build=${1:-$root/build}

[[ -x $build/bin/pascalc ]] || {
  echo "release-archive: $build/bin/pascalc is missing; build first" >&2
  exit 1
}

work=$(mktemp -d "${TMPDIR:-/tmp}/release-archive.XXXXXX")
trap 'rm -rf "$work"' EXIT

version=$("$build/bin/pascalc" --version)
tag=v${version##* }

# The wrong tag is refused, and the refusal is the *version* one and not a
# later failure: an archive named for a release the compiler is not must
# never get as far as being written.
if "$root/tools/release.sh" --archive "$build" v0.0.0 "" "$work/wrong" \
     >"$work/wrong.log" 2>&1; then
  echo "--- release-archive: a tag that is not the version was accepted ---" >&2
  exit 1
fi
if ! grep -q 'does not name the compiler.s version' "$work/wrong.log"; then
  echo "--- release-archive: v0.0.0 was refused for the wrong reason ---" >&2
  cat "$work/wrong.log" >&2
  exit 1
fi

if ! "$root/tools/release.sh" --archive "$build" "$tag" "" "$work/dist" \
       >"$work/archive.log" 2>&1; then
  echo "--- release-archive: --archive failed ---" >&2
  cat "$work/archive.log" >&2
  exit 1
fi
archives=("$work"/dist/afterschool-pascal-*.tar.gz)
[[ ${#archives[@]} -eq 1 && -f ${archives[0]} ]] || {
  echo "--- release-archive: expected one archive under $work/dist ---" >&2
  ls -l "$work/dist" >&2
  exit 1
}
archive=${archives[0]}

if ! "$root/tools/release.sh" --check "$archive" >"$work/check.log" 2>&1; then
  echo "--- release-archive: --check failed on the archive just built ---" >&2
  cat "$work/check.log" >&2
  exit 1
fi

# The digest sidecar is read: alter one character and the check must stop
# before opening the archive.
mkdir -p "$work/bad"
cp "$archive" "$work/bad/"
awk '{ first = substr($0, 1, 1) == "0" ? "1" : "0"; print first substr($0, 2) }' \
  "$archive.sha256" >"$work/bad/$(basename "$archive").sha256"
if "$root/tools/release.sh" --check "$work/bad/$(basename "$archive")" \
     >"$work/bad.log" 2>&1; then
  echo "--- release-archive: a wrong .sha256 was accepted ---" >&2
  exit 1
fi
if ! grep -q 'sha256 says' "$work/bad.log"; then
  echo "--- release-archive: the wrong digest was refused for another reason ---" >&2
  cat "$work/bad.log" >&2
  exit 1
fi

echo "release-archive: $(basename "$archive") built and checked;" \
     "$(grep -c '^release: ' "$work/check.log") report lines"
