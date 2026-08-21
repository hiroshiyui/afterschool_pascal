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

# How far is runtime/pasrt.c from ISO C, exactly?
#
# It is the only C in this project and the whole of what a port to another
# platform has to satisfy, and doc/roadmap.md's cross-platform chapter used to
# answer this by assertion -- "`bind` and the file model are POSIX assumptions
# in the runtime". Measured, they are not: the file model is `fopen`, `fseek`
# and `tmpfile`, all ISO C, and the runtime's entire departure from the
# standard is **three names**, each for a reason ISO C gives no way around.
#
# This turns that measurement into a claim that is checked. Two passes:
#
#   1. compile as strict C11. A C library that honours __STRICT_ANSI__ then
#      hides everything POSIX-only, so each such use becomes "call to
#      undeclared function". Those names are compared against
#      tests/checks/nonstandard_c.txt in **both** directions -- a fourth
#      dependency appearing is what this exists to catch, and a listed name
#      that stops appearing means the catalogue is describing a runtime that no
#      longer exists, which is verify/'s KNOWN_GAP rule.
#
#   2. compile again with only those two diagnostics silenced, and require a
#      clean build. That is what says the three names are the whole of it
#      rather than the first three of a longer list.
#
# There is a third pass, over the other half of the boundary. The *emitted*
# code names symbols too, and doc/roadmap.md claims "the only symbol the
# emitted code names outside runtime/pasrt.c and LLVM's intrinsics is
# `_setjmp`". That is the same kind of claim and gets the same treatment: every
# .pas in the corpus is compiled and every `declare`d name that is neither
# `pas_*` nor `llvm.*` has to be in the catalogue. It is where `_setjmp` comes
# from -- the runtime never calls it, the generated code does, because the
# frame setjmp saves has to be the one longjmp returns into.
#
# **It skips (77) where the C library does not hide POSIX.** macOS exposes
# POSIX declarations regardless of __STRICT_ANSI__, and there the first pass
# reports nothing -- which is indistinguishable from a runtime that grew clean.
# A check that cannot ask its question says so rather than passing.
set -u

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cc=${APASCAL_CLANG:-clang}
src=$root/runtime/pasrt.c
list=$here/nonstandard_c.txt

std=(-std=c11 -pedantic-errors -I"$root/runtime")

# --- pass 1: what does strict ISO C not declare? ---------------------------
"$cc" "${std[@]}" -c "$src" -o "$work/a.o" >"$work/p1.txt" 2>&1
found=$(grep -oE "call to undeclared function '[A-Za-z_][A-Za-z0-9_]*'" \
          "$work/p1.txt" | sed "s/.*'\(.*\)'/\1/" | sort -u)

if [[ -z $found ]]; then
  echo "runtime-isoc: this C library declares POSIX even under __STRICT_ANSI__," \
       "so the question cannot be asked here -- glibc is what it was measured on"
  exit 77
fi

# --- pass 3: and what does the *generated* code name? ----------------------
#
# The runtime is one half of the boundary; the emitted module is the other, and
# it declares what it calls. Everything this compiler emits is either its own
# `pas_` runtime or an LLVM intrinsic -- except `_setjmp`, which the generated
# code has to call itself.
pascalc=${PASCALC:-$root/build/bin/pascalc}
if [[ -x $pascalc ]]; then
  emitted=$(
    # The two conformance corpora and not tests/dialect/: ADR-0121's `external`
    # lets a dialect program name any C function it likes, so a declare there
    # is the *program's* business and not the compiler's. What is being asked
    # is what this compiler emits on its own account, and under --std=iso7185
    # and --std=extended a program has no way to add to that.
    for d in tests tests/extended; do
      case $d in
        tests) s=iso7185 ;;
        *) s=extended ;;
      esac
      for f in "$root/$d"/*.pas; do
        [[ -f $f ]] || continue
        "$pascalc" "--std=$s" "$f" -o "$work/e.ll" >/dev/null 2>&1
        [[ -s $work/e.ll ]] && grep -hoE '^declare [^@]*@[A-Za-z_][A-Za-z0-9_.]*' \
          "$work/e.ll" | sed 's/.*@//'
      done
    done | sort -u | grep -vE '^(pas_|llvm\.)' )
  found=$(printf '%s\n%s\n' "$found" "$emitted" | grep -v '^$' | sort -u)
else
  echo "runtime-isoc: no compiler at $pascalc, so only runtime/pasrt.c was" \
       "asked -- the emitted module's own symbols were not" >&2
fi

listed=$(grep -vE '^\s*(#|$)' "$list" | tr -d ' \t' | sort -u)

missing=$(comm -23 <(echo "$listed") <(echo "$found"))
extra=$(comm -13 <(echo "$listed") <(echo "$found"))

status=0
if [[ -n $extra ]]; then
  echo "runtime-isoc: runtime/pasrt.c uses an identifier ISO C does not" \
       "declare and this catalogue does not name:" >&2
  for n in $extra; do echo "          $n" >&2; done
  echo "        Every one of these is something a port to another C library" >&2
  echo "        has to supply. Add it to tests/checks/nonstandard_c.txt with" >&2
  echo "        the argument for why ISO C could not do it, or use ISO C." >&2
  status=1
fi
if [[ -n $missing ]]; then
  echo "runtime-isoc: the catalogue names an identifier runtime/pasrt.c no" \
       "longer uses:" >&2
  for n in $missing; do echo "          $n" >&2; done
  echo "        Good news, and it still fails: a catalogue describing a" >&2
  echo "        runtime that no longer exists is what verify/'s KNOWN_GAP" >&2
  echo "        rule is about. Strike the entry in the change that removed" >&2
  echo "        the dependency." >&2
  status=1
fi
[[ $status -eq 0 ]] || exit 1

# --- pass 2: and nothing else is non-standard ------------------------------
if ! "$cc" "${std[@]}" -Wall -Wextra \
     -Wno-implicit-function-declaration -Wno-int-conversion \
     -c "$src" -o "$work/b.o" >"$work/p2.txt" 2>&1; then
  echo "runtime-isoc: with those names excused, runtime/pasrt.c is still not" \
       "strict ISO C:" >&2
  head -20 "$work/p2.txt" >&2
  exit 1
fi

n=$(echo "$found" | wc -l)
echo "runtime-isoc: the runtime is strict ISO C11 and the emitted module names" \
     "nothing but its own, apart from $n catalogued: $(echo $found | tr '\n' ' ')"
