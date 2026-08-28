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

# Is the committed seed the one this source produces?
#
# The seed is refreshed at release tags and nowhere else (ADR-0085), so this
# is a question only a release can ask: between tags the seed is *meant* to be
# the previous release's, and asking on every commit would fail by design. It
# is therefore **not a ctest case** -- it is run by hand at a release, and by
# the `seed-is-current` job at the tag, which is the last moment anything can
# still refuse.
#
# At a release commit the compiler built *from* the seed must emit, for the
# current source, exactly the seed it was built from. That is the fixed point.
# Nothing else notices when it breaks: a stale seed still builds a working
# compiler, from the previous release's source, and every oracle here agrees
# with it.
#
# One module per program-component since ADR-0233, translated in the order
# `selfhost/compiler.components` gives, each importing the ones before it. The
# **set** is compared as well as each module: a component removed from the tree
# leaves its seed module behind and CMake's glob goes on linking it, so an
# extra file here is as much a stale seed as a differing one.
#
# **Why this is a script and not a `run:` block.** It was fourteen lines of
# shell inside `.github/workflows/ci.yml`, and a `run:` block in a container is
# `sh -e {0}` -- the arrays it was written with are a bash syntax error, so the
# job died before translating anything, at a tag, which is the only place it
# runs. That is the second time logic living in a workflow's shell has failed
# for want of anywhere to run it: `model-drift`'s base resolution was the
# first, and doc/sop.md records the same answer being reached then. Here the
# text CI runs and the text a release runs by hand are now one text.
#
# usage: seed_current.sh [compiler]      default build/bin/pascalc
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
pascalc=${1:-$root/build/bin/pascalc}

if [ ! -x "$pascalc" ]; then
  echo "seed-current: $pascalc is missing; build first" >&2
  exit 1
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/seed-current.XXXXXX")
trap 'rm -rf "$work"' EXIT

imports=()
expected=()
status=0

# compiler.pas is the program and is not in the sidecar -- the sidecar lists
# the components it imports, which is what every other reader of it needs.
while read -r component; do
  [ -n "$component" ] || continue
  expected+=("$component")
done < "$root/selfhost/compiler.components"
expected+=(compiler.pas)

for component in "${expected[@]}"; do
  base=${component%.pas}
  if ! "$pascalc" "${imports[@]+"${imports[@]}"}" \
       "$root/selfhost/$component" -o "$work/$base.ll"; then
    echo "seed-current: $component did not translate" >&2
    exit 1
  fi
  imports+=(--import "$root/selfhost/$component")

  if ! cmp -s "$work/$base.ll" "$root/seed/$base.ll"; then
    echo "seed/$base.ll is not what this source produces." >&2
    echo "Run seed/refresh.sh and amend the release commit." >&2
    diff -u "$root/seed/$base.ll" "$work/$base.ll" | head -40 >&2
    status=1
  fi
done

have=$(cd "$root/seed" && ls ./*.ll | sed 's|^\./||' | sort)
want=$(printf '%s\n' "${expected[@]%.pas}" | sed 's|$|.ll|' | sort)
if [ "$have" != "$want" ]; then
  echo "seed/ holds modules this source does not produce." >&2
  echo "this source produces:" >&2
  echo "$want" | sed 's|^|  |' >&2
  echo "seed/ holds:" >&2
  echo "$have" | sed 's|^|  |' >&2
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "the seed matches, ${#expected[@]} modules."
fi
exit "$status"
