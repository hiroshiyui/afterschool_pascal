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

r"""Every Markdown table in this tree is a table.

This exists because three were not, and none of them was visible to anything.
`CLAUDE.md`'s gate list -- the file loaded into every session before any work
starts -- had one row split in half by another row wedged between its two
pieces, and `doc/sop.md` had a row broken across two lines, which Markdown
renders as a mangled row followed by a paragraph. Both are structural and both
are what this checks.

A third was found in the same pass and is **not** checkable here, which is
worth saying so nobody adds it: a cell held `grep -lic 'mutation\|mutant'`
inside a code span, and GFM's table rule turns `\|` into a literal `|`
wherever it appears, code span included -- so the command *rendered* as
`'mutation|mutant'`, which is a different command and a wrong one. The source
was well formed; only the reader was misled. Nothing can tell that apart from
a cell that legitimately wants a literal pipe.

**The class is what makes it worth a gate rather than a proofread.** A prose
error is one reader away from being noticed; a broken table renders as
something that still looks like documentation, and the two most-read files
here carried one each. Nothing in `doc/sop.md` §7 could have seen it, because
every oracle in this repository reads Pascal, C or a golden.

What it checks is deliberately narrow: within one table, every row has the
number of cells the header row has, and every row begins with `|`. It does not
lint style, alignment or width -- there is no Markdown formatter here and
introducing one would be a change to 265 files rather than a check.

    markdown_tables.py [root]
"""

import re
import sys
from pathlib import Path

# `doc/vendor/` is the two standards, which are not ours to reformat and are
# gitignored anyway; `build/` is generated.
SKIP = ("build", "doc/vendor")

SEPARATOR = re.compile(r"\s*\|?[\s:|-]+\|[\s:|-]*")


def cells(row):
    """How many cells a table row has.

    A `|` escaped as `\\|` is content and not a separator -- GFM's own rule,
    and the one the code-span defect above got wrong."""
    return len(re.split(r"(?<!\\)\|", row.strip().strip("|"))) if row.strip() else 0


def check(path):
    bad = []
    lines = path.read_text(encoding="utf-8").split("\n")
    i = 0
    while i < len(lines):
        header, nxt = lines[i], lines[i + 1] if i + 1 < len(lines) else ""
        if header.count("|") >= 2 and "-" in nxt and SEPARATOR.fullmatch(nxt or " "):
            want = cells(header)
            i += 2
            while i < len(lines) and lines[i].strip():
                row = lines[i].strip()
                if not row.startswith("|"):
                    bad.append((i + 1, f"row does not begin with '|' -- a table "
                                       f"row is one line, and this is a "
                                       f"continuation: {row[:60]}"))
                elif cells(row) != want:
                    bad.append((i + 1, f"{cells(row)} cells where the header has "
                                       f"{want} -- an unescaped '|' in the text, "
                                       f"or a row from another table"))
                i += 1
        else:
            i += 1
    return bad


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    files = sorted(p for p in root.rglob("*.md")
                   if not str(p.relative_to(root)).startswith(SKIP))
    problems = 0
    tables = 0
    for p in files:
        text = p.read_text(encoding="utf-8").split("\n")
        tables += sum(1 for i, l in enumerate(text[:-1])
                      if l.count("|") >= 2 and "-" in text[i + 1]
                      and SEPARATOR.fullmatch(text[i + 1] or " "))
        for line, why in check(p):
            print(f"{p.relative_to(root)}:{line}: {why}")
            problems += 1
    if problems:
        print()
        print(f"markdown-tables: {problems} malformed row(s). A table row is "
              f"one line, and a '|' in the text must be written '\\|'.")
        return 1
    print(f"markdown-tables: {tables} tables across {len(files)} files, "
          f"every row the width of its header")
    return 0


if __name__ == "__main__":
    sys.exit(main())
