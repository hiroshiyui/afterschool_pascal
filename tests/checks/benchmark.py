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

"""How long the compiler takes, expressed so that a machine cannot answer.

Nothing here had ever profiled the compiler, and doc/roadmap.md's tooling
chapter said what was missing first: *the self-hosting build is the natural
benchmark and no committed number says how long it takes, so there is nothing
for a regression to fail against.* This is that number.

**A wall-clock second is not a claim this repository can make.** A baseline in
milliseconds is a fact about the machine that took it, so a slower machine
fails a gate it should pass and the gate is then something people re-run rather
than read. The threshold that survives that is so loose -- 3x, 5x -- that it
catches only a catastrophe.

So what is committed is a set of **proportions**, each measured in the same
run as what it is divided by: four stage *shares* of one compile, and two
component *scales*. Both denominators move with the machine, so what is left
is a number about this compiler rather than about this desktop, and that buys
a tight threshold -- 25% -- which is the difference between catching an
accidental O(n^2) and catching only a disaster. `shares()` records why the
first design, a ratio to the smallest component compiled whole, was thrown
away: a mutation that made the code generator slower slowed the denominator
with it and the gate passed.

**The stages are separated by dump flags and not by a profiler**, because each
`--dump-*` stops at the stage it names (ADR-0025):

    --dump-tokens   lexing
    --dump-ast      + parsing
    --dump-sema     + Sema
    (no flag)       + the code generator

Each is cumulative and each is what was actually measured; the differences
between them are printed for a reader and are not gated, a 20 ms difference
being noise where a 120 ms total is not.

**What it catches, measured rather than claimed.** Making `EmitStmt` do 4000
units of wasted arithmetic per statement takes the code generator's share from
0.449 to 0.555 and the gate names it; 1500 units moves it to about 0.48 and
passes. So the threshold is a stage made roughly a third slower in absolute
terms, and a stage made a fifth slower is invisible.

**What it cannot see at all** is a change that slows every stage of every
component in the same proportion -- a pool lookup they all make, a slower
`Peek`. Both denominators slow down with it. The absolute milliseconds are
recorded beside the proportions for exactly that reason, with the machine they
were taken on; they are for a reader and are not compared. doc/sop.md §7
carries the gap.

    python3 tests/checks/benchmark.py                    # the gate
    python3 tests/checks/benchmark.py --report           # the numbers
    python3 tests/checks/benchmark.py --write-baseline   # argue for it
"""

import argparse
import pathlib
import platform
import subprocess
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import components                                        # noqa: E402

SKIP = 77
BASELINE = "benchmark.txt"

# The measurement is a minimum, not a mean: a compile is bounded below by the
# work it does and everything above that floor is the machine doing something
# else. Five is enough to find the floor and cheap enough to run every time.
REPEATS = 5

# How far a proportion may move before this is a finding, per proportion,
# because they are not equally steady and one tolerance for all of them would
# be the loosest one.
#
# Measured over six consecutive runs on an idle machine, the run-to-run spread
# is 1.1% for the code generator's share, 1.8% for the lexer's, 2.1% for
# Sema's, 6.9% for the two scales and **9.4%** for the parser's -- the parser
# being a 19 ms difference between two 100 ms measurements, which is the one
# number here small enough for noise to matter. Each tolerance below is a
# margin over its own spread and not over the worst of them: a single 25%
# figure would have let a code generator made 20% slower through, which is
# most of what this gate is for.
TOLERANCE = {
    "share:lex": 0.15,
    "share:parse": 0.30,      # a 19 ms difference; 3x its measured spread
    "share:sema": 0.15,
    "share:codegen": 0.15,
    "scale:apfront": 0.20,
    "scale:compiler": 0.20,
}
DEFAULT_TOLERANCE = 0.25


def measure(exe, argv, work, repeats=REPEATS):
    """The floor of `repeats` runs, in seconds, with the dump discarded."""
    best = None
    for _ in range(repeats):
        started = time.perf_counter()
        r = subprocess.run([str(exe)] + argv + ["-o", str(work / "bench.ll")],
                           stdout=subprocess.DEVNULL,
                           stderr=subprocess.PIPE)
        elapsed = time.perf_counter() - started
        if r.returncode != 0:
            return None, r.stderr.decode("utf-8", "replace")[:400]
        best = elapsed if best is None else min(best, elapsed)
    return best, None


