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

# Regenerate seed/pascalc.ll from the current compiler, and prove it works.
#
#   seed/refresh.sh [build-dir]
#
# Run at release tags, not per commit: the seed is 6.3 MB and regenerating it
# rewrites all of it. seed/README.md says why an older seed keeps working.
#
# A seed is never committed on the strength of having been generated. This
# builds a compiler *from the candidate*, has that compiler translate the
# source again, and requires the two results to be identical -- the same fixed
# point selfhost/irtest.sh requires, asked of the artefact about to be trusted.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
build=${1:-$root/build}

pascalc=$build/bin/pascalc
runtime=$build/lib/libpasrt.a
for f in "$pascalc" "$runtime"; do
  [[ -e $f ]] || { echo "refresh: $f is missing -- build first" >&2; exit 1; }
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

std=$(tr -d '[:space:]' <"$root/selfhost/compiler.std")

echo "refresh: generating a candidate seed with $($pascalc --version)"
"$pascalc" "--std=$std" "$root/selfhost/compiler.pas" -o "$work/candidate.ll"

echo "refresh: building a compiler from the candidate"
clang -Wno-override-module "$work/candidate.ll" "$runtime" -lm -o "$work/from-seed"

echo "refresh: requiring that compiler to reproduce itself"
"$work/from-seed" "--std=$std" "$root/selfhost/compiler.pas" -o "$work/again.ll"
if ! cmp -s "$work/candidate.ll" "$work/again.ll"; then
  echo "refresh: the candidate does not reproduce itself -- not committing it" >&2
  diff -u "$work/candidate.ll" "$work/again.ll" | head -40 >&2
  exit 1
fi

# It also has to be a working compiler, not merely a self-reproducing one.
"$work/from-seed" "$root/tests/hello.pas" -o "$work/hello.ll"
clang -Wno-override-module "$work/hello.ll" "$runtime" -lm -o "$work/hello"
if [[ $("$work/hello" | head -1) != "Hello, Afterschool Pascal!" ]]; then
  echo "refresh: the candidate compiler does not compile hello.pas" >&2
  exit 1
fi

cp "$work/candidate.ll" "$here/pascalc.ll"
echo "refresh: seed/pascalc.ll updated ($(wc -l <"$here/pascalc.ll") lines)"
