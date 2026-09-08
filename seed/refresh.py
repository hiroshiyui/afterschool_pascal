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

"""Regenerate the seed from the current compiler, and prove it works.

  seed/refresh.py [build-dir]

**The seed is one module per program-component** (ADR-0233): the compiler is
three 6.13 components, and a seed is a working compiler in IR, so it is three
modules that clang links together. They are written as seed/<component>.ll,
and CMake matches seed/*.ll rather than naming them -- how many there are is
the seed's business.

Run at release tags, not per commit: the seed is several megabytes and
regenerating it rewrites all of it. seed/README.md says why an older seed
keeps working -- and it keeps working across this change too, a one-module
seed from before the split being a perfectly good compiler for building the
three sources that came after it.

A seed is never committed on the strength of having been generated. This
builds a compiler *from the candidate*, has that compiler translate the
source again, and requires the two results to be identical -- the same fixed
point selfhost/irtest.py requires, asked of the artefact about to be trusted.

Converted from shell under ADR-0366, together with
`tests/checks/seed_current.py`, which imports `components`, `translate` and
`unified` from here. That sharing is the point: the two must translate the
same way, and a difference between them is a seed that reproduces nowhere
(ADR-0347). In shell that claim was two copies of one loop.
"""

import difflib
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent

# The compiler these start inherits both streams, so this script's own lines
# must reach the file in the order they were written: Python block-buffers
# stdout when it is not a terminal, and the shell version's `echo` did not.
sys.stdout.reconfigure(line_buffering=True)


def components(root):
    """The components, in the order selfhost/compiler.components gives, with
    the program last -- the same list CMake and every harness reads.
    compiler.pas is the program and is not in the sidecar; the sidecar lists
    the components it imports, which is what every other reader needs."""
    names = [ln for ln in
             (root / 'selfhost' / 'compiler.components').read_text().split('\n')
             if ln.strip()]
    return names + ['compiler.pas']


def translate(root, cc, comps, out_for):
    """Translate each component in order, each importing the ones before it,
    yielding (component, output, ok) as it goes.

    Translated from `root` with a **relative** source path, and that is not a
    tidiness: since ADR-0293 every trap the compiler emits carries its own
    position, so the source's path is a string constant *in the emitted
    module* -- `@at.file`. An absolute path would put the machine that
    reseeded into a committed artefact, and `tests/checks/seed_current.py`
    could then pass only in the directory that generated it. It failed for
    exactly that reason in the tag job for v3.5.0, which is the one place it
    runs (ADR-0347).
    """
    imports = []
    for c in comps:
        out = out_for(c)
        r = subprocess.run([cc] + imports + ['selfhost/' + c, '-o', str(out)],
                           cwd=root)
        yield c, out, r.returncode
        if r.returncode != 0:
            return
        imports += ['--import', 'selfhost/' + c]


def gnu_date(p):
    ns = p.stat().st_mtime_ns
    t = time.localtime(ns // 10**9)
    return '%s.%09d %s' % (time.strftime('%Y-%m-%d %H:%M:%S', t),
                           ns % 10**9, time.strftime('%z', t))


def unified(a, b):
    """`diff -u a b` as a list of lines, timestamps and all, so what a failure
    prints is still a diff a reader can hand to `patch`."""
    return list(difflib.unified_diff(
        a.read_text().splitlines(keepends=True),
        b.read_text().splitlines(keepends=True),
        str(a), str(b), gnu_date(a), gnu_date(b)))


def main(argv):
    build = Path(argv[0]) if argv else ROOT / 'build'
    pascalc = build / 'bin' / 'pascalc'
    runtime = build / 'lib' / 'libpasrt.a'
    for f in (pascalc, runtime):
        if not f.exists():
            print('refresh: %s is missing -- build first' % f, file=sys.stderr)
            return 1

    work = Path(tempfile.mkdtemp())
    try:
        return refresh(pascalc, runtime, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def refresh(pascalc, runtime, work):
    comps = components(ROOT)
    numbered = {c: n + 1 for n, c in enumerate(comps)}

    def run(cc, prefix):
        for c, _out, rc in translate(ROOT, cc, comps,
                                     lambda c: work / ('%s%d.ll'
                                                       % (prefix,
                                                          numbered[c]))):
            if rc != 0:
                sys.exit(rc)

    version = subprocess.run([str(pascalc), '--version'],
                             capture_output=True, text=True).stdout.strip()
    print('refresh: generating a candidate seed with %s' % version)
    run(str(pascalc), 'candidate')

    print('refresh: building a compiler from the candidate')
    r = subprocess.run(['clang', '-Wno-override-module']
                       + [str(work / ('candidate%d.ll' % (n + 1)))
                          for n in range(len(comps))]
                       + [str(runtime), '-lm', '-o', str(work / 'from-seed')])
    if r.returncode != 0:
        return r.returncode

    print('refresh: requiring that compiler to reproduce itself')
    run(str(work / 'from-seed'), 'again')
    for n, c in enumerate(comps, 1):
        a = work / ('candidate%d.ll' % n)
        b = work / ('again%d.ll' % n)
        if a.read_bytes() != b.read_bytes():
            print('refresh: the candidate does not reproduce %s -- not '
                  'committing it' % c, file=sys.stderr)
            sys.stderr.writelines(unified(a, b)[:40])
            return 1

    # It also has to be a working compiler, not merely a self-reproducing one.
    r = subprocess.run([str(work / 'from-seed'), str(ROOT / 'tests/hello.pas'),
                        '-o', str(work / 'hello.ll')])
    if r.returncode != 0:
        return r.returncode
    r = subprocess.run(['clang', '-Wno-override-module',
                        str(work / 'hello.ll'), str(runtime), '-lm',
                        '-o', str(work / 'hello')])
    if r.returncode != 0:
        return r.returncode
    said = subprocess.run([str(work / 'hello')], capture_output=True,
                          text=True).stdout.split('\n')[0]
    if said != 'Hello, Afterschool Pascal!':
        print('refresh: the candidate compiler does not compile hello.pas',
              file=sys.stderr)
        return 1

    # The old seed is removed first: a seed left behind from a build with more
    # components would be linked in beside the new ones by CMake's glob, and
    # two definitions of the same program is a link error about a file nobody
    # wrote.
    for old in HERE.glob('*.ll'):
        old.unlink()
    total = 0
    for n, c in enumerate(comps, 1):
        dest = HERE / (c[:-len('.pas')] + '.ll')
        shutil.copyfile(work / ('candidate%d.ll' % n), dest)
        total += dest.read_text().count('\n')
    print('refresh: %d seed modules updated (%d lines)' % (len(comps), total))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
