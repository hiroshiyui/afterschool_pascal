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

# The stage-1 code generator, checked by running what it produces -- and then
# by closing the bootstrap.
#
#   irtest.sh <path-to-the-seed-compiler> [files...]
#
# Every earlier component was checked by *diffing* it against the C++ one, on a
# dump both sides write (ADR-0022, ADR-0023, ADR-0024). CodeGen cannot be: the
# C++ backend builds an llvm::Module through the API and the Pascal one prints
# assembler text, and LLVM's own printer is not a specification -- it renumbers,
# it reorders attributes, and it changes between releases. Requiring the Pascal
# side to reproduce it byte for byte would be porting LLVM's AsmWriter, not
# porting codegen.cpp.
#
# So the oracle here is the same one ADR-0011 already uses for the C++ compiler:
# the golden stdout of the program. Compile each case with the Pascal compiler,
# assemble and link what it wrote, run it, and compare against the *same*
# tests/*.out and tests/*.err the C++ compiler is held to. Two compilers, one
# expected answer -- which catches wrongness rather than spelling.
#
# Then the part that is the point of the whole exercise (ADR-0004):
#
#   stage 1 = seed(compiler.pas)           built by the committed seed
#   stage 2 = stage1(compiler.pas)         built by a compiler C++ built
#   stage 3 = stage2(compiler.pas)         built by a compiler Pascal built
#
# and stage 2 must equal stage 3. It is compared as IR rather than as a binary
# because that is what the Pascal compiler emits -- the same fixed point, one
# step earlier, and readable when it fails.
set -u

seedcc=$1
shift || { echo "usage: irtest.sh <seed-compiler> [files...]" >&2; exit 2; }

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

runtime=${AFTERSCHOOL_PASCAL_RUNTIME:-}
if [[ -z $runtime ]]; then
  runtime=$(dirname "$seedcc")/../lib/libpasrt.a
fi
if [[ ! -f $runtime ]]; then
  echo "irtest: cannot find libpasrt.a (looked at $runtime)" >&2
  exit 1
fi

# Two sizes live in two places that cannot include one another:
# runtime/pasrt.h, which codegen.cpp includes, and the constants of the Pascal
# compiler. A disagreement would allocate the wrong number of bytes in every
# activation record, so they are checked, not trusted.
check_size() {
  local macro=$1 constant=$2 want have
  want=$(sed -n "s/^#define $macro \([0-9]*\).*/\1/p" "$root/runtime/pasrt.h")
  have=$(sed -n "s/^ *$constant = \([0-9]*\);.*/\1/p" "$here/compiler.pas")
  if [[ -z $want || $want != "$have" ]]; then
    echo "irtest: $macro is $want but compiler.pas says $have" >&2
    exit 1
  fi
}
check_size PAS_FILE_SIZE fileSize
check_size PAS_JUMP_SIZE jumpSize

