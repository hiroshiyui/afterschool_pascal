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
#
# **ADR-0137 narrowed the third and fourth rows, and the narrowing is checked
# here too.** The mode was a proxy for the ABI and far too coarse a one:
# `lib/pasmath.pas` has no variant record in it at all, so its object code is
# identical under both modes, and a dialect program still could not link it --
# the layer built so the *conforming* language would have a library was the
# layer the language containing it could not use. A module whose interface
# carries no variant-part with a tag-field now emits its activation names under
# the dialect's spelling as well as its own. Two more rows, over `plain.pas`:
#
#   plain module conformance, program dialect   links
#   plain module dialect, program conformance   refused
#
# The second is not symmetry left undone. A dialect module may call `external`
# routines and is not a conforming program-component, so letting a conforming
# program link one would put a component outside both standards into a program
# that claims one -- which is ADR-0120's decision, not an oversight.
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

# As `matched`, over a module whose interface carries no tagged variant-part
# (ADR-0137), so the two modes may be mixed in the one direction that is safe.
#   $1 module std, $2 program std, $3 what the run should print
portable() {
  if ! "$pascalcc" "--std=$1" -c "$here/plain.pas" -o "$work/plain.o" \
       >"$work/log" 2>&1; then
    fail "$1 plain module did not translate"; cat "$work/log"; return
  fi
  if ! "$pascalcc" "--std=$2" "$here/plainuser.pas" --import "$here/plain.pas" \
       "$work/plain.o" -o "$work/plainuser" >"$work/log" 2>&1; then
    fail "plain $1 + $2 should link and did not"; cat "$work/log"; return
  fi
  got=$("$work/plainuser" 2>&1)
  if [[ $got == "$3" ]]; then
    note "ok   plain $1 module + $2 program links and says: $got"
  else
    fail "plain $1 + $2 printed '$got', wanted '$3'"
  fi
}

# The direction ADR-0137 leaves closed, over the same portable module.
#   $1 module std, $2 program std
portable_refused() {
  if ! "$pascalcc" "--std=$1" -c "$here/plain.pas" -o "$work/plain.o" \
       >"$work/log" 2>&1; then
    fail "$1 plain module did not translate"; cat "$work/log"; return
  fi
  if "$pascalcc" "--std=$2" "$here/plainuser.pas" --import "$here/plain.pas" \
     "$work/plain.o" -o "$work/plainuser" >"$work/log" 2>&1; then
    fail "plain $1 module + $2 program linked; a dialect module is not a conforming component"
    return
  fi
  if grep -q "was translated under a different --std" "$work/log"; then
    note "ok   plain $1 module + $2 program is refused, and says why"
  else
    fail "plain $1 module + $2 program was refused without naming the reason:"
    sed 's/^/       /' "$work/log"
  fi
}

# A module reaching a tagged variant only through the parameter list of a
# *procedural* parameter (ADR-0142). Same requirement as `mixed`, over a corpus
# whose reachability the walk got wrong: it asked each parameter about its own
# type and never entered a procedural parameter's own parameters.
#   $1 module std, $2 program std
callback_refused() {
  # Three components. The record lives in TagBase so that Callback can *reach*
  # it without *exporting* it -- a module exporting the type is locked by that
  # constituent alone, whichever way the parameter walk goes, and a first
  # version of this test did exactly that and passed without the fix.
  if ! "$pascalcc" "--std=$2" -c "$here/tagbase.pas" -o "$work/tagbase.o" \
       >"$work/log" 2>&1; then
    fail "tagbase module did not translate"; cat "$work/log"; return
  fi
  if ! "$pascalcc" "--std=$1" -c "$here/callback.pas" \
       --import "$here/tagbase.pas" -o "$work/callback.o" \
       >"$work/log" 2>&1; then
    fail "$1 callback module did not translate"; cat "$work/log"; return
  fi
  if "$pascalcc" "--std=$2" "$here/callbackuser.pas" \
     --import "$here/tagbase.pas" --import "$here/callback.pas" \
     "$work/tagbase.o" "$work/callback.o" -o "$work/cbuser" \
     >"$work/log" 2>&1; then
    fail "callback $1 module + $2 program linked; the tagged variant is reachable through a procedural parameter"
    "$work/cbuser" 2>&1 | sed 's/^/       and it ran: /'
    return
  fi
  if grep -q "was translated under a different --std" "$work/log"; then
    note "ok   callback $1 module + $2 program is refused, and says why"
  else
    fail "callback $1 module + $2 program was refused without naming the reason:"
    sed 's/^/       /' "$work/log"
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

echo "ADR-0137: and a module whose interface cannot differ may be mixed"
portable         extended    afterschool "plain -3 4"
portable         extended    extended    "plain -3 4"
portable_refused afterschool extended

echo "ADR-0142: and reachability follows a procedural parameter's own parameters"
callback_refused extended    afterschool

if [[ $failures -gt 0 ]]; then
  echo "$failures of 8 wrong"
  exit 1
fi
echo "all eight combinations as intended"
