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
# ADR-0308: does a source named without a directory find its neighbours?
#
# ADR-0244's first search rule is the source's own directory, and README and
# doc/tour.md both promise that a program and its components written in one
# directory need no manifest and no build order. `SourceDir` answered the
# empty string for a name with no `/` in it and `AddPath` drops an empty
# directory on purpose -- an empty entry in AFTERSCHOOL_PASCAL_PATH would name
# the working directory, which POSIX says of PATH and which is a surprise
# nobody wants -- so the promise was true of `./prog.pas` and false of
# `prog.pas`, which is the spelling a person types.
#
# It needs a harness of its own for `long-path`'s reason, met a third time:
# **no test case can choose how it is named.** Every case here is compiled
# where it sits and every harness passes a path, so the one spelling that was
# broken is the one no oracle here could produce. What this asserts is a
# property of the *invocation* and cannot be written in Pascal.
#
# Two claims, because the working directory reaches the compiler twice: the
# component found beside a bare source name, and the same program still
# compiling when it is named with a directory -- a fix that made `./` the
# answer for every name would pass the first and break nothing visible, so the
# second is what keeps the change to the case it was made for.
#
# ADR-0366's fourth conversion, from `bare_source_name.sh` on 2026-09-08, with
# both versions compared on every arm first. The `cd` the first claim needs is
# `cwd=` on the one call rather than a change to this process, so nothing here
# depends on the working directory being put back.
#
# One message differs on purpose. `${1:?usage: ...}` made bash prefix its own
# `<script>: line 42: 1:` before the usage line, naming a line number and a
# positional parameter that mean nothing to the reader. The usage line is
# printed plainly. Every other arm -- both claims, either claim, a driver that
# is not executable -- is byte for byte what the shell wrote.
#
# Usage:  bare_source_name.py <pascalcc>

import os
import subprocess
import sys
import tempfile
from pathlib import Path

GREETING = """module Greeting;
export Greeting = (Answer);
function Answer: integer;
end;
function Answer;
begin
  Answer := 42
end;
end.
"""

SAYHELLO = """program sayhello(output);
import Greeting;
begin
  writeln(Answer)
end.
"""


def run(cmd, cwd=None):
    """The command's combined output and whether it succeeded.

    Combined because the shell this replaced captured `2>&1`: a diagnostic is
    what the note prints, and the compiler writes on `output` (ADR-0083).
    """
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True,
                       errors="replace")
    return (r.stdout + r.stderr).rstrip("\n"), r.returncode == 0


def main():
    if len(sys.argv) < 2:
        print("usage: bare_source_name.py <pascalcc>", file=sys.stderr)
        return 1
    pascalcc = Path(sys.argv[1])
    if not (pascalcc.is_file() and os.access(pascalcc, os.X_OK)):
        print(f"bare-source-name: {pascalcc} is not executable", file=sys.stderr)
        return 1
    # Absolute, because claim 1 runs the compiler from another directory and a
    # relative driver would vanish under the cd -- which is the same shape as
    # the defect this gate is about.
    pascalcc = pascalcc.resolve()

    fail = 0

    def note(what):
        nonlocal fail
        print(f"  {what}", file=sys.stderr)
        fail += 1

    with tempfile.TemporaryDirectory() as work:
        (Path(work) / "greeting.pas").write_text(GREETING)
        (Path(work) / "sayhello.pas").write_text(SAYHELLO)

        # 1. The bare name, which is what a person types. The working
        #    directory is the whole of the test: the compiler is given
        #    `sayhello.pas` and nothing else, so the only thing that can find
        #    `greeting.pas` is the source's own directory.
        out, ok = run([str(pascalcc), "sayhello.pas", "-o", "hello"], cwd=work)
        if ok:
            ran, ok = run(["./hello"], cwd=work)
            ok = ok and ran == "42"
        if not ok:
            note(f"a source named with no directory: {out}")

        # 2. The same program named with a directory, which worked before this
        #    gate existed and has to go on working -- the search is the
        #    source's directory and not the working one, and those are the same
        #    above only by accident of where it was run.
        hello2 = os.path.join(work, "hello2")
        out, ok = run([str(pascalcc), os.path.join(work, "sayhello.pas"),
                       "-o", hello2])
        if ok:
            ran, ok = run([hello2])
            ok = ok and ran == "42"
        if not ok:
            note(f"a source named with a directory: {out}")

    if fail:
        print(f"bare-source-name: {fail} of 2 claims failed", file=sys.stderr)
        return 1
    print("bare-source-name: 2 of 2 claims hold")
    return 0


if __name__ == "__main__":
    sys.exit(main())
