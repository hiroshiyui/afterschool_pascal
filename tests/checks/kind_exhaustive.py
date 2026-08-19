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

"""Every case-statement over a type's kind names every kind.

A Pascal case-statement stops the program when no label matches (ADR-0018), so
a type kind left off one of these lists is a **compiler crash** on the first
program that reaches it -- not a wrong answer some golden could hold. That is
why no other gate here can see it: a missing arm is not a statement, so
line-coverage does not count it, and procedure-coverage asks only whether the
procedure was entered. difftest cannot report it either, because src/'s
counterparts are C++ `switch`es with a `default`, so the Pascal crashes where
the C++ answers and there is no disagreement to compare.

It has now happened twice. `StaticThroughout` listed fifteen of sixteen kinds
and omitted `tyString`, and every schema type containing a variable-string
stopped the compiler until that was found. ADR-0123 then added `tyOptional`
and the same routine crashed again, with all 578 cases, difftest, irtest,
verify, llc and the BSI suite green -- doc/sop.md §7 having named both the
hazard and the routine in advance, and having ended "a mechanical check is
cheap and is not written". This is that check.

It fails in **both** directions, which is verify/'s KNOWN_GAP rule (ADR-0013)
applied to a seventh catalogue:

  * a kind a case-statement does not name -- the crash is there, waiting;
  * a kind named by no case-statement at all, and by nothing else either --
    a kind nothing switches on is a kind that was removed from the type and
    left in the enumeration, or one added and never used.

What it does *not* do is judge whether an arm is **right**. `tyOptional:
StaticThroughout := true` would satisfy this check and be wrong. The claim is
only that every kind was considered somewhere, which is what turns a crash into
a review.
"""

import pathlib
import re
import sys

SOURCE = "selfhost/compiler.pas"

# `case <anything> kind of`, on one line, which is how every one of them is
# written. A case over something else -- a token kind, a node kind -- does not
# match, and would be a different catalogue with a different enumeration.
CASE = re.compile(r"(?<![A-Za-z0-9_])case(?![A-Za-z0-9_]).*\bkind of\s*$",
                  re.IGNORECASE)
DECL = re.compile(r"^\s*typeKind\s*=\s*\(", re.IGNORECASE)

# A case-statement's arms nest with begin/case/record, and `end` closes any of
# them. Counting words is enough once comments and string literals are gone,
# which is what strip() below is for: this source is full of prose containing
# the word "end", and a literal ')' or '}' inside quotes would close nothing.
OPENERS = ("begin", "case", "record")


def word(w):
    return re.compile(r"(?<![A-Za-z0-9_])" + w + r"(?![A-Za-z0-9_])",
                      re.IGNORECASE)


WORDS = {w: word(w) for w in OPENERS + ("end",)}


def strip(text):
    """Blank out { } comments and ' ' literals, keeping every newline.

    Line numbers have to survive, because what this reports is a line number
    in a 24,000-line file and nothing else would let a reader find the arm.
    """
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == "{":
            j = text.find("}", i)
            j = n - 1 if j < 0 else j
            out.append(re.sub(r"[^\n]", " ", text[i:j + 1]))
            i = j + 1
        elif c == "'":
            j = i + 1
            while j < n and text[j] != "'":
                j += 1
            out.append(re.sub(r"[^\n]", " ", text[i:min(j + 1, n)]))
            i = j + 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def kinds(lines):
    """The typeKind enumeration, in the order it is declared."""
    for i, line in enumerate(lines):
        if not DECL.match(line):
            continue
        text = ""
        j = i
        while j < len(lines):
            text += lines[j]
            if ")" in lines[j]:
                break
            j += 1
        inner = text[text.index("(") + 1:text.rindex(")")]
        return [n.strip() for n in inner.split(",") if n.strip()]
    return []


def arms(lines, start, names):
    """The kinds named between `case … kind of` and the `end` that closes it."""
    depth, j, seen = 1, start + 1, set()
    while j < len(lines) and depth > 0:
        for w in OPENERS:
            depth += len(WORDS[w].findall(lines[j]))
        depth -= len(WORDS["end"].findall(lines[j]))
        for name in names:
            if word(name).search(lines[j]):
                seen.add(name)
        j += 1
    return seen, j - start


def main():
    root = pathlib.Path(__file__).resolve().parents[2]
    raw = (root / SOURCE).read_text()
    lines = strip(raw).splitlines()

    names = kinds(lines)
    if not names:
        print(f"kind-exhaustive: no typeKind declaration in {SOURCE}",
              file=sys.stderr)
        return 1

    bad = []
    covered = set()
    found = 0
    for i, line in enumerate(lines):
        if not CASE.search(line):
            continue
        seen, span = arms(lines, i, names)
        # A case over a *kind* that names only one or two of them is switching
        # on something else -- a node kind, a link kind. Four is the smallest
        # any real one has, and every real one has all seventeen or is a bug.
        if len(seen) < 4:
            continue
        found += 1
        covered |= seen
        missing = [n for n in names if n not in seen]
        if missing:
            bad.append((i + 1, span, missing))

    if not found:
        print("kind-exhaustive: no case-statement over a type kind was found; "
              "the pattern this reads for must have changed", file=sys.stderr)
        return 1

    unused = [n for n in names if n not in covered]

    if bad or unused:
        for line, span, missing in bad:
            print(f"kind-exhaustive: {SOURCE}:{line} (a {span}-line case) "
                  f"does not name {', '.join(missing)}", file=sys.stderr)
            print("  a kind left off is a crash, not a wrong answer "
                  "(ADR-0018)", file=sys.stderr)
        for name in unused:
            print(f"kind-exhaustive: {name} is named by no case-statement at "
                  f"all -- it is unused, or the enumeration outlived it",
                  file=sys.stderr)
        return 1

    print(f"kind-exhaustive: {found} case-statements over {len(names)} type "
          f"kinds -- every one names every kind")
    return 0


if __name__ == "__main__":
    sys.exit(main())
