#!/usr/bin/env python3
"""Run selfhost/difftest.sh and hold its result against a recorded baseline.

Two independent implementations of the front end disagree on some files and
agree on the rest.  That set is a *baseline*, not a target: it may shrink and it
may not grow.  So this fails in both directions, which is `verify/`'s KNOWN_GAP
rule (ADR-0013) applied to a fourth catalogue --

  * a file that agreed and now disagrees is a **regression**, and fails;
  * a file that disagreed and now agrees is **progress**, and asks for the
    baseline to be regenerated rather than failing.  A gate that punished
    progress would be a gate people route around (ADR-0106 made the same
    choice for clause citations).

The point of running it red is that it protects the agreeing majority *today*.
Waiting for zero disagreements before wiring it up would leave the 600-odd
files that already agree guarded by nothing for as long as the catch-up takes.

The baseline records **which** files, not how many.  A count cannot tell a
regression from a coincidence -- one file fixed and one broken leaves the number
unchanged -- and this project has been caught by exactly that shape before.

Exit codes: 0 pass (or progress), 1 regression, 77 skip (nothing to run with).
"""

import argparse
import os
import pathlib
import subprocess
import sys

SKIP = 77

HEADER = """\
# Files on which the C++ reference front end (src/) and the Pascal compiler
# disagree, as compared by selfhost/difftest.sh over every Pascal source in
# the tree.
#
# A baseline, not a target: this list may shrink and may not grow (ADR-0108).
# Each entry is drift the C++ never received -- the Sema work since v1.0.0 --
# and clearing one means porting that rule into src/ and deleting its line.
#
# It is EMPTY, which is what makes this an ordinary regression gate rather
# than a ratchet: the two front ends agree on every source in the tree, so any
# entry appearing here is a disagreement this change introduced.  It was 89
# when the file was written.
#
# Regenerate with:  python3 tests/checks/difftest_check.py --write-baseline
# Doing so is a decision to argue for in the commit message: it is correct for
# progress, and it is also how a regression would be hidden.
"""


def read_baseline(path):
    if not path.exists():
        return None
    return {
        line.strip()
        for line in path.read_text().splitlines()
        if line.strip() and not line.startswith("#")
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root", nargs="?", default=".")
    ap.add_argument("--build", default="build")
    ap.add_argument("--write-baseline", action="store_true")
    args = ap.parse_args()

    root = pathlib.Path(args.root).resolve()
    build = pathlib.Path(args.build)
    if not build.is_absolute():
        build = (root / build).resolve()

    s0 = build / "bin" / "pascalc-s0"
    pascalc = build / "bin" / "pascalc"
    script = root / "selfhost" / "difftest.sh"
    baseline_path = root / "tests" / "checks" / "difftest_baseline.txt"

    for needed in (s0, pascalc, script):
        if not needed.exists():
            print(f"difftest: {needed} is missing; skipping", file=sys.stderr)
            return SKIP

    listing = build / "difftest-differs.txt"
    env = dict(os.environ, DIFFTEST_LIST=str(listing))
    # The script's exit status is the count of disagreements, which is exactly
    # what is *expected* to be non-zero here -- the baseline decides pass or
    # fail, not the status.  Its stderr carries the diffs and is passed through.
    subprocess.run(
        ["bash", str(script), str(s0), str(pascalc)],
        env=env, cwd=str(root), stdout=subprocess.DEVNULL,
    )

    if not listing.exists():
        print("difftest: produced no list; did it run at all?", file=sys.stderr)
        return 1
    now = {ln.strip() for ln in listing.read_text().splitlines() if ln.strip()}

    if args.write_baseline:
        baseline_path.write_text(HEADER + "".join(f"{f}\n" for f in sorted(now)))
        print(f"difftest: wrote baseline ({len(now)} disagreeing)")
        return 0

    was = read_baseline(baseline_path)
    if was is None:
        print("difftest: no baseline; run --write-baseline", file=sys.stderr)
        return 1

    # tests/bsi/suite/ is fetched, never committed (ADR-0086), so a tree
    # without it compares far fewer files.  Baseline entries whose source is
    # absent are dropped rather than counted as newly agreeing -- otherwise a
    # machine that simply has not fetched the suite reports 22 files "fixed"
    # and invites someone to bake that into the baseline.
    was = {f for f in was if (root / f).exists()}

    broke = sorted(now - was)
    fixed = sorted(was - now)

    if broke:
        print(
            f"difftest: {len(broke)} file(s) agreed and now disagree -- "
            "the two front ends have been driven apart:",
            file=sys.stderr,
        )
        for f in broke:
            print(f"    {f}", file=sys.stderr)
        print(
            "\nA front-end change belongs in both implementations (ADR-0108).\n"
            "See the diffs above, and doc/sop.md §3 B.",
            file=sys.stderr,
        )
        return 1

    if fixed:
        print(f"difftest: {len(now)} disagreeing, was {len(was)} -- "
              f"{len(fixed)} now agree:")
        for f in fixed:
            print(f"    {f}")
        print("\nRegenerate with --write-baseline and say which rule was ported.")
        return 0

    print(f"difftest: {len(now)} disagreeing, unchanged; none newly broken")
    return 0


if __name__ == "__main__":
    sys.exit(main())
