#!/usr/bin/env bash
#
# A second backend configuration, and the one question it can answer that
# nothing else here can: **is the compiler binary itself miscompiled?**
#
# `selfhost/irtest.sh` compiles the compiler with itself twice and requires
# stage 2 to equal stage 3. That is the bootstrap's own check and it is a strong
# one, but both stages are produced by *the same binary* -- so a code generator
# in `clang` that got one corner of `selfhost/compiler.pas` wrong would produce a
# wrong compiler that reproduced itself exactly, and the fixed point would hold.
# Every golden would agree too, because every golden was written by that binary.
# The suite builds `pascalc` exactly one way.
#
# So this builds it a second way -- a different backend, driven directly, at a
# different optimisation level -- and requires the two binaries to *compute the
# same thing*: byte-identical IR for the same source. Two machine-code programs
# that disagree about what `compiler.pas` means is a miscompilation, and it is
# the only shape of defect this catches that another oracle would not.
#
# **What it is not.** `llc` is not a stronger validity check on the IR than
# `clang` is: they share LLVM's parser and verifier, and reject the same module
# with the same message. Nor does it add relocation-model coverage -- the object
# path of `tools/pascalcc` already passes `-fPIC` and the executable path links
# PIE, so the whole corpus is built as position-independent code today. Don't
# add this to the list of oracles in doc/sop.md as "a second reader of the IR";
# it is one reader configured two ways.
#
# It skips when `llc` is absent, as verify-lowering does without z3 and
# bsi-validation-suite does without the suite: `llc` comes from LLVM, and
# ADR-0085's claim is that the *build* needs nothing of LLVM's. Making this a
# hard requirement would falsify that claim rather than test it.
#
# Usage:  tests/checks/llc_check.sh <build-dir>
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
build=${1:-$root/build}
pascalc=$build/bin/pascalc
runtime=$build/lib/libpasrt.a

if ! command -v llc >/dev/null 2>&1; then
  echo "llc-second-backend: llc is not installed -- skipping"
  echo "  (Debian/Ubuntu: apt-get install llvm)"
  exit 77
fi

for f in "$pascalc" "$runtime"; do
  [[ -e $f ]] || { echo "llc-second-backend: $f is missing -- build first" >&2
                   exit 1; }
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Which LLVM proved it. Worth printing: this check compares two backend
# configurations of one LLVM, so the version is the whole of what it was.
echo "llc-second-backend: $(llc --version | grep -i version | head -1 |
                            sed 's/^ *//')"

# `llc` defaults to a non-PIC relocation model while the system linker defaults
# to PIE, and the mismatch fails at link time with a message about
# `R_X86_64_32 against .bss` that reads like a code generator defect. It is an
# argument to llc. `clang` compiling the .ll chooses the model itself, which is
# why nothing else here has ever met this.
llc_flags=(-relocation-model=pic)

# ---- 1. llc accepts every module this compiler emits ----------------------
#
# Cheap, and it is the half that would notice IR only clang's *driver* tolerates.
accepted=0
for src in "$root"/tests/*.pas "$root"/tests/extended/*.pas; do
  base=${src%.pas}
  # An error-path case has no module to assemble; it is expected not to compile.
  [[ -e $base.err ]] && continue
  std=iso7185
  [[ $src == */tests/extended/* ]] && std=extended
  [[ -e $base.std ]] && std=$(tr -d '[:space:]' <"$base.std")
  "$pascalc" "--std=$std" "$src" -o "$work/t.ll" >/dev/null 2>&1 || continue
  if ! llc "${llc_flags[@]}" "$work/t.ll" -o "$work/t.s" 2>"$work/err"; then
    echo "llc-second-backend: llc rejected the module for $src" >&2
    sed -n 1,10p "$work/err" >&2
    exit 1
  fi
  accepted=$((accepted + 1))
done

# The committed seed is a module too, and the largest one here.
if ! llc "${llc_flags[@]}" "$root/seed/pascalc.ll" -o "$work/seed.s" \
        2>"$work/err"; then
  echo "llc-second-backend: llc rejected seed/pascalc.ll" >&2
  sed -n 1,10p "$work/err" >&2
  exit 1
fi
accepted=$((accepted + 1))

# ---- 2. a compiler built a second way computes the same thing --------------
std=$(tr -d '[:space:]' <"$root/selfhost/compiler.std")
"$pascalc" "--std=$std" "$root/selfhost/compiler.pas" -o "$work/ref.ll"

# Two backend configurations, both unlike the build's. -O0 is the one that
# matters: it shares almost no code with the -O2 pipeline the build used, so an
# optimiser that miscompiled the compiler cannot hide in both.
for level in -O0 -O2; do
  llc "$level" "${llc_flags[@]}" "$work/ref.ll" -o "$work/cc$level.s"
  clang "$level" "$work/cc$level.s" "$runtime" -lm -o "$work/pascalc$level"
  "$work/pascalc$level" "--std=$std" "$root/selfhost/compiler.pas" \
      -o "$work/out$level.ll"
  if ! cmp -s "$work/ref.ll" "$work/out$level.ll"; then
    echo "llc-second-backend: a compiler built with llc $level translates" >&2
    echo "  selfhost/compiler.pas differently from the one this build ships." >&2
    echo "  Two machine-code programs disagree about what the source means," >&2
    echo "  so one of them is miscompiled." >&2
    diff -u "$work/ref.ll" "$work/out$level.ll" | sed -n 1,40p >&2
    exit 1
  fi
done

echo "llc-second-backend: llc assembled $accepted modules, and compilers built" \
     "from its -O0 and -O2 output translate compiler.pas identically to this" \
     "build's"
