#!/usr/bin/env bash
# Differential test: a stage-1 component against the stage-0 one it was ported
# from, on every Pascal source in the repository.
#
#   difftest.sh <path-to-pascalc> [files...]
#
# The roadmap makes this the checkpoint that comes *before* stage 1 is declared
# working. A disagreement here is a bug in one of the two implementations,
# found on a file small enough to bisect; the same bug found at stage 3 is a
# byte mismatch between two compiler binaries with nothing to compare but their
# output.
#
# Both sides write the same format — `pascalc --dump-all` against
# selfhost/compiler.pas — so the comparison is a plain diff. ISO 7185 has no
# include mechanism, so the Pascal side is one program covering every stage
# ported so far, and it dumps all of them in one pass; there is no mode to
# select because there is no separate binary to select it on.
#
# The Pascal side is itself compiled by the compiler under test, so this also
# checks that the compiler can still build a program of that size and shape.
set -u

pascalc=$1
shift || { echo "usage: difftest.sh <pascalc> [files...]" >&2; exit 2; }

component=compiler
flag=--dump-all
what="stage for stage"

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if ! "$pascalc" "$here/compiler.pas" -o "$work/stage1" 2>"$work/build.err"; then
  echo "--- the Pascal $component did not compile ---" >&2
  cat "$work/build.err" >&2
  exit 1
fi

if [[ $# -gt 0 ]]; then
  files=("$@")
else
  # Every Pascal source in the tree, the stage-1 sources included: they are the
  # largest and most varied Pascal in the repository, and the shape the rest of
  # the port will take.
  mapfile -t files < <(find "$root/tests" "$here" -name '*.pas' | sort)
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "differential $component test: no files to compare" >&2
  exit 1
fi

# Which standard a source is written in is decided by where it lives:
# tests/extended/ is ISO/IEC 10206:1991, everything else is ISO 7185. Both
# compilers are told from the same variable so they cannot drift — the C++ one
# by --std, the Pascal one through a file, because ISO 7185 gives a program no
# other channel (ADR-0033).
# The glob is deliberately unanchored: a file named on the command line arrives
# as a relative path, and a leading-slash pattern would quietly call it ISO 7185
# and compare two identical rejections.
standard_of() {
  case $1 in
    *tests/extended/*)  echo extended ;;
    *)                  echo iso7185 ;;
  esac
}

checked=0
failed=0
for f in "${files[@]}"; do
  standard=$(standard_of "$f")
  echo "$standard" >"$work/options"
  # The fourth program parameter: 6.13's already-translated components. A file
  # compared on its own imports nothing, so it is empty -- but it has to exist,
  # ISO 7185 binding program parameters to arguments in order (ADR-0033).
  : >"$work/imports"
  "$pascalc" "--std=$standard" "$flag" "$f" >"$work/cpp.txt" 2>"$work/cpp.err"
  # A bug can be a *loop* rather than a wrong answer — a scanner that
  # recognises no character consumes none and never advances. That is a
  # failure like any other, so it is bounded here instead of hanging the run.
  # The second argument is where the Pascal compiler writes its IR. Nothing
  # here compares it -- selfhost/irtest.sh is what runs it -- but generating
  # it on every file is free coverage: a code generator that crashes or
  # loops on a corpus file fails here, on the file that did it.
  timeout 120 "$work/stage1" "$f" "$work/ir.ll" "$work/options" \
    "$work/imports" \
      >"$work/pas.txt" 2>"$work/pas.err"
  status=$?
  checked=$((checked + 1))
  if [[ $status -eq 124 ]]; then
    echo "--- $(basename "$f"): the Pascal $component did not terminate ---" >&2
    failed=$((failed + 1))
    continue
  fi
  if [[ $status -ne 0 ]]; then
    echo "--- $(basename "$f"): the Pascal $component exited with $status ---" >&2
    cat "$work/pas.err" >&2
    failed=$((failed + 1))
    continue
  fi
  # An empty dump on both sides would compare equal while proving nothing, and
  # every file in the corpus produces either a tree or a diagnostic.
  if [[ ! -s "$work/cpp.txt" ]]; then
    echo "--- $(basename "$f"): the C++ $component produced nothing to compare ---" >&2
    cat "$work/cpp.err" >&2
    failed=$((failed + 1))
    continue
  fi
  if ! diff -u --label "cpp/$(basename "$f")" --label "pascal/$(basename "$f")" \
          "$work/cpp.txt" "$work/pas.txt" >"$work/delta"; then
    echo "--- $(basename "$f"): the two ${component}s disagree ---" >&2
    head -40 "$work/delta" >&2
    failed=$((failed + 1))
  fi
done

if [[ $failed -ne 0 ]]; then
  echo "differential $component test: $failed of $checked files disagree" >&2
  exit 1
fi

echo "differential $component test: $checked files, both ${component}s agree $what"
