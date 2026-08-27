#!/usr/bin/env bash
#
# Is the compiler, built as a *dialect* source, still the compiler?
#
# ADR-0109 wants to know whether Afterschool Pascal is pleasant to write
# something large in, and the largest program within this project's reach is
# excluded from nearly everything the dialect was built for:
# `selfhost/compiler.std` says `extended`, so the compiler is locked out of
# `defer`, `owned ^T`, slices, `break`, `exit`, the generics and `type of`.
#
# Making it a dialect source has been rejected twice, and the rejection is
# narrower than it looks. ADR-0190 refused it because *"the fixed point holds
# only while the compiler is an Extended Pascal source"*, and ADR-0223 restates
# that -- but ADR-0223 is also the way through: it builds the compiler a second
# time under `--std=afterschool` and uses that build as a **reader**, never as
# the product. `doc/roadmap.md`'s v3 chapter puts the question that leaves:
# *not* whether the product changes its standard, but **how much the reader
# build can be shown to do before the product follows**.
#
# This is that measurement, and it makes two claims ADR-0190's objection had
# only ever been argued about (ADR-0231):
#
#   1. **The dialect build is a fixed point.** Compiled under
#      `--std=afterschool`, it reproduces its own IR byte for byte. The
#      objection said a fixed point holds only for an Extended Pascal source;
#      it holds for this one too, and now by measurement.
#
#   2. **The dialect build is the same compiler.** For every source in the
#      tree it emits byte-identical IR to the shipped compiler, or refuses it
#      with byte-identical diagnostics and the same exit status. The 2800-odd
#      variant guards it carries are checks *inside* the compiler and change
#      nothing it emits.
#
# **The shipped compiler still does not change**, and this does not argue that
# it should. It removes one reason it could not: "we do not know that it would
# work" is no longer among them. What remains is the seed -- `seed/pascalc.ll`
# must accept whatever the source becomes, and a seed is refreshed in a release
# rather than casually (ADR-0109).
#
# **What it cannot see.** Both builds come from one source, so a defect written
# into `compiler.pas` is in both and this compares two copies of it. It is an
# equivalence check, not a correctness one; `irtest.sh` and the goldens are
# what say the compiler is right, and this says the dialect build is the same.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
cc=${1:-$root/build/bin/pascalc}
runtime=${2:-$root/build/lib/libpasrt.a}

if [[ ! -x $cc ]]; then
  echo "dialect-build: no compiler at $cc" >&2
  exit 77
fi
if ! command -v clang >/dev/null; then
  echo "dialect-build: no clang, so the dialect compiler cannot be linked" >&2
  exit 77
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# --- stage 2 under the dialect ----------------------------------------------
# A failure here is a containment defect and not a skip: the dialect contains
# Extended Pascal (ADR-0117), so a source the shipped compiler accepts must
# compile under --std=afterschool too.
if ! "$cc" --std=afterschool "$root/selfhost/compiler.pas" -o "$work/ap.ll" \
     >"$work/gen.out" 2>"$work/gen.err"; then
  echo "dialect-build: the compiler does not compile under --std=afterschool," \
       "which is a containment defect (ADR-0117)" >&2
  head -20 "$work/gen.out" "$work/gen.err" >&2
  exit 1
fi
if ! clang -O2 -Wno-override-module "$work/ap.ll" "$runtime" -lm \
     -o "$work/pascalc-ap" 2>"$work/link.err"; then
  echo "dialect-build: the dialect compiler did not link" >&2
  head -20 "$work/link.err" >&2
  exit 1
fi

# --- claim 1: a fixed point --------------------------------------------------
if ! "$work/pascalc-ap" --std=afterschool "$root/selfhost/compiler.pas" \
     -o "$work/ap2.ll" >"$work/s3.out" 2>"$work/s3.err"; then
  echo "dialect-build: the dialect compiler could not compile its own source" >&2
  head -20 "$work/s3.out" "$work/s3.err" >&2
  exit 1
fi
if ! cmp -s "$work/ap.ll" "$work/ap2.ll"; then
  echo "dialect-build: stage 2 and stage 3 differ under --std=afterschool," \
       "so the dialect build is not a fixed point. ADR-0190's objection was" \
       "that a fixed point holds only for an Extended Pascal source; this is" \
       "the measurement of it" >&2
  diff <(head -60 "$work/ap.ll") <(head -60 "$work/ap2.ll") | head -20 >&2
  exit 1
fi

# --- claim 2: the same compiler ---------------------------------------------
# The standard each source is written in, derived from the path exactly as
# every other harness here derives it, plus the `.std` sidecar that speaks for
# a source outside tests/extended/ (ADR-0082, ADR-0166).
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

compiled=0
refused=0
differing=0
while IFS= read -r src; do
  std=$(standard_of "$src")
  "$cc" "--std=$std" "$src" -o "$work/p.ll" >"$work/p.out" 2>&1
  rc1=$?
  "$work/pascalc-ap" "--std=$std" "$src" -o "$work/q.ll" >"$work/q.out" 2>&1
  rc2=$?
  if (( rc1 != 0 || rc2 != 0 )); then
    # A refusal is half the corpus and the more interesting half: the error
    # paths are where the two builds could most easily part company.
    if (( rc1 == rc2 )) && cmp -s "$work/p.out" "$work/q.out"; then
      refused=$((refused + 1))
    else
      echo "--- $src: the two builds disagree about refusing it ---" >&2
      echo "shipped exit $rc1, dialect exit $rc2" >&2
      diff "$work/p.out" "$work/q.out" | head -6 >&2
      differing=$((differing + 1))
    fi
  elif cmp -s "$work/p.ll" "$work/q.ll"; then
    compiled=$((compiled + 1))
  else
    echo "--- $src: the two builds emit different IR ---" >&2
    diff "$work/p.ll" "$work/q.ll" | head -6 >&2
    differing=$((differing + 1))
  fi
done < <(find "$root/tests" "$root/selfhost" "$root/lib" -name '*.pas' | sort)

total=$((compiled + refused))
if (( total < 500 )); then
  echo "dialect-build: only $total sources were compared, and the corpus is" \
       "larger than that -- a run that reaches nothing passes for the same" \
       "reason a clean one does" >&2
  exit 1
fi
if (( differing > 0 )); then
  echo "dialect-build: $differing of $total sources are compiled or refused" \
       "differently by the dialect build" >&2
  exit 1
fi

echo "dialect-build: the dialect build is a fixed point, and agrees with the" \
     "shipped compiler on all $total sources -- $compiled compiled to" \
     "identical IR, $refused refused with identical diagnostics"
