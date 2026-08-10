#!/usr/bin/env bash
# The stage-1 code generator, checked by running what it produces -- and then
# by closing the bootstrap.
#
#   irtest.sh <path-to-pascalc> [files...]
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
#   stage 1 = pascalc(compiler.pas)        built by C++
#   stage 2 = stage1(compiler.pas)         built by a compiler C++ built
#   stage 3 = stage2(compiler.pas)         built by a compiler Pascal built
#
# and stage 2 must equal stage 3. It is compared as IR rather than as a binary
# because that is what the Pascal compiler emits -- the same fixed point, one
# step earlier, and readable when it fails.
set -u

pascalc=$1
shift || { echo "usage: irtest.sh <pascalc> [files...]" >&2; exit 2; }

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

runtime=${AFTERSCHOOL_PASCAL_RUNTIME:-}
if [[ -z $runtime ]]; then
  runtime=$(dirname "$pascalc")/../lib/libpasrt.a
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

# Compile one Pascal source with a stage-1 compiler and link the result.
#   build <compiler> <source.pas> <output-binary>
standard_of() {
  case $1 in
    */tests/extended/*) echo extended ;;
    *)                  echo iso7185 ;;
  esac
}

build() {
  local cc=$1 src=$2 out=$3
  rm -f "$work/ir.ll"
  # The Pascal compiler reads the standard from a file, because ISO 7185 gives
  # a program no other channel for it (ADR-0033).
  standard_of "$src" >"$work/options"
  timeout 600 "$cc" "$src" "$work/ir.ll" "$work/options" \
      >/dev/null 2>"$work/gen.err" || return 1
  [[ -s $work/ir.ll ]] || return 1
  clang -Wno-override-module "$work/ir.ll" "$runtime" -lm -o "$out" \
      2>"$work/link.err" || return 2
}

if ! "$pascalc" "$here/compiler.pas" -o "$work/stage1" 2>"$work/build.err"; then
  echo "--- the Pascal compiler did not compile ---" >&2
  cat "$work/build.err" >&2
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
  for f in "${files[@]}"; do
    name=$(basename "${f%.pas}")
    expected_out="${f%.pas}.out"
    expected_err="${f%.pas}.err"
    stdin_file="${f%.pas}.in"
    [[ -f $stdin_file ]] || stdin_file=/dev/null

    # Rejected by the C++ compiler: a diagnostic, not a program. difftest.sh is
    # what compares those, and it compares all of them.
    if ! "$pascalc" "--std=$(standard_of "$f")" "$f" -o "$work/ref" \
           >/dev/null 2>&1; then
      [[ $stage == stage1 ]] && skipped=$((skipped + 1))
      continue
    fi

    build "$cc" "$f" "$work/$name"
    rc=$?
    if [[ $rc -ne 0 ]]; then
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
