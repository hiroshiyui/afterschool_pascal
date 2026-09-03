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

# ADR-0308: does a source named without a directory find its neighbours?
#
# ADR-0244's first search rule is the source's own directory, and README and
# doc/tour.md both promise that a program and its components written in one
# directory need no manifest and no build order. `SourceDir` answered the
# empty string for a name with no `/` in it and `AddPath` drops an empty
# directory on purpose -- an empty entry in AFTERSCHOOL_PASCAL_PATH would name
# the working directory, which POSIX says of PATH and which is a surprise
# nobody wants -- so the promise was true of `./prog.pas` and false of
# `prog.pas`, which is the spelling a person types.
#
# It needs a harness of its own for `long-path`'s reason, met a third time:
# **no test case can choose how it is named.** Every case here is compiled
# where it sits and every harness passes a path, so the one spelling that was
# broken is the one no oracle here could produce. What this asserts is a
# property of the *invocation* and cannot be written in Pascal.
#
# Two claims, because the working directory reaches the compiler twice: the
# component found beside a bare source name, and the same program still
# compiling when it is named with a directory -- a fix that made `./` the
# answer for every name would pass the first and break nothing visible, so the
# second is what keeps the change to the case it was made for.
set -eu

pascalcc=${1:?usage: bare_source_name.sh <pascalcc>}
[[ -x $pascalcc ]] || {
  echo "bare-source-name: $pascalcc is not executable" >&2; exit 1; }
# Absolute, because claim 1 runs the compiler from another directory and a
# relative driver would vanish under the cd -- which is the same shape as the
# defect this gate is about.
pascalcc=$(cd "$(dirname "$pascalcc")" && pwd)/$(basename "$pascalcc")

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cat >"$work/greeting.pas" <<'PAS'
module Greeting;
export Greeting = (Answer);
function Answer: integer;
end;
function Answer;
begin
  Answer := 42
end;
end.
PAS

cat >"$work/sayhello.pas" <<'PAS'
program sayhello(output);
import Greeting;
begin
  writeln(Answer)
end.
PAS

fail=0
note() { echo "  $*" >&2; fail=$((fail + 1)); }

# 1. The bare name, which is what a person types. The `cd` is the whole of the
#    test: the compiler is given `sayhello.pas` and nothing else, so the only
#    thing that can find `greeting.pas` is the source's own directory.
if out=$(cd "$work" && "$pascalcc" sayhello.pas -o hello 2>&1) &&
   [[ $(cd "$work" && ./hello) == 42 ]]; then
  :
else
  note "a source named with no directory: $out"
fi

# 2. The same program named with a directory, which worked before this gate
#    existed and has to go on working -- the search is the source's directory
#    and not the working one, and those are the same here only by accident of
#    the cd above.
rm -f "$work/hello2"
if out=$("$pascalcc" "$work/sayhello.pas" -o "$work/hello2" 2>&1) &&
   [[ $("$work/hello2") == 42 ]]; then
  :
else
  note "a source named with a directory: $out"
fi

if (( fail )); then
  echo "bare-source-name: $fail of 2 claims failed" >&2
  exit 1
fi

echo "bare-source-name: 2 of 2 claims hold"
