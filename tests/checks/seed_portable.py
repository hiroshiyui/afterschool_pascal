#!/usr/bin/env python3
# Afterschool Pascal -- a Pascal compiler written in Pascal.
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
# Does the committed seed name a machine? (ADR-0347)
#
# Since ADR-0293 every trap the compiler emits carries its own position, and
# the source's path is therefore a string constant *in the emitted module* --
# `@at.file`. `seed/refresh.py` translated with an absolute path, so the seed
# committed for v3.5.0 held
#
#     @at.file = ... c"/home/<user>/<...>/selfhost/compiler.pas\00"
#
# and `tests/checks/seed_current.py` could then pass only in the directory that
# generated it. It failed in the tag job, which is the **one place it runs** --
# the seed is legitimately stale between releases, so that check cannot be a
# ctest case and a release is the first time anybody asks.
#
# This half can be asked on every push, and it is the half that was wrong: a
# committed artefact must not name the machine that built it. It is a much
# weaker question than `seed_current.py`'s -- it says nothing about whether the
# seed is *this* source's -- and that is the point. It would have caught this
# on the commit that introduced the positions rather than eight releases later.
#
# **This is ADR-0366's first conversion, and the pilot for the rest.** It was
# `seed_portable.sh` until 2026-09-08 and is the same question asked the same
# way: what the record requires of a conversion is that both versions produce
# byte-identical output on the current tree *and* that the gate's own mutation
# still fails the same way, and both were run before the shell version was
# removed. What changed besides the language is one thing worth naming: the
# shell version wrote its matches to `.seed-portable.tmp` **in the repository
# root**, which is a harness leaving a file in the tree it is measuring. There
# is no temporary file here.
#
# Usage:  tests/checks/seed_portable.py

import re
import sys
from pathlib import Path

# A string constant whose first character is `/`. Every path this compiler
# embeds is a source path, and a relative one is what a reproducible seed
# holds; nothing else in the language puts a leading slash in a constant.
#
# Matched per line, as `grep` matched it: a `"` may not be crossed, and a line
# may not be either.
ABSOLUTE = re.compile(r'c"/[^"]*"')

# So a run that globbed nothing cannot pass by comparing nothing -- the empty
# comparison this repository has been caught by before (ADR-0282).
FLOOR = 3


def absolute_paths(ll):
    """Every embedded absolute path in one module, in the order it holds them."""
    out = []
    with open(ll, encoding="utf-8", errors="replace") as f:
        for line in f:
            out.extend(ABSOLUTE.findall(line))
    return out


def main():
    root = Path(__file__).resolve().parent.parent.parent
    modules = sorted((root / "seed").glob("*.ll"))
    if not modules:
        print("seed-portable: no seed modules found", file=sys.stderr)
        return 1

    status = 0
    for ll in modules:
        held = absolute_paths(ll)
        if held:
            print(f"seed-portable: {ll.relative_to(root)} holds an absolute "
                  "path:", file=sys.stderr)
            for one in held[:3]:
                print(one, file=sys.stderr)
            print("  The seed names the machine that generated it, so",
                  file=sys.stderr)
            print("  tests/checks/seed_current.py can pass only there.",
                  file=sys.stderr)
            print("  seed/refresh.py translates from the root with a relative",
                  file=sys.stderr)
            print("  source path; reseed with it (ADR-0347).", file=sys.stderr)
            status = 1

    if len(modules) < FLOOR:
        print(f"seed-portable: only {len(modules)} seed module(s) swept, "
              f"below the floor of {FLOOR}", file=sys.stderr)
        return 1

    if status:
        return 1
    print(f"seed-portable: {len(modules)} seed modules, and none names a "
          "machine")
    return 0


if __name__ == "__main__":
    sys.exit(main())
