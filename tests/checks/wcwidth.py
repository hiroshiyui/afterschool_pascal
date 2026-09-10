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
the clause decides and the disagreement is written down with which way and
why.

**What is written down is a cause and not a code point**, and the first
version of this gate got that wrong: it held an enumerated list of sixteen
ranges, passed on the machine that generated it, and failed on macOS and on
ubuntu:24.04.  A range list is a fact about *one* C library's table.  Two
libraries built from the same database differ exactly where the database
leaves the question open -- a control, a format character, a spacing mark, a
conjoining jamo, an Ambiguous width -- and every one of those places has a
name and a property this tree already has a table for.  So the claim is that
**every disagreement falls into a catalogued cause**, and one that falls into
none is the transcription error this gate exists to find.

The classes come from `pas_u_gcb`, the Grapheme_Cluster_Break table the
committed header already holds for segmentation, which is what makes them a
property of the code point rather than of the machine.

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

# **The two tables are built from different Unicode versions, and no catalogue
# can close that.**  ubuntu:24.04's glibc predates the release that made the
# trigrams U+2630..U+2637 Wide, so it says one where this table says two --
# and which code points a given library is behind on is a property of that
# library's age, not of any property of the character.
#
# So exact agreement is not the claim.  The claim is that divergence is
# **bounded**, and the bound is set by measurement rather than taste: the
# smallest systematic error this table could contain is every zero-width code
# point transcribed wrongly, which is 2307 of them, and the largest is every
# Wide one, which is 182869.  An upstream version skew is tens.  Five hundred
# separates those by a factor of four in one direction and by three hundred in
# the other.
#
# What it costs is written down in `doc/sop.md` §7: an error in *one* code
# point is under the bound and this cannot see it.  `unicode-conformance` is
# what covers that half, regenerating the header from the database and
# diffing; between them what is left uncovered is a generate.py bug that
# misreads fewer than five hundred code points.
UNEXPLAINED_MAX = 500


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


GCB_NAMES = ("Other", "CR", "LF", "Control", "Extend", "ZWJ", "RI",
             "Prepend", "SpacingMark", "L", "V", "T", "LV", "LVT")


def breaks():
    """Grapheme_Cluster_Break per code point, from the committed header.

    The same table `pas_text_next` segments with, so the classes below are the
    ones the clause's own *unit* is defined in terms of -- which is why a
    disagreement about a jamo is not a disagreement about a text.
    """
    text = HEADER.read_text()
    m = re.search(r"pas_u_gcb\[\] = \{(.*?)\};", text, re.S)
    if not m:
        sys.exit("wcwidth: no pas_u_gcb table in %s" % HEADER)
    table = bytearray(0x110000)
    for lo, hi, v in re.findall(r"\{0x([0-9A-Fa-f]+), 0x([0-9A-Fa-f]+), (\d+)\}",
                                m.group(1)):
        for cp in range(int(lo, 16), int(hi, 16) + 1):
            table[cp] = int(v)
    return table


def catalogued():
    """The causes: {cause: set of GCB names}, plus the named exceptions."""
    causes, named, ranges = {}, {}, []
    for line in CATALOGUE.read_text().splitlines():
        line = line.split("#")[0].strip()
        if not line:
            continue
        f = line.split()
        cause, rest = f[0], f[1:]
        if len(rest) == 2 and all(re.fullmatch("[0-9A-Fa-f]{4,6}", x)
                                  for x in rest):
            ranges.append((int(rest[0], 16), int(rest[1], 16), cause))
            causes.setdefault(cause, set())
        elif rest and rest[0].startswith("U+"):
            for cp in rest:
                named[int(cp[2:], 16)] = cause
            causes.setdefault(cause, set())
        else:
            for name in rest:
                if name not in GCB_NAMES:
                    sys.exit("wcwidth: %s: %r is not a "
                             "Grapheme_Cluster_Break value"
                             % (CATALOGUE.name, name))
            causes[cause] = set(rest)
    for want in ("cluster", "jamo", "mark", "ambiguous", "filler"):
        if want not in causes:
            sys.exit("wcwidth: %s has no `%s` cause, and the check below "
                     "names it" % (CATALOGUE.name, want))
    if len(ranges) < 300:
        sys.exit("wcwidth: %s has %d code-point range(s), which is too few "
                 "to be UAX #11's Ambiguous set beside the spacing marks -- a "
                 "class with no members excuses nothing and hides everything"
                 % (CATALOGUE.name, len(ranges)))
    return causes, named, ranges


