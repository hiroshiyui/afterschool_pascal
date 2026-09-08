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

"""Are the two opaque sizes big enough on every target a compiler is here for?

`PAS_FILE_SIZE` and `PAS_JUMP_SIZE` are the sizes of two C structs, written
down in runtime/pasrt.h and again as `fileSize` and `jumpSize` in
selfhost/compiler.pas, which is what allocates the bytes. The two files cannot
include one another, so selfhost/irtest.py checks that the four numbers agree.

**Agreeing is not the same as being right.** Both numbers were measurements of
x86-64 presented as constants, and `struct pas_jump` embeds a `jmp_buf` --
200 bytes on x86-64, 312 on aarch64, 392 on 32-bit arm. So `PAS_JUMP_SIZE`
was 256 and an aarch64 build stopped at the runtime's own _Static_assert
before anything else could go wrong (ADR-0155).

The check is to compile runtime/pasrt.c itself for each target rather than to
re-measure the structs here: the asserts are in that file, so what is checked
is the real definition and there is no copy of it to drift. That is
ADR-0144's lesson -- a check holding both halves of its own comparison cannot
fail.

It reports **which targets it reached**, always. A cross compiler that is not
installed is skipped, and a run that reached only the host says so in those
words: an empty list is what a clean run and a run that asked nothing both
produce, and this repository has been caught by that before.

**A compiler being on PATH is not the same as being usable**, and telling the
two apart is most of this script. Debian and Ubuntu package the cross
compiler and its C library separately, so `gcc-aarch64-linux-gnu` without
`libc6-dev-arm64-cross` gives a driver that runs and then cannot find
<setjmp.h> -- and the first version of this reported that as the size being
too small, which is an accusation against the wrong file. Every target is
therefore probed with a trivial translation unit first: one that fails there
is *incomplete*, not failing, and the message says which package is missing.

**`TARGET_SIZES_REQUIRE` is how CI refuses to pass by skipping.** Set it to a
space-separated list of triples and every one of them must be reached: absent
or header-less becomes a failure rather than a note. Without it the script
reports and moves on, which is right on a developer's machine and wrong on a
job whose whole purpose was to install those compilers -- the same shape the
`second-backend` job has, where installing llc and then skipping would be a
green run that asked nothing.

Converted from shell under ADR-0366; the shell version's output is what this
was required to reproduce byte for byte, on this tree and on every arm.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent

# Every target this repository can plausibly be built for and a Debian or
# Ubuntu box can install a compiler for in one package. The host is in the list
# on purpose: it makes the run non-empty everywhere, and a list whose only
# member is the host is a fact worth printing rather than a silent pass.
TARGETS = """x86_64-linux-gnu aarch64-linux-gnu arm-linux-gnueabihf
         arm-linux-gnueabi i686-linux-gnu riscv64-linux-gnu
         powerpc64le-linux-gnu s390x-linux-gnu mips64el-linux-gnuabi64""".split()

# Can this compiler see a C library at all? The header the runtime's sizes turn
# on is the one to ask for.
PROBE = '#include <setjmp.h>\n#include <stdio.h>\njmp_buf b;\n'

FAILED_MSG = """
runtime/pasrt.c did not compile for a target above. If it is one of the two
_Static_asserts, the size is a measurement of some other machine: raise both
PAS_JUMP_SIZE (or PAS_FILE_SIZE) in runtime/pasrt.h and jumpSize (or fileSize)
in selfhost/compiler.pas, which selfhost/irtest.py requires to agree. The cost
of the jump record is paid only by a block that is the target of a non-local
goto. See ADR-0155 and doc/roadmap.md's cross-platform chapter.
"""

# The three asserts are the point; anything else is a portability problem in
# the runtime that this check has found and should also report.
ASSERT_RE = re.compile(r'PAS_(FILE|JUMP|TASKSET)_SIZE|error')


def dumpmachine():
    """What this machine is, so that "not the host" is a fact about the target
    rather than about how the compiler happened to be named.
    `x86_64-linux-gnu-gcc` and `gcc` are the same compiler here, and only one
    of the two spellings exists in a minimal container."""
    try:
        r = subprocess.run(['cc', '-dumpmachine'], capture_output=True,
                           text=True)
    except OSError:
        return None
    return r.stdout.strip() if r.returncode == 0 else None


def main():
    host = dumpmachine() or 'unknown'
    work = Path(tempfile.mkdtemp())
    try:
        return run(host, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def run(host, work):
    (work / 'probe.c').write_text(PROBE)

    checked = crossed = failed = 0
    absent = ''
    incomplete = ''

    for t in TARGETS:
        cc = t + '-gcc'
        if shutil.which(cc) is None:
            # The host's compiler is usually just `gcc`, without the triple
            # prefix.
            if t == dumpmachine() and shutil.which('cc') is not None:
                cc = 'cc'
            else:
                absent += ' ' + t
                continue
        if subprocess.run([cc, '-c', str(work / 'probe.c'),
                           '-o', str(work / 'probe.o')],
                          capture_output=True).returncode != 0:
            incomplete += ' ' + t
            continue
        checked += 1
        if t != host:
            crossed += 1
        # Two translation units, because the `_Static_assert`s are in two.
        # runtime/pasrt.c carries PAS_FILE_SIZE's and PAS_JUMP_SIZE's;
        # runtime/pasrt_task.c carries PAS_TASKSET_SIZE's, and a task set is a
        # pointer and two ints, so a 32-bit target sizes it differently
        # (ADR-0268).
        err = ''
        ok = True
        for unit, obj in (('pasrt.c', t + '.o'),
                          ('pasrt_task.c', t + '-task.o')):
            r = subprocess.run([cc, '-c', str(ROOT / 'runtime' / unit),
                                '-I', str(ROOT / 'runtime'),
                                '-o', str(work / obj)],
                               capture_output=True, text=True)
            err += r.stderr
            if r.returncode != 0:
                ok = False
                break
        if ok:
            print('target-sizes: %s ok' % t)
        else:
            failed += 1
            print('target-sizes: %s FAILED' % t, file=sys.stderr)
            hits = [ln for ln in err.splitlines() if ASSERT_RE.search(ln)][:3]
            for ln in hits:
                print(ln, file=sys.stderr)

    if absent:
        print('target-sizes: no compiler installed for:%s' % absent)

    if incomplete:
        # Not a failure and not silence: the toolchain is here and cannot be
        # used, so the question was not asked for it and saying which package
        # is missing is the useful half.
        print('target-sizes: a compiler is installed but has no C library '
              'headers for:%s -- on Debian and Ubuntu that is the matching '
              'libc6-dev-<arch>-cross package, which --no-install-recommends '
              'omits' % incomplete)

    # Anything CI said it would ask about and did not.
    unreached = set(absent.split()) | set(incomplete.split())
    missing = ''
    for want in os.environ.get('TARGET_SIZES_REQUIRE', '').split():
        if want in unreached:
            missing += ' ' + want
    if missing:
        print('target-sizes: TARGET_SIZES_REQUIRE names%s, and the run did '
              'not reach them. This job installed those compilers on purpose, '
              'so a skip here is a question that was not asked rather than '
              'one that passed.' % missing, file=sys.stderr)
        return 1

    if failed > 0:
        sys.stderr.write(FAILED_MSG)
        return 1

    if crossed == 0:
        print('target-sizes: only the host was checked -- install a cross '
              'compiler (apt install gcc-aarch64-linux-gnu) to ask the '
              'question this exists for')
        return 77

    print('target-sizes: PAS_FILE_SIZE and PAS_JUMP_SIZE are large enough on '
          'all %d targets a compiler is installed for, %d of them not the host'
          % (checked, crossed))
    return 0


if __name__ == '__main__':
    sys.exit(main())
