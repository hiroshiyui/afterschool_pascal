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

# Compile one .pas with a --dump flag and compare the dump against a golden.
#
#   run.sh <path-to-pascalc> <path-to-test.pas>
#
# A case here needs its own harness rather than a sidecar on tests/run_test.sh,
# because the thing under test is what the *compiler* writes to standard
# output, where every case there compares what the compiled *program* writes.
# The two never meet: a dump case is not run, and an ordinary case never passes
# a --dump flag.
#
#   name.dump    expected standard output, in full
#   name.flags   the flag to compile with; --dump-all when absent
#
# The case's own directory is rewritten to <dir>/ in what is compared, which
# tests/run_test.sh does to a diagnostic for the same reason: --dump-imports
# answers with *paths*, and a path that begins at the checkout cannot be
# written down once (ADR-0244). No other dump names a file, so this changes
# nothing for the rest.
#
# These exist because tests/checks/coverage.py found that no case in the corpus
# passed any --dump flag, leaving thirty-one walker procedures entered by
# nothing while four documented flags claimed to work. Keeping them green is
# what stops that recurring; keeping the goldens honest is a separate
# obligation, and regenerating one is a decision to argue for in the commit
# message rather than a step (doc/sop.md §5).
set -u

pascalc=$1
source_file=$2
base="${source_file%.pas}"
name=$(basename "$base")

expected="$base.dump"
flags_file="$base.flags"

flags="--dump-all"
[[ -f $flags_file ]] && flags=$(tr -d '[:space:]' <"$flags_file")

if [[ ! -f $expected ]]; then
  echo "missing expected-dump file: $expected" >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The IR still gets written -- a --dump flag stops the *reporting* at the stage
# it names, not the translation -- so it goes somewhere disposable. Only what
# reaches standard output is the subject here.
"$pascalc" "$flags" "$source_file" -o "$work/out.ll" \
  >"$work/actual" 2>"$work/stderr"
status=$?

# Diagnostics go to `output` too (no standard Pascal program has a second
# stream), so a case that stopped compiling would show up as a dump diff rather
# than as a mystery. The exit status is still checked: these are valid programs
# and a non-zero status means the golden is recording a failure.
if [[ $status -ne 0 ]]; then
  echo "--- $name: the compiler exited with status $status ---" >&2
  cat "$work/actual" "$work/stderr" >&2
  exit 1
fi

if [[ -s $work/stderr ]]; then
  echo "--- $name: unexpected output on standard error ---" >&2
  cat "$work/stderr" >&2
  exit 1
fi

# The source path is rewritten so a golden does not depend on where the
# checkout lives, exactly as tests/run_test.sh does it.
if ! diff -u "$expected" <(sed -e "s|$source_file|<source>|g" \
                               -e "s|$(dirname "$source_file")/|<dir>/|g" \
                               "$work/actual"); then
  echo "--- $name: dump differs (expected vs actual above) ---" >&2
  exit 1
fi

echo "$name: ok ($flags)"
