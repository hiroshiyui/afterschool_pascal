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

"""Build the language server.

  build.py <path-to-pascalcc> <output-binary>

`pasls.components` lists ISO/IEC 10206:1991 6.13's other program-components,
one path per line relative to this directory and in dependency order -- the
same sidecar convention `tests/run_test.sh` and `selfhost/irtest.sh` read,
and read here for the same reason: the build order is written down once.

This is not a CMake target. Nothing in this tree installs a library or a
second program, and a server needs a binary a *user* can point an editor at
rather than one buried in a build tree -- so it is a script, as
`tools/pascalcc` is. `lsp/run.py` calls it, and so can anyone.

Converted from shell under ADR-0366; the shell version's binary is what this
was required to reproduce, and the comparison is the emitted IR of every
component and of the server itself, byte for byte.
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
    if len(argv) < 2:
        print('usage: build.py <pascalcc> <output-binary>', file=sys.stderr)
        return 2
    pascalcc, out = argv[0], argv[1]

    work = Path(tempfile.mkdtemp())
    try:
        build(pascalcc, out, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    return 0


def build(pascalcc, out, work):
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
    for rel in (HERE / 'pasls.components').read_text().split('\n'):
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

    # Statement coverage of the server, and of nothing it was linked with
    # (tests/checks/lsp_coverage.py). `--coverage` goes on *this* translation
    # and on no component's, which is ADR-0350's attribution problem met one
    # directory over: $PASCOV_LINES records a bare line number and no file, so
    # a statement reached at pasjson.pas:900 would otherwise be counted as
    # pasls.pas:900. The instrumented IR is written out as well, because the
    # *denominator* is the `pas_cov_hit` sites of the very module the
    # numerator came from -- nothing here may keep a second idea of what was
    # executable (ADR-0104).
    #
    # An env var and not a flag, for AFTERSCHOOL_PASCAL_OPT's reason above:
    # what builds the server is `lsp/run.py`, which passes this script its two
    # arguments and has no third to spare.
    covflag = []
    if os.environ.get('PASLS_COVERAGE_IR'):
        covflag = ['--coverage']
        run([pascalcc] + optflag + ['-S', '--coverage', str(HERE / 'pasls.pas')]
            + imports + ['-o', os.environ['PASLS_COVERAGE_IR']])

    run([pascalcc] + optflag + covflag + [str(HERE / 'pasls.pas')]
        + imports + objects + ['-o', out])


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
