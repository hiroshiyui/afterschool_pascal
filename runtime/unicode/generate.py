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

"""runtime/pasrt_unicode_data.h, from the Unicode Character Database.

AP 6.4.15 rests on two properties of a character and this reads both out of
the database that defines them: the canonical decomposition and combining
class that Normalization Form C is computed from (6.4.15.2), and the
Grapheme_Cluster_Break value that says where one element ends (6.4.15.3).

    runtime/unicode/fetch.sh            get the pinned database
    python3 runtime/unicode/generate.py rewrite the header
    ctest -R unicode-conformance        check it against Unicode's own answers

**Nothing here decides anything.** Every table is a transcription, every
transcription names the file it came from, and the checks below are about the
*shape* the C side relies on -- that a canonical decomposition is at most two
code points, that it bottoms out, that no Hangul syllable acquired a table
entry. A property this script had an opinion about would be a property with no
oracle, which is the whole thing ADR-0189 chose this model to avoid.

The output is committed. It is the artefact a build needs, and the database is
what a *refresh* needs; runtime/unicode/fetch.sh has why the second is not in
the tree.
"""

import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
UCD = HERE / "ucd"
OUT = HERE.parent / "pasrt_unicode_data.h"

# `-o` is how `unicode-conformance` regenerates into a temporary file and diffs
# it against the committed one. A gate that wrote to the tree and put the file
# back would leave a fresh mtime behind for the next build to chase, and would
# be a gate that modifies the thing it is judging.
if len(sys.argv) == 3 and sys.argv[1] == "-o":
    OUT = pathlib.Path(sys.argv[2])
elif len(sys.argv) != 1:
    print("usage: generate.py [-o output.h]", file=sys.stderr)
    sys.exit(2)

# Hangul is composed and decomposed arithmetically (UAX #15, and The Unicode
# Standard 3.12), so its 11 172 syllables are in no table here. The C side
# carries the same constants; they are a property of the encoding and have not
# moved since Unicode 2.0.
S_BASE, L_BASE, V_BASE, T_BASE = 0xAC00, 0x1100, 0x1161, 0x11A7
L_COUNT, V_COUNT, T_COUNT = 19, 21, 28
N_COUNT = V_COUNT * T_COUNT
S_COUNT = L_COUNT * N_COUNT


def die(msg):
    print(f"generate: {msg}", file=sys.stderr)
    sys.exit(1)


def lines(name):
    p = UCD / name
    if not p.exists():
        die(f"no {p} -- run runtime/unicode/fetch.sh first")
    for raw in p.read_text(encoding="utf-8").splitlines():
        text = raw.split("#", 1)[0].strip()
        if text:
            yield text


def ranges(name, wanted):
    """Sorted (lo, hi, value) from a UCD property file, for the values wanted.

    `wanted` maps the property value's spelling to the number the C side uses.
    A line is `cp ; Value` or `lo..hi ; Value`, with a third field on the
    derived files, which is why the split takes the first two and no more.
    """
    out = []
    for text in lines(name):
        parts = [f.strip() for f in text.split(";")]
        if len(parts) < 2:
            continue
        key = tuple(parts[1:3]) if len(parts) > 2 else (parts[1],)
        value = None
        for spelling, number in wanted.items():
            if key[: len(spelling)] == spelling:
                value = number
                break
        if value is None:
            continue
        span = parts[0].split("..")
        lo = int(span[0], 16)
        hi = int(span[-1], 16)
        out.append((lo, hi, value))
    out.sort()
    return coalesce(out)


def coalesce(rs):
    """Merge ranges that touch and agree. The files are already nearly sorted
    into runs, so this is worth a few hundred entries."""
    out = []
    for lo, hi, v in rs:
        if out and out[-1][2] == v and out[-1][1] + 1 == lo:
            out[-1] = (out[-1][0], hi, v)
        else:
            out.append((lo, hi, v))
    return out


# --- UnicodeData.txt: combining class and canonical decomposition ----------

ccc = {}
decomp = {}
for text in lines("UnicodeData.txt"):
    f = text.split(";")
    cp = int(f[0], 16)
    if int(f[3]):
        ccc[cp] = int(f[3])
    mapping = f[5].strip()
    # A mapping in angle brackets is a *compatibility* decomposition and has
    # no part in Normalization Form C.
    if mapping and not mapping.startswith("<"):
        decomp[cp] = [int(x, 16) for x in mapping.split()]

if not decomp or not ccc:
    die("UnicodeData.txt yielded no decompositions -- wrong file?")
for cp, to in decomp.items():
    if len(to) > 2:
        die(f"U+{cp:04X} has a canonical decomposition of {len(to)} code "
            "points; the C side assumes at most two")

