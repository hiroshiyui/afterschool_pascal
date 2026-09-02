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

# ADR-0291: can this compiler open a file whose path is longer than a name?
#
# `nameStr` was 255 and held both an identifier and a file name, so a source
# at a 310-character path reached `pas_str_fits` and stopped the compiler with
# `a string of length 310 does not fit a capacity of 255` -- naming no file,
# from a program that had asked to compile one. A checkout a few directories
# deeper than usual is the whole of what it takes.
#
# It needs a harness of its own because **no test case can choose its own
# path**: every case here is compiled where it sits, and every path a harness
# passes is short. That is `stale-component`'s argument -- no case can edit
# its own source between two compilations -- met a second time.
#
# Three claims, because a path arrives by more than one route: the source
# named on the command line, and a module found under an `--import-path`,
# which is a path the compiler *computed* rather than one it was handed. The
# third is that a diagnostic about such a file still names it -- a path that
# reaches the message is a path the message has to be able to hold, and it is
# the half `pas_str_fits` used to reach instead.
set -eu

pascalcc=${1:?usage: long_path.sh <pascalcc>}
[[ -x $pascalcc ]] || { echo "long-path: $pascalcc is not executable" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Twelve directories of ordinary length, which is a project somebody has and
# not an attack. The assertion below is on the length rather than on the
# nesting: what matters is that the *file* passes 255, and how it got there is
# incidental -- `mktemp -d` contributes about twenty characters here and more
# on a system whose TMPDIR is elsewhere.
deep=$work
for i in 01 02 03 04 05 06 07 08 09 10 11 12; do
  deep=$deep/a_nested_directory_$i
done
mkdir -p "$deep"

cat >"$deep/dep.pas" <<'PAS'
module Dep;
export Dep = (Answer);
function Answer: integer;
end;
function Answer;
begin
  Answer := 42
end;
end.
PAS

cat >"$deep/main.pas" <<'PAS'
program main(output);
import Dep;
begin
  writeln(Answer)
end.
PAS

cat >"$deep/plain.pas" <<'PAS'
program plain(output);
begin
  writeln(42)
end.
PAS

cat >"$deep/bad.pas" <<'PAS'
program bad(output);
begin
  writeln(nowhere)
end.
PAS

full=$deep/main.pas
n=${#full}
if (( n <= 255 )); then
  echo "long-path: the path is only $n characters -- this checks nothing" >&2
  exit 1
fi

fail=0
note() { echo "  $*" >&2; fail=$((fail + 1)); }

# 1. the source named on the command line
if out=$("$pascalcc" "$deep/plain.pas" -o "$work/plain" 2>&1) &&
   [[ $("$work/plain") == 42 ]]; then
  :
else
  note "a source at a ${n}-character path: $out"
fi

# 2. the same module found by --import-path rather than named
if out=$("$pascalcc" --import-path "$deep" "$deep/main.pas" \
                     -o "$work/main2" 2>&1) && [[ $("$work/main2") == 42 ]]; then
  :
else
  note "--import-path at a ${n}-character path: $out"
fi

# 3. a diagnostic about such a file still names it. The path is what the
#    message begins with, so a compiler that could compile the file and not
#    complain about it would be a compiler with the bound moved rather than
#    removed.
out=$("$pascalcc" "$deep/bad.pas" -o "$work/bad" 2>&1) && \
  note "the erroneous source at a long path was accepted"
case $out in
  "$deep/bad.pas:"*"undeclared identifier 'nowhere'"*) ;;
  *) note "the diagnostic did not name the file: $out" ;;
esac

if (( fail > 0 )); then
  echo "long-path: $fail of 3 claims failed at a $n-character path" >&2
  exit 1
fi
echo "long-path: 3 claims at a $n-character path"
