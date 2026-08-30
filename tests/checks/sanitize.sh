#!/bin/bash
# Run the corpus under AddressSanitizer, UndefinedBehaviorSanitizer and
# LeakSanitizer (ADR-0259).
#
# **This is the only oracle here that reads the runtime's own memory
# behaviour.** Every other gate compares what a program printed, or counts
# something the compiler reported about itself: `heap-balance` (ADR-0183) tallies
# `pas_new` against `pas_dispose` and is the closest, and it counts *calls*
# rather than watching storage -- so a write one byte past an allocation, a read
# of a freed block, or a signed overflow in the runtime's own C is invisible to
# it and to everything else in this tree. `runtime/pasrt.c` is the only C here
# and it does the allocation, the handles, the setjmp buffers and the string
# arena; nothing was watching any of it.
#
# It is not a fuzzer and does not pretend to be. What it does is run the corpus
# that already exists under three checkers, which is the cheap half of the gap
# `doc/sop.md` §7 records -- the expensive half is generating inputs nobody
# wrote, and that is a separate job.
#
# **A leak is not automatically a failure**, for the reason ADR-0183 gives: no
# standard obliges a program to dispose what it created. `heap_balance.txt`
# already records, case by case, which programs legitimately end with something
# outstanding -- so that file is the suppression list, and using it rather than
# a second list of this script's own is the point. A case leaking that the
# catalogue says balances is a failure; a case leaking that the catalogue
# already accounts for is not. The two therefore cannot drift apart without one
# of them failing.
#
# Skips are counted and printed rather than hidden. A program whose heading
# declares file parameters needs names on its command line, which `run_test.sh`
# supplies from its sidecars and this does not -- those are reported as skipped,
# which is honest and is this harness's own limit.
#
#   usage: sanitize.sh <pascalcc> [<pascalc>]
set -u

pascalcc=${1:?usage: sanitize.sh <pascalcc> [<pascalc>]}
pascalc=${2:-${PASCALC:-pascalc}}
root=$(cd "$(dirname "$0")/../.." && pwd)

for tool in clang ar; do
  command -v "$tool" >/dev/null || { echo "sanitize: no $tool" >&2; exit 77; }
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The runtime, built the way every program below will be linked. The flags are
# one string so the compile and the link cannot disagree about them, which is
# the mistake that makes a sanitizer silently do nothing: ASan's runtime is
# pulled in at the *link*, so a program compiled with it and linked without is
# an ordinary program that took longer to build.
san="-fsanitize=address,undefined -fno-omit-frame-pointer"
mkdir -p "$work/lib"
for u in pasrt pasrt_posix pasrt_unicode; do
  # shellcheck disable=SC2086
  if ! clang $san -O1 -I"$root/runtime" -c "$root/runtime/$u.c" \
       -o "$work/$u.o" 2>"$work/cc.txt"; then
    echo "sanitize: the runtime does not build under $san" >&2
    head -20 "$work/cc.txt" >&2
    exit 1
  fi
done
ar rcs "$work/lib/libpasrt.a" "$work"/pasrt.o "$work"/pasrt_posix.o \
       "$work"/pasrt_unicode.o || exit 1

# Every case the catalogue says ends with something outstanding. Read once.
declare -A outstanding=()
while read -r name n; do
  [[ $name == \#* || -z $name ]] && continue
  [[ ${n:-0} -gt 0 ]] && outstanding[$name]=$n
done <"$root/tests/checks/heap_balance.txt"

clean=0; skipped=0; failed=0; known=0
for src in "$root"/tests/*.pas "$root"/tests/extended/*.pas \
           "$root"/tests/dialect/*.pas; do
  [[ -f $src ]] || continue
  name=$(basename "$src" .pas)
  dir=$(dirname "$src")
  # A case with no `.out` is one that is meant to fail, and what it prints is a
  # diagnostic rather than a run.
  [[ -f $dir/$name.out ]] || { skipped=$((skipped + 1)); continue; }

  argv=()
  if [[ -f $dir/$name.components ]]; then
    while read -r rel; do
      [[ -n $rel ]] && argv+=(--import "$dir/$rel")
    done <"$dir/$name.components"
  fi
  opt=-O1
  [[ -f $dir/$name.opt ]] && opt=$(<"$dir/$name.opt")

  if ! AFTERSCHOOL_PASCAL_CFLAGS="$san" \
       AFTERSCHOOL_PASCAL_RUNTIME="$work/lib" \
       PASCALC="$pascalc" \
       "$pascalcc" "$opt" "${argv[@]+"${argv[@]}"}" "$src" \
       -o "$work/prog" >"$work/build.txt" 2>&1; then
    skipped=$((skipped + 1)); continue
  fi

  in=/dev/null
  [[ -f $dir/$name.in ]] && in=$dir/$name.in
  ( cd "$work" && ASAN_OPTIONS=detect_leaks=1 ./prog ) \
    >"$work/out.txt" 2>"$work/err.txt" <"$in"

  # A program that wanted file names on its command line, which this harness
  # does not supply. Its own `.out` is what run_test.sh compares; here it is a
  # skip and is counted as one.
  if grep -q "needs a file name as argument" "$work/err.txt"; then
    skipped=$((skipped + 1)); continue
  fi

  # **The two `runtime error:` messages are not the same message**, and telling
  # them apart is the whole of what makes this gate readable. This compiler
  # traps on purpose -- an array subscript out of bounds, an integer overflow,
  # a case with no matching label -- and `runtime/pasrt.c` writes
  # `runtime error: ...` at the start of a line for it (ADR-0014, ADR-0017).
  # UBSan writes `<file>:<line>:<col>: runtime error: ...`, with a position in
  # front. Matching the bare text called every `trap_*` case in the corpus a
  # sanitizer finding, which is thirteen programs doing exactly what they were
  # written to do.
  if grep -qE '^==[0-9]+==ERROR: |:[0-9]+:[0-9]+: runtime error: ' \
       "$work/err.txt"; then
    # LeakSanitizer alone, on a case the catalogue already accounts for, is the
    # catalogue being right rather than a defect.
    #
    # Asked of the ERROR *line*, not of the whole output: LeakSanitizer prints
    # its own summary as `SUMMARY: AddressSanitizer: ... leaked`, so a test for
    # the absence of the string `AddressSanitizer` anywhere suppressed nothing
    # and reported every catalogued leak.
    if grep -qE '^==[0-9]+==ERROR: LeakSanitizer' "$work/err.txt" &&
       ! grep -qE '^==[0-9]+==ERROR: AddressSanitizer' "$work/err.txt" &&
       ! grep -qE ':[0-9]+:[0-9]+: runtime error: ' "$work/err.txt" &&
       [[ -n ${outstanding[$name]:-} ]]; then
      clean=$((clean + 1)); continue
    fi
    # A finding this tree already knows about and has argued for.
    if grep -qE "^$name( |\$)" "$root/tests/checks/sanitizer_findings.txt" \
       2>/dev/null; then
      known=$((known + 1)); continue
    fi
    echo "--- $name ---" >&2
    grep -m4 '^==[0-9]*==ERROR: \|runtime error: \|SUMMARY:' "$work/err.txt" >&2
    failed=$((failed + 1)); continue
  fi
  clean=$((clean + 1))
done

echo "sanitize: $clean clean, $known catalogued, $failed flagged,"\
     "$skipped skipped"
if (( clean < 100 )); then
  echo "sanitize: only $clean programs ran, and the corpus is larger than that" \
       "-- a run that reaches nothing passes for the same reason a clean one" \
       "does" >&2
  exit 1
fi
(( failed == 0 )) || exit 1
