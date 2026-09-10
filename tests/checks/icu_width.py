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

"""Does ICU read the width properties the same way? (ADR-0400)

AP 6.4.15.13's table is generated from `EastAsianWidth.txt` and
`UnicodeData.txt`, and East_Asian_Width is the one property in this tree with
no conformance file Unicode publishes -- so `unicode-conformance` regenerating
the header and diffing it checks that the *generator* is stable, which is a
different claim from the table being right.

**ICU is a second reading of the same two files by another project**, and it
is the right one to compare against for a reason that is a property of the
oracle rather than a preference: it exposes `UCHAR_EAST_ASIAN_WIDTH` and
`u_charType` -- the *properties* the clause is written over -- and it says
which Unicode version it was built from.  So this compares what the clause
compares and can **abstain** when the versions differ, which is what makes
exact agreement a claim worth making.

That matters because the first two versions of this gate compared against the
C library's `wcwidth` and could make no such claim.  `wcwidth` answers a
*width*, which is that library's own policy about characters the standard
leaves open; it names no version; and every machine has one, all different.
Three red builds went into discovering that a differential oracle against a
system library can bound divergence and cannot forbid it.  ICU has none of
those problems: 1 112 064 code points, exact agreement, no catalogue of
excuses at all.

Skips 77 without ICU or when its Unicode version is not the pinned one;
`ICU_WIDTH_REQUIRE` refuses to pass by skipping.
"""

import os
import pathlib
import re
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
HEADER = ROOT / "runtime" / "pasrt_unicode_data.h"
FETCH = ROOT / "runtime" / "unicode" / "fetch.py"

# AP 6.4.15.13 written in ICU's vocabulary, and written *here* rather than
# read out of the header -- the whole value of a differential is that the two
# sides arrive at the answer independently.  a) Wide and Fullwidth take two
# cells; b) a nonspacing or enclosing mark, a format character or a control
# takes none; c) everything else takes one.
PROBE = r"""
#include <stdio.h>
#include <unicode/uchar.h>
#include <unicode/uversion.h>

int main(void) {
  UVersionInfo v;
  char s[U_MAX_VERSION_STRING_LENGTH];
  UChar32 cp;

  u_getUnicodeVersion(v);
  u_versionToString(v, s);
  printf("unicode %s\n", s);

  for (cp = 0; cp < 0x110000; cp++) {
    int ea, gc, w;
    if (cp >= 0xD800 && cp <= 0xDFFF)
      continue;   /* not a scalar value; AP 6.4.15.1 */
    ea = u_getIntPropertyValue(cp, UCHAR_EAST_ASIAN_WIDTH);
    gc = u_charType(cp);
    w = (ea == U_EA_WIDE || ea == U_EA_FULLWIDTH) ? 2 : 1;
    if (gc == U_NON_SPACING_MARK || gc == U_ENCLOSING_MARK ||
        gc == U_FORMAT_CHAR || gc == U_CONTROL_CHAR)
      w = 0;
    printf("%X %d\n", cp, w);
  }
  return 0;
}
"""

# Every scalar value there is, less the surrogates.  A floor rather than a
# count, so a probe that stopped early is a failure and not a pass (ADR-0282).
LEAST_COMPARED = 0x110000 - 0x800


def skip(message, required=True):
    """Skip, and let `ICU_WIDTH_REQUIRE` turn it into a failure -- unless the
    reason is one that variable has no business overriding.

    **A missing ICU is a job that was set up wrong** and the variable is there
    to say so. **A version mismatch is not**: two readings of different
    releases of the database are not a disagreement about the reading, and a
    machine whose ICU predates the pinned Unicode cannot answer this question
    however loudly it is asked. That is an abstention in ADR-0282's sense --
    say what could not be measured rather than measure something else -- and
    forcing it to fail would make the gate report a defect in Debian's
    packaging schedule.
    """
    if required and os.environ.get("ICU_WIDTH_REQUIRE"):
        print("icu-width: %s, and ICU_WIDTH_REQUIRE is set" % message,
              file=sys.stderr)
        return 1
    print("icu-width: skipped -- %s" % message)
    return 77


