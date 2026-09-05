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

"""Does every gate that can skip have a job that refuses to let it?

A gate here skips with 77 where the thing it needs is absent -- `fpc`, a 32-bit
libc, libssl, z3, llc -- because that is right for a developer's checkout and
would be wrong as a hard dependency. ctest reads 77 as success, so a skipped
gate and a clean one print the same green bar. The convention that closes it is
a `*_REQUIRE` environment variable: set it, and the skip becomes a failure.

**The convention has been shipped broken three times and nobody noticed the
third.** `doc/sop.md` §7 records `fpc-differential` landing with a
`FPC_DIFFERENTIAL_REQUIRE` no job set, and `target32` doing the same on
2026-09-05. Writing this file found `TLS_REQUIRE` in the same state since
ADR-0264 -- the only check of whether `lib/dialect/pastls.pas`'s transcribed
constants are still OpenSSL's, answering on whatever machine happened to have
libssl. And it found the other direction: the `sanitizers` job's comment named
a `SANITIZE_REQUIRE` as its refusal mechanism, and **no script read it** -- the
job refused a skip by grepping its own log, so the mechanism worked and the
sentence describing it was false.

So the check is both directions, which is this repository's rule for a
catalogue (ADR-0013):

  - every `*_REQUIRE` a check reads must be set by some job, or the gate
    answers only where its author was;
  - every `*_REQUIRE` a workflow mentions must be read by some check, or a job
    is setting a variable nothing consults and a comment is describing a
    mechanism that is not there.

It reads no Pascal and needs nothing installed, which makes it the cheapest
gate here after `markdown-tables` -- and, like that one, it watches something
no other oracle can see: every other check in this directory asks about the
compiler, and this one asks about the checks.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CHECKS = os.path.join(ROOT, "tests", "checks")
WORKFLOWS = os.path.join(ROOT, ".github", "workflows")

NAME = re.compile(r"\b([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)*_REQUIRE)\b")

# **A workflow must *set* the variable, not mention it.** Matching anywhere in
# the YAML was the first version, and its own mutation test caught it: renaming
# the setting to something else left the name in the job's comment above, so
# the gate went on passing. That is precisely the `SANITIZE_REQUIRE` failure
# read backwards -- a sentence describing a mechanism standing in for the
# mechanism -- which would have made this file a comfort rather than a check.
# A mapping key at the start of a line is what a `env:` entry is.
SETTING = re.compile(
    r"^[ \t]*([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)*_REQUIRE)[ \t]*:", re.M)

# A floor, so that a run which read nothing cannot pass by comparing nothing --
# the empty comparison this repository has been caught by before. It is well
# under the number that exists, so it does not move with a gate added.
FLOOR = 4


def scan(directory, suffixes, pattern=NAME):
    """{variable: sorted [files it appears in]} under one directory."""
    found = {}
    for entry in sorted(os.listdir(directory)):
        if not entry.endswith(suffixes):
            continue
        path = os.path.join(directory, entry)
        if not os.path.isfile(path):
            continue
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read()
        for name in set(pattern.findall(text)):
            found.setdefault(name, []).append(entry)
    return found


def main():
    # This file names every variable it is about, in its own docstring, and
    # would otherwise report itself as a check that reads them all.
    read = scan(CHECKS, (".sh", ".py"))
    read = {k: [f for f in v if f != os.path.basename(__file__)]
            for k, v in read.items()}
    read = {k: v for k, v in read.items() if v}

    set_by = scan(WORKFLOWS, (".yml", ".yaml"), SETTING)

    if len(read) < FLOOR:
        sys.stderr.write(
            "require-consistency: only %d *_REQUIRE variables found in %s, "
            "below the floor of %d -- the scan reached almost nothing\n"
            % (len(read), CHECKS, FLOOR))
        return 1

    problems = []
    for name in sorted(read):
        if name not in set_by:
            problems.append(
                "%s is read by %s and set by no workflow -- that gate answers "
                "only where its author was" % (name, ", ".join(read[name])))
    for name in sorted(set_by):
        if name not in read:
            problems.append(
                "%s is named by %s and read by no check -- a job setting a "
                "variable nothing consults, or a comment describing a "
                "mechanism that is not there"
                % (name, ", ".join(set_by[name])))

    if problems:
        sys.stderr.write(
            "require-consistency: a gate that can skip needs a job that "
            "refuses to let it.\n")
        for p in problems:
            sys.stderr.write("  " + p + "\n")
        sys.stderr.write(
            "\nSet the variable in the job that installs what the gate needs, "
            "or -- if the\nvariable is not the mechanism -- take the name out "
            "of the workflow. See doc/sop.md.\n")
        return 1

    print("require-consistency: %d *_REQUIRE variable(s), each read by a check "
          "and set by a job" % len(read))
    return 0


if __name__ == "__main__":
    sys.exit(main())
