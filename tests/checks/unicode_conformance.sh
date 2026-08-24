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

# runtime/pasrt_unicode.c against the Unicode Character Database's own answers.
#
# **This is the oracle nobody here wrote**, and it is the reason AP 6.4.15 can
# rest on two properties no reader of this repository is qualified to check by
# eye. NormalizationTest.txt is twenty thousand lines of input-and-answer and
# GraphemeBreakTest.txt is seven hundred and sixty-six; both are published with
# the database, by people with no interest in this compiler. ADR-0086 made the
# same argument for the BSI suite, and this is it applied where a misreading
# would otherwise be invisible -- every other check here compares this compiler
# against a reading taken here.
#
# It asks a second question the test files cannot: does regenerating the tables
# from the database reproduce the committed header? That is seed/'s discipline
# (ADR-0085). Without it the header and the pinned version could drift and the
# conformance run would keep passing, because it exercises the header rather
# than the database.
#
# Skips (77) when the database is absent -- it is fetched, never committed
# (runtime/unicode/fetch.sh), as tests/bsi/ is. Set UNICODE_CONFORMANCE_REQUIRE
# to refuse to pass by skipping, which is what CI does.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ucd=$root/runtime/unicode/ucd
cc=${CC:-clang}

require=${UNICODE_CONFORMANCE_REQUIRE:-}

if [ ! -f "$ucd/NormalizationTest.txt" ] ||
   [ ! -f "$ucd/auxiliary/GraphemeBreakTest.txt" ]; then
  if [ -n "$require" ]; then
    echo "unicode-conformance: UNICODE_CONFORMANCE_REQUIRE is set and the" \
         "database is not in $ucd -- run runtime/unicode/fetch.sh" >&2
    exit 1
  fi
  echo "unicode-conformance: skipped, no Unicode Character Database in $ucd" \
       "(runtime/unicode/fetch.sh)"
  exit 77
fi

if ! command -v "$cc" >/dev/null 2>&1; then
  if [ -n "$require" ]; then
    echo "unicode-conformance: UNICODE_CONFORMANCE_REQUIRE is set and there" \
         "is no C compiler" >&2
    exit 1
  fi
  echo "unicode-conformance: skipped, no C compiler"
  exit 77
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The driver is compiled here rather than by CMake because it is the *runtime*
# it tests and not the compiler: pasrt_unicode.c is strict ISO C11 that calls
# nothing outside it, so this is the whole of what it takes to build, and
# compiling it under -pedantic-errors is a second reading of that claim.
if ! "$cc" -std=c11 -pedantic-errors -Wall -Wextra -Werror -O2 \
     -I"$root/runtime" \
     "$root/tests/checks/unicode_conf.c" "$root/runtime/pasrt_unicode.c" \
     -o "$work/unicode_conf" 2>"$work/cc.err"; then
  echo "unicode-conformance: the driver did not build as strict ISO C11:" >&2
  cat "$work/cc.err" >&2
  exit 1
fi

# Run it plainly and read the status afterwards. Inside `if ! cmd; then`, `$?`
# is the negation's status and always 0, so the "incomplete database" arm would
# never be taken.
"$work/unicode_conf" "$ucd"
status=$?
if [ "$status" -ne 0 ]; then
  if [ "$status" -eq 2 ]; then
    echo "unicode-conformance: the database is incomplete -- re-run" \
         "runtime/unicode/fetch.sh" >&2
  fi
  exit 1
fi

# The other half: is the committed header what the database says?
#
# A run that only exercised the header would agree with whatever generated it,
# which is the closed loop a golden always has. Regenerating and diffing is what
# ties the committed artefact to the pinned version -- and it fails in both
# directions, so a header edited by hand is as loud as a version that moved.
if ! command -v python3 >/dev/null 2>&1; then
  echo "unicode-conformance: no python3, so the committed header was not" \
       "checked against the database"
  exit 0
fi

committed=$root/runtime/pasrt_unicode_data.h
if ! python3 "$root/runtime/unicode/generate.py" -o "$work/fresh.h" \
     >"$work/gen.out" 2>&1; then
  cat "$work/gen.out" >&2
  echo "unicode-conformance: runtime/unicode/generate.py failed" >&2
  exit 1
fi

if ! diff -u "$committed" "$work/fresh.h" >"$work/diff" 2>&1; then
  head -40 "$work/diff" >&2
  echo "unicode-conformance: runtime/pasrt_unicode_data.h is not what" \
       "runtime/unicode/generate.py makes of the database in $ucd. Either the" \
       "header was edited by hand, or the fetched version is not the pinned" \
       "one -- runtime/unicode/fetch.sh has the pin." >&2
  exit 1
fi

echo "unicode-conformance: and the committed tables are what the database says"
