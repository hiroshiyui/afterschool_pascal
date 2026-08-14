#!/usr/bin/env bash
# The compiler this repository produces, exercised as a user would reach it.
#
#   producttest.sh <path-to-pascalc> <runtime-dir> [files...]
#
# `pascalc` is `selfhost/compiler.pas` translated by `pascalc-s0` and linked by
# CMake, and until this existed nothing tested that artefact. `irtest.sh` looks
# thorough enough to cover it and does not: it builds a stage-1 compiler of its
# own in a temporary directory, so the binary in `build/bin` could be missing,
# stale or built from the wrong source and every test would stay green. What is
# checked here is the *build wiring* -- that the product exists, runs, and
# compiles a program correctly -- rather than the compiler, which the 276 cases
# and the stage-2/stage-3 fixed point already cover.
#
# It is deliberately small for that reason. Two programs, one per standard,
# because the standard reaches the Pascal compiler through a file rather than a
# flag (ADR-0033) and that file is part of the interface being checked.
set -u

pascalc=${1:-}
runtime=${2:-}
if [[ -z $pascalc || -z $runtime ]]; then
  echo "usage: producttest.sh <pascalc> <runtime-dir> [files...]" >&2
  exit 2
fi
shift 2

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [[ ! -x $pascalc ]]; then
  echo "producttest: $pascalc is not executable -- was it built?" >&2
  exit 1
fi

# The default pair covers one program per standard. A caller may name others.
if [[ $# -gt 0 ]]; then
  files=("$@")
else
  files=("$root/tests/hello.pas" "$root/tests/extended/otherwise.pas")
fi

# Which standard a source is written in is decided by where it lives, exactly
# as in run_test.sh, difftest.sh and irtest.sh -- so the four harnesses cannot
# be told different things about one file. Unanchored on purpose (ADR-0034).
standard_of() {
  # A source outside tests/extended/ may still be Extended Pascal, and says so
  # with a `name.std` file beside it holding one word -- the same sidecar
  # convention as `name.in`, `name.epoch` and `name.components`. It exists
  # because selfhost/compiler.pas is Extended Pascal and does not live in the
  # directory that would otherwise be the only way to say so (ADR-0033).
  local sidecar="${1%.pas}.std"
  if [[ -f $sidecar ]]; then
    tr -d '[:space:]' <"$sidecar"
    echo
    return
  fi
  case $1 in
    *tests/extended/*)  echo extended ;;
    *)                  echo iso7185 ;;
  esac
}

failed=0
checked=0
for f in "${files[@]}"; do
  name=$(basename "${f%.pas}")
  expected="${f%.pas}.out"
  if [[ ! -f $expected ]]; then
    echo "producttest: $name has no .out to compare against" >&2
    failed=$((failed + 1))
    continue
  fi

  # The four program parameters, in order: source, IR, the standard, and
  # §6.13's already-translated components. The last two are files rather than
  # flags because ISO 7185 gives a program no command line beyond its program
  # parameters (ADR-0033, ADR-0079), and the fourth must exist even when it is
  # empty, parameters binding to arguments in order.
  standard_of "$f" >"$work/options"
  : >"$work/imports"
  if ! timeout 120 "$pascalc" "$f" "$work/ir.ll" "$work/options" \
       "$work/imports" >/dev/null 2>"$work/gen.err"; then
    echo "--- $name: pascalc did not translate it ---" >&2
    cat "$work/gen.err" >&2
    failed=$((failed + 1))
    continue
  fi
  # A compiler that exits 0 and writes nothing would otherwise be reported as a
  # link failure, which names the wrong component.
  if [[ ! -s $work/ir.ll ]]; then
    echo "--- $name: pascalc exited 0 and wrote no IR ---" >&2
    failed=$((failed + 1))
    continue
  fi

  # Linking is the one part of a driver's job that does not port: neither
  # standard has process control, so the Pascal compiler stops at the IR and
  # something outside it assembles and links. Here that is this script.
  if ! clang -Wno-override-module "$work/ir.ll" "$runtime/libpasrt.a" -lm \
       -o "$work/prog" 2>"$work/link.err"; then
    echo "--- $name: what pascalc wrote did not link ---" >&2
    cat "$work/link.err" >&2
    failed=$((failed + 1))
    continue
  fi

  stdin_file="${f%.pas}.in"
  [[ -f $stdin_file ]] || stdin_file=/dev/null
  "$work/prog" <"$stdin_file" >"$work/out.txt" 2>/dev/null
  checked=$((checked + 1))
  if ! diff -u "$expected" "$work/out.txt" >"$work/diff.txt"; then
    echo "--- $name: pascalc built a program with the wrong output ---" >&2
    cat "$work/diff.txt" >&2
    failed=$((failed + 1))
  fi
done

if [[ $failed -ne 0 ]]; then
  echo "producttest: $failed of $((checked + failed)) failed" >&2
  exit 1
fi
echo "producttest: $checked programs built and run by pascalc"
