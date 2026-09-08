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
# Does the compiler survive every tool dump over every source? (ADR-0349)
#
# **The dumps a *tool* asks for are the ones with no corpus.** `--dump-symbols`,
# `--dump-uses` and `--dump-words` exist for `lsp/pasls.pas` -- an editor's
# outline, its go-to-definition, and the word lists a completion offers -- and
# an agent reaches the first two through MCP. `tests/dumps/` has one case each,
# over one small source apiece, and that is the whole of what asked.
#
# So a language feature added afterwards is swept by nothing. ADR-0338's traits
# put two new node kinds into a block's declaration list, and `DumpSymBlock`
# read them through the procedure arm: `--dump-symbols` over any source with a
# `trait` in it **stopped the compiler** with 6.5.3.3's wrong-arm read. The
# whole suite was green -- 888 cases -- because no case passes `--dump-symbols`
# over such a source, and the MCP `outline` tool answered with the one line it
# had printed before it died. A person would have read that as an empty file.
#
# This is ADR-0269's question -- *did the compiler survive every invocation?* --
# asked of the dumps instead of of the corpus, and it is a **crash sweep and
# not a golden**: what each dump *says* is `tests/dumps/`'s business, and what
# this asks is only that the compiler is still running afterwards. A source
# that fails to compile is fine; a source that takes the compiler down is not.
#
# ADR-0366's second conversion, and the template for the gates shaped like it:
# enumerate a corpus, run the compiler over it, judge what came back. It was
# `tool_dumps.sh` until 2026-09-08, and both versions were run against the
# current tree and against an induced crash before the shell one was removed.
#
# Usage:  tests/checks/tool_dumps.py [pascalc]

import os
import subprocess
import sys
import tempfile
from pathlib import Path

# Every dump a tool asks for. `--dump-imports` is here too: `tools/pascalcc`
# reads it to learn what to translate, so a crash in it is a build that stops
# rather than an editor that goes quiet.
DUMPS = ("--dump-symbols", "--dump-uses", "--dump-words", "--dump-imports")

ROOTS = ("tests", "selfhost", "lib", "lsp", "examples")

# So a run that enumerated nothing cannot pass by sweeping nothing (ADR-0282).
# Four dumps over the tree is thousands; 1000 is well under.
FLOOR = 1000


def enumerate_sources(root):
    """Every `.pas` under the roots, minus what git ignores.

    A walk with git as an *optional filter* -- `variant_check.sh`'s shape, and
    it is the shape for the reason that gate learned: a checkout may have a
    retired corpus or a second build tree on disk, and what is gitignored is
    not a source this project ships.

    It was `git ls-files` first, and CI is where that failed. A container runs
    as a different user than the checkout is owned by, so git refuses the
    repository outright -- *detected dubious ownership* -- and the sweep
    enumerated **zero** sources. The floor is what reported it (ADR-0282),
    doing exactly the job a floor is for; every gate here that reaches for git
    has to survive git declining to answer.

    Sorted by bytes, so the sweep order is the same everywhere. The shell this
    replaced piped `find` into `sort`, whose collation follows the locale --
    the same names in a different order under a different `LANG`.
    """
    found = []
    for name in ROOTS:
        for dirpath, _dirs, files in os.walk(root / name):
            for f in files:
                if f.endswith(".pas"):
                    found.append(os.path.join(dirpath, f))
    found.sort(key=os.fsencode)
    if not found:
        return found

    try:
        r = subprocess.run(["git", "-C", str(root), "check-ignore", "--stdin"],
                           input="\n".join(found) + "\n",
                           capture_output=True, text=True)
        ignored = {ln for ln in r.stdout.split("\n") if ln}
    except OSError:
        ignored = set()
    return [p for p in found if p not in ignored] if ignored else found


def survived(out, status):
    """A diagnostic is an answer and a non-zero status with one is fine.

    What is not fine is the runtime saying the program stopped, or a signal.
    """
    return "runtime error:" not in out and status <= 1


def main():
    root = Path(__file__).resolve().parent.parent.parent
    pascalc = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "build/bin/pascalc"
    if not os.access(pascalc, os.X_OK) or not pascalc.is_file():
        print(f"tool-dumps: {pascalc} is not executable", file=sys.stderr)
        return 1

    sources = enumerate_sources(root)
    swept = 0
    crashed = 0
    with tempfile.TemporaryDirectory() as work:
        out_ll = os.path.join(work, "out.ll")
        for src in sources:
            for dump in DUMPS:
                swept += 1
                r = subprocess.run([str(pascalc), dump, src, "-o", out_ll],
                                   capture_output=True, text=True,
                                   errors="replace")
                out = (r.stdout + r.stderr).rstrip("\n")
                if not survived(out, r.returncode):
                    rel = os.path.relpath(src, root)
                    print(f"tool-dumps: {dump} {rel}", file=sys.stderr)
                    for line in out.split("\n")[-2:]:
                        print(f"  {line}", file=sys.stderr)
                    crashed += 1

    if swept < FLOOR:
        print(f"tool-dumps: only {swept} invocations, below the floor of "
              f"{FLOOR}", file=sys.stderr)
        return 1
    if crashed:
        print(f"tool-dumps: {crashed} of {swept} invocations stopped the "
              "compiler", file=sys.stderr)
        return 1
    print(f"tool-dumps: {len(DUMPS)} dumps over {len(sources)} sources, "
          f"{swept} invocations, and the compiler survived every one")
    return 0


if __name__ == "__main__":
    sys.exit(main())
