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

# Does the corpus still run when a pointer is four bytes? (ADR-0325)
#
# `target-layout` asks whether this compiler's arithmetic agrees with LLVM's,
# which is a question about *numbers*. This one asks the other half: whether a
# program built with those numbers behaves. They are not the same question, and
# the difference is what this gate was written for -- both defects the i386 port
# found are invisible to every arithmetic check here.
#
#   - `pas_select` indexed its arm array with `sizeof(struct pas_select_arm)`
#     where the compiler strides `PAS_SELECT_ARM_SIZE`. Those are one number on
#     an LP64 target and two on i386, and the header above the struct claimed
#     the larger *is* what indexes it.
#   - and the compiler wrote the arm's fourth field at offset 16, which is
#     where an LP64 target puts it and four bytes past where i386 does.
#
# Neither is a layout rule and neither is in a frame, so `target-layout` passes
# with both in place. `tests/dialect/select.pas` segfaults.
#
# **The catalogue fails in both directions.** A case that starts failing is a
# regression; a case that stops failing is a defect somebody fixed without
# saying so, and the file is where the reason for each is written down. The
# residue today is one address-space limit and one decision that has not been
# taken -- see the file.
#
# Skips with 77 where no 32-bit toolchain is here: `clang --target=i386` needs
# a 32-bit libc to link against, which is a separate package on most
# distributions. `TARGET32_REQUIRE=1` refuses to pass by skipping, which is how
# CI asks for the real answer.
#
# **It has a second axis and honours it** (ADR-0334): `AFTERSCHOOL_PASCAL_OPT`
# reaches `run_test.sh` from the environment, and the answer is not the same at
# both levels. `tests/dialect/int64_foreign.pas` declared C's `labs` as taking
# an `int64` -- a wrong ABI on every ILP32 target -- and passed here for two
# weeks because at -O2 the optimiser folded the call away. The `thirty-two-bit`
# job now runs this gate twice, because the combination that showed it was run
# by no job at all: the `unoptimised` job has no 32-bit libc and skips.

set -u

root=$(cd "$(dirname "$0")/../.." && pwd)
pascalcc=${1:-$root/tools/pascalcc}
catalogue=$root/tests/checks/target32_known.txt
target=i386-pc-linux-gnu

require=${TARGET32_REQUIRE:-}

skip() {
  if [[ -n $require ]]; then
    echo "target32: $1 -- and TARGET32_REQUIRE is set" >&2
    exit 1
  fi
  echo "target32: skipped -- $1"
  exit 77
}

command -v clang >/dev/null 2>&1 || skip "no clang"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Can this machine link and run a 32-bit binary at all? Asked with C, before
# anything of this compiler's is built, so a missing libc is reported as what
# it is rather than as a Pascal failure.
printf 'int main(void){return 0;}\n' > "$work/probe.c"
clang --target=$target -o "$work/probe" "$work/probe.c" >/dev/null 2>&1 ||
  skip "clang cannot link for $target (a 32-bit libc is a separate package)"
"$work/probe" >/dev/null 2>&1 || skip "this machine cannot run an i386 binary"

# The runtime, built for the target. Not the one in the build tree: that one is
# the host's, and linking it would fail at the first object.
mkdir -p "$work/rt"
for c in "$root"/runtime/*.c; do
  if ! clang --target=$target -O2 -fPIC -c "$c" \
       -o "$work/rt/$(basename "${c%.c}").o" 2>"$work/cc.err"; then
    echo "target32: the runtime would not compile for $target:" >&2
    head -20 "$work/cc.err" >&2
    exit 1
  fi
done
ar rcs "$work/rt/libpasrt.a" "$work/rt"/*.o || exit 1

export AFTERSCHOOL_PASCAL_RUNTIME=$work/rt
export AFTERSCHOOL_PASCAL_TARGET=$target
export PASCALC=${PASCALC:-$root/build/bin/pascalc}

mapfile -t known < <(grep -v '^\s*#' "$catalogue" | grep -v '^\s*$' | awk '{print $1}')
is_known() { local n; for n in "${known[@]}"; do [[ $n == "$1" ]] && return 0; done; return 1; }

total=0; ran=0; unexpected=(); fixed=()
for root_dir in tests tests/extended tests/dialect examples; do
  for src in "$root/$root_dir"/*.pas; do
    [[ -e $src ]] || continue
    rel=${src#"$root"/}
    total=$((total + 1))
    if "$root/tests/run_test.sh" "$pascalcc" "$src" >/dev/null 2>&1; then
      ran=$((ran + 1))
      is_known "$rel" && fixed+=("$rel")
    else
      is_known "$rel" || unexpected+=("$rel")
    fi
  done
done

# A floor, so that a run reaching nothing cannot pass by comparing nothing --
# the empty comparison this repository has been caught by before.
if (( total < 400 )); then
  echo "target32: only $total sources swept, below the floor of 400" >&2
  exit 1
fi

status=0
if (( ${#unexpected[@]} )); then
  echo "target32: ${#unexpected[@]} case(s) fail for $target and are not in the catalogue:" >&2
  printf '  %s\n' "${unexpected[@]}" >&2
  status=1
fi
if (( ${#fixed[@]} )); then
  echo "target32: ${#fixed[@]} catalogued case(s) now pass -- say why and take the row out:" >&2
  printf '  %s\n' "${fixed[@]}" >&2
  status=1
fi
(( status )) && exit 1

echo "target32: $ran of $total sources build and run for $target; ${#known[@]} catalogued"