# Which standard a source is written in is decided by where it lives. The glob
# is deliberately unanchored: a file named on the command line arrives as a
# relative path, and a leading-slash pattern would quietly call it ISO 7185 and
# then compare two identical rejections.
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
    # The dialect (ADR-0117). Same construction as the line above, and the
    # glob is unanchored for the same reason: a relative path named on the
    # command line must not fall through to iso7185.
    *tests/dialect/*)   echo afterschool ;;
    *)                  echo iso7185 ;;
  esac
}

# Compile one Pascal source with a stage-1 compiler and link the result.
#   build <compiler> <source.pas> <output-binary>
build() {
  local cc=$1 src=$2 out=$3 rel comp n std
  rm -f "$work/ir.ll"
  std=$(standard_of "$src")
  # ISO/IEC 10206:1991 6.13's already-translated program-components. Each is
  # named with its own --import, and each is also translated on its own here,
  # so what is linked is genuinely several objects and not one -- which is the
  # clause's whole point. They used to reach the Pascal compiler concatenated
  # into a single program parameter, a program that cannot name a file being
  # unable to open several; ADR-0081 gave it names.
  local objects=() imports=()
  n=0
  if [[ -f ${src%.pas}.components ]]; then
    while IFS= read -r rel; do
      [[ -n $rel ]] || continue
      comp="$(dirname "$src")/$rel"
      n=$((n + 1))
      rm -f "$work/comp.ll"
      # With the components listed before it, and not with its own --import:
      # 6.13 lets one component import another and the list is in dependency
      # order, so the import is added after this translation rather than before.
      timeout 600 "$cc" "--std=$std" "${imports[@]+"${imports[@]}"}" \
          "$comp" -o "$work/comp.ll" \
          >/dev/null 2>"$work/gen.err" || return 1
      imports+=(--import "$comp")
      [[ -s $work/comp.ll ]] || return 1
      clang -Wno-override-module -fPIC -c "$work/comp.ll" -o "$work/c$n.o" \
          2>"$work/link.err" || return 2
      objects+=("$work/c$n.o")
    done <"${src%.pas}.components"
  fi
  timeout 600 "$cc" "--std=$std" "$src" -o "$work/ir.ll" \
    "${imports[@]+"${imports[@]}"}" \
      >/dev/null 2>"$work/gen.err" || return 1
  [[ -s $work/ir.ll ]] || return 1
  clang -Wno-override-module "$work/ir.ll" "${objects[@]+"${objects[@]}"}" \
      "$runtime" -lm -o "$out" 2>"$work/link.err" || return 2
}

# Stage 1 is built by the seed -- seed/pascalc.ll assembled into a compiler --
# where it used to be built by the C++ one. Nothing else about the chain
# changes: what the fixed point proves is that a compiler built from this
# source reproduces itself, and which compiler started it off has never been
# part of that claim (ADR-0004, ADR-0085).
if ! build "$seedcc" "$here/compiler.pas" "$work/stage1"; then
  echo "--- the seed could not compile the Pascal compiler ---" >&2
  head -20 "$work/gen.err" "$work/link.err" >&2
  exit 1
fi

if [[ $# -gt 0 ]]; then
  files=("$@")
else
  mapfile -t files < <(find "$root/tests" -name '*.pas' | sort)
fi

# --- the golden suite, run against what a given stage-1 compiler produces ---
checked=0
skipped=0
failed=0
golden() {
  local cc=$1 stage=$2 f name expected_out expected_err stdin_file status rc
  local refargs
  for f in "${files[@]}"; do
    name=$(basename "${f%.pas}")
    expected_out="${f%.pas}.out"
    expected_err="${f%.pas}.err"
    stdin_file="${f%.pas}.in"
    [[ -f $stdin_file ]] || stdin_file=/dev/null
    # The same fixed-clock hook run_test.sh has, and for the same reason: a
    # golden file that names a date can only be compared against a date
    # somebody chose. Unset again afterwards so one case cannot leak into
    # the next.
    if [[ -f ${f%.pas}.epoch ]]; then
      SOURCE_DATE_EPOCH=$(<"${f%.pas}.epoch")
      export SOURCE_DATE_EPOCH
    else
      unset SOURCE_DATE_EPOCH
    fi

    # A source with no expectation is not a case: ISO/IEC 10206:1991 6.13's
    # separately accepted components live under tests/ and are compiled as
    # part of the cases that import them, never run on their own -- there is
    # no main-program-declaration in one to enter it through.
    if [[ ! -f $expected_out && ! -f $expected_err ]]; then
      [[ $stage == stage1 ]] && skipped=$((skipped + 1))
      continue
    fi

    # A case that is *meant* not to compile is not this test's business:
    # tests/run_test.sh compares its diagnostics, and what is checked here is
    # what the code generator produces for programs there are programs for.
    #
    # It used to be told which those were by asking the C++ compiler, which is
    # gone (ADR-0085). The question is now answered by the outcome and the
    # expectation together: a build that fails where a .err golden exists is
    # that case doing what it says; a build that fails with no .err is a
    # regression, and is reported rather than skipped. Deciding by expectation
    # alone would let a program that must not compile pass by failing to.
    build "$cc" "$f" "$work/$name"
    rc=$?
    if [[ $rc -ne 0 ]]; then
      if [[ -f $expected_err ]]; then
        [[ $stage == stage1 ]] && skipped=$((skipped + 1))
        continue
      fi
      case $rc in
        1) echo "--- $stage/$name: the Pascal compiler failed on it ---" >&2
           cat "$work/gen.err" >&2 ;;
        *) echo "--- $stage/$name: the generated IR did not assemble ---" >&2
           head -20 "$work/link.err" >&2 ;;
      esac
      failed=$((failed + 1))
      continue
    fi

    checked=$((checked + 1))
    # A wrong lowering can make a program *loop* rather than answer wrongly --
    # a `downto` that steps upward runs 2^31 times before it wraps out. That is
    # a failure like any other, so it is bounded here instead of hanging ctest.
    timeout 60 "$work/$name" "$work/file1" "$work/file2" \
        <"$stdin_file" >"$work/actual" 2>"$work/actual.err"
    status=$?
    if [[ $status -eq 124 ]]; then
      echo "--- $stage/$name: the program did not terminate ---" >&2
      failed=$((failed + 1))
      continue
    fi

    if [[ -f $expected_err ]]; then
      # A program that is supposed to stop: the message is the thing under test.
      if [[ $status -eq 0 ]]; then
        echo "--- $stage/$name: expected a failure, but it succeeded ---" >&2
        failed=$((failed + 1))
        continue
      fi
      if ! diff -u "$expected_err" "$work/actual.err" >"$work/delta"; then
        echo "--- $stage/$name: runtime error message differs ---" >&2
        head -20 "$work/delta" >&2
        failed=$((failed + 1))
        continue
      fi
      if [[ -f $expected_out ]] && \
         ! diff -u "$expected_out" "$work/actual" >"$work/delta"; then
        echo "--- $stage/$name: output before the failure differs ---" >&2
        head -20 "$work/delta" >&2
        failed=$((failed + 1))
      fi
      continue
    fi

    if [[ $status -ne 0 ]]; then
      echo "--- $stage/$name: the program exited with status $status ---" >&2
      cat "$work/actual.err" >&2
      failed=$((failed + 1))
      continue
    fi
    # run_test.sh folds stderr into stdout for an ordinary case; do the same, so
    # the golden file means the same thing on both sides.
    cat "$work/actual.err" >>"$work/actual"
    if ! diff -u "$expected_out" "$work/actual" >"$work/delta"; then
      echo "--- $stage/$name: output differs ---" >&2
      head -30 "$work/delta" >&2
      failed=$((failed + 1))
    fi
  done
}

golden "$work/stage1" stage1

# --- the bootstrap: stage 2 against stage 3 ---
if ! build "$work/stage1" "$here/compiler.pas" "$work/stage2"; then
  echo "--- the Pascal compiler could not compile itself ---" >&2
  head -20 "$work/gen.err" "$work/link.err" >&2
  exit 1
fi
cp "$work/ir.ll" "$work/stage2.ll"

if ! build "$work/stage2" "$here/compiler.pas" "$work/stage3"; then
  echo "--- stage 2 could not compile the compiler ---" >&2
  head -20 "$work/gen.err" "$work/link.err" >&2
  exit 1
fi
cp "$work/ir.ll" "$work/stage3.ll"

if ! diff -q "$work/stage2.ll" "$work/stage3.ll" >/dev/null; then
  echo "--- stage 2 and stage 3 differ: the compiler is not a fixed point ---" >&2
  diff -u "$work/stage2.ll" "$work/stage3.ll" | head -40 >&2
  exit 1
fi

# A compiler that reproduces itself and nothing else would pass the line above,
# so stage 2 is held to the same golden output stage 1 was.
golden "$work/stage2" stage2

if [[ $failed -ne 0 ]]; then
  echo "stage-1 codegen test: $failed of $checked programs are wrong" >&2
  exit 1
fi

echo "stage-1 codegen test: $checked programs behave as the golden output says"\
     "($skipped rejected at compile time), and stage 2 = stage 3:" \
     "the compiler is a fixed point"
