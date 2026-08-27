#!/usr/bin/env bash
#
# The AST is a variant record, and this is the only thing that checks it is
# read through the arm its tag selects.
#
# `selfhost/compiler.pas` has exactly one variant record -- `case kind:` appears
# once in 36,000 lines -- and it is the AST: 63 arms, read by the parser, Sema,
# both dump walkers and the code generator. ISO/IEC 10206:1991 6.5.3.3 makes
# reading a field of an inactive variant an **error**, and 3.1 lets a processor
# leave an error undetected. `selfhost/compiler.std` says `extended`, so this
# compiler does leave it undetected -- in itself. A wrong-arm read of a node is
# silent rubbish, and if the field is a pointer the next walk follows it.
#
# ADR-0118 already fixes this, for programs that ask: under `--std=afterschool`
# a write to a variant's field activates that variant and a read of an inactive
# one traps. So the check exists, it is tested, and the compiler was not using
# it on itself. This builds a second compiler that does.
#
#   --std=extended     1 occurrence of the trap message -- a string constant
#                      the compiler *emits* into programs it compiles
#   --std=afterschool  2821 guards
#
# **The shipped compiler does not change.** This is `llc_check.sh`'s shape: a
# second build used only as a reader, never as the product. `compiler.std` stays
# `extended`, so the fixed point that irtest.sh proves is untouched -- and
# ADR-0190's rejection of making the compiler a dialect source does not apply,
# because that alternative made the dialect build *the compiler*.
#
# **What it cannot see.** 6.4.3.3 permits a variant part with no tag field, and
# there is then nothing to compare against -- doc/sop.md 7 carries that row. The
# AST's variant part has a tag, so this covers it; a second variant record added
# without one would be outside this silently.
#
# It compiles rather than runs: every pass that touches a node runs during a
# compilation, and running the compiled program tells you nothing about the
# compiler's own AST.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
cc=${1:-$root/build/bin/pascalc}
runtime=${2:-$root/build/lib/libpasrt.a}

if [[ ! -x $cc ]]; then
  echo "variant-check: no compiler at $cc" >&2
  exit 1
fi
if ! command -v clang >/dev/null; then
  echo "variant-check: no clang, so the guarded compiler cannot be linked" >&2
  exit 77
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The guarded compiler: the same source, translated under the mode that has the
# check. A failure here is a containment defect and not a skip -- the dialect
# contains Extended Pascal (ADR-0117), so a source the shipped compiler accepts
# must compile under --std=afterschool too.
if ! "$cc" --std=afterschool "$root/selfhost/compiler.pas" -o "$work/ap.ll" \
     >"$work/gen.out" 2>"$work/gen.err"; then
  echo "variant-check: the compiler does not compile under --std=afterschool," \
       "which is a containment defect (ADR-0117)" >&2
  head -20 "$work/gen.out" "$work/gen.err" >&2
  exit 1
fi

guards=$(grep -c 'variant: the tag selects another arm' "$work/ap.ll" || true)
if (( guards < 100 )); then
  echo "variant-check: the guarded build has $guards variant guards in it." \
       "ADR-0118's check is not being emitted, so this would pass by asking" \
       "nothing -- which is the one way it must not pass" >&2
  exit 1
fi

if ! clang -O2 -Wno-override-module "$work/ap.ll" "$runtime" -lm \
     -o "$work/pascalc-ap" 2>"$work/link.err"; then
  echo "variant-check: the guarded compiler did not link" >&2
  head -20 "$work/link.err" >&2
  exit 1
fi

# The corpus, with the standard each source is written in -- the same rule every
# other harness here derives from the path, plus the `.std` sidecar that speaks
# for a source outside tests/extended/ (ADR-0082, ADR-0166).
standard_of() {
  local src=$1 sidecar=${1%.pas}.std
  if [[ -f $sidecar ]]; then cat "$sidecar"; return; fi
  case "$src" in
    */tests/dialect/*|*/lib/dialect/*) echo afterschool ;;
    */tests/extended/*)                echo extended ;;
    */tests/*)                         echo iso7185 ;;
    *)                                 echo extended ;;
  esac
}

checked=0
trapped=0
while IFS= read -r src; do
  std=$(standard_of "$src")
  # Every dump runs, so both walkers are exercised and not only the four
  # passes -- difftest.sh drives them the same way and for the same reason.
  "$work/pascalc-ap" "--std=$std" --dump-all "$src" -o "$work/out.ll" \
      >"$work/dump.out" 2>"$work/dump.err"
  checked=$((checked + 1))
  # The runtime's own wording, on the runtime's own stream. Matching the bare
  # message anywhere would match `--dump-all` of compiler.pas printing the
  # string literal the emitter carries -- which it did, on the first run.
  if grep -qs '^runtime error: variant:' "$work/dump.err"; then
    echo "--- $src: the compiler read a node through the wrong arm ---" >&2
    grep -hs '^runtime error: variant:' "$work/dump.err" | head -3 >&2
    trapped=$((trapped + 1))
  fi
done < <(find "$root/tests" "$root/selfhost" "$root/lib" -name '*.pas' | sort)

if (( checked < 500 )); then
  echo "variant-check: only $checked sources were compiled, and the corpus is" \
       "larger than that -- a run that reaches nothing passes for the same" \
       "reason a clean one does" >&2
  exit 1
fi

if (( trapped > 0 )); then
  echo "variant-check: $trapped of $checked sources made the compiler read a" \
       "node through an arm its tag does not select" >&2
  exit 1
fi

echo "variant-check: $checked sources compiled by a compiler carrying" \
     "$guards variant guards; every node was read through the arm its tag" \
     "selects"
