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
# because --std is part of the interface being checked.
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

  # A command line, since ADR-0081: the compiler reads its own arguments
  # through the binding of its program-parameters, so --std and -o are flags
  # like any other compiler's rather than the files they used to be.
  if ! timeout 120 "$pascalc" "--std=$(standard_of "$f")" "$f" \
       -o "$work/ir.ll" >/dev/null 2>"$work/gen.err"; then
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

# --- the version it reports is the one the project carries -------------------
#
# Pascal has no preprocessor, so CMake cannot substitute the number into
# compiler.pas: it is written there as a constant and checked here, which is
# the arrangement `fileSize` and PAS_FILE_SIZE already have for the same
# reason -- two files that cannot include one another, and a disagreement that
# is checked rather than trusted. A compiler that misreports its own version
# makes every bug report worse than no version at all.
want=$(sed -n 's/^project(afterschool_pascal VERSION \([0-9.]*\).*/\1/p' \
       "$root/CMakeLists.txt")
have=$("$pascalc" --version 2>/dev/null | sed -n 's/^pascalc (Afterschool Pascal) //p')
checked=$((checked + 1))
if [[ -z $want ]]; then
  echo "--- version: CMakeLists.txt names no project VERSION ---" >&2
  failed=$((failed + 1))
elif [[ $want != "$have" ]]; then
  echo "--- version: the project is $want but pascalc says '$have' ---" >&2
  failed=$((failed + 1))
fi

# --- and that it says so when it does not translate something ---------------
#
# A compiler that cannot report failure is not usable from a build rule:
# `pascalc bad.pas && clang bad.ll ...` would run the linker on a file that was
# never written. ISO/IEC 10206:1991 §6.7.5.7's `halt` takes no parameters and
# neither standard models an exit status, so this is the one language extension
# this processor adds for its own sake (ADR-0084) -- and *nothing else checks
# it*. Removing `halt(1)` from compiler.pas passed all 279 cases, the golden
# files comparing what a program wrote and never how it stopped.
cat >"$work/rejected.pas" <<'PAS'
program Rejected(output);
begin
  undeclared := 1
end.
PAS
: >"$work/ir.ll"
"$pascalc" "$work/rejected.pas" -o "$work/ir.ll" >"$work/rej.txt" 2>&1
status=$?
checked=$((checked + 1))
if [[ $status -eq 0 ]]; then
  echo "--- rejected: pascalc exited 0 for a program it refused ---" >&2
  failed=$((failed + 1))
elif [[ -s $work/ir.ll ]]; then
  echo "--- rejected: pascalc wrote IR for a program it refused ---" >&2
  failed=$((failed + 1))
elif ! grep -q "undeclared identifier" "$work/rej.txt"; then
  echo "--- rejected: pascalc gave no diagnostic naming the fault ---" >&2
  cat "$work/rej.txt" >&2
  failed=$((failed + 1))
fi

# The other half of the same contract: a successful run must exit 0, or a build
# rule would stop on every program it compiled.
"$pascalc" "$root/tests/hello.pas" -o "$work/ir.ll" >/dev/null 2>&1
status=$?
checked=$((checked + 1))
if [[ $status -ne 0 ]]; then
  echo "--- accepted: pascalc exited $status for a program it translated ---" >&2
  failed=$((failed + 1))
fi

if [[ $failed -ne 0 ]]; then
  echo "producttest: $failed of $((checked + failed)) failed" >&2
  exit 1
fi
echo "producttest: $checked checks passed against the built pascalc"
