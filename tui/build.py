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

  build.py [<path-to-pascalcc> [<program.pas> [<output-binary>]]]

**Every argument has an obvious answer, so every argument is optional**: with
none, this builds the editor with the driver in this tree and puts it in
`build/bin/apide`, beside the `pascalc` that `pascalcc` already finds, and
says where it went. That is the whole of what a person has to know to run it,
and it used to be four things -- a driver path, a program, an output path
they had to invent, and then remembering the one they invented.

They stay positional and in the order they were, so a caller that passes all
three is unaffected: `tui/run.py` is the one in the tree, and it names both
programs explicitly because it builds both.

`lsp/build.py` with one difference, and it is the reason this is a copy
rather than a shared script: `tui/` holds **two** programs over one model --
`session.pas`, which replays a script and prints what it drew, and
`apide.pas`, which puts the same model on a terminal. So the program to build
is an argument, and its `.components` sidecar is found beside it.

The sidecar convention is `tests/run_test.py`'s and `selfhost/irtest.py`'s:
one path per line, relative to this directory, in dependency order, so the
build order is written down once.

Not a CMake target, for `lsp/build.py`'s reason: an editor is a binary a
*person* runs, not one buried in a build tree. The default output is inside
one all the same, and that is not a contradiction -- what the reason objects
to is a binary a person cannot *name*, and this one is named, printed, and
sits where `pascalc` does. A person who wants it elsewhere says so, which is
the third argument.
"""

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.stdout.reconfigure(line_buffering=True)

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent

# What each argument answers to when it is not given. The driver is this
# tree's, since a person building the editor from this directory has one; the
# program is the editor, `session.pas` being a thing only `run.py` builds; and
# the output sits beside the compiler, which is both where `pascalcc` looks
# for the runtime and a directory `.gitignore` already covers.
DEFAULT_CC = str(ROOT / 'tools' / 'pascalcc')
DEFAULT_PROG = 'apide.pas'
DEFAULT_OUT = ROOT / 'build' / 'bin'


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
    if len(argv) > 3:
        print('usage: build.py [<pascalcc> [<program.pas> [<output>]]]',
              file=sys.stderr)
        return 2
    # An empty argument means "the default for this one", which is what makes
    # the second and third reachable without restating the first: the driver
    # is the argument nobody wants to type and the program is the one a person
    # building `session.pas` has to.
    pascalcc = argv[0] if len(argv) > 0 and argv[0] else DEFAULT_CC
    prog = Path(argv[1] if len(argv) > 1 and argv[1] else DEFAULT_PROG)
    if not prog.is_absolute():
        prog = HERE / prog
    if len(argv) > 2:
        out = argv[2]
    else:
        # Named after the program, so `build.py '' session.pas` lands
        # somewhere that is not the editor rather than overwriting it.
        DEFAULT_OUT.mkdir(parents=True, exist_ok=True)
        out = str(DEFAULT_OUT / prog.stem)

    if not prog.exists():
        print('build.py: no such program: %s' % prog, file=sys.stderr)
        return 2

    work = Path(tempfile.mkdtemp())
    try:
        build(pascalcc, prog, out, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    # Where it went and how to start it. A person who has just built a
    # program should not have to work out either, and the second line is the
    # one this script exists to shorten.
    if len(argv) < 3:
        print('built %s' % out)
        # The two programs are started differently -- the editor takes an
        # optional file and the replayer reads a script -- so the hint asks
        # which was built rather than printing one of them at the other.
        if prog.stem == 'session':
            print('run it with:  %s < tui/sessions/<name>.keys' % out)
        else:
            print('run it with:  %s [file.pas]' % out)
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