# --- DerivedNormalizationProps.txt: which decompositions do not compose ----

excluded = set()
for text in lines("DerivedNormalizationProps.txt"):
    parts = [f.strip() for f in text.split(";")]
    if len(parts) >= 2 and parts[1] == "Full_Composition_Exclusion":
        span = parts[0].split("..")
        for cp in range(int(span[0], 16), int(span[-1], 16) + 1):
            excluded.add(cp)
if not excluded:
    die("no Full_Composition_Exclusion found -- wrong file?")

# The primary composites: a canonical decomposition of exactly two, whose
# first element is a starter, which is not excluded. UAX #15's definition,
# and the exclusion file is what makes it a transcription rather than a
# reimplementation -- singletons and non-starter decompositions are already
# in it.
compose = {}
for cp, to in decomp.items():
    if len(to) == 2 and cp not in excluded:
        if ccc.get(to[0], 0) != 0:
            die(f"U+{cp:04X} composes from a non-starter but is not excluded")
        compose[(to[0], to[1])] = cp

for cp in range(S_BASE, S_BASE + S_COUNT):
    if cp in decomp:
        die("a Hangul syllable has a table entry; the C side computes it")

# How deep a canonical decomposition goes, and how wide it ends up. The C side
# decomposes into a fixed array per code point and this is what says how big it
# has to be -- measured here rather than assumed, because a released version
# that made it five would otherwise overrun quietly.
def full(cp, depth=0):
    if depth > 8:
        die(f"U+{cp:04X} decomposes in a cycle")
    if cp not in decomp:
        return [cp]
    out = []
    for x in decomp[cp]:
        out += full(x, depth + 1)
    return out


widest = max(len(full(cp)) for cp in decomp)

# **A starter is not always a boundary.** 59 primary composites have a starter
# as their *second* element -- 33 vowel signs across sixteen Indic and
# Southeast Asian scripts, where U+09C7 + U+09BE composes to the Bengali vowel
# sign O although both are of combining class zero. So the rule
# "a normalisation segment begins at every starter" is wrong, and a
# normalisation written to it drops those compositions with every conformance
# test still passing except the few lines that reach them. This is the set the
# C side excludes; Hangul V and T are the same case and are handled there,
# arithmetically, with the rest of Hangul.
back = sorted({b for (a, b) in compose if ccc.get(b, 0) == 0})
combines_back = coalesce([(cp, cp, 1) for cp in back])

# --- The break properties -------------------------------------------------

GCB = ["Other", "CR", "LF", "Control", "Extend", "ZWJ", "Regional_Indicator",
       "Prepend", "SpacingMark", "L", "V", "T", "LV", "LVT"]
gcb = ranges("auxiliary/GraphemeBreakProperty.txt",
             {(name,): i for i, name in enumerate(GCB) if name != "Other"})

INCB = ["None", "Consonant", "Extend", "Linker"]
incb = ranges("DerivedCoreProperties.txt",
              {("InCB", name): i for i, name in enumerate(INCB)
               if name != "None"})

extpict = ranges("emoji/emoji-data.txt", {("Extended_Pictographic",): 1})

for table, name in ((gcb, "Grapheme_Cluster_Break"),
                    (incb, "Indic_Conjunct_Break"),
                    (extpict, "Extended_Pictographic")):
    if not table:
        die(f"no {name} ranges found -- wrong file?")

version = (UCD / "VERSION").read_text().strip()

# --- Emit -----------------------------------------------------------------

out = []
w = out.append

w("""/* Afterschool Pascal runtime library -- Unicode character data.
 * Copyright (C) 2026 Hui-Hong You
 *
 * This library is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.
 *
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * As a special exception, if you link this library with other files to
 * produce an executable, that does not by itself cause the resulting
 * executable to be covered by the GNU General Public License.  This exception
 * does not however invalidate any other reasons why the executable file might
 * be covered by the GNU General Public License.  See COPYING.RUNTIME.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

/* GENERATED by runtime/unicode/generate.py -- do not edit.
 *
 * Every table below is a transcription of one file of the Unicode Character
 * Database, named above it. AP 6.4.15.12 makes the version implementation-
 * defined and requires the processor to state it; PAS_UNICODE_VERSION is
 * where it is stated, and doc/implementation-defined.md is where a user
 * reads it.
 *
 * Hangul is absent on purpose: its 11 172 syllables decompose and compose
 * arithmetically and pasrt_unicode.c does that, so a table would be 11 172
 * entries restating a formula. */""")
