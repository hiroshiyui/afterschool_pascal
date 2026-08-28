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

# Build the language server.
#
#   build.sh <path-to-pascalcc> <output-binary>
#
# `pasls.components` lists ISO/IEC 10206:1991 6.13's other program-components,
# one path per line relative to this directory and in dependency order -- the
# same sidecar convention `tests/run_test.sh` and `selfhost/irtest.sh` read,
# and read here for the same reason: the build order is written down once.
#
# This is not a CMake target. Nothing in this tree installs a library or a
# second program, and a server needs a binary a *user* can point an editor at
# rather than one buried in a build tree -- so it is a script, as
# `tools/pascalcc` is. `lsp/run.sh` calls it, and so can anyone.
set -eu

if [[ $# -lt 2 ]]; then
  echo "usage: build.sh <pascalcc> <output-binary>" >&2
  exit 2
fi

pascalcc=$1
out=$2
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The optimisation level, so that the corpus-wide -O0 sweep (doc/sop.md 6's A3)
# reaches this program too. It matters here for the reason ADR-0102 gives: an
# alloca claimed inside a loop is invisible at -O2, LLVM being free to hoist one
# whose address does not escape, and a server's whole shape is a loop.
optflag=()
if [[ -n ${AFTERSCHOOL_PASCAL_OPT:-} ]]; then
  optflag=("$AFTERSCHOOL_PASCAL_OPT")
fi

imports=()
objects=()
n=0
while IFS= read -r rel; do
  [[ -n $rel ]] || continue
  n=$((n + 1))
  # Translated with the components listed *before* it, since 6.13 lets one
  # component import another and the list is in dependency order; its own
  # --import is added after, so a component is never handed its own interface.
  "$pascalcc" "${optflag[@]+"${optflag[@]}"}" \
    "${imports[@]+"${imports[@]}"}" -c "$here/$rel" -o "$work/c$n.o"
  imports+=(--import "$here/$rel")
  objects+=("$work/c$n.o")
done <"$here/pasls.components"

"$pascalcc" "${optflag[@]+"${optflag[@]}"}" "$here/pasls.pas" \
  "${imports[@]+"${imports[@]}"}" "${objects[@]+"${objects[@]}"}" -o "$out"
