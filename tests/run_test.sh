#!/usr/bin/env bash
# Compile one .pas file, run it, and compare against the expected output.
#
#   run_test.sh <path-to-pascalc> <path-to-test.pas>
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
name=$(basename "${source_file%.pas}")
[[ -f $stdin_file ]] || stdin_file=/dev/null

if [[ ! -f $expected_out && ! -f $expected_err ]]; then
  echo "missing expected-output file: $expected_out or $expected_err" >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

normalise() { sed "s|$source_file|<source>|g" "$1"; }

# The compiled program runs with a deliberately small descriptor table. Closing
# a file at block exit is ISO's rule and this compiler's obligation — a test
# that opens thousands of scratch files in sequence (files_scratch.pas,
# goto_files.pas) can only fail if the table can actually run out, and on a
# machine whose default limit is half a million it never would.
run_program() {
  ( ulimit -n 256
    exec "$work/$name" "$work/file1" "$work/file2" <"$stdin_file" )
}

"$pascalc" "$source_file" -o "$work/$name" 2>"$work/compile.err"
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
