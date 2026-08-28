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

"""Every diagnostic the compiler can write is named by some golden file.

doc/sop.md §5 argues why this is worth enforcing rather than remembering: a
message no test names is a message nothing checks, and this corpus has been
opened by exactly that gap every time anyone has counted -- no file had a tab,
no file had a parse error, Sema reached 48 of its 85 messages, and a conformance
sweep found 32 messages unreached at once.

Failing in **both directions** is deliberate, and it is verify/'s KNOWN_GAP rule
applied to a different catalogue (ADR-0013): a message listed as unreachable
that acquires a golden is as loud as a new message with none. The first means
the compiler changed and the list now describes one that no longer exists; the
second means coverage was lost. Neither should be discovered later.

Run it from anywhere:

    python3 tests/checks/diagnostic_coverage.py [repo-root]
"""

import pathlib
import re
import sys

# --help text, the driver's own messages and the two capacity limits are not
# diagnostics about a program being compiled and have no golden by design.
# Without this the sweep prints thirty lines of usage text and reads as thirty
# gaps -- and a check that cries wolf gets ignored, which is worse than no
# check. The filter is therefore part of the tool, not a convenience.
NOT_A_DIAGNOSTIC = re.compile(
    r"^ {4,}"                                  # --help, which is indented
    r"|^\s*(-|clang out|It writes|not link|output, and|assembling"
    r"|tools/pascalcc|usage:|Afterschool|pascalc:|pascalc \("
    r"|out of string space|too many tokens)"
)

# A message shorter than this is a fragment shared by several diagnostics --
# "found ", "expected " -- and matching it against the goldens would say
# nothing about whether any particular message was reached.
MIN_LENGTH = 20


# The compiler is three program-components (ADR-0233), and a message is a
# message wherever it is written: ApFront reports what Sema found and the
# program reports what the code generator did. Reading one of the three would
# have made every message in the other two look unreachable -- which is how
# this gate failed on the day of the split, four entries of the catalogue at
# once, in the direction that says "the argument was wrong".
SOURCES = ("aptypes.pas", "apfront.pas", "compiler.pas")


def messages(root):
    """Every string literal the compiler writes that is long enough to be a
    diagnostic of its own, with the component and line it is written on."""
    out = {}
    for name in SOURCES:
        src = (root / "selfhost" / name).read_text()
        for m in re.finditer(r"write(?:ln)?\('([^']{%d,})'" % MIN_LENGTH, src):
            out.setdefault(m.group(1), f"{name}:{src[: m.start()].count(chr(10)) + 1}")
    return out


def goldens(root):
    """Everything every .err file records, as one blob. A message is 'named'
    when it appears in one -- which is a weaker claim than a test asserting it
    fires for the right reason, and the strongest one that can be made
    mechanically."""
    return "\n".join(
        p.read_text()
        for d in ("tests", "selfhost")
        for p in (root / d).rglob("*.err")
    )


def allowed(root):
    """The messages accepted as unreachable, each with the argument for it.

    An entry is `= ` followed by the message exactly, so leading spaces --
    which several messages have, being the tail of a two-part diagnostic --
    survive. Everything else is commentary."""
    path = root / "tests" / "checks" / "unreachable_diagnostics.txt"
    return {
        line[2:].rstrip("\n")
        for line in path.read_text().splitlines()
        if line.startswith("= ")
    }


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1
                        else pathlib.Path(__file__).resolve().parents[2])
    msgs = messages(root)
    blob = goldens(root)
    listed = allowed(root)

    uncovered = {m for m in msgs
                 if m not in blob and not NOT_A_DIAGNOSTIC.match(m)}

    missing = sorted(uncovered - listed)
    revived = sorted(listed - uncovered)

    for m in missing:
        print(f"no golden names this diagnostic ({msgs[m]}):")
        print(f"    {m!r}")
    for m in revived:
        print("listed as unreachable, but a golden now names it -- either the "
              "compiler changed or the argument was wrong:")
        print(f"    {m!r}")

    if missing or revived:
        print()
        print(f"diagnostic-coverage: {len(missing)} unnamed, "
              f"{len(revived)} wrongly listed as unreachable")
        print("Write a case, or -- if the branch genuinely cannot fire -- "
              "comment it at its site with what would have to change, and add "
              "it to tests/checks/unreachable_diagnostics.txt with that "
              "argument. See doc/sop.md §5.")
        return 1

    print(f"diagnostic-coverage: {len(msgs)} messages, "
          f"{len(listed)} argued unreachable, none unnamed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
