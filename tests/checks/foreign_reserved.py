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

"""Every global this compiler emits by name is a foreign name it refuses.

ADR-0121 lets a program name a linker symbol: `external 'cbrt'`. LLVM's
assembler refuses a second declaration of any global, however identical the
two are -- so a program naming one the compiler already emits is answered with
an error about a file nobody wrote. `ReservedForeignName` in
selfhost/compiler.pas turns that into a diagnostic, and it does so from a
short list of bare names, which is a second copy of what the emitter writes.

A second copy is exactly the thing that drifts, so this compares them, and it
fails in **both** directions:

  * a name the emitter writes that the predicate would let through -- the
    collision is back, and the next person to add `declare double @cbrt(double)`
    would break a program that had been compiling;
  * a name the predicate reserves that the emitter no longer writes -- the
    program is being refused something it could have had, which is the same
    rule verify/'s KNOWN_GAP has and doc/sop.md applies to five catalogues.

What it reads are the `declare` and `define` **string literals** in the
compiler source, which is where every fixed global name is written out. Names
the compiler *composes* -- the counters, and 6.13's linkage names -- are not
literals and are covered structurally instead: every one of them either holds
a dot or is a letter and digits, which is what the predicate tests for. That
half cannot drift without the naming scheme itself changing.
"""

import re
import sys
from pathlib import Path

COMPILER = Path(__file__).resolve().parents[2] / "selfhost" / "compiler.pas"

# A Pascal string literal on one line, and the LLVM globals inside it.
LITERAL = re.compile(r"'((?:[^']|'')*)'")
GLOBAL = re.compile(r"@([A-Za-z_][A-Za-z0-9_.]*)")

# The predicate's own words, read back out of the source rather than repeated
# here -- a third copy would be a third thing to drift.
PREDICATE = re.compile(
    r"function ReservedForeignName.*?\nend;", re.DOTALL)
POOL_IS = re.compile(r"PoolIs\(at, len, '([^']*)'\)")
POOL_STARTS = re.compile(r"PoolStarts\(at, len, '([^']*)'\)")

# What the predicate answers without consulting a list. Kept in step with the
# comment above it; a change to the naming scheme changes both.
COMPOSED = re.compile(r"[ps][0-9]+\Z")


def emitted_names(text):
    """Every fixed global name the emitter writes, from its own literals."""
    names = set()
    for line in text.splitlines():
        for lit in LITERAL.findall(line):
            if not lit.startswith("declare ") and not lit.startswith("define "):
                continue
            names.update(GLOBAL.findall(lit))
    return names


def predicate_words(text):
    body = PREDICATE.search(text)
    if body is None:
        raise SystemExit(
            "foreign-reserved: ReservedForeignName is not in "
            f"{COMPILER.name}.\nIf it was renamed, update this check -- a "
            "check that cannot find what it is about must fail loudly, not "
            "pass.")
    body = body.group(0)
    exact = {w.rstrip() for w in POOL_IS.findall(body)}
    prefixes = {w.rstrip() for w in POOL_STARTS.findall(body)}
    if not exact or not prefixes:
        raise SystemExit(
            "foreign-reserved: ReservedForeignName names no words this check "
            "can read. Update the check, or the predicate.")
    return exact, prefixes


def covered(name, exact, prefixes):
    return ("." in name
            or COMPOSED.match(name) is not None
            or any(name.startswith(p) for p in prefixes)
            or name in exact)


def main():
    text = COMPILER.read_text(encoding="utf-8")
    emitted = emitted_names(text)
    exact, prefixes = predicate_words(text)

    leaked = sorted(n for n in emitted if not covered(n, exact, prefixes))
    stale = sorted(w for w in exact if w not in emitted)

    for n in leaked:
        print(f"foreign-reserved: the emitter writes @{n} and "
              "ReservedForeignName would let a program declare it")
    for w in stale:
        print(f"foreign-reserved: ReservedForeignName reserves '{w}' and the "
              "emitter no longer writes it")

    if leaked or stale:
        print()
        print("ADR-0121: a foreign name that is also one this compiler emits")
        print("makes LLVM refuse the module, with a message about a file")
        print("nobody wrote. The predicate is what turns that into a")
        print("diagnostic, and it is a second copy of this list -- so add the")
        print("new name to it, or stop reserving the one that went away.")
        return 1

    print(f"foreign-reserved: {len(emitted)} emitted names, "
          f"{len(exact)} reserved by name and "
          f"{len(prefixes)} by prefix -- all accounted for")
    return 0


if __name__ == "__main__":
    sys.exit(main())
