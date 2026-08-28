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

"""A second answer for the corpus, from a processor nobody here wrote.

Every program in `tests/` has exactly one reader.  Since ADR-0232 retired the
BSI suite and `difftest`, the only oracle in this tree that this project did
not write is `unicode-conformance`, and it reaches one clause.  Open question
2 of doc/roadmap.md is the standing proposal to fix that with a second
*processor* rather than a second corpus, and this is it: Free Pascal under
`-Miso`, compiling and running the programs that already have goldens.

**FPC is not an authority and this gate does not treat it as one.**  It
implements neither standard completely, and where the two disagree the clause
decides -- four times so far, all four in this compiler's favour, which is
recorded per entry in `fpc_disagreements.txt`.  What a second processor buys
is not correctness but *contradiction*: a reading nothing here could challenge
now has something that will disagree with it out loud.

**What is deliberately not compared.**  ISO 7185 6.9.3.1 leaves the default
TotalWidth to the processor and 6.9.3.4.1 leaves ExpDigits and the exponent
character; FPC writes an integer in 11 columns and an exponent in three digits
where this compiler writes the fewest it can and two.  Comparing those would
be comparing two permitted answers, so numeric output is compared *by value*
and default padding is collapsed.  An explicit width is honoured by both and
survives the collapse.

Four verdicts and only the last is catalogued:

  refused    FPC will not compile it -- 6.11 modules above all, which
             -Mextendedpascal does not implement at all.  Counted, not listed:
             it is a fact about FPC's coverage and not about this compiler.
  agree      same bytes, or the same values under the rule above.
  expected   a disagreement whose class is known and whose reason is one fact
             rather than N: an ISO error this compiler traps (ADR-0014,
             ADR-0015) and FPC runs past, or a program whose parameters are
             bound to files, which the two processors bind differently.
  DISAGREE   everything else, and every one needs an entry in the catalogue
             saying which clause decides it and which way.

The catalogue fails in **both** directions, as every catalogue here does: a
disagreement that goes away is as loud as one that appears, because the first
means somebody changed an answer this file explains.

Skips 77 without `fpc`.  FPC_DIFFERENTIAL_REQUIRE=1 turns the skip into a
failure, which is how a CI job refuses to pass by skipping.
"""

import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
CATALOGUE = pathlib.Path(__file__).with_name('fpc_disagreements.txt')
CORPORA = ('tests', 'tests/extended')
SKIP = 77

NUMBER = re.compile(rb'[-+]?(?:\d+\.\d*(?:[Ee][-+]?\d+)?|\.\d+(?:[Ee][-+]?\d+)?'
                    rb'|\d+[Ee][-+]?\d+|\d+)')


def tokens(b):
    """Split output into comparable items: numbers, and the text between them.

    A number keeps its own identity so it can be compared by value.  Every
    other character keeps its identity except **blanks**, which are dropped
    entirely -- because a default field width is padding and 6.9.3.1 leaves it
    to the processor, and a boolean written next to another with no separator
    turns that padding into a space *inside* a run: this compiler writes
    `truefalsetrue` where FPC writes `truefalse true`, and the two are the
    same answer.  A newline is kept, being a line and not padding.

    What this costs is stated rather than hidden: a genuinely missing space
    between two words is invisible here, and two numbers written with no
    separator read as one number, which is why `tests/ordinals` cannot be
    compared at all and is catalogued as such.
    """
    b = b.replace(b'TRUE', b'true').replace(b'FALSE', b'false')
    out, i = [], 0

    def text(chunk):
        chunk = re.sub(rb'[ \t]+', b'', chunk)
        if chunk:
            out.append(chunk)

    for m in NUMBER.finditer(b):
        text(b[i:m.start()])
        out.append(m.group())
        i = m.end()
    text(b[i:])
    return out


def same(a, b):
    """Equal, allowing each processor its own permitted numeric spelling."""
    ta, tb = tokens(a), tokens(b)
    if len(ta) != len(tb):
        return False
    for x, y in zip(ta, tb):
        if x == y:
            continue
        if NUMBER.fullmatch(x) and NUMBER.fullmatch(y):
            try:
                fx, fy = float(x), float(y)
            except ValueError:
                return False
            if fx == fy or abs(fx - fy) <= 1e-12 * max(abs(fx), abs(fy), 1.0):
                continue
        return False
    return True


