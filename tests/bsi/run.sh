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

# Run the BSI Pascal Validation Suite and compare against tests/bsi/expected.tsv.
#
#   tests/bsi/run.sh [pascalcc]
#
# The suite is *not* in this repository. BSI holds the copyright and grants use
# on three conditions without granting redistribution, so it is fetched into a
# gitignored directory the way doc/vendor/ holds the standards themselves:
#
#   tests/bsi/fetch.sh
#
# What makes this an oracle rather than a report is expected.tsv. Every one of
# the 812 programs has a line saying what this compiler does with it today and
# why, and *any* difference fails -- a test that starts passing fails just as
# loudly as one that starts failing, because the catalogue has then stopped
# describing the compiler. That is verify/'s KNOWN_GAP discipline (ADR-0013)
# applied to a corpus nobody here wrote.
#
# BSI's third condition -- that any representation of results describe the
# whole suite and not selected tests -- is why every category is run on every
# invocation and why the summary prints all nine counts.
set -u

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$(dirname "$here")")
pvs=$here/suite
pascalcc=${1:-$root/tools/pascalcc}
expected=$here/expected.tsv

if [[ ! -d $pvs ]]; then
  echo "bsi: the suite is not present; run tests/bsi/fetch.sh" >&2
  exit 77                      # ctest SKIP_RETURN_CODE
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# A program the compiler wrongly accepts may loop or write without end. The
# limits are the harness's own, not the compiler's.
ulimit -f 200000

# Classify one program. Echoes a single verdict word.
#
#   REJECTED      the compiler refused it
#   SAYS-PASS     it ran and printed PASS      (CONFORM)
#   SAYS-FAIL     it ran and printed FAIL      (CONFORM, DEVIANCE completing)
#   NOT-DETECTED  it ran and printed ERROR NOT DETECTED  (ERROR)
#   TRAPPED       it stopped with a run-time error
#   RAN           it ran to completion with nothing above to say
classify() {
  local src=$1
  if ! timeout 25 "$pascalcc" "$src" -o "$work/prog" >"$work/msg" 2>&1; then
    echo REJECTED; return
  fi
  # §6.10 binds a program-parameter that possesses a file-type to a
  # command-line argument, so a program declaring one needs a name to bind to
  # or it stops before its first statement. Two of the 812 do (CONF212 and
  # CONF213, the external-binding tests), and without these they were catalogued
  # as TRAPPED -- which reads as a defect and was a missing argument.
  #
  # Given to every program rather than to those two, because the harness has no
  # business knowing which is which: a program that declares no file parameter
  # ignores them, `input` and `output` are the standard streams and never
  # arguments, and a non-file parameter consumes none (ADR-0074). The directory
  # is fresh per program, so nothing one leaves behind is another's input.
  rm -rf "$work/bound"; mkdir -p "$work/bound"
  timeout 25 "$work/prog" "$work/bound/f1" "$work/bound/f2" \
                          "$work/bound/f3" "$work/bound/f4" \
    </dev/null >"$work/out" 2>&1
  local rc=$?
  if   grep -q 'ERROR NOT DETECTED' "$work/out"; then echo NOT-DETECTED
  elif grep -q 'FAIL'               "$work/out"; then echo SAYS-FAIL
  elif grep -q 'PASS'               "$work/out"; then echo SAYS-PASS
  elif [[ $rc -ne 0 ]];                          then echo TRAPPED
  else                                                echo RAN
  fi
}

declare -A want note
while IFS=$'\t' read -r name verdict why; do
  [[ -z ${name:-} || $name == \#* ]] && continue
  want[$name]=$verdict
  note[$name]=$why
done <"$expected"

# A verdict that is not its category's own must carry a note saying why.
#
# The suite's DOC/README.TXT is what each category requires: a CONFORM program
# must print PASS, a DEVIANCE program must be refused or stop, and a LEVEL1
# program must be refused by a level 0 processor. A row that disagrees is
# either a defect or a decision, and an unexplained one reads as neither -- it
# had been four rows of `TRAPPED` with nothing beside them, one of which was a
# real conformance defect (§6.6.5.2's appended end-of-line) and two of which
# were the harness giving a program no argument to bind.
#
# So this is checked against the catalogue rather than against a run: it costs
# nothing, it fails before the 812 are compiled, and it cannot be satisfied by
# editing a verdict. ERROR rows always carry the Annex D number they name, so
# the category needs no rule here.
bare=0
for name in "${!want[@]}"; do
  case ${note[$name]} in
    CONFORM*)  expected_verdict=SAYS-PASS ;;
    DEVIANCE*) expected_verdict='REJECTED|TRAPPED' ;;
    LEVEL1*)   expected_verdict=REJECTED ;;
    *)         continue ;;
  esac
  [[ ${want[$name]} =~ ^($expected_verdict)$ ]] && continue
  # Anything after the category word is a note.
  if [[ ${note[$name]} =~ ^(CONFORM|DEVIANCE|LEVEL1)[[:space:]]*$ ]]; then
    echo "bsi: $name is ${want[$name]} where its category expects" \
         "${expected_verdict//|/ or }, and says nothing about why" >&2
    bare=$((bare + 1))
  fi
done
if (( bare )); then
  echo "bsi: $bare row(s) of the catalogue need a note. A verdict that is" >&2
  echo "bsi: not its category's own is a finding or a decision; say which." >&2
  exit 1
fi

fail=0; checked=0
declare -A tally
for dir in CONFORM DEVIANCE ERROR EXTEND IMPDEF IMPDEFB IMPDEP LEVEL1; do
  for src in "$pvs/$dir"/*.PAS "$pvs/$dir"/*.pas; do
    [[ -e $src ]] || continue
    b=$(basename "$src"); b=${b%.*}
    got=$(classify "$src")
    checked=$((checked + 1))
    tally[$dir/$got]=$(( ${tally[$dir/$got]:-0} + 1 ))
    exp=${want[$b]:-}
    if [[ -z $exp ]]; then
      echo "bsi: $b is not in expected.tsv (got $got)" >&2
      fail=$((fail + 1))
    elif [[ $exp != "$got" ]]; then
      echo "bsi: $b expected $exp, got $got   [${note[$b]:-}]" >&2
      fail=$((fail + 1))
    fi
  done
done

echo
echo "Pascal Validation Suite 5.7 (C) British Standards Institution"
echo "$checked programs, whole suite:"
for k in "${!tally[@]}"; do echo "  $k ${tally[$k]}"; done | sort
echo

if [[ $fail -ne 0 ]]; then
  echo "bsi: $fail programs differ from tests/bsi/expected.tsv" >&2
  echo "bsi: a program that started *passing* is a finding too -- fix the" >&2
  echo "bsi: catalogue entry in the same change that fixed the compiler." >&2
  exit 1
fi
echo "bsi: all $checked agree with the catalogue"
