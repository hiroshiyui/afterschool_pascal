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

"""Does this tree's own source still compile with nothing to say?

ADR-0272 gave the compiler a diagnostic that is not an error, and there are
four of them now. A **test case** is held to them by a sidecar: a case with a
`name.warn` must produce those warnings and a case without one must produce
none, which is the half that stops a warning added later from appearing on
dozens of green cases. `selfhost/`, `lib/` and `lsp/` have no sidecars. They
are compiled by CMake, by four harnesses and by `lsp/build.sh`, all of which
read the exit status and none of which reads what the compiler *said* -- so a
warning here is written to a build log and nothing fails.

That mattered the moment ADR-0283 landed. Its warning found 54 parameters in
this tree that could say `protected`, all 54 were given the word, and the
count is now zero -- held by nobody. `doc/sop.md` §7 recorded the gap and gave
a reason for declining a gate: the count is a **fixed point** rather than a
number, so a gate over it would have to iterate to convergence. That reason is
wrong, and it is wrong in the way this repository's roadmap keeps finding.
Iterating is what reaching zero needed. *Holding* zero needs one sweep, and
the sweep can make the stronger claim for free, over all four warnings at
once: **the compiler writes nothing at all about this tree's own source.**

Two claims, so that it fails in both directions:

**Every implementation source compiles silently.** Exit status 0 and not one
byte on either stream. The compiler is quiet on success and writes
`file:line:col:` diagnostics to `output` (no standard Pascal program has a
second stream), so "said nothing" is the whole test and it needs no parsing.

**Every source named as deliberately broken really is.** `selfhost/torture.pas`
and the two bad-parse and bad-Sema corpora exist to be refused, and they are
the only things excluded here. If one of them starts compiling, the exclusion
has stopped meaning what it says and this fails rather than quietly sweeping
one file fewer -- which is the shape a skip-what-fails sweep would have had,
and would have turned a source that broke into a source that was skipped.
"""

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

# The implementation, which is everything in this tree written in this
# language that is not a test case. `tests/` is deliberately absent: a case
# there is already governed by its `.warn` sidecar, in both directions, and
# sweeping it here would be a second opinion free to drift from the first.
ROOTS = ("selfhost", "lib", "lsp")

# Where an `import` is looked for. Named rather than left to
# AFTERSCHOOL_PASCAL_PATH so that what the gate compiles does not depend on
# the environment it is run from.
IMPORT_PATHS = ("lib", "lib/dialect", "selfhost", "lsp")

# The three things here that are *meant* not to compile, and the reason each
# is written down rather than detected: a sweep that skipped whatever failed
# would report a source that broke as a source it had nothing to say about.
REFUSED = ("selfhost/torture.pas", "selfhost/badparse/", "selfhost/badsema/")

# ...except that a bad-Sema *case* may have a program-component beside it, and
# a component is an ordinary module that has to compile. `components/` is
# where those live, by the convention `tests/extended/components/` already
# holds -- a subdirectory, because the globs that register cases are not
# recursive. This exception was written by the gate rather than foreseen: its
# second claim named `selfhost/badsema/components/exporter.pas` on the first
# run, which is a module the corpus imports and not a source anyone meant to
# be refused.
NOT_REFUSED = ("/components/",)

# An instrument that measures nothing must not pass by measuring nothing --
# variant-check's floor, for variant-check's reason. This tree has forty
# implementation sources as this is written and the number only grows.
FLOOR = 20


def sources(root: Path) -> list:
    found = sorted(str(p.relative_to(root))
                   for r in ROOTS for p in (root / r).rglob("*.pas"))
    if not found:
        return found
    # Filtered through git only if git answers: `git ls-files` exits 128 in a
    # container whose checkout git calls dubiously owned, and a sweep that
    # read that as an empty list is exactly what ADR-0282 found in
    # format-check. The floor above is the other half of that repair.
    ignored = subprocess.run(["git", "-C", str(root), "check-ignore", "--stdin"],
                             input="\n".join(found), capture_output=True,
                             text=True)
    if ignored.returncode in (0, 1):
        drop = set(ignored.stdout.split())
        found = [f for f in found if f not in drop]
    return found


