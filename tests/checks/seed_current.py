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

"""Is the committed seed the one this source produces?

The seed is refreshed at release tags and nowhere else (ADR-0085), so this
is a question only a release can ask: between tags the seed is *meant* to be
the previous release's, and asking on every commit would fail by design. It
is therefore **not a ctest case** -- it is run by hand at a release, and by
the `seed-is-current` job at the tag, which is the last moment anything can
still refuse.

At a release commit the compiler built *from* the seed must emit, for the
current source, exactly the seed it was built from. That is the fixed point.
Nothing else notices when it breaks: a stale seed still builds a working
compiler, from the previous release's source, and every oracle here agrees
with it.

One module per program-component since ADR-0233, translated in the order
`selfhost/compiler.components` gives, each importing the ones before it. The
**set** is compared as well as each module: a component removed from the tree
leaves its seed module behind and CMake's glob goes on linking it, so an
extra file here is as much a stale seed as a differing one.

**Why this is a script and not a `run:` block.** It was fourteen lines of
shell inside `.github/workflows/ci.yml`, and a `run:` block in a container is
`sh -e {0}` -- the arrays it was written with are a bash syntax error, so the
job died before translating anything, at a tag, which is the only place it
runs. That is the second time logic living in a workflow's shell has failed
for want of anywhere to run it: `model-drift`'s base resolution was the
first, and doc/sop.md records the same answer being reached then. Here the
text CI runs and the text a release runs by hand are now one text.

Converted from shell under ADR-0366, together with `seed/refresh.py`: the two
translate the same way and a difference between them is a seed that
reproduces nowhere, so converting one alone would have put that claim across
two languages.

usage: seed_current.py [compiler]      default build/bin/pascalc
"""

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent

# The compiler these start inherits both streams, so this script's own lines
# must reach the file in the order they were written: Python block-buffers
# stdout when it is not a terminal, and the shell version's `echo` did not.
sys.stdout.reconfigure(line_buffering=True)
sys.path.insert(0, str(ROOT / 'seed'))
from refresh import components, translate, unified  # noqa: E402


def main(argv):
    pascalc = Path(argv[0]) if argv else ROOT / 'build' / 'bin' / 'pascalc'
    if not os.access(pascalc, os.X_OK):
        print('seed-current: %s is missing; build first' % pascalc,
              file=sys.stderr)
        return 1

    work = Path(tempfile.mkdtemp(prefix='seed-current.',
                                 dir=os.environ.get('TMPDIR', '/tmp')))
    try:
        return check(pascalc, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def check(pascalc, work):
    # compiler.pas is the program and is not in the sidecar -- the sidecar
    # lists the components it imports, which is what every other reader of it
    # needs.
    expected = components(ROOT)
    status = 0

    # From `$root` with a **relative** source path, exactly as seed/refresh.py
    # translates: ADR-0293 puts the source's own path into the emitted module
    # as `@at.file`, so an absolute one would make this check answer about the
    # directory rather than about the source. It did, and this job is the only
    # place it runs, so the tag was where that was found (ADR-0347).
    for component, out, rc in translate(
            ROOT, str(pascalc), expected,
            lambda c: work / (c[:-len('.pas')] + '.ll')):
        if rc != 0:
            print('seed-current: %s did not translate' % component,
                  file=sys.stderr)
            return 1

        base = component[:-len('.pas')]
        committed = ROOT / 'seed' / (base + '.ll')
        # A module that is not there at all is a mismatch and not a crash, and
        # the set check below still has its own half to say. The shell version
        # reached this by letting `diff` fail, which printed the C library's
        # message in the operator's locale -- one of the two reasons ADR-0366
        # exists.
        if not committed.exists():
            print('seed/%s.ll is not what this source produces.' % base,
                  file=sys.stderr)
            print('Run seed/refresh.py and amend the release commit.',
                  file=sys.stderr)
            print('seed/%s.ll is not there at all.' % base, file=sys.stderr)
            status = 1
        elif out.read_bytes() != committed.read_bytes():
            print('seed/%s.ll is not what this source produces.' % base,
                  file=sys.stderr)
            print('Run seed/refresh.py and amend the release commit.',
                  file=sys.stderr)
            sys.stderr.writelines(unified(committed, out)[:40])
            status = 1

    have = sorted(p.name for p in (ROOT / 'seed').glob('*.ll'))
    want = sorted(c[:-len('.pas')] + '.ll' for c in expected)
    if have != want:
        print('seed/ holds modules this source does not produce.',
              file=sys.stderr)
        print('this source produces:', file=sys.stderr)
        for n in want:
            print('  ' + n, file=sys.stderr)
        print('seed/ holds:', file=sys.stderr)
        for n in have:
            print('  ' + n, file=sys.stderr)
        status = 1

    if status == 0:
        print('the seed matches, %d modules.' % len(expected))
    return status


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