def subjects(root):
    """What is timed, in the order it is reported.

    The three program-components whole, then the stage boundaries of the
    largest one. `apfront.pas` is the subject for the stages because it is the
    largest single component -- 24 206 lines, and its translation reads ApTypes
    as well -- so each stage has enough work in it to be measured rather than
    sampled."""
    for c in components.COMPONENTS:
        yield f"whole:{c}", components.translate(root, c)
    front = components.translate(root, "apfront.pas")
    yield "stage:lex", front + ["--dump-tokens"]
    yield "stage:parse", front + ["--dump-ast"]
    yield "stage:sema", front + ["--dump-sema"]


def read_baseline(root):
    path = root / "tests" / "checks" / BASELINE
    if not path.exists():
        return None
    out = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) == 3 and parts[0] == "ratio":
            out[parts[1]] = float(parts[2])
    return out


def write_baseline(root, ratios, times):
    path = root / "tests" / "checks" / BASELINE
    lines = [
        "# What the compiler costs, as proportions: four stage shares of one",
        "# compile of the largest program-component, and two component scales.",
        "# Each denominator is measured in the same run as its numerator, so a",
        "# slow machine moves none of them. tests/checks/benchmark.py says why",
        "# a millisecond is not a claim this repository can make, and why a",
        "# ratio to a whole compile was the first design and did not work.",
        "#",
        "# Regenerate with:  python3 tests/checks/benchmark.py --write-baseline",
        "# Doing so is a decision to argue for in the commit message: a",
        "# proportion that moved is one stage doing more work than it did.",
        "",
    ]
    for k in ratios:
        lines.append(f"ratio {k} {ratios[k]:.3f}")
    lines += [
        "",
        "# Milliseconds, for a reader. NOT compared -- they are a fact about",
        "# the machine below and not about this compiler. A change that slows",
        "# every stage in proportion moves these and no ratio above, which is",
        "# the gap doc/sop.md §7 records for this gate.",
        "#",
        f"#   {platform.platform()}",
        f"#   {platform.processor() or platform.machine()}",
        "#",
    ]
    for k in sorted(times):
        lines.append(f"#   {k:22s} {times[k] * 1000:8.1f} ms")
    path.write_text("\n".join(lines) + "\n")


