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

"""Does the corpus still run when a pointer is four bytes? (ADR-0325)

`target-layout` asks whether this compiler's arithmetic agrees with LLVM's,
which is a question about *numbers*. This one asks the other half: whether a
program built with those numbers behaves. They are not the same question, and
the difference is what this gate was written for -- both defects the i386 port
found are invisible to every arithmetic check here.

  - `pas_select` indexed its arm array with `sizeof(struct pas_select_arm)`
    where the compiler strides `PAS_SELECT_ARM_SIZE`. Those are one number on
    an LP64 target and two on i386, and the header above the struct claimed
    the larger *is* what indexes it.
  - and the compiler wrote the arm's fourth field at offset 16, which is
    where an LP64 target puts it and four bytes past where i386 does.

Neither is a layout rule and neither is in a frame, so `target-layout` passes
with both in place. `tests/dialect/select.pas` segfaults.

**The catalogue fails in both directions.** A case that starts failing is a
regression; a case that stops failing is a defect somebody fixed without
saying so, and the file is where the reason for each is written down. The
residue today is one address-space limit and one decision that has not been
taken -- see the file.

Skips with 77 where no 32-bit toolchain is here: `clang --target=i386` needs
a 32-bit libc to link against, which is a separate package on most
distributions. `TARGET32_REQUIRE=1` refuses to pass by skipping, which is how
CI asks for the real answer.

**It has a second axis and honours it** (ADR-0334): `AFTERSCHOOL_PASCAL_OPT`
reaches `run_test.py` from the environment, and the answer is not the same at
both levels. `tests/dialect/int64_foreign.pas` declared C's `labs` as taking
an `int64` -- a wrong ABI on every ILP32 target -- and passed here for two
weeks because at -O2 the optimiser folded the call away. The `thirty-two-bit`
job now runs this gate twice, because the combination that showed it was run
by no job at all: the `unoptimised` job has no 32-bit libc and skips.

Converted from shell under ADR-0366. The sweep stays serial: what is compared
is one list of failures in one order, and the shell version's order is the
one the catalogue was written against.
"""

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
CATALOGUE = ROOT / 'tests' / 'checks' / 'target32_known.txt'
TARGET = 'i386-pc-linux-gnu'

# Which i386, and it is the language's answer rather than this gate's
# (ADR-0345, ADR-0346). An i386 this compiler emits for has SSE2:
# `tools/pascalcc` puts `-march=pentium4` on every clang it starts for this
# triple, because clang's own default here is `i686`, whose eighty-bit x87
# registers make section 6.7.6.3's `round` contradict its clause and D.32's
# `sqr` error go undetected.
#
# It is repeated here because this gate builds a runtime and a probe with
# **direct** clang calls, which is the one path `pascalcc` is not on. Those two
# places are the whole of it and each names the other; a runtime built for a
# different processor than the programs linking it is what this line prevents.
#
# It also happens to be what makes this gate answer the same thing everywhere.
# clang 19 defaults this triple to `i686` and clang 21 to `pentium4`, so before
# the processor was named `tests/round_equivalence` and `tests/trap_sqrreal`
# failed on CI and passed on a developer's machine with nothing in the tree
# different between them.
CPU = '-march=pentium4'

ROOTS = ['tests', 'tests/extended', 'tests/dialect', 'examples']
FLOOR = 400


class Skip(Exception):
    pass


def main(argv):
    pascalcc = argv[0] if argv else str(ROOT / 'tools' / 'pascalcc')
    require = os.environ.get('TARGET32_REQUIRE', '')
    work = Path(tempfile.mkdtemp())
    try:
        return sweep(pascalcc, work)
    except Skip as s:
        if require:
            print('target32: %s -- and TARGET32_REQUIRE is set' % s,
                  file=sys.stderr)
            return 1
        print('target32: skipped -- %s' % s)
        return 77
    finally:
        shutil.rmtree(work, ignore_errors=True)


def sweep(pascalcc, work):
    if shutil.which('clang') is None:
        raise Skip('no clang')

    # Can this machine link and run a 32-bit binary at all? Asked with C,
    # before anything of this compiler's is built, so a missing libc is
    # reported as what it is rather than as a Pascal failure.
    (work / 'probe.c').write_text('int main(void){return 0;}\n')
    if subprocess.run(['clang', '--target=' + TARGET, CPU,
                       '-o', str(work / 'probe'), str(work / 'probe.c')],
                      capture_output=True).returncode != 0:
        raise Skip('clang cannot link for %s (a 32-bit libc is a separate '
                   'package)' % TARGET)
    if subprocess.run([str(work / 'probe')],
                      capture_output=True).returncode != 0:
        raise Skip('this machine cannot run an i386 binary')

    # The runtime, built for the target. Not the one in the build tree: that
    # one is the host's, and linking it would fail at the first object.
    rt = work / 'rt'
    rt.mkdir(parents=True, exist_ok=True)
    objects = []
    for c in sorted((ROOT / 'runtime').glob('*.c')):
        obj = rt / (c.stem + '.o')
        r = subprocess.run(['clang', '--target=' + TARGET, CPU, '-O2', '-fPIC',
                            '-c', str(c), '-o', str(obj)],
                           capture_output=True, text=True)
        if r.returncode != 0:
            print('target32: the runtime would not compile for %s:' % TARGET,
                  file=sys.stderr)
            sys.stderr.writelines(
                ln + '\n' for ln in r.stderr.splitlines()[:20])
            return 1
        objects.append(str(obj))
    if subprocess.run(['ar', 'rcs', str(rt / 'libpasrt.a')] + objects,
                      capture_output=True).returncode != 0:
        return 1

    env = dict(os.environ)
    env['AFTERSCHOOL_PASCAL_RUNTIME'] = str(rt)
    env['AFTERSCHOOL_PASCAL_TARGET'] = TARGET
    env.setdefault('PASCALC', str(ROOT / 'build' / 'bin' / 'pascalc'))

    known = []
    for line in CATALOGUE.read_text().splitlines():
        s = line.strip()
        if not s or s.startswith('#'):
            continue
        known.append(s.split()[0])

    total = ran = 0
    unexpected = []
    fixed = []
    for d in ROOTS:
        for src in sorted((ROOT / d).glob('*.pas')):
            rel = str(src.relative_to(ROOT))
            total += 1
            ok = subprocess.run([str(ROOT / 'tests' / 'run_test.py'),
                                 pascalcc, str(src)],
                                env=env, capture_output=True).returncode == 0
            if ok:
                ran += 1
                if rel in known:
                    fixed.append(rel)
            elif rel not in known:
                unexpected.append(rel)

    # A floor, so that a run reaching nothing cannot pass by comparing
    # nothing -- the empty comparison this repository has been caught by
    # before.
    if total < FLOOR:
        print('target32: only %d sources swept, below the floor of %d'
              % (total, FLOOR), file=sys.stderr)
        return 1

    status = 0
    if unexpected:
        print('target32: %d case(s) fail for %s and are not in the catalogue:'
              % (len(unexpected), TARGET), file=sys.stderr)
        for n in unexpected:
            print('  ' + n, file=sys.stderr)
        status = 1
    if fixed:
        print('target32: %d catalogued case(s) now pass -- say why and take '
              'the row out:' % len(fixed), file=sys.stderr)
        for n in fixed:
            print('  ' + n, file=sys.stderr)
        status = 1
    if status:
        return 1

    print('target32: %d of %d sources build and run for %s; %d catalogued'
          % (ran, total, TARGET, len(known)))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
