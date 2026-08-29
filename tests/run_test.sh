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

# Compile one .pas file, run it, and compare against the expected output.
#
#   run_test.sh <path-to-pascalcc> <path-to-test.pas>
#
# Two forms of expectation:
#
#   name.out   expected stdout; the program must compile and exit 0.
#   name.err   expected stderr, for a program that is *supposed* to fail —
#              either it does not compile, or it stops on a runtime error.
#              A non-zero exit is then required, and name.out (if present) is
#              compared against whatever was written before the failure.
#
# Two more inputs, for the text-file tests:
#
#   name.in    fed to the program's standard input. Without it stdin is
#              /dev/null, so a program that reads sees end-of-file at once
#              rather than waiting for a terminal that is not there.
#   name.epoch one integer: seconds since 1970-01-01 UTC, exported as
#              SOURCE_DATE_EPOCH so the program's idea of "now" is fixed.
#              ISO/IEC 10206:1991 §6.7.5.8 makes the current date and time
#              implementation-defined, and this implementation defines them
#              from that variable when it is set — which is what lets a golden
#              file name a date at all.
#   name.opt   one word: the optimisation flag to compile this case with, where
#              the default -O2 would hide what it is testing. Storage is the
#              only thing that has needed it -- an alloca inside a loop is
#              invisible at -O2, LLVM being free to hoist one whose address
#              does not escape, so a leak of it can only be seen at -O0.
#   arguments  two writable scratch paths are always passed, so a program
#              whose header names external files has somewhere to put them.
#              A program that names none simply ignores them.
#
# The source path is rewritten to <source> in stderr so diagnostics can be
# compared without depending on where the checkout lives.
set -u

pascalc=$1
source_file=$2
expected_out="${source_file%.pas}.out"
expected_err="${source_file%.pas}.err"
stdin_file="${source_file%.pas}.in"
epoch_file="${source_file%.pas}.epoch"
opt_file="${source_file%.pas}.opt"
name=$(basename "${source_file%.pas}")
[[ -f $stdin_file ]] || stdin_file=/dev/null
# Unset when there is no .epoch file, so every other case runs against the real
# clock -- and does so whatever the developer happens to have exported, since a
# fixed instant inherited from the environment would otherwise silently replace
# the clock in the one case that is testing the clock.
if [[ -f $epoch_file ]]; then
  SOURCE_DATE_EPOCH=$(<"$epoch_file")
  export SOURCE_DATE_EPOCH
else
  unset SOURCE_DATE_EPOCH
fi

if [[ ! -f $expected_out && ! -f $expected_err ]]; then
  echo "missing expected-output file: $expected_out or $expected_err" >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The source path is rewritten so a golden does not depend on where the
# checkout lives. A diagnostic may also name one of §6.13's *other*
# program-components -- an --import reports a heading's errors against the file
# that wrote it -- so the case's own directory is rewritten too, which leaves
# such a path as <dir>/components/name.pas and portable with it.
normalise() {
  sed -e "s|$source_file|<source>|g" \
      -e "s|$(dirname "$source_file")/|<dir>/|g" "$1"
}

# The compiled program runs with a deliberately small descriptor table. Closing
# a file at block exit is ISO's rule and this compiler's obligation — a test
# that opens thousands of scratch files in sequence (files_scratch.pas,
# goto_files.pas) can only fail if the table can actually run out, and on a
# machine whose default limit is half a million it never would.
#
# The stack is bounded for the same reason and it is the same argument: a test
# that leaks stack per iteration can only fail where the stack can actually run
# out, and 8 MB is the ordinary Linux default -- so this changes nothing for
# every other case and makes for_nested_stack.pas mean something wherever it
# runs, including a container that inherited no limit at all.
# ADR-0183's heap balance belongs to the *program under test*, and this script
# runs a Pascal compiler to produce it -- `pascalc` is itself a Pascal program
# on the same runtime, so an inherited PASHEAP_BALANCE would have it count its
# own allocations into the same file. It did, on the first run of that gate:
# every case reported hundreds of outstanding variables, which were the
# compiler's. So the variable is taken out of the environment here and put back
# only around the program.
heap_balance="${PASHEAP_BALANCE:-}"
unset PASHEAP_BALANCE

run_program() {
  ( ulimit -n 256
    ulimit -s 8192
    if [[ -n $heap_balance ]]; then export PASHEAP_BALANCE="$heap_balance"; fi
    exec "$work/$name" "$work/file1" "$work/file2" <"$stdin_file" )
}

