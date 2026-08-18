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

The base it is handed may not be a commit at all -- see resolve_base.

Usage:

    python3 tests/checks/model_drift.py <base> [head]
    python3 tests/checks/model_drift.py            # origin/main..HEAD
"""

import re
import subprocess
import sys

TRAILER = re.compile(r"^Model-unchanged:\s*\S", re.MULTILINE)

# The regions of the one source file that a `verify/` rule can be about. Found
# by banner text rather than by line number, because the line numbers move with
# every change and this check would then be measuring the wrong thing.
#
# CodeGen is the obvious one and was the only one for a long time. The constant
# folder is here because it is a *second* implementation of the same clauses:
# §6.7.2.2's `mod` and `div`, and the overflow conditions of §6.7.2.2 and
# Annex D, are decided once in the emitted code and again in Sema for an
# expression that folds. The two have disagreed -- ADR-0077 found the folder
# refusing a negative `mod` divisor while the code it emitted did not -- and a
# regression in the folder is caught by neither the rules (which model the
# lowering) nor this gate as it was.
#
# An end banner means the region is the section and not "everything after it";
# CodeGen has none because it runs to the end of the file.
REGIONS = [
    ("CodeGen",
     "CodeGen -- the annotated tree, written out as textual LLVM IR",
     None),
    ("the constant folder",
     "------- constant folding }",
     "------ type resolution -- }"),
]

COMPILER = "selfhost/compiler.pas"

# What has to change with a lowering. A `verify/` path is not enough: the
# proofs are about `lowering.py`, and editing verify/README.md discharged this
# gate until the test was narrowed.
MODEL = "verify/lowering.py"


def run(*args):
    return subprocess.run(args, capture_output=True, text=True,
                          check=True).stdout


def is_commit(rev):
    """Whether `rev` names a commit that is actually in this repository.

    The peel to `^{commit}` is the whole point. `git rev-parse --verify` given
    a full 40-hex string exits 0 without ever looking the object up, so the
    obvious spelling of this question answers yes for a commit that is not
    here.
    """
    if not rev:
        return False
    return subprocess.run(("git", "cat-file", "-e", f"{rev}^{{commit}}"),
                          capture_output=True).returncode == 0


def resolve_base(base, head):
    """The base to judge from, given the one the caller reported.

    A push does not always report a usable one. A new branch reports nothing
    and a tag reports all zeros, which are the easy cases; a **force-push**
    reports a real SHA that the rewrite discarded, which is not, because it
    looks exactly like a good one. Rewriting every commit message in this
    repository is what turned that into a CI failure (run 32131932455): the
    workflow asked `git rev-parse --verify`, was told yes, and died in
    `git diff` a moment later.

    With no range to judge, fall back to the single commit rather than guessing
    at one -- a check with no range must not invent one, and must not silently
    pass a lowering change either. A head with no parent falls back further, to
    the empty tree, so that the range is everything rather than an exception.
    """
    if is_commit(base):
        return base
    fallback = f"{head}^"
    if not is_commit(fallback):
        fallback = run("git", "hash-object", "-t", "tree", "/dev/null").strip()
    print(f"model-drift: the reported base {base or '(none)'} is not a commit "
          f"here, so the range is {fallback}..{head}")
    return fallback


def region_bounds(rev):
    """Each watched region as (name, first line, last line) in the *new*
    revision -- so a hunk's new-file line number can be compared against it."""
    lines = run("git", "show", f"{rev}:{COMPILER}").splitlines()
    bounds = []
    for name, opener, closer in REGIONS:
        start = next((n for n, l in enumerate(lines, 1) if opener in l), None)
        if start is None:
            raise SystemExit(
                f"model-drift: the banner for {name} is not in {COMPILER} at "
                f"{rev}.\nIf the file was reorganised, update REGIONS in this "
                "script -- a check that cannot find its landmark must fail "
                "loudly, not pass.")
        end = len(lines)
        if closer is not None:
            end = next((n for n, l in enumerate(lines, 1)
                        if n > start and closer in l), None)
            if end is None:
                raise SystemExit(
                    f"model-drift: {name} has no closing banner in {COMPILER} "
                    f"at {rev}. Update REGIONS in this script.")
            end -= 1
        bounds.append((name, start, end))
    return bounds


def touched_regions(base, head):
    """The watched regions this range edited, each with the hunk lines."""
    bounds = region_bounds(head)
    diff = run("git", "diff", "-U0", f"{base}..{head}", "--", COMPILER)
    hit = {name: [] for name, _, _ in bounds}
    for m in re.finditer(r"^@@ -\S+ \+(\d+)", diff, re.MULTILINE):
        start = int(m.group(1))
        for name, lo, hi in bounds:
            if lo <= start <= hi:
                hit[name].append(start)
    return {k: v for k, v in hit.items() if v}, bounds


def main():
    base = sys.argv[1] if len(sys.argv) > 1 else "origin/main"
    head = sys.argv[2] if len(sys.argv) > 2 else "HEAD"
    base = resolve_base(base, head)

    changed = run("git", "diff", "--name-only", f"{base}..{head}").split()
    if COMPILER not in changed:
        print("model-drift: the compiler did not change")
        return 0

    hit, bounds = touched_regions(base, head)
    where = ", ".join(f"{n} ({lo}-{hi})" for n, lo, hi in bounds)
    if not hit:
        print(f"model-drift: {COMPILER} changed, but not in a modelled "
              f"region -- {where}")
        return 0

    what = "; ".join(f"{name}, {len(lines)} hunks" for name, lines in
                     hit.items())
    if MODEL in changed:
        print(f"model-drift: {what} -- and {MODEL} changed with it")
        return 0

    log = run("git", "log", "--format=%B", f"{base}..{head}")
    if TRAILER.search(log):
        print(f"model-drift: {what} -- no {MODEL} change, and the range "
              "says why")
        return 0

    for name, lines in hit.items():
        print(f"model-drift: {COMPILER} changed in {name} at lines "
              f"{', '.join(map(str, lines[:8]))}"
              f"{' ...' if len(lines) > 8 else ''}")
    print(f"            and {MODEL} did not change.")
    print()
    print("verify/lowering.py models the arithmetic this compiler emits, and")
    print("the constant folder decides the same clauses a second time for an")
    print("expression that folds. The rules prove the model against the")
    print("specification -- neither touches the compiler --")
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
