#!/bin/sh
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
#
# Diverse double-compiling (David A. Wheeler), applied to `seed/pascalc.ll`.
#
# The seed is an opaque committed artefact. Its provenance is this repository's
# history -- a claim about a chain, not something a reader checks by
# inspection -- and that is the trusting-trust problem in its ordinary form.
# It is answerable *once*, by building a compiler through an unrelated
# implementation and comparing what the two produce:
#
#   A = the v0.1.0 C++ compiler (LLVM's own code generator) translating
#       today's selfhost/compiler.pas, then assembled and linked
#   B = build/bin/pascalc, which came from seed/pascalc.ll the ordinary way
#
# A and B are then each asked to translate selfhost/compiler.pas, and *those*
# two outputs must be identical. A and B themselves are **not** compared --
# ADR-0025 settled that two backends' assembler text is not comparable, which
# is exactly why the comparison is made one stage further on. What makes it
# evidence is that A's code generator is LLVM's and B's is the Pascal one, so
# an artefact carrying behaviour its source does not would show up here.
#
# What this does NOT establish: v0.1.0 is this project's own earlier compiler,
# so the two implementations are diverse but not independently authored. It
# rules out a seed that drifted from the source. It does not rule out a mistake
# present in both.
#
# **The window closes on its own and nothing announces it**: this works only
# while the v0.1.0 C++ compiler still accepts selfhost/compiler.pas, and every
# feature the compiler starts using risks ending that. Skips rather than fails
# when it cannot run, as verify-lowering does without z3 -- but a skip is the
# thing to read, not to ignore.
#
# **It closed at ADR-0233.** The compiler is three 6.13 program-components now,
# and v0.1.0 has no `--import`: it reports `no interface named 'aptypes' has
# been exported` and stops. That is the announcement the paragraph above says
# nothing makes, made once, here -- the check runs, says THE WINDOW HAS CLOSED
# and exits 0, and there is nothing to fix. seed/README.md records the last
# result it obtained. Do not try to reopen it by feeding v0.1.0 the components
# separately: it cannot link them either.
#
# Usage:  seed/ddc.sh [build-dir]        (default: build)

set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
builddir=${1:-$root/build}

skip() {
  echo "ddc: SKIP -- $1"
  exit 0
}

command -v git >/dev/null 2>&1 || skip "no git"
command -v clang >/dev/null 2>&1 || skip "no clang"
command -v cmake >/dev/null 2>&1 || skip "no cmake"
command -v llvm-config >/dev/null 2>&1 || skip "no llvm-config: the v0.1.0 C++ compiler links libLLVM"

git -C "$root" rev-parse -q --verify refs/tags/v0.1.0 >/dev/null 2>&1 \
  || skip "tag v0.1.0 is not present (a shallow clone has no tags)"

[ -x "$builddir/bin/pascalc" ] || skip "no $builddir/bin/pascalc: build first"
[ -f "$builddir/lib/libpasrt.a" ] || skip "no $builddir/lib/libpasrt.a: build first"

llvmdir=$(llvm-config --cmakedir 2>/dev/null) || skip "llvm-config has no --cmakedir"
[ -d "$llvmdir" ] || skip "LLVM cmake directory $llvmdir does not exist"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "ddc: extracting v0.1.0 -- the last commit where a C++ compiler could"
echo "     reproduce a compiler from source alone"
git -C "$root" archive v0.1.0 | tar -x -C "$work"

echo "ddc: building the v0.1.0 C++ compiler against LLVM from $llvmdir"
cmake -S "$work" -B "$work/build" -DCMAKE_BUILD_TYPE=Release \
      -DLLVM_DIR="$llvmdir" >"$work/cmake.log" 2>&1 \
  || { tail -20 "$work/cmake.log"; skip "v0.1.0 does not configure against this LLVM"; }
cmake --build "$work/build" -j --target pascalc-s0 >"$work/make.log" 2>&1 \
  || { tail -20 "$work/make.log"; skip "v0.1.0 does not build against this LLVM"; }

# Whether it still *accepts* today's source is the window, and the one outcome
# worth distinguishing from a broken environment. It is still a skip -- there
# is nothing to fix -- but it says the answer can no longer be obtained.
echo "ddc: translating today's selfhost/compiler.pas with it"
if ! "$work/build/bin/pascalc-s0" --std=extended -S \
       "$root/selfhost/compiler.pas" -o "$work/A.ll" >"$work/a.log" 2>&1; then
  head -10 "$work/a.log"
  echo "ddc: THE WINDOW HAS CLOSED -- the v0.1.0 compiler no longer accepts"
  echo "     selfhost/compiler.pas, so this check can never run again."
  echo "     seed/README.md records the last time it passed."
  exit 0
fi

echo "ddc: linking compiler A from that IR"
clang "$work/A.ll" "$builddir/lib/libpasrt.a" -lm -o "$work/A_compiler"

# No --std= on either: A and B are both built from *today's* compiler.pas, and
# ADR-0232 removed the flag from it. The line above keeps its `--std=extended`
# because that one is the v0.1.0 binary, which still has the modes -- which is
# the whole shape of this check, an old implementation translating a new source.
echo "ddc: A and B each translate selfhost/compiler.pas"
"$work/A_compiler" "$root/selfhost/compiler.pas" -o "$work/from_A.ll"
"$builddir/bin/pascalc" "$root/selfhost/compiler.pas" -o "$work/from_B.ll"

if cmp -s "$work/from_A.ll" "$work/from_B.ll"; then
  sum=$(sha256sum "$work/from_A.ll" | cut -d' ' -f1)
  bytes=$(wc -c <"$work/from_A.ll")
  echo "ddc: PASS -- a compiler built through LLVM's code generator and one"
  echo "     built from the seed translate selfhost/compiler.pas to the same"
  echo "     $bytes bytes"
  echo "ddc: sha256 $sum"
  exit 0
fi

echo "ddc: FAIL -- the two outputs differ, so the seed carries behaviour that"
echo "     selfhost/compiler.pas does not account for. This is the finding the"
echo "     check exists for; do not 'fix' it by refreshing the seed."
cmp "$work/from_A.ll" "$work/from_B.ll" || true
exit 1
