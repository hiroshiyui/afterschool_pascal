#!/usr/bin/env bash
# Differential test: the C++ lexer against the Pascal one, on every Pascal
# source in the repository.
#
#   difftest.sh <path-to-pascalc> [files...]
#
# The roadmap makes this the checkpoint that comes *before* stage 1 is declared
# working. A disagreement here is a bug in one of the two lexers, found on a
# file small enough to bisect; the same bug found at stage 3 is a byte mismatch
# between two compiler binaries with nothing to compare but their output.
#
# Both lexers write the same format — see `pascalc --dump-tokens` and
# selfhost/lexer.pas — so the comparison is a plain diff. The Pascal lexer is
# itself compiled by the compiler under test, so this also checks that the
# compiler can build a program of that size and shape.
set -u

pascalc=$1
shift

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if ! "$pascalc" "$here/lexer.pas" -o "$work/plex" 2>"$work/build.err"; then
  echo "--- the Pascal lexer did not compile ---" >&2
  cat "$work/build.err" >&2
  exit 1
fi

if [[ $# -gt 0 ]]; then
  files=("$@")
else
  # Every Pascal source in the tree, the lexer's own source included: it is
  # the largest and most varied Pascal in the repository, and the one the
  # rest of the port will look like.
  mapfile -t files < <(find "$root/tests" "$here" -name '*.pas' | sort)
fi

checked=0
failed=0
for f in "${files[@]}"; do
  "$pascalc" --dump-tokens "$f" >"$work/cpp.txt" 2>"$work/cpp.err"
  # A lexer bug can be a *loop* rather than a wrong token — a scanner that
  # recognises no character consumes none and never advances. That is a
  # failure like any other, so it is bounded here instead of hanging the run.
  timeout 30 "$work/plex" "$f" >"$work/pas.txt" 2>"$work/pas.err"
  status=$?
  checked=$((checked + 1))
  if [[ $status -eq 124 ]]; then
    echo "--- $(basename "$f"): the Pascal lexer did not terminate ---" >&2
    failed=$((failed + 1))
    continue
  fi
  if [[ $status -ne 0 ]]; then
    echo "--- $(basename "$f"): the Pascal lexer exited with $status ---" >&2
    cat "$work/pas.err" >&2
    failed=$((failed + 1))
    continue
  fi
  if ! diff -u --label "cpp/$(basename "$f")" --label "pascal/$(basename "$f")" \
          "$work/cpp.txt" "$work/pas.txt" >"$work/delta"; then
    echo "--- $(basename "$f"): the two lexers disagree ---" >&2
    head -40 "$work/delta" >&2
    failed=$((failed + 1))
  fi
done

if [[ $failed -ne 0 ]]; then
  echo "differential lexer test: $failed of $checked files disagree" >&2
  exit 1
fi

echo "differential lexer test: $checked files, both lexers agree token for token"
