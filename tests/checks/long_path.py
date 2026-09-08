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

# ADR-0291: can this compiler open a file whose path is longer than a name?
#
# `nameStr` was 255 and held both an identifier and a file name, so a source
# at a 310-character path reached `pas_str_fits` and stopped the compiler with
# `a string of length 310 does not fit a capacity of 255` -- naming no file,
# from a program that had asked to compile one. A checkout a few directories
# deeper than usual is the whole of what it takes.
#
# It needs a harness of its own because **no test case can choose its own
# path**: every case here is compiled where it sits, and every path a harness
# passes is short. That is `stale-component`'s argument -- no case can edit
# its own source between two compilations -- met a second time.
#
# Three claims, because a path arrives by more than one route: the source
# named on the command line, and a module found under an `--import-path`,
# which is a path the compiler *computed* rather than one it was handed. The
# third is that a diagnostic about such a file still names it -- a path that
# reaches the message is a path the message has to be able to hold, and it is
# the half `pas_str_fits` used to reach instead.
#
# ADR-0366's fifth conversion, from `long_path.sh` on 2026-09-08, both versions
# compared on every arm first. The usage line loses bash's `line N: 1:` prefix,
# as `bare_source_name.py`'s did; everything else is byte for byte.
#
# Usage:  long_path.py <pascalcc>

import os
import subprocess
import sys
import tempfile
from pathlib import Path

DEP = """module Dep;
export Dep = (Answer);
function Answer: integer;
end;
function Answer;
begin
  Answer := 42
end;
end.
"""

MAIN = """program main(output);
import Dep;
begin
  writeln(Answer)
end.
"""

PLAIN = """program plain(output);
begin
  writeln(42)
end.
"""

BAD = """program bad(output);
begin
  writeln(nowhere)
end.
"""

# The bound `nameStr` used to carry. The assertion is on the *length* of the
# path rather than on the nesting: what matters is that the file passes this,
# and how it got there is incidental.
BOUND = 255


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True, errors="replace")
    return (r.stdout + r.stderr).rstrip("\n"), r.returncode == 0


def main():
    if len(sys.argv) < 2:
        print("usage: long_path.py <pascalcc>", file=sys.stderr)
        return 1
    pascalcc = Path(sys.argv[1])
    if not (pascalcc.is_file() and os.access(pascalcc, os.X_OK)):
        print(f"long-path: {pascalcc} is not executable", file=sys.stderr)
        return 1

    with tempfile.TemporaryDirectory() as work:
        # Twelve directories of ordinary length, which is a project somebody
        # has and not an attack. `mkdtemp` contributes about twenty characters
        # here and more on a system whose TMPDIR is elsewhere.
        deep = work
        for i in range(1, 13):
            deep = os.path.join(deep, f"a_nested_directory_{i:02d}")
        os.makedirs(deep, exist_ok=True)
        for name, text in (("dep.pas", DEP), ("main.pas", MAIN),
                           ("plain.pas", PLAIN), ("bad.pas", BAD)):
            Path(deep, name).write_text(text)

        full = os.path.join(deep, "main.pas")
        n = len(full)
        if n <= BOUND:
            print(f"long-path: the path is only {n} characters -- this checks "
                  "nothing", file=sys.stderr)
            return 1

        fail = 0

        def note(what):
            nonlocal fail
            print(f"  {what}", file=sys.stderr)
            fail += 1

        # 1. the source named on the command line
        out, ok = run([str(pascalcc), os.path.join(deep, "plain.pas"),
                       "-o", os.path.join(work, "plain")])
        if ok:
            ran, ok = run([os.path.join(work, "plain")])
            ok = ok and ran == "42"
        if not ok:
            note(f"a source at a {n}-character path: {out}")

        # 2. the same module found by --import-path rather than named
        out, ok = run([str(pascalcc), "--import-path", deep,
                       os.path.join(deep, "main.pas"),
                       "-o", os.path.join(work, "main2")])
        if ok:
            ran, ok = run([os.path.join(work, "main2")])
            ok = ok and ran == "42"
        if not ok:
            note(f"--import-path at a {n}-character path: {out}")

        # 3. a diagnostic about such a file still names it. The path is what
        #    the message begins with, so a compiler that could compile the file
        #    and not complain about it would be a compiler with the bound moved
        #    rather than removed.
        bad = os.path.join(deep, "bad.pas")
        out, ok = run([str(pascalcc), bad, "-o", os.path.join(work, "bad")])
        if ok:
            note("the erroneous source at a long path was accepted")
        if not (out.startswith(f"{bad}:")
                and "undeclared identifier 'nowhere'" in out):
            note(f"the diagnostic did not name the file: {out}")

    if fail > 0:
        print(f"long-path: {fail} of 3 claims failed at a {n}-character path",
              file=sys.stderr)
        return 1
    print(f"long-path: 3 claims at a {n}-character path")
    return 0


if __name__ == "__main__":
    sys.exit(main())
