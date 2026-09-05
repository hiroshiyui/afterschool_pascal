#!/bin/bash
# Run the corpus under AddressSanitizer, UndefinedBehaviorSanitizer and
# LeakSanitizer (ADR-0261).
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
# **Two modes, one harness** (ADR-0327). ThreadSanitizer is the oracle AP
# 6.9.3.12's task rests on and it was run by hand -- `doc/sop.md` §7 carried
# that, and CLAUDE.md said "run it by hand over every concurrent program when a
# task changes", which is a procedure nobody executes on a Tuesday. What it
# needs is what this script already is: a second runtime built with the
# checker's flags, and every case linked against it, because a sanitizer's
# runtime arrives at the **link**.
#
# It is a mode rather than a second script because the 120 lines below that
# translate a case's components, supply its import paths and read its sidecars
# are the part that took the defects out (47 cases silently unlinked, once),
# and a copy of them is a copy free to drift.
#
# ThreadSanitizer cannot be combined with AddressSanitizer -- clang refuses the
# pair -- so the modes are exclusive rather than a longer flag list.
mode=${SANITIZE_MODE:-address}
case $mode in
  address) san="-fsanitize=address,undefined -fno-omit-frame-pointer";;
  thread)  san="-fsanitize=thread -fno-omit-frame-pointer";;
  *) echo "sanitize: unknown SANITIZE_MODE '$mode'" >&2; exit 1;;
esac

# Is the checker itself here? Debian's `clang` package has carried
# compiler-rt separately before, and a missing one shows up as every link
# failing for a reason this harness reports once and counts 500 times -- which
# it learned to do the hard way. Asked with C, before anything else, so the
# answer is "the checker is absent" and not "the corpus does not build".
printf 'int main(void){return 0;}\n' >"$work/probe.c"
# shellcheck disable=SC2086
if ! clang $san -o "$work/probe" "$work/probe.c" >"$work/probe.txt" 2>&1; then
  echo "sanitize: clang here cannot link $san -- skipping" >&2
  head -3 "$work/probe.txt" >&2
  exit 77
fi
mkdir -p "$work/lib"
for u in pasrt pasrt_posix pasrt_unicode pasrt_task; do
  # shellcheck disable=SC2086
  if ! clang $san -O1 -I"$root/runtime" -c "$root/runtime/$u.c" \
       -o "$work/$u.o" 2>"$work/cc.txt"; then
    echo "sanitize: the runtime does not build under $san" >&2
    head -20 "$work/cc.txt" >&2
    exit 1
  fi
done
ar rcs "$work/lib/libpasrt.a" "$work"/pasrt.o "$work"/pasrt_posix.o \
       "$work"/pasrt_unicode.o "$work"/pasrt_task.o || exit 1

