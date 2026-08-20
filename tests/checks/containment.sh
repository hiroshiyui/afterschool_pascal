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
# ADR-0117: the dialect contains Extended Pascal -- everything Extended Pascal
# accepts, --std=afterschool accepts and means the same thing.
#
# That is a claim about every program, and it was witnessed by one:
# tests/dialect/inherits_extended.pas, a single source exercising the features
# its author thought to write down. The corpus that would witness it properly
# already existed and was compiled under exactly one mode -- which is the same
# shape as "no corpus program had ever written pack, page or a string
# constant", a claim every oracle agreed with because nothing had tried it.
#
# So: compile the whole of tests/extended/ a second way and require the same
# result. Not the same IR -- ADR-0119 spells --std into a module's activation
# names and ADR-0118 adds a tag check to every variant access, so sixteen of
# 219 sources differ textually for reasons that are the dialect working. What
# containment claims is about *behaviour*, so this runs the case: same
# compilation outcome, same output, same diagnostics, which is exactly what
# run_test.sh already decides.
#
# It fails in both directions, against tests/checks/containment_exceptions.txt:
# a case that stops behaving identically breaks containment, and a listed case
# that starts behaving identically means the catalogue is describing a compiler
# that no longer exists.
#
# It also reports how many cases it compared, and fails at zero. A gate whose
# corpus is enumerated by glob has two ways to be green -- everything passed,
# and nothing ran -- and difftest_check.py carries this same check for the same
# reason.
set -u

pascalcc=${1:?usage: containment.sh <pascalcc> <srcdir>}
srcdir=${2:?usage: containment.sh <pascalcc> <srcdir>}
catalogue=$srcdir/tests/checks/containment_exceptions.txt

[[ -f $catalogue ]] || { echo "missing catalogue: $catalogue" >&2; exit 1; }

# The catalogue is arguments with the entries embedded in them; a name is any
# line that is neither blank nor a comment.
listed=" $(grep -v '^[[:space:]]*#' "$catalogue" | tr -s '[:space:]' ' ') "
argued=$(wc -w <<<"$listed")

compared=0
broke=()     # not listed, and diverged -- containment is broken
stale=()     # listed, and did not diverge -- the catalogue is out of date
seen=" "     # every case name the glob reached, to find a catalogue entry
             # that names none: a renamed or deleted case would otherwise take
             # its entry out of service without failing anything, which is the
             # quiet half of "fails in both directions" and was a hole in this
             # script until an entry reading `hello` was accepted in silence.

for case in "$srcdir"/tests/extended/*.pas; do
  [[ -e $case ]] || continue
  name=$(basename "${case%.pas}")
  seen+="$name "
  compared=$((compared + 1))
  if "$srcdir/tests/run_test.sh" "$pascalcc" "$case" afterschool \
       >/dev/null 2>&1; then
    same=yes
  else
    same=no
  fi
  if [[ $listed == *" $name "* ]]; then
    [[ $same == yes ]] && stale+=("$name")
  else
    [[ $same == no ]] && broke+=("$name")
  fi
done

echo "ADR-0117: the conformance corpus, compiled a second way"
echo "  compared $compared cases under --std=afterschool"

status=0

if [[ $compared -eq 0 ]]; then
  echo "  FAIL: no cases were compared; the glob reached nothing"
  status=1
fi

if [[ ${#broke[@]} -gt 0 ]]; then
  echo "  FAIL: ${#broke[@]} case(s) behave differently under the dialect and"
  echo "        are not in tests/checks/containment_exceptions.txt:"
  for n in "${broke[@]}"; do
    echo "          $n"
    "$srcdir/tests/run_test.sh" "$pascalcc" "$srcdir/tests/extended/$n.pas" \
      afterschool 2>&1 | sed 's/^/            /'
  done
  echo "        Extended Pascal accepts these and the dialect must too; an"
  echo "        entry in the catalogue needs the argument for why it may not."
  status=1
fi

orphan=()
for n in $listed; do
  [[ $seen == *" $n "* ]] || orphan+=("$n")
done
if [[ ${#orphan[@]} -gt 0 ]]; then
  echo "  FAIL: ${#orphan[@]} catalogue entries name no case under tests/extended/:"
  for n in "${orphan[@]}"; do echo "          $n"; done
  echo "        An entry that matches nothing is an argument guarding nothing."
  status=1
fi

if [[ ${#stale[@]} -gt 0 ]]; then
  echo "  FAIL: ${#stale[@]} case(s) are in the catalogue and no longer diverge:"
  for n in "${stale[@]}"; do echo "          $n"; done
  echo "        Delete the entry and its argument. A catalogue that only grows"
  echo "        is a catalogue nobody trusts."
  status=1
fi

if [[ $status -eq 0 ]]; then
  echo "  ok   $((compared - argued)) behave identically, $argued diverge and are argued for"
fi
exit $status
