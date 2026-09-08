#!/usr/bin/env python3
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

"""runtime/pasrt_unicode.c against the Unicode Character Database's own answers.

**This is the oracle nobody here wrote**, and it is the reason AP 6.4.15 can
rest on two properties no reader of this repository is qualified to check by
eye. NormalizationTest.txt is twenty thousand lines of input-and-answer and
GraphemeBreakTest.txt is seven hundred and sixty-six; both are published with
the database, by people with no interest in this compiler. ADR-0086 made the
same argument for the BSI suite, and this is it applied where a misreading
would otherwise be invisible -- every other check here compares this compiler
against a reading taken here.

It asks a second question the test files cannot: does regenerating the tables
from the database reproduce the committed header? That is seed/'s discipline
(ADR-0085). Without it the header and the pinned version could drift and the
conformance run would keep passing, because it exercises the header rather
than the database.

Skips (77) when the database is absent -- it is fetched, never committed
(runtime/unicode/fetch.py), as tests/bsi/ is. Set UNICODE_CONFORMANCE_REQUIRE
to refuse to pass by skipping, which is what CI does.

The `python3` this looks for is the interpreter that runs generate.py, and the
check stays even though this file is itself Python: CMake hands the gate an
absolute interpreter path, so a machine with no `python3` on PATH still
reaches here and must still say which half went unchecked.

Converted from shell under ADR-0366; the shell version's output is what this
was required to reproduce byte for byte, on this tree and on every arm.
"""

import difflib
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
UCD = ROOT / 'runtime' / 'unicode' / 'ucd'


def gnu_date(p):
    """`diff -u`'s header timestamp, so what this writes is still a unified
    diff a reader can hand to `patch`."""
    ns = p.stat().st_mtime_ns
    t = time.localtime(ns // 10**9)
    return '%s.%09d %s' % (time.strftime('%Y-%m-%d %H:%M:%S', t),
                           ns % 10**9, time.strftime('%z', t))


def main():
    cc = os.environ.get('CC', 'clang')
    require = os.environ.get('UNICODE_CONFORMANCE_REQUIRE', '')

    if not (UCD / 'NormalizationTest.txt').is_file() or \
       not (UCD / 'auxiliary' / 'GraphemeBreakTest.txt').is_file():
        if require:
            print('unicode-conformance: UNICODE_CONFORMANCE_REQUIRE is set '
                  'and the database is not in %s -- run '
                  'runtime/unicode/fetch.py' % UCD, file=sys.stderr)
            return 1
        print('unicode-conformance: skipped, no Unicode Character Database in '
              '%s (runtime/unicode/fetch.py)' % UCD)
        return 77

    if shutil.which(cc) is None:
        if require:
            print('unicode-conformance: UNICODE_CONFORMANCE_REQUIRE is set '
                  'and there is no C compiler', file=sys.stderr)
            return 1
        print('unicode-conformance: skipped, no C compiler')
        return 77

    work = Path(tempfile.mkdtemp())
    try:
        return check(cc, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def check(cc, work):
    # The driver is compiled here rather than by CMake because it is the
    # *runtime* it tests and not the compiler: pasrt_unicode.c is strict ISO
    # C11 that calls nothing outside it, so this is the whole of what it takes
    # to build, and compiling it under -pedantic-errors is a second reading of
    # that claim.
    driver = work / 'unicode_conf'
    r = subprocess.run([cc, '-std=c11', '-pedantic-errors', '-Wall', '-Wextra',
                        '-Werror', '-O2', '-I', str(ROOT / 'runtime'),
                        str(ROOT / 'tests' / 'checks' / 'unicode_conf.c'),
                        str(ROOT / 'runtime' / 'pasrt_unicode.c'),
                        '-o', str(driver)],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print('unicode-conformance: the driver did not build as strict ISO '
              'C11:', file=sys.stderr)
        sys.stderr.write(r.stderr)
        return 1

    # Its two streams are this gate's own, so it is run with them inherited
    # and the status is read afterwards. The shell version carried a comment
    # about `if ! cmd` making `$?` the negation's status; here the trap is
    # simply not available, and the arm below is the one it protected.
    sys.stdout.flush()
    status = subprocess.run([str(driver), str(UCD)]).returncode
    if status != 0:
        if status == 2:
            print('unicode-conformance: the database is incomplete -- re-run '
                  'runtime/unicode/fetch.py', file=sys.stderr)
        return 1

    # The other half: is the committed header what the database says?
    #
    # A run that only exercised the header would agree with whatever generated
    # it, which is the closed loop a golden always has. Regenerating and
    # diffing is what ties the committed artefact to the pinned version -- and
    # it fails in both directions, so a header edited by hand is as loud as a
    # version that moved.
    if shutil.which('python3') is None:
        print('unicode-conformance: no python3, so the committed header was '
              'not checked against the database')
        return 0

    committed = ROOT / 'runtime' / 'pasrt_unicode_data.h'
    fresh = work / 'fresh.h'
    r = subprocess.run(['python3', str(ROOT / 'runtime' / 'unicode' /
                                       'generate.py'), '-o', str(fresh)],
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stdout + r.stderr)
        print('unicode-conformance: runtime/unicode/generate.py failed',
              file=sys.stderr)
        return 1

    a = committed.read_text().splitlines(keepends=True)
    b = fresh.read_text().splitlines(keepends=True)
    if a != b:
        d = list(difflib.unified_diff(a, b, str(committed), str(fresh),
                                      gnu_date(committed), gnu_date(fresh)))
        sys.stderr.writelines(d[:40])
        print('unicode-conformance: runtime/pasrt_unicode_data.h is not what '
              'runtime/unicode/generate.py makes of the database in %s. '
              'Either the header was edited by hand, or the fetched version '
              'is not the pinned one -- runtime/unicode/fetch.py has the pin.'
              % UCD, file=sys.stderr)
        return 1

    print('unicode-conformance: and the committed tables are what the '
          'database says')
    return 0


if __name__ == '__main__':
    sys.exit(main())
