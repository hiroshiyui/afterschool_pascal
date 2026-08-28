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

# --- pass 0: which headers are not ISO C's? --------------------------------
#
# __STRICT_ANSI__ hides what a POSIX *extension* adds to an ISO C header, and
# that is all it hides. A header ISO C does not have at all -- <unistd.h> --
# is not touched by it: glibc declares `access` there unconditionally, so a
# strict compile of the file as written says nothing about it. The first
# version of this script had exactly that hole, and `access` went through it.
# So the strict compile is of a *copy* with every non-ISO include removed,
# which is what an ISO C library would present, and each name such a header
# declared becomes "undeclared" and is harvested with the rest. The list is
# C11's twenty-nine headers, Annex B.
iso_headers='assert complex ctype errno fenv float inttypes iso646 limits locale math setjmp signal stdalign stdarg stdatomic stdbool stddef stdint stdio stdlib stdnoreturn string tgmath threads time uchar wchar wctype'
stripped=$work/pasrt.c
cp "$src" "$stripped"
for h in $(grep -oE '^#include <[a-z0-9_/]+\.h>' "$src" | sed 's/.*<\(.*\)\.h>/\1/'); do
  case " $iso_headers " in
    *" $h "*) ;;
    *) sed -i "s|^#include <$h\.h>|/* <$h.h> is not ISO C: removed by runtime_isoc.sh */|" "$stripped" ;;
  esac
done

# --- pass 1: what does strict ISO C not declare? ---------------------------
"$cc" "${std[@]}" -c "$stripped" -o "$work/a.o" >"$work/p1.txt" 2>&1
p1=$?
found=$(grep -oE "call to undeclared function '[A-Za-z_][A-Za-z0-9_]*'" \
          "$work/p1.txt" | sed "s/.*'\(.*\)'/\1/" | sort -u)

