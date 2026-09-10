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

"""Does a second implementation give a code point the same width? (ADR-0398)

AP 6.4.15.13's table is generated from `EastAsianWidth.txt`, and
`unicode-conformance` regenerates the header and diffs it -- which checks that
the *generator* is stable and not that the table is right.  Normalisation and
segmentation each have a conformance file Unicode publishes; East_Asian_Width
has none, and `doc/sop.md` §7 carried that as the largest thing ADR-0395 left
open.

The C library has a table of its own, built by other people from the same
database, and `wcwidth` is how a program asks it.  **It is not an authority**
-- that is `fpc-differential`'s rule and its reason -- so where the two differ
the clause decides and the disagreement is catalogued with which way and why.
What a second opinion actually buys is narrow and worth having: a
transcription error here would show up as a range with no explanation.

Both directions.  A range that stops disagreeing is as loud as a new one,
either being a table that moved -- ours or the C library's.

Skips 77 without a C compiler or without a UTF-8 locale; `WCWIDTH_REQUIRE`
refuses to pass by skipping.
"""

import os
import pathlib
import re
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
CATALOGUE = HERE / "wcwidth_disagreements.txt"
HEADER = ROOT / "runtime" / "pasrt_unicode_data.h"

# `wcwidth` is XSI rather than base POSIX, so the feature-test macro is
# `_XOPEN_SOURCE` -- ADR-0383's lesson about `_longjmp`, one library call
# further on.  A locale is required and is not optional: glibc answers -1 for
# everything outside the locale's charmap, so in the "C" locale this would
# compare nothing and report perfect agreement.
PROBE = r"""
#define _XOPEN_SOURCE 700
#include <locale.h>
#include <stdio.h>
#include <wchar.h>

int main(void) {
  unsigned int cp;
  if (setlocale(LC_ALL, "C.UTF-8") == NULL &&
      setlocale(LC_ALL, "en_US.UTF-8") == NULL) {
    fprintf(stderr, "no UTF-8 locale\n");
    return 2;
  }
  for (cp = 0; cp < 0x110000u; cp++) {
    if (cp >= 0xD800u && cp <= 0xDFFFu)
      continue;   /* not a scalar value; AP 6.4.15.1 */
    printf("%X %d\n", cp, wcwidth((wchar_t)cp));
  }
  return 0;
}
"""

# A floor, so the gate cannot pass by comparing nothing (ADR-0282).  A locale
# whose charmap covers only Latin-1 would answer -1 for the rest and agree
# with everything it had not looked at.
LEAST_COMPARED = 100000


def skip(message):
    if os.environ.get("WCWIDTH_REQUIRE"):
        print("wcwidth: %s, and WCWIDTH_REQUIRE is set" % message,
              file=sys.stderr)
        return 1
    print("wcwidth: skipped -- %s" % message)
    return 77


def ours():
    """The width of every code point, from the committed header.

    Absent from the table means one, which is the whole reason the table is
    small; reading it as zero is the mistake `range_lookup_or` exists to stop
    the C side making, and it would be the same mistake here.
    """
    text = HEADER.read_text()
    m = re.search(r"pas_u_width\[\] = \{(.*?)\};", text, re.S)
    if not m:
        sys.exit("wcwidth: no pas_u_width table in %s" % HEADER)
    table = bytearray([1]) * 0x110000
    for lo, hi, v in re.findall(r"\{0x([0-9A-Fa-f]+), 0x([0-9A-Fa-f]+), (\d)\}",
                                m.group(1)):
        for cp in range(int(lo, 16), int(hi, 16) + 1):
            table[cp] = int(v)
    return table


def catalogued():
    """The catalogue, as {(lo, hi): (ours, theirs, cause)}."""
    out = {}
    for line in CATALOGUE.read_text().splitlines():
        line = line.split("#")[0].strip()
        if not line:
            continue
        f = line.split()
        if len(f) != 5:
            sys.exit("wcwidth: %s: five fields wanted, got %r" %
                     (CATALOGUE.name, line))
        out[(int(f[0], 16), int(f[1], 16))] = (int(f[2]), int(f[3]), f[4])
    return out


def main():
    cc = os.environ.get("CC", "clang")
    with tempfile.TemporaryDirectory() as tmp:
        d = pathlib.Path(tmp)
        (d / "probe.c").write_text(PROBE)
        r = subprocess.run([cc, "-std=gnu11", str(d / "probe.c"),
                            "-o", str(d / "probe")],
                           capture_output=True, text=True)
        if r.returncode != 0:
            return skip("no C compiler that builds a wcwidth probe")
        r = subprocess.run([str(d / "probe")], capture_output=True, text=True)
        if r.returncode != 0:
            return skip("the probe would not run: %s" % r.stderr.strip())
        answers = r.stdout

    mine = ours()
    compared = 0
    found = {}
    for line in answers.splitlines():
        a, b = line.split()
        cp, w = int(a, 16), int(b)
        # -1 is "no printable width in this locale", which is a statement
        # about the locale and not about the character.  Unassigned code
        # points answer it, and so does anything the charmap omits.
        if w < 0:
            continue
        compared += 1
        if mine[cp] != w:
            found[cp] = w

    if compared < LEAST_COMPARED:
        print("wcwidth: only %d code point(s) had a width in this locale, "
              "under the floor of %d -- the comparison would be about the "
              "locale rather than about the table"
              % (compared, LEAST_COMPARED), file=sys.stderr)
        return 1

    # Coalesce into the ranges the catalogue is written in: a run of adjacent
    # code points that disagree the same way is one row.
    runs = []
    for cp in sorted(found):
        if runs and runs[-1][1] + 1 == cp and \
                (mine[runs[-1][0]], found[runs[-1][0]]) == (mine[cp], found[cp]):
            runs[-1][1] = cp
        else:
            runs.append([cp, cp])

    want = catalogued()
    bad = []
    seen = set()
    for lo, hi in runs:
        key = (lo, hi)
        seen.add(key)
        if key not in want:
            bad.append("U+%04X..U+%04X disagrees and is not catalogued: "
                       "AP 6.4.15.13 says %d, wcwidth says %d"
                       % (lo, hi, mine[lo], found[lo]))
        else:
            o, t, _ = want[key]
            if (o, t) != (mine[lo], found[lo]):
                bad.append("U+%04X..U+%04X is catalogued as %d against %d "
                           "and is now %d against %d"
                           % (lo, hi, o, t, mine[lo], found[lo]))
    for key in want:
        if key not in seen:
            bad.append("U+%04X..U+%04X is catalogued as a disagreement and "
                       "the two now agree -- a table moved, and which one is "
                       "the question" % key)

    if bad:
        for b in bad:
            print("wcwidth: " + b, file=sys.stderr)
        return 1

    causes = {}
    for o, t, cause in want.values():
        causes[cause] = causes.get(cause, 0) + 1
    print("wcwidth: %d code point(s) compared against the C library's own "
          "table; %d catalogued disagreement(s) in %d cause(s) (%s)"
          % (compared, len(want), len(causes),
             ", ".join("%s %d" % (c, n) for c, n in sorted(causes.items()))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
