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
#
# ADR-0119: the program-components of one program must agree on --std.
#
# This is the one case `tests/` cannot express. run_test.sh compiles every
# component of a case with a single `--std` -- deliberately, since the standard
# is a property of the source and a case that could disagree with itself would
# be testing the harness -- so a *mixture* has to be built by hand. Four builds
# of the same two files:
#
#   both --std=extended       links, and prints an unchecked read (7185's
#                             §6.5.3.3 error, left undetected by both
#                             conformance modes)
#   both --std=afterschool    links, and traps on the read
#   module dialect, program conformance   refused
#   module conformance, program dialect   refused
#
# The third row is why the refusal exists rather than being tidiness. It used
# to link, and it printed an answer: the module's guard ran, consulted a tag
# the program's write never stored, and passed an access that was wrong. A
# safety check that reports `safe` for an unsafe read is worse than no check,
# and it is the only outcome ADR-0118's claim cannot survive.
#
# It fails in both directions. A mixture that starts linking is as loud as a
# matched pair that stops.
set -u

pascalcc=${1:?usage: mixed_mode_link.sh <pascalcc> <srcdir>}
srcdir=${2:?usage: mixed_mode_link.sh <pascalcc> <srcdir>}
here=$srcdir/tests/checks/mixedmode

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

failures=0
note() { echo "  $*"; }
fail() { echo "  FAIL: $*"; failures=$((failures + 1)); }

# $1 module std, $2 program std, $3 what the run should print
matched() {
  if ! "$pascalcc" "--std=$1" -c "$here/parts.pas" -o "$work/parts.o" \
       >"$work/log" 2>&1; then
    fail "$1 module did not translate"; cat "$work/log"; return
  fi
  if ! "$pascalcc" "--std=$2" "$here/user.pas" --import "$here/parts.pas" \
       "$work/parts.o" -o "$work/user" >"$work/log" 2>&1; then
    fail "$1 + $2 should link and did not"; cat "$work/log"; return
  fi
  got=$("$work/user" 2>&1)
  if [[ $got == "$3" ]]; then
    note "ok   $1 + $2 links and says: $got"
  else
    fail "$1 + $2 printed '$got', wanted '$3'"
  fi
}

# $1 module std, $2 program std
mixed() {
  if ! "$pascalcc" "--std=$1" -c "$here/parts.pas" -o "$work/parts.o" \
       >"$work/log" 2>&1; then
    fail "$1 module did not translate"; cat "$work/log"; return
  fi
  if "$pascalcc" "--std=$2" "$here/user.pas" --import "$here/parts.pas" \
     "$work/parts.o" -o "$work/user" >"$work/log" 2>&1; then
    fail "$1 module + $2 program linked, and the modes are not mixable"
    return
  fi
  # Refused is necessary and not sufficient: any broken link refuses. The
  # message is what says the refusal was *this* rule, and it is the half a
  # reader acts on.
  if grep -q "was translated under a different --std" "$work/log"; then
    note "ok   $1 module + $2 program is refused, and says why"
  else
    fail "$1 module + $2 program was refused without naming the reason:"
    sed 's/^/       /' "$work/log"
  fi
}

echo "ADR-0119: the components of one program agree on --std"
matched extended    extended    "peek 4"
matched afterschool afterschool "runtime error: variant: the tag selects another arm"
mixed   afterschool extended
mixed   extended    afterschool

if [[ $failures -gt 0 ]]; then
  echo "$failures of 4 wrong"
  exit 1
fi
echo "all four combinations as intended"
