#!/usr/bin/env bash
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

# Fetch the Unicode Character Database into runtime/unicode/ucd (gitignored).
#
# What is committed here is what this reads *out* of the UCD --
# runtime/pasrt_unicode_data.h, some 5500 lines of tables -- and not the UCD
# itself. That follows seed/pascalc.ll rather than tests/bsi/suite: the
# Unicode licence does permit redistribution, so this is a size and a
# provenance decision and not a licensing one. The generated header is the
# artefact a build needs; the database is what a *refresh* needs, and a refresh
# happens when the version moves.
#
# The version is pinned. An oracle that changes under you is not one, and the
# elements of a text value and the equality of two of them both move with the
# Unicode version (AP 6.4.15.12) -- so "whatever is current today" would make a
# red bar ambiguous between a defect here and a character that changed class
# upstream.
#
#   runtime/unicode/fetch.sh              fetch the pinned version
#   runtime/unicode/fetch.sh 16.0.0       fetch another, to compare
#
# Then runtime/unicode/generate.py rewrites the header, and
# `ctest -R unicode-conformance` runs the two test files against it.

set -euo pipefail

# ADR-0189 and AP 6.4.15.12. Moving this is a decision with a record, not an
# upgrade: doc/implementation-defined.md states the version a program is
# entitled to know, and the conformance gate is what says the move was clean.
PINNED=17.0.0

version=${1:-$PINNED}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
dest=$here/ucd
base=https://www.unicode.org/Public/$version/ucd

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
#   NormalizationTest.txt        the oracle for normalisation
#   auxiliary/GraphemeBreakTest.txt  the oracle for segmentation
files=(
  UnicodeData.txt
  DerivedNormalizationProps.txt
  DerivedCoreProperties.txt
  NormalizationTest.txt
  auxiliary/GraphemeBreakProperty.txt
  auxiliary/GraphemeBreakTest.txt
  emoji/emoji-data.txt
)

mkdir -p "$dest/auxiliary" "$dest/emoji"
echo "$version" > "$dest/VERSION"

for f in "${files[@]}"; do
  echo "fetching $f"
  curl -fsSL "$base/$f" -o "$dest/$f"
done

echo
echo "unicode: $version in $dest"
echo "next: python3 runtime/unicode/generate.py"