# ISO/IEC 10206:1991 6.13's other program-components, when the case has any:
# name.components lists them, one path per line, relative to the .pas's own
# directory. Each is translated on its own first -- which is the whole point of
# the clause, and the reason they are named here rather than concatenated into
# the source. They live in a subdirectory so the CMake glob, which is not
# recursive, does not register a component with no program declaration as a
# case that fails to run.
components_file="${source_file%.pas}.components"
imports=()
objects=()
if [[ -f $components_file ]]; then
  n=0
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    # One path per line. A second field used to name a standard, because
    # ADR-0137's case had components under two of them; ADR-0232 removed the
    # modes and there is one language, so anything after the path is ignored.
    read -r rel _ <<<"$line"
    comp="$(dirname "$source_file")/$rel"
    n=$((n + 1))
    # Translated with the components listed *before* it, because §6.13 lets one
    # component import another and the list is in dependency order. Its own
    # --import is added after, so a component is never handed its own
    # interface. Each is still translated on its own, which is the clause's
    # point: what is linked is several objects.
    if ! "$pascalc" \
           "${imports[@]+"${imports[@]}"}" -c "$comp" -o "$work/c$n.o" \
           2>"$work/compile.err"; then
      echo "--- $name: component $rel did not translate ---" >&2
      cat "$work/compile.err" >&2
      exit 1
    fi
    imports+=(--import "$comp")
    objects+=("$work/c$n.o")
  done <"$components_file"
fi

# ADR-0244's search path, when the case has one: name.importpath lists
# directories, one per line, relative to the .pas's own directory. It is the
# other half of name.components and the two are deliberately different
# questions -- .components names the files and this names the *places*, so a
# case with one is asserting that the compiler found what it was not told.
#
# The harness hands the flag to pascalcc, which hands it to pascalc and then
# translates and links whatever the compiler reports having resolved. Nothing
# here reads a heading; the compiler is asked.
importpath_file="${source_file%.pas}.importpath"
paths=()
if [[ -f $importpath_file ]]; then
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    paths+=(--import-path "$(dirname "$source_file")/$line")
  done <"$importpath_file"
fi

# ...and the same path as an *environment*: name.importenv holds one line, the
# value of AFTERSCHOOL_PASCAL_PATH, with <dir> standing for the case's own
# directory. It is a second sidecar rather than a second line of the first
# because they are different claims -- a flag is what one command line says and
# a variable is what a machine was configured with, and only the second can
# hold an empty entry, a trailing separator or a directory nobody can name on a
# command line without quoting it.
importenv_file="${source_file%.pas}.importenv"
import_env=()
if [[ -f $importenv_file ]]; then
  import_env=("AFTERSCHOOL_PASCAL_PATH=$(sed -e "s|<dir>|$(dirname "$source_file")|g" \
                                             "$importenv_file" | head -1)")
fi

# Which optimisation level to compile at, most specific first:
#
#   name.opt                  this case pins one, because the default hides
#                             what it is testing
#   AFTERSCHOOL_PASCAL_OPT    the whole run wants one -- which is how the
#                             corpus is swept at -O0 without 497 sidecars
#   neither                   pascalcc's own default, -O2
#
# The sidecar wins so that a case pinning -O0 still means -O0 during an -O2
# sweep, and vice versa: a case that pins a level does so because the other one
# cannot see the defect, and a sweep must not quietly undo that.
optflag=()
if [[ -f $opt_file ]]; then
  optflag=("$(tr -d '[:space:]' <"$opt_file")")
elif [[ -n ${AFTERSCHOOL_PASCAL_OPT:-} ]]; then
  optflag=("$AFTERSCHOOL_PASCAL_OPT")
fi

env "${import_env[@]+"${import_env[@]}"}" \
  "$pascalc" "${optflag[@]+"${optflag[@]}"}" "$source_file" \
  "${imports[@]+"${imports[@]}"}" "${paths[@]+"${paths[@]}"}" \
  "${objects[@]+"${objects[@]}"}" -o "$work/$name" 2>"$work/compile.err"
compile_status=$?

if [[ ! -f $expected_err ]]; then
  # --- ordinary test: must compile, run, and exit 0 ---
  if [[ $compile_status -ne 0 ]]; then
    echo "--- $name: compilation failed ---" >&2
    cat "$work/compile.err" >&2
    exit 1
  fi
  run_program >"$work/actual" 2>&1
  status=$?
  if [[ $status -ne 0 ]]; then
    echo "--- $name: program exited with status $status ---" >&2
    cat "$work/actual" >&2
    exit 1
  fi
  if ! diff -u "$expected_out" "$work/actual"; then
    echo "--- $name: output differs (expected vs actual above) ---" >&2
    exit 1
  fi
  echo "$name: ok"
  exit 0
fi

# --- expected-failure test ---
if [[ $compile_status -ne 0 ]]; then
  # Failed to compile: the diagnostics are the thing under test.
  if ! diff -u "$expected_err" <(normalise "$work/compile.err"); then
    echo "--- $name: compiler diagnostics differ ---" >&2
    exit 1
  fi
  echo "$name: ok (rejected at compile time)"
  exit 0
fi

run_program >"$work/actual" 2>"$work/actual.err"
status=$?
if [[ $status -eq 0 ]]; then
  echo "--- $name: expected a failure, but the program succeeded ---" >&2
  exit 1
fi
if ! diff -u "$expected_err" <(normalise "$work/actual.err"); then
  echo "--- $name: runtime error message differs ---" >&2
  exit 1
fi
if [[ -f $expected_out ]] && ! diff -u "$expected_out" "$work/actual"; then
  echo "--- $name: output before the failure differs ---" >&2
  exit 1
fi
echo "$name: ok (failed as expected)"