# Every case the catalogue says ends with something outstanding. Read once.
declare -A outstanding=()
while read -r name n; do
  [[ $name == \#* || -z $name ]] && continue
  [[ ${n:-0} -gt 0 ]] && outstanding[$name]=$n
done <"$root/tests/checks/heap_balance.txt"

# **Three reasons to skip, and they are not the same news.** For as long as
# this gate existed the tally said `233 skipped` and a reader could not tell a
# case with no `.out` -- which is nothing to run and is honest -- from one that
# *failed to link*, which is coverage silently lost. 47 of that 233 were the
# second kind. They are counted apart now so the number that matters is on its
# own: `unbuilt` should be 0, and a run where it is not has stopped watching
# something it used to watch.
clean=0; failed=0; known=0; reported=0
noout=0; needsargs=0; unbuilt=0; notconc=0
for src in "$root"/tests/*.pas "$root"/tests/extended/*.pas \
           "$root"/tests/dialect/*.pas "$root"/examples/*.pas; do
  [[ -f $src ]] || continue
  name=$(basename "$src" .pas)
  dir=$(dirname "$src")
  # In thread mode, the programs with two threads of control in them. Selected
  # by what the source *writes* rather than from a list, so a concurrent
  # program added tomorrow is swept without this file being edited -- the
  # arrangement `target-layout` has for a target. A single-threaded program
  # under ThreadSanitizer is minutes of runtime and no question asked.
  if [[ $mode == thread ]] &&
     ! grep -qE '(^|[^A-Za-z_])(spawn|channel|task)([^A-Za-z_]|$)' "$src"; then
    notconc=$((notconc + 1)); continue
  fi
  # A case with no `.out` is one that is meant to fail, and what it prints is a
  # diagnostic rather than a run.
  [[ -f $dir/$name.out ]] || { noout=$((noout + 1)); continue; }

  # **A component named with --import needs an object, and this did not supply
  # one.** `pascalcc` translates and links whatever `--dump-imports` reports
  # *except* what the caller already named -- "its object is the caller's to
  # supply, and tests/run_test.sh supplies one" -- and this harness named them
  # and supplied nothing, so every case with a `.components` sidecar failed at
  # the link and was counted as a **skip**. 47 of them, silently: the whole of
  # `lib/` and `lib/dialect/` reached the only memory-safety oracle here
  # through no case at all. So the components are compiled here the way
  # run_test.sh compiles them -- each translated with the ones before it, in
  # the dependency order §6.13 gives -- and the objects go to the link.
  argv=(); objs=(); compfail=
  paths=()
  if [[ -f $dir/$name.importpath ]]; then
    while IFS= read -r line; do
      [[ -n $line ]] && paths+=(--import-path "$dir/$line")
    done <"$dir/$name.importpath"
  fi
  import_env=()
  if [[ -f $dir/$name.importenv ]]; then
    import_env=("AFTERSCHOOL_PASCAL_PATH=$(sed -e "s|<dir>|$dir|g" \
                                               "$dir/$name.importenv" | head -1)")
  fi
  if [[ -f $dir/$name.components ]]; then
    cn=0
    while read -r rel _; do
      [[ -n $rel ]] || continue
      cn=$((cn + 1))
      if ! env "${import_env[@]+"${import_env[@]}"}" \
             AFTERSCHOOL_PASCAL_CFLAGS="$san" \
             AFTERSCHOOL_PASCAL_RUNTIME="$work/lib" \
             PASCALC="$pascalc" \
             "$pascalcc" "${argv[@]+"${argv[@]}"}" \
             "${paths[@]+"${paths[@]}"}" -c "$dir/$rel" \
             -o "$work/c$cn.o" >"$work/build.txt" 2>&1; then
        compfail=yes; break
      fi
      argv+=(--import "$dir/$rel")
      objs+=("$work/c$cn.o")
    done <"$dir/$name.components"
  fi
  opt=-O1
  [[ -f $dir/$name.opt ]] && opt=$(<"$dir/$name.opt")

  if [[ -n $compfail ]] ||
     ! env "${import_env[@]+"${import_env[@]}"}" \
       AFTERSCHOOL_PASCAL_CFLAGS="$san" \
       AFTERSCHOOL_PASCAL_RUNTIME="$work/lib" \
       PASCALC="$pascalc" \
       "$pascalcc" "$opt" "${argv[@]+"${argv[@]}"}" \
       "${paths[@]+"${paths[@]}"}" "$src" "${objs[@]+"${objs[@]}"}" \
       -o "$work/prog" >"$work/build.txt" 2>&1; then
    # **Say why, once.** A program that will not build is counted as a skip,
    # and the tally at the end refuses a run that reached nothing -- which is
    # the guard working. But "0 clean, 516 skipped" does not say *what* went
    # wrong, and the first time that happened the cause took a container to
    # find: debian:trixie's `clang` package does not carry compiler-rt, so
    # every `-fsanitize=address` link failed with a missing
    # `libclang_rt.asan.a` and this harness reported none of it.
    #
    # One program's output is enough -- when they all fail they fail for one
    # reason -- and printing every one would bury the tally under 516 copies.
    if [[ $reported -eq 0 ]]; then
      reported=1
      echo "sanitize: $name did not build under $san, and here is why:" >&2
      head -10 "$work/build.txt" >&2
      echo "sanitize: (further build failures are counted, not printed)" >&2
    fi
    unbuilt=$((unbuilt + 1)); continue
  fi

  in=/dev/null
  [[ -f $dir/$name.in ]] && in=$dir/$name.in
  # `halt_on_error=0` so a program with two findings reports both, and
  # `exitcode=0` so the detection below is by what was *written* -- which is
  # what the address mode already does, ASan's own exit status never being
  # consulted here.
  ( cd "$work" && ASAN_OPTIONS=detect_leaks=1 \
      TSAN_OPTIONS="halt_on_error=0 exitcode=0" ./prog ) \
    >"$work/out.txt" 2>"$work/err.txt" <"$in"

  # A program that wanted file names on its command line, which this harness
  # does not supply. Its own `.out` is what run_test.sh compares; here it is a
  # skip and is counted as one.
  if grep -q "needs a file name as argument" "$work/err.txt"; then
    needsargs=$((needsargs + 1)); continue
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
  # ThreadSanitizer announces itself differently from the other three: a data
  # race is `WARNING: ThreadSanitizer: data race`, with no `==pid==ERROR:` in
  # front of it, so the pattern the address mode matches finds nothing and
  # every racy program reports clean. That is the shape of failure this whole
  # register exists to refuse, so the two patterns are named separately rather
  # than a wider one being written that happens to catch both.
  if [[ $mode == thread ]]; then
    if grep -qE '^(WARNING|SUMMARY): ThreadSanitizer: ' "$work/err.txt"; then
      if grep -qE "^$name( |\$)" \
           "$root/tests/checks/sanitizer_findings.txt" 2>/dev/null; then
        known=$((known + 1)); continue
      fi
      echo "--- $name ---" >&2
      grep -m6 'ThreadSanitizer: ' "$work/err.txt" >&2
      failed=$((failed + 1)); continue
    fi
    clean=$((clean + 1)); continue
  fi
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

echo "sanitize[$mode]: $clean clean, $known catalogued, $failed flagged,"\
     "$((noout + needsargs + unbuilt + notconc)) skipped"\
     "($noout with no .out, $needsargs wanting file names, $unbuilt unbuilt,"\
     "$notconc single-threaded)"
if (( unbuilt > 0 )); then
  echo "sanitize: $unbuilt case(s) with a golden did not build, and a case" \
       "that cannot be linked is coverage lost rather than a case with" \
       "nothing to run -- see the first one printed above" >&2
fi
# The floor, and it is a different number for each mode because each sweeps a
# different corpus: everything with a golden, against the eleven programs in
# this tree that have two threads of control. Both exist for one reason -- a
# run that reaches nothing prints the same tally as a clean one.
floor=100
[[ $mode == thread ]] && floor=8
if (( clean + known < floor )); then
  echo "sanitize[$mode]: only $((clean + known)) programs ran, below the floor" \
       "of $floor -- a run that reaches nothing passes for the same reason a" \
       "clean one does" >&2
  exit 1
fi
(( failed == 0 )) || exit 1
