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

"""Replay every editor session and compare the screens it drew.

  run.py <path-to-pascalcc> [path-to-pascalc]

**A screen program is testable here because the terminal is not in the loop**
(ADR-0381). `tui/apedit.pas` turns keys into a *screen* -- rows by columns of
characters and a cursor cell -- and `tui/session.pas` feeds it a script and
prints what it drew. So what a session compares is what a person would have
seen, frame by frame, with no pseudo-terminal anywhere: ADR-0262 declined a
PTY binding on the grounds that a case needing one becomes a test of the
binding, and that argument is why this shape was chosen rather than worked
around.

This is `lsp/run.py` with the framing taken out. What it keeps is that file's
three load-bearing decisions:

  * **the golden is exact bytes**, read with newline translation off, since a
    drawing that has lost a trailing blank is a different drawing;
  * **one build for every session**, because building the program is most of
    the cost and a case apiece would pay it once per session; and
  * **a session that writes to standard error with no `.note` beside it
    fails**, so a new complaint cannot appear unnoticed.

A session is `sessions/<name>.keys` and its golden is `sessions/<name>.screen`.
The directives are documented in `tui/session.pas`, which is also the program
that refuses an unknown one -- a directive that silently did nothing would be
a session asserting less than it appears to.
"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SESSIONS = HERE / 'sessions'

# A sweep that finds nothing prints a number and passes (ADR-0282). The
# editor has more sessions than this and each is a claim someone wrote down.
FLOOR = 5


def read_bytes(p):
    """Exactly what is in the file. `Path.read_text` translates newlines, and
    a golden here holds a drawing: the difference between a line that ends in
    blanks and one that does not is the thing being compared."""
    return p.read_bytes().decode('utf-8', 'surrogateescape')


def main(argv):
    if not argv:
        print('usage: run.py <pascalcc> [pascalc]', file=sys.stderr)
        return 2
    pascalcc = argv[0]
    env = dict(os.environ)
    if len(argv) > 1:
        env['PASCALC'] = argv[1]

    names = sorted(p.stem for p in SESSIONS.glob('*.keys'))
    if len(names) < FLOOR:
        print('tui: %d session(s), below the floor of %d -- this harness '
              'cannot pass by replaying nothing' % (len(names), FLOOR),
              file=sys.stderr)
        return 1

    work = Path(tempfile.mkdtemp(prefix='tui-'))
    binary = work / 'session'
    build = subprocess.run([sys.executable, str(HERE / 'build.py'), pascalcc,
                            'session.pas', str(binary)], env=env)
    if build.returncode != 0:
        print('tui: the session program did not build', file=sys.stderr)
        return build.returncode

    bad = 0
    for name in names:
        script = SESSIONS / (name + '.keys')
        golden = SESSIONS / (name + '.screen')
        note = SESSIONS / (name + '.note')
        with open(script, 'rb') as fin:
            r = subprocess.run([str(binary)], stdin=fin, capture_output=True,
                               env=env, timeout=60)
        got = r.stdout.decode('utf-8', 'surrogateescape')
        err = r.stderr.decode('utf-8', 'surrogateescape')

        if not golden.exists():
            print('tui: %s has no golden; what it drew was:' % name,
                  file=sys.stderr)
            sys.stderr.write(got)
            bad += 1
            continue
        want = read_bytes(golden)
        if got != want:
            print('tui: %s drew something else:' % name, file=sys.stderr)
            import difflib
            for d in difflib.unified_diff(want.split('\n'), got.split('\n'),
                                          'expected', 'drawn', lineterm=''):
                print('  ' + d, file=sys.stderr)
            bad += 1
        # Standard error is a claim too: absent means none, and a session that
        # complains without a `.note` beside it fails, so a new complaint
        # cannot arrive unnoticed. `lsp/run.py`'s rule, and its reason.
        want_note = read_bytes(note) if note.exists() else ''
        if err != want_note:
            print('tui: %s wrote to standard error:' % name, file=sys.stderr)
            sys.stderr.write(err)
            bad += 1
        if r.returncode != 0:
            print('tui: %s exited %d' % (name, r.returncode), file=sys.stderr)
            bad += 1

    if bad:
        return 1
    print('tui: %d session(s) replayed, every screen as recorded'
          % len(names))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