# Nothing undeclared has two very different causes, and telling them apart is
# the whole of this branch. A *clean* compile means the C library declared
# everything -- macOS exposes POSIX regardless of __STRICT_ANSI__ -- and the
# question cannot be asked here. A compile that *failed* and still named
# nothing means it stopped before reaching the calls, which a bad #include does,
# and reporting that as "this C library declares POSIX" is a lie that exits 77.
#
# The first version of this script had exactly that bug: replacing <errno.h>
# with a header that does not exist made it print the skip message and pass.
if [[ -z $found ]]; then
  if [[ $p1 -eq 0 ]]; then
    echo "runtime-isoc: this C library declares POSIX even under" \
         "__STRICT_ANSI__, so the question cannot be asked here --" \
         "glibc is what it was measured on"
    exit 77
  fi
  echo "runtime-isoc: runtime/pasrt.c does not compile as strict ISO C, and" \
       "the failure is not a POSIX call:" >&2
  head -20 "$work/p1.txt" >&2
  exit 1
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
    # tests/ and tests/extended/ and not tests/dialect/: ADR-0121's `external`
    # lets a program name any C function it likes, so a declare there is the
    # *program's* business and not the compiler's. What is being asked is what
    # this compiler emits on its own account, and no source in these two
    # directories writes an `external` heading -- which used to be guaranteed
    # by the conformance modes and is now a property of the corpus, checked
    # here rather than assumed.
    for d in tests tests/extended; do
      for f in "$root/$d"/*.pas; do
        [[ -f $f ]] || continue
        grep -qw external "$f" && continue
        "$pascalc" "$f" -o "$work/e.ll" >/dev/null 2>&1
        [[ -s $work/e.ll ]] && grep -hoE '^declare [^@]*@[A-Za-z_][A-Za-z0-9_.]*' \
          "$work/e.ll" | sed 's/.*@//'
      done
    done | sort -u | grep -vE '^(pas_|llvm\.)' )
  found=$(printf '%s\n%s\n' "$found" "$emitted" | grep -v '^$' | sort -u)
else
  # No degraded mode. Half the harvest against a whole catalogue accuses it of
  # naming `_setjmp`, which the runtime indeed does not use -- the *generated
  # code* does -- so running on without the emitted half turns a missing build
  # into a false finding against the file that is right. Skips as
  # buffer-headroom does for the same reason.
  echo "runtime-isoc: no compiler at $pascalc -- half of this check reads what" \
       "the emitted module declares, and half a harvest against a whole" \
       "catalogue is a false accusation rather than a partial answer. Build" \
       "first, or set PASCALC."
  exit 77
fi

# The identifier half of the catalogue. `header:` lines belong to the POSIX
# unit's section (ADR-0186) and are read by pass 3, not here -- without this
# they arrive as identifiers pasrt.c does not use, and the both-directions
# check reports the new section as a stale entry.
listed=$(grep -vE '^\s*(#|$)' "$list" | grep -v '^header:' |
         tr -d ' \t' | sort -u)

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
     -c "$stripped" -o "$work/b.o" >"$work/p2.txt" 2>&1; then
  echo "runtime-isoc: with those names excused, runtime/pasrt.c is still not" \
       "strict ISO C:" >&2
  head -20 "$work/p2.txt" >&2
  exit 1
fi

# --- pass 3: and the POSIX unit is bounded by its headers -------------------
#
# ADR-0186 split the runtime because the catalogue above can only ever hold
# *functions*: it is proved complete by stripping includes and requiring what
# is left to compile, and an incomplete `struct stat` is an error no flag
# silences. runtime/pasrt_posix.c is therefore not held to ISO C at all. What
# is bounded for it is the set of non-ISO headers it may include -- the
# granularity a port actually cares about, and one that can be checked without
# conjuring a type.
#
# Both directions, like everything else here: a header appearing without an
# entry, and an entry naming a header the file no longer includes.
posix_src=$root/runtime/pasrt_posix.c
if [[ ! -f $posix_src ]]; then
  echo "runtime-isoc: no runtime/pasrt_posix.c -- ADR-0186 says the runtime" \
       "has two translation units, and this one is where anything needing a" \
       "POSIX type lives. If it went away, strike its section from" \
       "$list." >&2
  exit 1
fi

posix_used=$(grep -oE '^#include <[a-z0-9_/]+\.h>' "$posix_src" |
             sed 's/.*<\(.*\)>/\1/' | while read -r h; do
               base=${h%.h}
               case " $iso_headers " in *" $base "*) ;; *) echo "<$h>" ;; esac
             done | sort -u)
posix_named=$(grep -oE '^header: <[a-z0-9_/]+\.h>' "$list" |
              sed 's/^header: //' | sort -u)

extra=$(comm -23 <(echo "$posix_used") <(echo "$posix_named"))
gone=$(comm -13 <(echo "$posix_used") <(echo "$posix_named"))
if [[ -n $extra ]]; then
  echo "runtime-isoc: runtime/pasrt_posix.c includes a non-ISO header this" \
       "catalogue does not name:" >&2
  for h in $extra; do echo "          $h" >&2; done
  echo "        That file's headers *are* its porting surface (ADR-0186)." \
       "Add it to $list with the argument for why ISO C could not do it." >&2
  exit 1
fi
if [[ -n $gone ]]; then
  echo "runtime-isoc: the catalogue names a header runtime/pasrt_posix.c no" \
       "longer includes:" >&2
  for h in $gone; do echo "          $h" >&2; done
  echo "        Good news, and it still fails, for verify/'s KNOWN_GAP" \
       "reason. Strike the entry in the change that removed it." >&2
  exit 1
fi

# It still has to be *clean* C -- POSIX rather than ISO, which is what the
# feature macro selects, and nothing warned about at all.
if ! "$cc" -std=c11 -D_POSIX_C_SOURCE=200809L -pedantic-errors \
     -Wall -Wextra -Werror -I"$root/runtime" \
     -c "$posix_src" -o "$work/posix.o" >"$work/p3.txt" 2>&1; then
  echo "runtime-isoc: runtime/pasrt_posix.c is not clean POSIX C11:" >&2
  head -20 "$work/p3.txt" >&2
  exit 1
fi

# And nothing the *compiler* emits may call into it: everything there is
# `pasx_`, which is what makes the whole file optional for a port (ADR-0131).
bad=$(grep -oE '^[a-z].*\b(pas_[A-Za-z0-9_]*)\s*\(' "$posix_src" |
      grep -oE 'pas_[A-Za-z0-9_]*' | grep -v '^pasx_' | sort -u)
if [[ -n $bad ]]; then
  echo "runtime-isoc: runtime/pasrt_posix.c defines or calls a pas_ name:" >&2
  for n in $bad; do echo "          $n" >&2; done
  echo "        Everything in that file has to be pasx_, or a system" \
       "without these headers loses the language and not just a library" \
       "routine (ADR-0186)." >&2
  exit 1
fi

# --- pass 4: and the Unicode unit is held to more than pasrt.c is -----------
#
# runtime/pasrt_unicode.c is AP 6.4.15's tables and the arithmetic over them,
# and it needs *nothing* outside ISO C -- no allocation, no locale, no POSIX,
# not even the five names pass 2 excuses pasrt.c. So it is compiled with no
# catalogue at all, which is a stronger claim than either file above carries
# and one that is free to make while it stays true.
#
# It is checked here rather than left to the build because the build compiles
# it with the project's warnings and not with -pedantic-errors, and because a
# third translation unit invisible to this gate is exactly the gap ADR-0186
# closed for the second.
uni_src=$root/runtime/pasrt_unicode.c
if [[ ! -f $uni_src ]]; then
  echo "runtime-isoc: no runtime/pasrt_unicode.c -- if the text primitives" \
       "went away, strike this pass. If they moved, this pass follows them." >&2
  exit 1
fi

if ! "$cc" -std=c11 -pedantic-errors -Wall -Wextra -Werror \
     -I"$root/runtime" -c "$uni_src" -o "$work/uni.o" >"$work/p4.txt" 2>&1; then
  echo "runtime-isoc: runtime/pasrt_unicode.c is not strict ISO C11:" >&2
  head -20 "$work/p4.txt" >&2
  echo "        It is held to ISO C with no catalogued name at all" \
       "(ADR-0189). If it now needs one, that is a decision and not a" \
       "compile flag." >&2
  exit 1
fi

# The same both-directions question pass 2 asks of pasrt.c, asked of a file
# whose answer must be zero: any non-ISO include here would be a dependency the
# catalogue does not know about, and __STRICT_ANSI__ would hide it exactly as
# <unistd.h> hid `access` (ADR-0186).
uni_extra=$(grep -oE '^#include <[a-z0-9_/]+\.h>' "$uni_src" |
            sed 's/.*<\(.*\)>/\1/' | while read -r hh; do
              base=${hh%.h}
              case " $iso_headers " in *" $base "*) ;; *) echo "<$hh>" ;; esac
            done | sort -u)
if [[ -n $uni_extra ]]; then
  echo "runtime-isoc: runtime/pasrt_unicode.c includes a non-ISO header:" >&2
  for hh in $uni_extra; do echo "          $hh" >&2; done
  echo "        That file is the one part of the runtime a port gets for" \
       "free. Keep it that way, or say in ADR why not." >&2
  exit 1
fi

n=$(echo "$found" | wc -l)
h=$(echo "$posix_named" | wc -l)
echo "runtime-isoc: runtime/pasrt.c is strict ISO C11 apart from $n catalogued" \
     "names ($(echo $found | tr '\n' ' ')), runtime/pasrt_posix.c is bounded by" \
     "$h catalogued headers ($(echo $posix_named | tr '\n' ' ')),"\
     "runtime/pasrt_unicode.c needs no catalogue at all, and the" \
     "emitted module names nothing but its own"
