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

"""Fetch the Unicode Character Database into runtime/unicode/ucd (gitignored).

What is committed here is what this reads *out* of the UCD --
runtime/pasrt_unicode_data.h, some 5500 lines of tables -- and not the UCD
itself. That follows seed/*.ll rather than tests/bsi/suite: the
Unicode licence does permit redistribution, so this is a size and a
provenance decision and not a licensing one. The generated header is the
artefact a build needs; the database is what a *refresh* needs, and a refresh
happens when the version moves.

The version is pinned. An oracle that changes under you is not one, and the
elements of a text value and the equality of two of them both move with the
Unicode version (AP 6.4.15.12) -- so "whatever is current today" would make a
red bar ambiguous between a defect here and a character that changed class
upstream.

  runtime/unicode/fetch.py              fetch the pinned version
  runtime/unicode/fetch.py 16.0.0       fetch another, to compare

Then runtime/unicode/generate.py rewrites the header, and
`ctest -R unicode-conformance` runs the two test files against it.

Converted from runtime/unicode/fetch.py under ADR-0366. The download is
urllib rather than curl, so a *failed* fetch says so in this script's own
words instead of the C library's and the transfer tool's; everything a
successful run writes is unchanged.
"""

import os
import sys
import urllib.error
import urllib.request

# ADR-0189 and AP 6.4.15.12. Moving this is a decision with a record, not an
# upgrade: doc/implementation-defined.md states the version a program is
# entitled to know, and the conformance gate is what says the move was clean.
PINNED = "17.0.0"

# Every file is here because something reads it, and the reader is named.
#
#   UnicodeData.txt              canonical combining class, and the canonical
#                                decomposition mapping of every character
#   DerivedNormalizationProps.txt Full_Composition_Exclusion -- which
#                                decompositions do *not* compose back
#   auxiliary/GraphemeBreakProperty.txt  UAX #29's Grapheme_Cluster_Break
#   emoji/emoji-data.txt         Extended_Pictographic, which GB11 needs
#   DerivedCoreProperties.txt    Indic_Conjunct_Break, which GB9c needs
#                                (Unicode 15.1 and later)
#   CaseFolding.txt              full case folding, which is what makes a
#                                caseless comparison correct
#   SpecialCasing.txt            the case mappings that are not one-to-one --
#                                the German sharp s uppercasing to two letters
#   NormalizationTest.txt        the oracle for normalisation
#   auxiliary/GraphemeBreakTest.txt  the oracle for segmentation
FILES = [
    "UnicodeData.txt",
    "DerivedNormalizationProps.txt",
    "DerivedCoreProperties.txt",
    "CaseFolding.txt",
    "SpecialCasing.txt",
    "NormalizationTest.txt",
    "auxiliary/GraphemeBreakProperty.txt",
    "auxiliary/GraphemeBreakTest.txt",
    "emoji/emoji-data.txt",
]


def main():
    sys.stdout.reconfigure(line_buffering=True)
    version = sys.argv[1] if len(sys.argv) > 1 else PINNED
    here = os.path.realpath(os.path.dirname(os.path.abspath(__file__)))
    dest = os.path.join(here, "ucd")
    base = f"https://www.unicode.org/Public/{version}/ucd"

    # A destination that cannot be written is this script's own diagnostic and
    # not a traceback: the shell reached the same refusal by letting `mkdir`
    # print the C library's message, in the operator's locale, twice.
    try:
        os.makedirs(os.path.join(dest, "auxiliary"), exist_ok=True)
        os.makedirs(os.path.join(dest, "emoji"), exist_ok=True)
        with open(os.path.join(dest, "VERSION"), "w", encoding="utf-8") as f:
            f.write(version + "\n")
    except OSError as exc:
        print(f"fetch: cannot write {dest}: {exc.strerror}", file=sys.stderr)
        return 1

    for name in FILES:
        print(f"fetching {name}")
        out = os.path.join(dest, *name.split("/"))
        try:
            with urllib.request.urlopen(f"{base}/{name}") as response:
                body = response.read()
        except (urllib.error.URLError, OSError) as exc:
            # curl -fsSL is silent until it fails, and then says which URL and
            # why; so does this. The wording is this script's own -- there is
            # no transfer tool here to quote.
            print(f"fetch: cannot fetch {base}/{name}: {exc}", file=sys.stderr)
            return 1
        with open(out, "wb") as f:
            f.write(body)

    print()
    print(f"unicode: {version} in {dest}")
    print("next: python3 runtime/unicode/generate.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
