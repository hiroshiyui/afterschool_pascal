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

"""Compile one .pas with a --dump flag and compare the dump against a golden.

  run.py <path-to-pascalc> <path-to-test.pas>

A case here needs its own harness rather than a sidecar on tests/run_test.py,
because the thing under test is what the *compiler* writes to standard
output, where every case there compares what the compiled *program* writes.
The two never meet: a dump case is not run, and an ordinary case never passes
a --dump flag.

  name.dump    expected standard output, in full
  name.flags   the flags to compile with, whitespace-separated;
               --dump-all when absent. It held exactly one flag until
               ADR-0284 needed `--format --range=L:H`, and the failure was
               the readable kind: the two were concatenated and the compiler
               reported `unknown option --format--range=15:21`.
  name.components  section 6.13's other program-components, one path per line
               relative to this directory, each passed as an --import. It
               is the same sidecar tests/run_test.py and irtest.py read and
               it means less here: a dump is not linked, so what these
               supply is the *declarations* a name can resolve to. They
               live in components/, which this corpus's glob does not
               reach, for the reason tests/extended/components/ does
  name.status  the exit status this case expects, when it is not 0. A dump
               that reports what a *failed* compilation still found is the
               one kind of case here whose subject is a program the
               compiler rejects, and requiring status 0 of everything is
               what would make it unwritable (ADR-0246)

The case's own directory is rewritten to <dir>/ in what is compared, which
tests/run_test.py does to a diagnostic for the same reason: --dump-imports
answers with *paths*, and a path that begins at the checkout cannot be
written down once (ADR-0244). No other dump names a file, so this changes
nothing for the rest.

These exist because tests/checks/coverage.py found that no case in the corpus
passed any --dump flag, leaving thirty-one walker procedures entered by
nothing while four documented flags claimed to work. Keeping them green is
what stops that recurring; keeping the goldens honest is a separate
obligation, and regenerating one is a decision to argue for in the commit
message rather than a step (doc/sop.md section 5).

Converted from shell under ADR-0366; the shell version's output is what this
was required to reproduce byte for byte, over every case in the corpus and on
every arm.
"""

import difflib
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.stdout.reconfigure(line_buffering=True)


def read_exact(p):
    """A golden, byte for byte.

    `Path.read_text()` translates newlines: it turns `\r\n` into `\n`, so a
    golden holding LSP framing compares equal to output that has lost its
    carriage returns -- which is precisely the claim these goldens exist to
    make. Read with translation off.
    """
    with open(p, 'r', encoding='utf-8', errors='surrogateescape',
              newline='') as f:
        return f.read()


def split_lines(text):
    """Lines as `diff` counts them: broken at `\n` and nowhere else.
    `str.splitlines` also breaks at a bare carriage return."""
    out = text.split('\n')
    tail = out.pop()
    lines = [ln + '\n' for ln in out]
    if tail:
        lines.append(tail)
    return lines


def gnu_date(p):
    ns = p.stat().st_mtime_ns
    t = time.localtime(ns // 10**9)
    return '%s.%09d %s' % (time.strftime('%Y-%m-%d %H:%M:%S', t),
                           ns % 10**9, time.strftime('%z', t))


def main(argv):
    pascalc, source = argv[0], argv[1]
    src = Path(source)
    base = source[:-len('.pas')] if source.endswith('.pas') else source
    name = Path(base).name

    expected = Path(base + '.dump')
    flags_file = Path(base + '.flags')

    # Split on whitespace, and drop anything that splits to nothing -- a
    # sidecar with a trailing newline is the ordinary case. The shell's
    # `read -r -a` takes the first line and no more, so this does too.
    flags = ['--dump-all']
    if flags_file.is_file():
        first = flags_file.read_text().split('\n')[0]
        flags = first.split()

    # One --import per line, resolved against this case's own directory so the
    # golden does not depend on where the checkout lives.
    imports = []
    components = Path(base + '.components')
    if components.is_file():
        for rel in components.read_text().split('\n'):
            if rel:
                imports += ['--import', os.path.join(os.path.dirname(source),
                                                     rel)]

    want_status = 0
    status_file = Path(base + '.status')
    if status_file.is_file():
        want_status = int(''.join(status_file.read_text().split()))

    if not expected.is_file():
        print('missing expected-dump file: %s' % expected, file=sys.stderr)
        return 1

    work = Path(tempfile.mkdtemp())
    try:
        return compare(pascalc, source, src, name, expected, flags, imports,
                       want_status, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def compare(pascalc, source, src, name, expected, flags, imports,
            want_status, work):
    # The IR still gets written -- a --dump flag stops the *reporting* at the
    # stage it names, not the translation -- so it goes somewhere disposable.
    # Only what reaches standard output is the subject here.
    r = subprocess.run([pascalc] + imports + flags + [source,
                                                      '-o', str(work / 'out.ll')],
                       capture_output=True, text=True)
    actual, errors = r.stdout, r.stderr

    # Diagnostics go to `output` too (no standard Pascal program has a second
    # stream), so a case that stopped compiling would show up as a dump diff
    # rather than as a mystery. The exit status is still checked, against what
    # the case says it expects: almost every case here is a valid program, and
    # a status the case did not ask for means the golden is recording a
    # failure nobody meant.
    if r.returncode != want_status:
        print('--- %s: the compiler exited with status %d, wanted %d ---'
              % (name, r.returncode, want_status), file=sys.stderr)
        sys.stderr.write(actual + errors)
        return 1

    if errors:
        print('--- %s: unexpected output on standard error ---' % name,
              file=sys.stderr)
        sys.stderr.write(errors)
        return 1

    # The source path is rewritten so a golden does not depend on where the
    # checkout lives, exactly as tests/run_test.py does it.
    rewritten = actual.replace(source, '<source>')
    rewritten = rewritten.replace(os.path.dirname(source) + '/', '<dir>/')
    got = work / 'actual'
    got.write_bytes(rewritten.encode('utf-8', 'surrogateescape'))
    a = split_lines(read_exact(expected))
    b = split_lines(rewritten)
    if a != b:
        sys.stdout.writelines(difflib.unified_diff(
            a, b, str(expected), '/dev/fd/63',
            gnu_date(expected), gnu_date(got)))
        print('--- %s: dump differs (expected vs actual above) ---' % name,
              file=sys.stderr)
        return 1

    print('%s: ok (%s)' % (name, ' '.join(flags)))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
