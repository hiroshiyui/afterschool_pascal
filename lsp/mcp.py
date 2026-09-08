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

"""Start the language server in MCP mode, for an agent working on *this*
checkout. `.mcp.json` names this script, and Claude Code starts it in the
project directory.

It exists because `build.py` is deliberately not a CMake target -- a server
wants a binary a user can point an editor at rather than one buried in a
build tree, and that decision is worth keeping. What an agent needs instead
is a *stable command*, so this is that command: it finds the compiler, builds
the server if the binary is missing or older than its sources, and execs it.

Everything it writes for a person goes to standard error, because standard
output is the protocol (ADR-0236). A failure here is a failure to start, and
the client shows the stderr.

Converted from shell under ADR-0366. The freshness test is the one thing that
had to be written rather than translated: `ls -t | head -1` answers with the
newest *name* and `-nt` then compares that name's mtime, so what the shell
computed is a maximum -- which is what this takes directly.
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent


def main():
    # The compiler this server invokes on a document. A build tree first,
    # since that is what a developer has; then whatever is on PATH, which is
    # what an installed copy gives (ADR-0244).
    pascalc = os.environ.get('PASCALC', '')
    if not pascalc:
        built = ROOT / 'build' / 'bin' / 'pascalc'
        if os.access(built, os.X_OK):
            pascalc = str(built)
        else:
            pascalc = shutil.which('pascalc') or ''
    if not pascalc:
        print('pasls: no pascalc found: build one (cmake --build build) or '
              'set PASCALC', file=sys.stderr)
        return 1

    runtime = os.environ.get('AFTERSCHOOL_PASCAL_RUNTIME', '')
    if not runtime and (ROOT / 'build' / 'lib').is_dir():
        runtime = str(ROOT / 'build' / 'lib')

    # The binary goes beside the build tree rather than into it: it is not a
    # build product (build.py says why), and a developer who removes `build/`
    # should not be left with a stale server the next `.mcp.json` start would
    # use.
    out = Path(os.environ.get('PASLS_BINARY',
                              str(ROOT / 'build' / 'bin' / 'pasls')))
    sources = [HERE / 'pasls.pas', HERE / 'pasls.components']
    sources += sorted((ROOT / 'lib' / 'dialect').glob('*.pas'))
    sources += sorted((ROOT / 'lib').glob('*.pas'))
    newest = max((p.stat().st_mtime_ns for p in sources if p.exists()),
                 default=None)
    stale = (not os.access(out, os.X_OK)
             or (newest is not None and newest > out.stat().st_mtime_ns))
    if stale:
        print('pasls: building the server...', file=sys.stderr)
        out.parent.mkdir(parents=True, exist_ok=True)
        env = dict(os.environ)
        env['PASCALC'] = pascalc
        env['AFTERSCHOOL_PASCAL_RUNTIME'] = runtime
        r = subprocess.run([str(HERE / 'build.py'),
                            str(ROOT / 'tools' / 'pascalcc'), str(out)],
                           env=env, stdout=sys.stderr.fileno())
        if r.returncode != 0:
            print('pasls: the server did not build', file=sys.stderr)
            return 1

    os.environ['PASLS_COMPILER'] = pascalc
    if runtime:
        os.environ['AFTERSCHOOL_PASCAL_RUNTIME'] = runtime
    os.execv(str(out), [str(out), '--mcp'])


if __name__ == '__main__':
    sys.exit(main())