def pinned():
    """The Unicode version this tree is generated from."""
    m = re.search(r'^PINNED = "([0-9.]+)"',
                  FETCH.read_text(), re.M)
    if not m:
        sys.exit("icu-width: no PINNED version in %s" % FETCH)
    return m.group(1)


def ours():
    """The width of every code point, from the committed header.

    Absent from the table means one, which is why the table is small; reading
    it as zero is the mistake `range_lookup_or` exists to stop the C side
    making, and it would be the same mistake here.
    """
    text = HEADER.read_text()
    m = re.search(r"pas_u_width\[\] = \{(.*?)\};", text, re.S)
    if not m:
        sys.exit("icu-width: no pas_u_width table in %s" % HEADER)
    table = bytearray([1]) * 0x110000
    for lo, hi, v in re.findall(r"\{0x([0-9A-Fa-f]+), 0x([0-9A-Fa-f]+), (\d)\}",
                                m.group(1)):
        for cp in range(int(lo, 16), int(hi, 16) + 1):
            table[cp] = int(v)
    return table


def main():
    cc = os.environ.get("CC", "clang")
    # `pkg-config` is how ICU says where it is, and it is not everywhere --
    # a machine can have the headers and not the tool. Its absence is a
    # `FileNotFoundError` and not a return code, which is the sort of thing
    # that turns a skip into a traceback if it is not caught.
    flags = ["-licuuc"]
    try:
        r = subprocess.run(["pkg-config", "--cflags", "--libs", "icu-uc"],
                           capture_output=True, text=True)
        if r.returncode == 0 and r.stdout.split():
            flags = r.stdout.split()
    except OSError:
        pass

    with tempfile.TemporaryDirectory() as tmp:
        d = pathlib.Path(tmp)
        (d / "probe.c").write_text(PROBE)
        r = subprocess.run([cc, "-std=gnu11", str(d / "probe.c"),
                            "-o", str(d / "probe")] + flags,
                           capture_output=True, text=True)
        if r.returncode != 0:
            return skip("no ICU development headers a probe can be built "
                        "against")
        r = subprocess.run([str(d / "probe")], capture_output=True, text=True)
        if r.returncode != 0:
            return skip("the probe would not run: %s" % r.stderr.strip())
        answers = r.stdout

    head, _, rest = answers.partition("\n")
    if not head.startswith("unicode "):
        sys.exit("icu-width: the probe did not name a Unicode version")
    theirs = head.split()[1]
    want = pinned()

    # **The abstention, and it is the point of using ICU.** Two readings of
    # different releases of the database are not a disagreement about the
    # reading, and reporting one as a defect would be this gate answering a
    # question nobody asked. It is ADR-0282's shape: say what could not be
    # measured rather than measure something else.
    if want.split(".")[:2] != theirs.split(".")[:2]:
        return skip("ICU is built from Unicode %s and this tree is generated "
                    "from %s, so the two are not reading the same database"
                    % (theirs, want), required=False)

    mine = ours()
    compared = 0
    bad = []
    for line in rest.splitlines():
        a, b = line.split()
        cp, w = int(a, 16), int(b)
        compared += 1
        if mine[cp] != w:
            bad.append((cp, mine[cp], w))

    if compared < LEAST_COMPARED:
        print("icu-width: the probe answered for %d code point(s) and there "
              "are %d, so it stopped early and this compared a prefix"
              % (compared, LEAST_COMPARED), file=sys.stderr)
        return 1

    if bad:
        for cp, o, t in bad[:20]:
            print("icu-width: U+%04X: AP 6.4.15.13's table says %d and ICU's "
                  "properties give %d" % (cp, o, t), file=sys.stderr)
        if len(bad) > 20:
            print("icu-width: ...and %d more" % (len(bad) - 20),
                  file=sys.stderr)
        print("icu-width: %d code point(s) differ, and both sides read "
              "Unicode %s -- so one of the two transcriptions is wrong"
              % (len(bad), theirs), file=sys.stderr)
        return 1

    print("icu-width: %d code point(s) agree exactly with ICU's own reading "
          "of Unicode %s" % (compared, theirs))
    return 0


if __name__ == "__main__":
    sys.exit(main())