w("#ifndef APASCAL_PASRT_UNICODE_DATA_H")
w("#define APASCAL_PASRT_UNICODE_DATA_H")
w("")
w(f'#define PAS_UNICODE_VERSION "{version}"')
w("")
w("/* The longest a canonical decomposition gets, applied recursively.")
w(" * Measured from the database rather than assumed. */")
w(f"#define PAS_U_DECOMP_MAX {widest}")
w("")

w("/* A code point range carrying a small property value. Sorted and disjoint,")
w(" * so pasrt_unicode.c finds one by bisection. */")
w("struct pas_u_range {")
w("  unsigned int lo, hi;")
w("  unsigned char v;")
w("};")
w("")


def emit_ranges(name, table, comment):
    w(comment)
    w(f"static const struct pas_u_range {name}[] = {{")
    for lo, hi, v in table:
        w(f"    {{0x{lo:04X}, 0x{hi:04X}, {v}}},")
    w("};")
    w(f"#define {name.upper()}_N "
      f"(sizeof {name} / sizeof {name}[0])")
    w("")


emit_ranges("pas_u_ccc", coalesce(sorted(
    (cp, cp, v) for cp, v in ccc.items())),
    "/* Canonical_Combining_Class, from UnicodeData.txt field 3. Absent means\n"
    " * zero, which is the default and the overwhelming majority. */")

emit_ranges("pas_u_gcb", gcb,
            "/* Grapheme_Cluster_Break, from auxiliary/GraphemeBreakProperty.txt.\n"
            " * Absent means Other (0). The numbering is pasrt_unicode.c's own\n"
            " * and the two must be read together. */")

emit_ranges("pas_u_incb", incb,
            "/* Indic_Conjunct_Break, from DerivedCoreProperties.txt, which\n"
            " * UAX #29's GB9c needs. Absent means None (0). */")

emit_ranges("pas_u_combines_back", combines_back,
            "/* Starters that can be the second element of a primary\n"
            " * composite, so that a normalisation segment must NOT be taken to\n"
            " * begin at one. Derived from the composition table; Hangul V and T\n"
            " * are the same case and pasrt_unicode.c adds them. */")

emit_ranges("pas_u_extpict", extpict,
            "/* Extended_Pictographic, from emoji/emoji-data.txt, which GB11\n"
            " * needs. The value is always 1; the range list is the property. */")

w("/* Canonical decomposition, from UnicodeData.txt field 5, excluding the")
w(" * <tagged> compatibility mappings. `b` is 0 for a singleton. Sorted by")
w(" * `cp`. The mapping is applied recursively by pasrt_unicode.c. */")
w("struct pas_u_decomp {")
w("  unsigned int cp, a, b;")
w("};")
w("static const struct pas_u_decomp pas_u_decomp_tbl[] = {")
for cp in sorted(decomp):
    to = decomp[cp]
    b = to[1] if len(to) == 2 else 0
    w(f"    {{0x{cp:04X}, 0x{to[0]:04X}, 0x{b:04X}}},")
w("};")
w("#define PAS_U_DECOMP_N "
  "(sizeof pas_u_decomp_tbl / sizeof pas_u_decomp_tbl[0])")
w("")

w("/* The primary composites: a canonical decomposition of exactly two whose")
w(" * first element is a starter and which Full_Composition_Exclusion does not")
w(" * exclude (UAX #15). Sorted by (a, b). */")
w("struct pas_u_compose {")
w("  unsigned int a, b, cp;")
w("};")
w("static const struct pas_u_compose pas_u_compose_tbl[] = {")
for (a, b) in sorted(compose):
    w(f"    {{0x{a:04X}, 0x{b:04X}, 0x{compose[(a, b)]:04X}}},")
w("};")
w("#define PAS_U_COMPOSE_N "
  "(sizeof pas_u_compose_tbl / sizeof pas_u_compose_tbl[0])")
w("")
w("#endif /* APASCAL_PASRT_UNICODE_DATA_H */")

OUT.write_text("\n".join(out) + "\n")
try:
    where = OUT.relative_to(HERE.parent.parent)
except ValueError:
    where = OUT  # `-o` into a temporary directory, which the gate does
print(f"generate: Unicode {version} -> {where} ({len(out)} lines)")
print(f"  ccc {len(ccc)} code points in {len(coalesce(sorted((c, c, v) for c, v in ccc.items())))} ranges,"
      f" decomp {len(decomp)}, compose {len(compose)}")
print(f"  gcb {len(gcb)} ranges, incb {len(incb)}, extpict {len(extpict)},"
      f" combines-back {len(combines_back)}")
print(f"  a canonical decomposition is at most {widest} code points")
