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

# Regenerate the seed from the current compiler, and prove it works.
#
#   seed/refresh.sh [build-dir]
#
# **The seed is one module per program-component** (ADR-0233): the compiler is
# three 6.13 components, and a seed is a working compiler in IR, so it is three
# modules that clang links together. They are written as seed/<component>.ll,
# and CMake matches seed/*.ll rather than naming them -- how many there are is
# the seed's business.
#
# Run at release tags, not per commit: the seed is several megabytes and
# regenerating it rewrites all of it. seed/README.md says why an older seed
# keeps working -- and it keeps working across this change too, a one-module
# seed from before the split being a perfectly good compiler for building the
# three sources that came after it.
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

# The components, in the order selfhost/compiler.components gives, with the
# program last -- the same list CMake and every harness reads.
mapfile -t components < <(grep -v '^[[:space:]]*$' \
                              "$root/selfhost/compiler.components")
components+=(compiler.pas)

translate() {         # translate <compiler> <output-prefix>
  local cc=$1 prefix=$2 imports=() n=0
  for component in "${components[@]}"; do
    n=$((n + 1))
    "$cc" "${imports[@]+"${imports[@]}"}" \
        "$root/selfhost/$component" -o "$prefix$n.ll"
    imports+=(--import "$root/selfhost/$component")
  done
}

echo "refresh: generating a candidate seed with $($pascalc --version)"
translate "$pascalc" "$work/candidate"

echo "refresh: building a compiler from the candidate"
clang -Wno-override-module "$work"/candidate*.ll "$runtime" -lm \
      -o "$work/from-seed"

echo "refresh: requiring that compiler to reproduce itself"
translate "$work/from-seed" "$work/again"
for n in $(seq 1 ${#components[@]}); do
  if ! cmp -s "$work/candidate$n.ll" "$work/again$n.ll"; then
    echo "refresh: the candidate does not reproduce ${components[$((n - 1))]}" \
         "-- not committing it" >&2
    diff -u "$work/candidate$n.ll" "$work/again$n.ll" | head -40 >&2
    exit 1
  fi
done

# It also has to be a working compiler, not merely a self-reproducing one.
"$work/from-seed" "$root/tests/hello.pas" -o "$work/hello.ll"
clang -Wno-override-module "$work/hello.ll" "$runtime" -lm -o "$work/hello"
if [[ $("$work/hello" | head -1) != "Hello, Afterschool Pascal!" ]]; then
  echo "refresh: the candidate compiler does not compile hello.pas" >&2
  exit 1
fi

# The old seed is removed first: a seed left behind from a build with more
# components would be linked in beside the new ones by CMake's glob, and two
# definitions of the same program is a link error about a file nobody wrote.
rm -f "$here"/*.ll
total=0
for n in $(seq 1 ${#components[@]}); do
  name=${components[$((n - 1))]}
  cp "$work/candidate$n.ll" "$here/${name%.pas}.ll"
  total=$((total + $(wc -l <"$here/${name%.pas}.ll")))
done
echo "refresh: ${#components[@]} seed modules updated ($total lines)"
