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

# Are the two opaque sizes big enough on every target a compiler is here for?
#
# `PAS_FILE_SIZE` and `PAS_JUMP_SIZE` are the sizes of two C structs, written
# down in runtime/pasrt.h and again as `fileSize` and `jumpSize` in
# selfhost/compiler.pas, which is what allocates the bytes. The two files cannot
# include one another, so selfhost/irtest.sh checks that the four numbers agree.
#
# **Agreeing is not the same as being right.** Both numbers were measurements of
# x86-64 presented as constants, and `struct pas_jump` embeds a `jmp_buf` --
# 200 bytes on x86-64, 312 on aarch64, 392 on 32-bit arm. So `PAS_JUMP_SIZE`
# was 256 and an aarch64 build stopped at the runtime's own _Static_assert
# before anything else could go wrong (ADR-0155).
#
# The check is to compile runtime/pasrt.c itself for each target rather than to
# re-measure the structs here: the asserts are in that file, so what is checked
# is the real definition and there is no copy of it to drift. That is
# ADR-0144's lesson -- a check holding both halves of its own comparison cannot
# fail.
#
# It reports **which targets it reached**, always. A cross compiler that is not
# installed is skipped, and a run that reached only the host says so in those
# words: an empty list is what a clean run and a run that asked nothing both
# produce, and this repository has been caught by that before.
set -u

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Every target this repository can plausibly be built for and a Debian or
# Ubuntu box can install a compiler for in one package. The host is in the list
# on purpose: it makes the run non-empty everywhere, and a list whose only
# member is the host is a fact worth printing rather than a silent pass.
targets="x86_64-linux-gnu aarch64-linux-gnu arm-linux-gnueabihf
         arm-linux-gnueabi i686-linux-gnu riscv64-linux-gnu
         powerpc64le-linux-gnu s390x-linux-gnu mips64el-linux-gnuabi64"

checked=0
crossed=0
failed=0
absent=""

for t in $targets; do
  cc="$t-gcc"
  command -v "$cc" >/dev/null 2>&1 || { absent="$absent $t"; continue; }
  checked=$((checked + 1))
  [[ $t == x86_64-linux-gnu ]] || crossed=$((crossed + 1))
  if "$cc" -c "$root/runtime/pasrt.c" -I"$root/runtime" -o "$work/$t.o" \
       2>"$work/$t.err"; then
    echo "target-sizes: $t ok"
  else
    failed=$((failed + 1))
    echo "target-sizes: $t FAILED" >&2
    # The two asserts are the point; anything else is a portability problem in
    # the runtime that this check has found and should also report.
    grep -m3 -E 'PAS_(FILE|JUMP)_SIZE|error' "$work/$t.err" >&2
  fi
done

if [[ -n $absent ]]; then
  echo "target-sizes: no compiler installed for:$absent"
fi

if (( failed > 0 )); then
  cat >&2 <<'MSG'

runtime/pasrt.c did not compile for a target above. If it is one of the two
_Static_asserts, the size is a measurement of some other machine: raise both
PAS_JUMP_SIZE (or PAS_FILE_SIZE) in runtime/pasrt.h and jumpSize (or fileSize)
in selfhost/compiler.pas, which selfhost/irtest.sh requires to agree. The cost
of the jump record is paid only by a block that is the target of a non-local
goto. See ADR-0155 and doc/roadmap.md's cross-platform chapter.
MSG
  exit 1
fi

if (( crossed == 0 )); then
  echo "target-sizes: only the host was checked -- install a cross compiler" \
       "(apt install gcc-aarch64-linux-gnu) to ask the question this exists for"
  exit 77
fi

echo "target-sizes: PAS_FILE_SIZE and PAS_JUMP_SIZE are large enough on all" \
     "$checked targets a compiler is installed for, $crossed of them not the host"
