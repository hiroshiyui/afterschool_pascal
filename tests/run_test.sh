#!/usr/bin/env bash
# Compile one .pas file, run it, and compare stdout with the matching .out file.
#
#   run_test.sh <path-to-pascalc> <path-to-test.pas>
set -u

pascalc=$1
source_file=$2
expected="${source_file%.pas}.out"
name=$(basename "${source_file%.pas}")

if [[ ! -f $expected ]]; then
  echo "missing expected-output file: $expected" >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if ! "$pascalc" "$source_file" -o "$work/$name" 2>"$work/compile.err"; then
  echo "--- $name: compilation failed ---" >&2
  cat "$work/compile.err" >&2
  exit 1
fi

"$work/$name" >"$work/actual" 2>&1
status=$?
if [[ $status -ne 0 ]]; then
  echo "--- $name: program exited with status $status ---" >&2
  cat "$work/actual" >&2
  exit 1
fi

if ! diff -u "$expected" "$work/actual"; then
  echo "--- $name: output differs (expected vs actual above) ---" >&2
  exit 1
fi

echo "$name: ok"
