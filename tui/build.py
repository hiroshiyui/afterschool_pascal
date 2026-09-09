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

"""Build a program of the editor's.

  build.py <path-to-pascalcc> <program.pas> <output-binary>

`lsp/build.py` with one difference, and it is the reason this is a copy
rather than a shared script: `tui/` holds **two** programs over one model --
`session.pas`, which replays a script and prints what it drew, and
`apide.pas`, which puts the same model on a terminal. So the program to build
is an argument, and its `.components` sidecar is found beside it.

The sidecar convention is `tests/run_test.py`'s and `selfhost/irtest.py`'s:
one path per line, relative to this directory, in dependency order, so the
build order is written down once.

Not a CMake target, for `lsp/build.py`'s reason: an editor is a binary a
*person* runs, not one buried in a build tree.
"""

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.stdout.reconfigure(line_buffering=True)

HERE = Path(__file__).resolve().parent


def run(argv):
    """Run a compilation, and stop where `set -e` did.

    A command that cannot be started is 127 and a message, as a shell reports
    it: this is handed a `pascalcc` by its caller and a wrong one must say so
    rather than raise."""
    try:
        r = subprocess.run(argv)
    except OSError as e:
        print('build.py: %s: %s' % (argv[0], e.strerror), file=sys.stderr)
        sys.exit(127)
    if r.returncode != 0:
        sys.exit(r.returncode)


def main(argv):
    if len(argv) < 3:
        print('usage: build.py <pascalcc> <program.pas> <output-binary>',
              file=sys.stderr)
        return 2
    pascalcc, prog, out = argv[0], Path(argv[1]), argv[2]
    if not prog.is_absolute():
        prog = HERE / prog

    work = Path(tempfile.mkdtemp())
    try:
        build(pascalcc, prog, out, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    return 0


def build(pascalcc, prog, out, work):
    # The optimisation level, so that the corpus-wide -O0 sweep (doc/sop.md
    # 6's A3) reaches this program too. It matters here for the reason
    # ADR-0102 gives: an alloca claimed inside a loop is invisible at -O2,
    # LLVM being free to hoist one whose address does not escape, and a
    # server's whole shape is a loop.
    optflag = []
    if os.environ.get('AFTERSCHOOL_PASCAL_OPT'):
        optflag = [os.environ['AFTERSCHOOL_PASCAL_OPT']]

    imports = []
    objects = []
    n = 0
    for rel in prog.with_suffix('.components').read_text().split('\n'):
        if not rel:
            continue
        n += 1
        obj = str(work / ('c%d.o' % n))
        # Translated with the components listed *before* it, since 6.13 lets
        # one component import another and the list is in dependency order;
        # its own --import is added after, so a component is never handed its
        # own interface.
        run([pascalcc] + optflag + imports + ['-c', str(HERE / rel),
                                              '-o', obj])
        imports += ['--import', str(HERE / rel)]
        objects.append(obj)

    # Statement coverage of *this* program and of nothing it was linked
    # with, which is `lsp/build.py`'s arrangement and ADR-0350's attribution
    # problem: `$PASCOV_LINES` records a bare line number and no file, so a
    # statement reached at apedit.pas:200 would otherwise be counted as
    # session.pas:200. The instrumented IR is written out too, because the
    # *denominator* is the `pas_cov_hit` sites of the very module the
    # numerator came from (ADR-0104).
    covflag = []
    if os.environ.get('APIDE_COVERAGE_IR'):
        covflag = ['--coverage']
        run([pascalcc] + optflag + ['-S', '--coverage', str(prog)]
            + imports + ['-o', os.environ['APIDE_COVERAGE_IR']])

    run([pascalcc] + optflag + covflag + [str(prog)]
        + imports + objects + ['-o', out])


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
