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
#
# ADR-0140: the dialect reserves no word-symbol.
#
# That decision is the whole of what keeps ADR-0117's containment true, because
# a reserved word breaks it by construction: every conforming program using
# that identifier stops compiling, and no gate can repair that after the fact.
# It is also exactly how ISO 7185 and Extended Pascal came to be non-nested
# (ADR-0033), which is the mistake the dialect exists downstream of.
#
# ADR-0138's corpus sweep would catch a reserved word only where a corpus
# program happens to use that identifier as a name. This asks the question
# directly and of every word: for each spelling the compiler knows, can a
# program use it as a variable name -- and do --std=extended and
# --std=afterschool give the same answer?
#
# It fails in BOTH directions. A word the dialect starts reserving fails, and
# so does a word the dialect starts *allowing* that Extended Pascal reserves,
# since that would be the containment broken from the other side: a program
# accepted by the dialect that is not a program of the language it contains.
#
# The dialect's own four spellings are checked too, as names a program may
# still take. They are contextual keywords (ADR-0140's decision), and the
# property that makes them free is precisely that a program can shadow them.
import argparse
import pathlib
import re
import subprocess
import sys
import tempfile

# The four spellings ADR-0121, ADR-0123, ADR-0125 and ADR-0128 introduced that
# are *words*. `?` is punctuation and has no identifier form to check.
DIALECT_SPELLINGS = ["external", "int64", "optional", "slice", "maxint64"]


def keywords(source: pathlib.Path):
    """Every spelling InstallKeywords registers, in order, plus `restricted`.

    Read from the compiler's own source rather than transcribed: a list
    transcribed here would be a second copy free to drift, which is the defect
    `foreign-reserved` was written to prevent in its own area (ADR-0121).
    """
    text = source.read_text()
    words = [m.group(1).strip().lower()
             for m in re.finditer(r"DefineKeyword\(\s*\d+,\s*'([^']*)'", text)]
    if not words:
        sys.exit("reserved-words: found no DefineKeyword calls; has the "
                 "lexer's keyword table been rewritten?")
    # A word-symbol too long for kwLit is matched separately by LookupKeyword,
    # through StrIsWide -- `restricted` is the one there is. These are read too
    # rather than the one name being written in here, because a second dialect
    # word added by that route is precisely what this gate has to see, and a
    # gate that only knows the mechanism its author expected is the shape of
    # gap doc/sop.md §7 collects.
    wide = [m.group(1).strip().lower()
            for m in re.finditer(r"StrIsWide\(s,\s*'([^']*)'", text)]
    if not wide:
        sys.exit("reserved-words: LookupKeyword's wide-spelling arm has "
                 "disappeared; `restricted` was matched there, and if the "
                 "mechanism moved this gate is now reading the wrong place.")
    return words + wide


def usable_as_a_name(pascalcc, std, word, workdir):
    """Can a program of this standard declare a variable with this spelling?"""
    src = workdir / "p.pas"
    src.write_text(
        "program p(output);\n"
        f"var {word}: integer;\n"
        f"begin {word} := 1; writeln({word}) end.\n")
    done = subprocess.run(
        [pascalcc, f"--std={std}", "-S", str(src), "-o", str(workdir / "p.ll")],
        capture_output=True, text=True)
    return done.returncode == 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pascalcc", required=True)
    ap.add_argument("--source", required=True,
                    help="selfhost/compiler.pas")
    args = ap.parse_args()

    words = keywords(pathlib.Path(args.source))
    disagree = []
    unshadowable = []

    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        for w in words:
            ep = usable_as_a_name(args.pascalcc, "extended", w, work)
            ap_ = usable_as_a_name(args.pascalcc, "afterschool", w, work)
            if ep != ap_:
                disagree.append((w, ep, ap_))
        for w in DIALECT_SPELLINGS:
            if not usable_as_a_name(args.pascalcc, "afterschool", w, work):
                unshadowable.append(w)

    print(f"reserved-words: {len(words)} word-symbols, "
          f"{len(DIALECT_SPELLINGS)} dialect spellings")

    if disagree:
        for w, ep, ap_ in disagree:
            if ap_:
                print(f"  FAIL: '{w}' is reserved by Extended Pascal and is a "
                      f"usable name in the dialect -- the dialect accepts a "
                      f"program that is not one of the language it contains")
            else:
                print(f"  FAIL: '{w}' is a usable name in Extended Pascal and "
                      f"is reserved by the dialect -- ADR-0140 says the "
                      f"dialect reserves no word-symbol, and this breaks "
                      f"ADR-0117's containment for every program using it")
        print("        Spell the feature in a position where a conforming "
              "program could not have written it (ADR-0140), or write the "
              "record that says why that is impossible here.")
        return 1

    if unshadowable:
        for w in unshadowable:
            print(f"  FAIL: '{w}' can no longer be a program's own name. It is "
                  f"a contextual keyword or a required identifier, and "
                  f"§6.1.3's shadowing is what makes it free")
        return 1

    print("  ok   the dialect reserves exactly what Extended Pascal does, "
          "and every dialect spelling is still a name a program may take")
    return 0


if __name__ == "__main__":
    sys.exit(main())