def parameters(src):
    """The program-parameters of a source, or None if it declares no program."""
    m = re.search(rb'\bprogram\s+\w+\s*\(([^)]*)\)', src.read_bytes(), re.I)
    if not m:
        return None
    return [p.strip().lower().decode() for p in m.group(1).split(b',')]


def read_catalogue():
    entries = {}
    for line in CATALOGUE.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        case, _, reason = line.partition(':')
        entries[case.strip()] = reason.strip()
    return entries


def main():
    if shutil.which('fpc') is None:
        print('fpc is not installed; skipping the differential.')
        if os.environ.get('FPC_DIFFERENTIAL_REQUIRE'):
            print('FPC_DIFFERENTIAL_REQUIRE is set: a skip is a failure here.',
                  file=sys.stderr)
            return 1
        return SKIP

    catalogue = read_catalogue()
    work = pathlib.Path(tempfile.mkdtemp(prefix='fpc-differential.'))
    tally = {'refused': 0, 'agree': 0, 'expected': 0}
    disagree = {}

    try:
        for corpus in CORPORA:
            for src in sorted((ROOT / corpus).glob('*.pas')):
                golden = src.with_suffix('.out')
                if not golden.exists():
                    continue
                case = f'{corpus}/{src.stem}'
                w = work / src.stem
                w.mkdir(parents=True, exist_ok=True)
                shutil.copy(src, w / src.name)

                for mode in ('iso', 'extendedpascal'):
                    r = subprocess.run(
                        ['fpc', f'-M{mode}', '-va-', f'-FE{w}', f'-FU{w}',
                         str(w / src.name)],
                        capture_output=True, timeout=180)
                    if r.returncode == 0 and (w / src.stem).exists():
                        break
                else:
                    tally['refused'] += 1
                    continue

                stdin = src.with_suffix('.in')
                try:
                    r = subprocess.run(
                        [str(w / src.stem)], cwd=w, capture_output=True,
                        timeout=30,
                        input=stdin.read_bytes() if stdin.exists() else b'')
                except subprocess.TimeoutExpired:
                    disagree[case] = 'FPC did not terminate'
                    continue

                if same(r.stdout, golden.read_bytes()):
                    tally['agree'] += 1
                    continue

                # An ISO error this compiler traps and FPC runs past: the
                # golden stops where the trap does, so FPC's output extends
                # it.  One fact about FPC's checking, not one per case.
                # Compared after normalising, not before: the golden stops
                # at the trap, and the lines before it differ in padding like
                # everybody else's.
                # A prefix of the *joined* normalisation, not of the token
                # list: the golden stops in the middle of the line the trap
                # cut short, so the divergence is usually inside one item.
                want = b''.join(tokens(golden.read_bytes()))
                got = b''.join(tokens(r.stdout))
                if src.stem.startswith('trap_') and got.startswith(want):
                    tally['expected'] += 1
                    continue

                # A program bound to files other than input and output: the
                # two processors bind program-parameters differently and the
                # harness supplies neither's arguments.
                params = parameters(src)
                if params and set(params) - {'input', 'output', ''}:
                    tally['expected'] += 1
                    continue

                disagree[case] = None

        stale = sorted(set(catalogue) - set(disagree))
        fresh = sorted(set(disagree) - set(catalogue))

        total = sum(tally.values()) + len(disagree)
        print(f'{total} cases with a golden: '
              f"{tally['agree']} agree, {tally['expected']} disagree for a "
              f"catalogued class, {tally['refused']} FPC will not compile, "
              f'{len(disagree)} substantive disagreements.')
        for case in sorted(disagree):
            print(f'  {case}: {catalogue.get(case, "NOT IN THE CATALOGUE")}')

        if fresh:
            print('\nA case disagrees with FPC and the catalogue does not say '
                  'why:', file=sys.stderr)
            for case in fresh:
                print(f'  {case}', file=sys.stderr)
            print('Decide which processor the clause is on, then add an entry.',
                  file=sys.stderr)
        if stale:
            print('\nThe catalogue explains a disagreement that no longer '
                  'happens:', file=sys.stderr)
            for case in stale:
                print(f'  {case}: {catalogue[case]}', file=sys.stderr)
            print('An answer changed -- this compiler\'s or FPC\'s. Find out '
                  'which before deleting the entry.', file=sys.stderr)
        return 1 if (fresh or stale) else 0
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())