def compile_one(pascalc: Path, root: Path, name: str, out: Path):
    args = [str(pascalc), name, "-o", str(out)]
    for p in IMPORT_PATHS:
        args += ["--import-path", str(root / p)]
    # ...and the source's own `.importpath`, ADR-0244's sidecar, one directory
    # a line relative to the source (ADR-0311). The fixed list above is where
    # this tree's library lives and cannot know where a fixture's neighbour
    # does. This gate is the third reader of that sidecar after
    # `tests/run_test.sh` and `lsp/pasls.pas`, and it was the third to be
    # told; `doc/sop.md` §7 carries what that costs.
    sidecar = (root / name).with_suffix(".importpath")
    if sidecar.exists():
        for line in sidecar.read_text().splitlines():
            line = line.strip()
            if line:
                args += ["--import-path", str((sidecar.parent / line).resolve())]
    r = subprocess.run(args, cwd=root, capture_output=True, text=True,
                       encoding="latin-1")
    return r.returncode, (r.stdout + r.stderr)


def main() -> int:
    # argparse rather than positional indexing, which is what every other check
    # here uses -- and the reason is that the hand-rolled version read
    # `--build` as the *root* when no root was given, so
    # `warning_free.py --build build` swept a directory named `--build` and
    # found nothing in it. The FLOOR below caught that and exited 1, which is
    # the floor doing its job; matching the siblings is what stops it arising.
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("root", nargs="?", default=None)
    ap.add_argument("--build", default=None)
    args = ap.parse_args()
    root = Path(args.root) if args.root else Path(__file__).resolve().parents[2]
    build = Path(args.build) if args.build else root / "build"
    pascalc = build / "bin" / "pascalc"
    if not pascalc.exists():
        print(f"warning-free: {pascalc} is missing -- skipping")
        return 77

    all_sources = sources(root)
    def is_refused(n):
        return n.startswith(REFUSED) and not any(x in n for x in NOT_REFUSED)

    refused = [n for n in all_sources if is_refused(n)]
    checked = [n for n in all_sources if not is_refused(n)]

    # A directory of its own for the run, so the suite stays parallel-safe
    # (ADR-0281): every harness here works in a directory it created.
    with tempfile.TemporaryDirectory(prefix="warning-free.") as tmp:
        out = Path(tmp) / "out.ll"
        noisy = []
        for name in checked:
            status, said = compile_one(pascalc, root, name, out)
            if status != 0:
                noisy.append(f"{name}: exit {status}\n" +
                             "\n".join("      " + l for l in said.splitlines()[:6]))
            elif said.strip():
                noisy.append(f"{name}: compiled, and said\n" +
                             "\n".join("      " + l for l in said.splitlines()[:6]))

        accepted = []
        for name in refused:
            status, _ = compile_one(pascalc, root, name, out)
            if status == 0:
                accepted.append(name)

    if noisy:
        print(f"warning-free: {len(noisy)} of {len(checked)} implementation "
              f"sources are not silent", file=sys.stderr)
        for line in noisy[:20]:
            print(f"    {line}", file=sys.stderr)
        if len(noisy) > 20:
            print(f"    ... and {len(noisy) - 20} more", file=sys.stderr)
        print("\n  Every source in selfhost/, lib/ and lsp/ must compile with "
              "nothing to say.\n  A warning here is written to a build log and "
              "nothing else fails (ADR-0286).", file=sys.stderr)
        return 1

    if accepted:
        print(f"warning-free: {len(accepted)} source(s) named as deliberately "
              f"broken now compile", file=sys.stderr)
        for name in accepted:
            print(f"    {name}", file=sys.stderr)
        print("\n  These are excluded from the sweep because they exist to be "
              "refused.\n  One that compiles is either fixed -- and belongs in "
              "the sweep -- or has\n  stopped testing what it was written for.",
              file=sys.stderr)
        return 1

    if len(checked) < FLOOR:
        print(f"warning-free: only {len(checked)} implementation sources were "
              f"compiled, and this tree has far more than that -- the sweep "
              f"found nothing to do", file=sys.stderr)
        return 1

    print(f"warning-free: {len(checked)} implementation sources compile with "
          f"nothing to say, and the {len(refused)} written to be refused still "
          f"are")
    return 0


if __name__ == "__main__":
    sys.exit(main())
