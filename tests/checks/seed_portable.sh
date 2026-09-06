#!/bin/sh
# Afterschool Pascal -- a Pascal compiler written in Pascal.
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
# Does the committed seed name a machine? (ADR-0347)
#
# Since ADR-0293 every trap the compiler emits carries its own position, and
# the source's path is therefore a string constant *in the emitted module* --
# `@at.file`. `seed/refresh.sh` translated with an absolute path, so the seed
# committed for v3.5.0 held
#
#     @at.file = ... c"/home/<user>/<...>/selfhost/compiler.pas\00"
#
# and `tests/checks/seed_current.sh` could then pass only in the directory that
# generated it. It failed in the tag job, which is the **one place it runs** --
# the seed is legitimately stale between releases, so that check cannot be a
# ctest case and a release is the first time anybody asks.
#
# This half can be asked on every push, and it is the half that was wrong: a
# committed artefact must not name the machine that built it. It is a much
# weaker question than `seed_current.sh`'s -- it says nothing about whether the
# seed is *this* source's -- and that is the point. It costs a grep and it
# would have caught this on the commit that introduced the positions rather
# than eight releases later.
#
# Usage:  tests/checks/seed_portable.sh
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
status=0
found=0

for ll in "$root"/seed/*.ll; do
  [ -e "$ll" ] || { echo "seed-portable: no seed modules found" >&2; exit 1; }
  found=$((found + 1))
  # A string constant whose first character is `/`. Every path this compiler
  # embeds is a source path, and a relative one is what a reproducible seed
  # holds; nothing else in the language puts a leading slash in a constant.
  if grep -o 'c"/[^"]*"' "$ll" > "$root/.seed-portable.tmp" 2>/dev/null &&
     [ -s "$root/.seed-portable.tmp" ]; then
    echo "seed-portable: ${ll#"$root"/} holds an absolute path:" >&2
    head -3 "$root/.seed-portable.tmp" >&2
    echo "  The seed names the machine that generated it, so" >&2
    echo "  tests/checks/seed_current.sh can pass only there." >&2
    echo "  seed/refresh.sh translates from the root with a relative" >&2
    echo "  source path; reseed with it (ADR-0347)." >&2
    status=1
  fi
  rm -f "$root/.seed-portable.tmp"
done

# A floor, so a run that globbed nothing cannot pass by comparing nothing --
# the empty comparison this repository has been caught by before (ADR-0282).
if [ "$found" -lt 3 ]; then
  echo "seed-portable: only $found seed module(s) swept, below the floor of 3" >&2
  exit 1
fi

[ "$status" -eq 0 ] || exit 1
echo "seed-portable: $found seed modules, and none names a machine"