def shares(times):
    """The committed numbers: what fraction of a compile each stage is.

    **A ratio to a whole compile was the first design and it did not work.**
    The denominator was `aptypes.pas` compiled whole, which runs the code
    generator like everything else -- so a mutation that made `EmitStmt` do
    4000 units of wasted arithmetic slowed the numerator and the denominator
    together and every ratio stayed inside tolerance. The gate passed on a
    compiler that had been made measurably slower, which is the exact failure
    this file exists to refuse.

    What a stage's *share of its own compile* answers instead is "did one
    stage grow relative to the others", and that is the question a regression
    asks. The same mutation takes the code generator's share from 0.449 to
    0.555 and the gate names it.

    Two scale ratios stand beside them, because a share cannot see a compile
    that got slower everywhere at once: `apfront.pas` and `compiler.pas`
    against `aptypes.pas`, which catches work that grows faster than the
    source does -- an accidental O(n^2), a table rebuilt per declaration.

    What is left uncovered is a change that slows every stage of every
    component in the same proportion. The milliseconds are recorded beside
    these for that, and are read by a person; doc/sop.md §7 carries the row."""
    whole = times["whole:apfront.pas"]
    lex = times["stage:lex"]
    parse = times["stage:parse"]
    sema = times["stage:sema"]
    return {
        "share:lex": lex / whole,
        "share:parse": (parse - lex) / whole,
        "share:sema": (sema - parse) / whole,
        "share:codegen": (whole - sema) / whole,
        "scale:apfront": whole / times["whole:aptypes.pas"],
        "scale:compiler": times["whole:compiler.pas"] /
                          times["whole:aptypes.pas"],
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root", nargs="?", default=None)
    ap.add_argument("--build", default=None)
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--write-baseline", action="store_true")
    args = ap.parse_args()

    root = pathlib.Path(args.root or
                        pathlib.Path(__file__).resolve().parents[2]).resolve()
    build = pathlib.Path(args.build or root / "build").resolve()
    exe = build / "bin" / "pascalc"
    if not exe.exists():
        print("benchmark: skipped -- no compiler at", exe)
        return SKIP

    work = build / "benchmark"
    work.mkdir(exist_ok=True)

    def run():
        times = {}
        for name, argv in subjects(root):
            seconds, err = measure(exe, argv, work)
            if seconds is None:
                print(f"benchmark: {name} did not compile\n{err}",
                      file=sys.stderr)
                return None
            times[name] = seconds
        return times

    times = run()
    if times is None:
        return 1
    ratios = shares(times)
    unit = times["whole:aptypes.pas"]

    if args.write_baseline:
        write_baseline(root, ratios, times)
        print(f"benchmark: baseline written; the smallest component\n"
              f"           compiles in {unit * 1000:.1f} ms on this machine")
        return 0

    if args.report:
        print("measured (minimum of %d):" % REPEATS)
        for k in sorted(times):
            print(f"  {k:22s} {times[k] * 1000:8.1f} ms")
        print("\ncommitted:")
        for k in sorted(ratios):
            print(f"  {k:22s} {ratios[k]:8.3f}")
        return 0

    want = read_baseline(root)
    if want is None:
        print("benchmark: no baseline; run --write-baseline", file=sys.stderr)
        return 1

    moved = compare(ratios, want)
    if moved:
        # **A failure is confirmed before it is reported.** Everything above is
        # a duration, and a duration is the one measurement here a machine can
        # get wrong on its own -- a scheduler hiccup, a neighbour, a page fault
        # storm. A gate that goes red for those is one people re-run instead of
        # reading, which is worse than not having it. So the whole measurement
        # is taken a second time and the finding has to survive: a regression
        # reproduces and noise does not, and the cost is paid only when
        # something already looks wrong.
        again = run()
        if again is None:
            return 1
        second = compare(shares(again), want)
        if not second:
            print("benchmark: a proportion moved and did not move again on a "
                  "second measurement, so the first was the machine and not "
                  "the compiler:", file=sys.stderr)
            for line in moved:
                print(f"  {line}", file=sys.stderr)
            moved = []
        else:
            moved = second
            times = again

    if moved:
        for line in moved:
            print(f"benchmark: {line}", file=sys.stderr)
        print(f"\nbenchmark: measured twice, and it moved both times. The "
              f"smallest program-component compiled in "
              f"{times['whole:aptypes.pas'] * 1000:.1f} ms. A "
              "proportion moves when one stage does more work than it did, "
              "not when the machine is slow -- every denominator was measured "
              "in the same run as its numerator. If the work is genuinely "
              "different, --write-baseline and say why.", file=sys.stderr)
        return 1

    print(f"benchmark: {len(ratios)} proportions within tolerance of "
          f"baseline; the smallest program-component compiles in "
          f"{unit * 1000:.1f} ms here")
    return 0


def compare(ratios, want):
    """Every proportion that left its tolerance, said in words."""
    moved = []
    for k, got in sorted(ratios.items()):
        if k not in want:
            moved.append(f"{k}: {got:.3f} now, and no baseline names it -- "
                         "a subject was added without --write-baseline")
            continue
        tol = TOLERANCE.get(k, DEFAULT_TOLERANCE)
        if abs(got - want[k]) > tol * want[k]:
            how = "slower" if got > want[k] else "faster"
            moved.append(f"{k}: {want[k]:.3f} -> {got:.3f} "
                         f"({100.0 * (got - want[k]) / want[k]:+.0f}%, {how}; "
                         f"tolerance {tol:.0%})")
    for k in sorted(set(want) - set(ratios)):
        moved.append(f"{k}: baselined at {want[k]:.3f} and no longer measured")
    return moved


if __name__ == "__main__":
    sys.exit(main())