def write_classes():
    """Rewrite the `mark` and `ambiguous` ranges from the pinned database.

    Both sets move with the Unicode version, and the database is fetched and
    never committed (ADR-0189), so this is a step a *refresh* takes and not
    something the gate can do for itself on a machine that has no UCD.
    """
    ucd = ROOT / "runtime" / "unicode" / "ucd"
    eaw, udata = ucd / "EastAsianWidth.txt", ucd / "UnicodeData.txt"
    for f in (eaw, udata):
        if not f.is_file():
            sys.exit("wcwidth: %s is not there; runtime/unicode/fetch.py puts "
                     "it in place" % f)

    def coalesce(rows):
        rows.sort()
        out = []
        for lo, hi in rows:
            if out and out[-1][1] + 1 == lo:
                out[-1][1] = hi
            else:
                out.append([lo, hi])
        return out

    amb = []
    for line in eaw.read_text(encoding="utf-8").splitlines():
        line = line.split("#")[0].strip()
        if not line:
            continue
        span, value = [f.strip() for f in line.split(";")[:2]]
        if value.split()[0] != "A":
            continue
        ends = span.split("..")
        amb.append([int(ends[0], 16), int(ends[-1], 16)])

    # A `<..., First>` line and the `<..., Last>` after it are one range, the
    # way `runtime/unicode/generate.py` reads the same file.
    mc, first = [], None
    for line in udata.read_text(encoding="utf-8").splitlines():
        f = line.split(";")
        cp = int(f[0], 16)
        if f[1].endswith(", First>"):
            first = (cp, f[2])
            continue
        if f[1].endswith(", Last>"):
            if first[1] == "Mc":
                mc.append([first[0], cp])
            first = None
            continue
        if f[2] == "Mc":
            mc.append([cp, cp])

    amb, mc = coalesce(amb), coalesce(mc)
    # Anchored on a line start: the word `mark` also appears in the prose
    # above, and cutting there once ate half the catalogue's explanation.
    text = CATALOGUE.read_text()
    lines = text.splitlines(True)
    for n, line in enumerate(lines):
        if line.startswith("mark ") or line.startswith("ambiguous "):
            break
    else:
        sys.exit("wcwidth: %s has no generated ranges to replace"
                 % CATALOGUE.name)
    head = "".join(lines[:n])
    CATALOGUE.write_text(
        head
        + "".join("mark %04X %04X\n" % (lo, hi) for lo, hi in mc)
        + "".join("ambiguous %04X %04X\n" % (lo, hi) for lo, hi in amb))
    print("wcwidth: wrote %d spacing-mark and %d Ambiguous range(s) to %s"
          % (len(mc), len(amb), CATALOGUE.name))
    return 0


def main():
    if "--write-classes" in sys.argv[1:]:
        return write_classes()
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
    gcb = breaks()
    causes, named, ranges = catalogued()
    byrange = bytearray(0x110000)
    order = sorted(causes)
    for lo, hi, cause in ranges:
        for cp in range(lo, hi + 1):
            byrange[cp] = order.index(cause) + 1
    by_gcb = {}
    for cause, names in causes.items():
        for name in names:
            by_gcb[GCB_NAMES.index(name)] = cause

    compared = 0
    counts = {}
    unexplained = []
    for line in answers.splitlines():
        a, b = line.split()
        cp, w = int(a, 16), int(b)
        # -1 is "no printable width in this locale", which is a statement
        # about the locale and not about the character.  Unassigned code
        # points answer it, and so does anything the charmap omits.
        if w < 0:
            continue
        compared += 1
        if mine[cp] == w:
            continue
        if cp in named:
            cause = named[cp]
        elif gcb[cp] in by_gcb:
            cause = by_gcb[gcb[cp]]
        elif byrange[cp]:
            cause = order[byrange[cp] - 1]
        else:
            cause = None
        if cause is None:
            unexplained.append((cp, mine[cp], w))
        else:
            counts[cause] = counts.get(cause, 0) + 1

    if compared < LEAST_COMPARED:
        print("wcwidth: only %d code point(s) had a width in this locale, "
              "under the floor of %d -- the comparison would be about the "
              "locale rather than about the table"
              % (compared, LEAST_COMPARED), file=sys.stderr)
        return 1

    # Report every uncatalogued disagreement whether or not it is fatal: a
    # handful is this library's age showing and is worth seeing, and a person
    # reading the log is the only thing that can tell that from the beginning
    # of something else.
    for cp, o, t in unexplained[:20]:
        print("wcwidth: U+%04X disagrees for no catalogued reason: "
              "AP 6.4.15.13 says %d, wcwidth says %d, and its "
              "Grapheme_Cluster_Break is %s"
              % (cp, o, t, GCB_NAMES[gcb[cp]]),
              file=sys.stderr if len(unexplained) > UNEXPLAINED_MAX
              else sys.stdout)
    if len(unexplained) > 20:
        print("wcwidth: ...and %d more" % (len(unexplained) - 20),
              file=sys.stderr if len(unexplained) > UNEXPLAINED_MAX
              else sys.stdout)
    if len(unexplained) > UNEXPLAINED_MAX:
        print("wcwidth: %d code point(s) disagree for no catalogued reason, "
              "over the bound of %d -- that is too many to be one C library "
              "being a Unicode release or two behind, and is the shape a "
              "systematic transcription error takes"
              % (len(unexplained), UNEXPLAINED_MAX), file=sys.stderr)
        return 1

    # A cause nothing exercises is not a failure and is worth saying: two C
    # libraries decide these differently, so a cause with no code points here
    # is one this machine's library happens to agree about.  Reporting it is
    # what keeps the catalogue from quietly describing nobody.
    idle = sorted(c for c in causes if c not in counts)
    print("wcwidth: %d code point(s) compared against the C library's own "
          "table; %s%s; %d unexplained, under the bound of %d"
          % (compared,
             ", ".join("%s %d" % (c, n) for c, n in sorted(counts.items()))
             or "no catalogued disagreement on this machine",
             "; none here from " + ", ".join(idle) if idle else "",
             len(unexplained), UNEXPLAINED_MAX))
    return 0


if __name__ == "__main__":
    sys.exit(main())
