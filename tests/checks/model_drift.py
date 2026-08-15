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

"""CodeGen changed, so verify/ must change or the change must say why not.

This is doc/sop.md's gate A1, made mechanical. verify/lowering.py is a *model*
of the code generator; the rules prove that model against a property-style
statement of the standard, and **neither of them touches the compiler**. So a
lowering that changes without its model does not fail anything -- the proofs go
on passing, about a compiler that no longer exists.

That is not hypothetical here. v1.1.0 applied §6.7.1 to succ and pred, and
verify/ went on asserting for a release that a subrange runs out at its own last
value. Three docstrings said so in as many words and 43 rules stayed green.

The check cannot decide *which* CodeGen changes touch a modelled lowering --
that is a judgement -- so it asks for the judgement to be written down:

    Model-unchanged: <why this lowering has no rule, or affects none>

as a trailer in the commit message. One line, and it is the line a reviewer
reads first. Copying it thoughtlessly defeats the check, which is true of every
process gate; what it buys is that nobody changes a lowering without being
asked the question.

Usage:

    python3 tests/checks/model_drift.py <base> [head]
    python3 tests/checks/model_drift.py            # origin/main..HEAD
"""

import re
import subprocess
import sys

TRAILER = re.compile(r"^Model-unchanged:\s*\S", re.MULTILINE)

# The banner that opens the code generator inside the one source file. Found by
# text rather than by line number, because the line number moves with every
# change and this check would then be measuring the wrong thing.
CODEGEN_BANNER = "CodeGen -- the annotated tree, written out as textual LLVM IR"

COMPILER = "selfhost/compiler.pas"


def run(*args):
    return subprocess.run(args, capture_output=True, text=True,
                          check=True).stdout


def codegen_starts_at(rev):
    """The line the code generator begins on, in the *new* revision -- so a
    hunk's new-file line number can be compared against it."""
    src = run("git", "show", f"{rev}:{COMPILER}")
    for n, line in enumerate(src.splitlines(), 1):
        if CODEGEN_BANNER in line:
            return n
    raise SystemExit(
        f"model-drift: the CodeGen banner is not in {COMPILER} at {rev}.\n"
        "If the file was reorganised, update CODEGEN_BANNER in this script --"
        " a check that cannot find its landmark must fail loudly, not pass.")


def touched_codegen(base, head):
    """The new-file line numbers of hunks that land at or after the banner."""
    boundary = codegen_starts_at(head)
    diff = run("git", "diff", "-U0", f"{base}..{head}", "--", COMPILER)
    hit = []
    for m in re.finditer(r"^@@ -\S+ \+(\d+)", diff, re.MULTILINE):
        start = int(m.group(1))
        if start >= boundary:
            hit.append(start)
    return hit, boundary


def main():
    base = sys.argv[1] if len(sys.argv) > 1 else "origin/main"
    head = sys.argv[2] if len(sys.argv) > 2 else "HEAD"

    changed = run("git", "diff", "--name-only", f"{base}..{head}").split()
    if COMPILER not in changed:
        print("model-drift: the compiler did not change")
        return 0

    hunks, boundary = touched_codegen(base, head)
    if not hunks:
        print(f"model-drift: {COMPILER} changed, but not below the CodeGen "
              f"banner (line {boundary})")
        return 0

    if any(f.startswith("verify/") for f in changed):
        print(f"model-drift: CodeGen changed ({len(hunks)} hunks) and verify/ "
              "changed with it")
        return 0

    log = run("git", "log", "--format=%B", f"{base}..{head}")
    if TRAILER.search(log):
        print(f"model-drift: CodeGen changed ({len(hunks)} hunks) with no "
              "verify/ change, and the range says why")
        return 0

    print(f"model-drift: {COMPILER} changed below the CodeGen banner "
          f"(line {boundary}) at lines {', '.join(map(str, hunks[:8]))}"
          f"{' ...' if len(hunks) > 8 else ''}")
    print("            and nothing under verify/ changed.")
    print()
    print("verify/lowering.py models the code generator. The rules prove that")
    print("model against the specification -- neither touches the compiler --")
    print("so a lowering that changes without its model keeps passing while")
    print("describing a compiler that no longer exists. That has happened.")
    print()
    print("Either change the model in this range, or add a trailer saying why")
    print("this change needs none:")
    print()
    print("    Model-unchanged: emits a new statement kind; no rule covers it")
    print()
    print("See doc/sop.md gate A1.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
