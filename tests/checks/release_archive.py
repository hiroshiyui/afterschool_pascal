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

"""**Does the release script still produce an archive that checks out?**
(ADR-0296)

  release_archive.py <build-directory>

`tools/release.py` runs at a tag and nowhere else if nothing drives it
between tags, and this tree has learned twice what happens to shell that
only a tag exercises (ADR-0233's seed_current.py, ADR-0282). So this is the
`ctest` case that drives both halves on every run: build an archive from
the build tree under the version the compiler prints, then check it the way
the tag job will -- digest, one directory, licences, and every question
`install-layout` asks of a prefix.

Three claims fail separately, and each has been made to: `--archive`
refuses a tag that is not the compiler's version, `--check` refuses an
archive whose `.sha256` says something else, and `--check` refuses an
archive missing `lib/afterschool/` -- that last through `install_layout.py
--prefix`, whose file list names `lib/afterschool/pastext.pas`.

Not RELEASE_REQUIRE_STATIC: a developer's tree links dynamically and this
case runs in one. The tag job sets it, having configured the static link.

`tools/release.py` is what this drives and is still shell: converting the
gate is what ADR-0366's rule asks for, and the script it exercises is
unchanged, which is what keeps this a conversion rather than a redesign.

Converted from shell under ADR-0366; the shell version's output is what this
was required to reproduce byte for byte, on this tree and on every arm.
"""

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
RELEASE = ROOT / 'tools' / 'release.py'


def run(cmd, log, **kw):
    """Run a command, writing its two streams to `log` as the shell's
    `>file 2>&1` did, and answer whether it succeeded."""
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    log.write_text(r.stdout + r.stderr)
    return r.returncode == 0


def main(argv):
    build = Path(argv[0]) if argv else ROOT / 'build'
    pascalc = build / 'bin' / 'pascalc'
    if not os.access(pascalc, os.X_OK):
        print('release-archive: %s is missing; build first' % pascalc,
              file=sys.stderr)
        return 1

    work = Path(tempfile.mkdtemp(prefix='release-archive.',
                                 dir=os.environ.get('TMPDIR', '/tmp')))
    try:
        return check(build, pascalc, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def check(build, pascalc, work):
    version = subprocess.run([str(pascalc), '--version'],
                             capture_output=True, text=True).stdout.strip()
    tag = 'v' + version.rsplit(' ', 1)[-1]

    # The wrong tag is refused, and the refusal is the *version* one and not a
    # later failure: an archive named for a release the compiler is not must
    # never get as far as being written.
    wrong_log = work / 'wrong.log'
    if run([str(RELEASE), '--archive', str(build), 'v0.0.0', '',
            str(work / 'wrong')], wrong_log):
        print('--- release-archive: a tag that is not the version was '
              'accepted ---', file=sys.stderr)
        return 1
    if 'does not name the compiler' not in wrong_log.read_text():
        print('--- release-archive: v0.0.0 was refused for the wrong '
              'reason ---', file=sys.stderr)
        sys.stderr.write(wrong_log.read_text())
        return 1

    archive_log = work / 'archive.log'
    if not run([str(RELEASE), '--archive', str(build), tag, '',
                str(work / 'dist')], archive_log):
        print('--- release-archive: --archive failed ---', file=sys.stderr)
        sys.stderr.write(archive_log.read_text())
        return 1
    archives = sorted((work / 'dist').glob('afterschool-pascal-*.tar.gz'))
    if len(archives) != 1 or not archives[0].is_file():
        print('--- release-archive: expected one archive under %s/dist ---'
              % work, file=sys.stderr)
        subprocess.run(['ls', '-l', str(work / 'dist')], stdout=sys.stderr)
        return 1
    archive = archives[0]

    check_log = work / 'check.log'
    if not run([str(RELEASE), '--check', str(archive)], check_log):
        print('--- release-archive: --check failed on the archive just '
              'built ---', file=sys.stderr)
        sys.stderr.write(check_log.read_text())
        return 1

    # The digest sidecar is read: alter one character and the check must stop
    # before opening the archive.
    bad = work / 'bad'
    bad.mkdir(parents=True, exist_ok=True)
    shutil.copy(archive, bad / archive.name)
    digest = Path(str(archive) + '.sha256').read_text()
    flipped = ''.join(('1' if ln[:1] == '0' else '0') + ln[1:] + '\n'
                      for ln in digest.splitlines())
    (bad / (archive.name + '.sha256')).write_text(flipped)
    bad_log = work / 'bad.log'
    if run([str(RELEASE), '--check', str(bad / archive.name)], bad_log):
        print('--- release-archive: a wrong .sha256 was accepted ---',
              file=sys.stderr)
        return 1
    if 'sha256 says' not in bad_log.read_text():
        print('--- release-archive: the wrong digest was refused for another '
              'reason ---', file=sys.stderr)
        sys.stderr.write(bad_log.read_text())
        return 1

    reports = sum(1 for ln in check_log.read_text().splitlines()
                  if ln.startswith('release: '))
    print('release-archive: %s built and checked; %d report lines'
          % (archive.name, reports))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
