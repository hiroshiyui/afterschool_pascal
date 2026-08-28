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

"""Which *statements* of the compiler the corpus runs.

coverage.py measures procedures and ADR-0103 says what that cannot see: a
procedure entered once counts, so the `case` arm nobody reaches is invisible.
This is the finer measurement, and unlike the block coverage that record
rejected, its denominator is honest -- the lines counted are the statements a
human wrote, because the compiler decides what is executable and emits one
counter per statement (ADR-0104).

Both halves come from one artefact. The *denominator* is read back out of the
IR the compiler just wrote (`call void @pas_cov_hit(i32 N)`), and the numerator
is what the runtime reported, so the two cannot disagree about what was
instrumented -- there is no separate notion of an executable line to drift.

    python3 tests/checks/line_coverage.py --report        # the breakdown
    python3 tests/checks/line_coverage.py --report --by-procedure
    python3 tests/checks/line_coverage.py                 # the ratchet

**The gate is a ratchet, and that is weaker than coverage.py's allowlist.**
A per-line catalogue of arguments is not writable at this scale, and a number
hides which line was lost -- so the ratchet is backed by
tests/checks/line_coverage.txt, which records the count *and* the per-procedure
figures, and a drop names the procedures that moved. It is honest about being
the weaker instrument; doc/sop.md §7 carries the row.
"""

import argparse
import collections
import concurrent.futures
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import coverage  # noqa: E402  -- one definition of "the corpus", shared

SKIP = 77
HIT = re.compile(r"call void @pas_cov_hit\(i32 (\d+)\)")
NAMED = re.compile(r"^; ([a-z_][a-z_0-9]*) (\d+)$", re.MULTILINE)
RATCHET = "line_coverage.txt"


def build(root, build_dir, work):
    """An instrumented compiler, and the IR it was built from.

    Stage 2 for ADR-0103's reason: build/pascalc.ll is the *seed's* output and
    predates any change being measured."""
    pascalc = build_dir / "bin" / "pascalc"
    pasrt = build_dir / "lib" / "libpasrt.a"
    if not pascalc.exists() or not pasrt.exists() or not shutil.which("clang"):
        print(f"line-coverage: no compiler at {pascalc} -- build first",
              file=sys.stderr)
        return None

    ir, exe = work / "cov.ll", work / "pascalc-linecov"
    r = subprocess.run([str(pascalc), "--coverage",
                        str(root / "selfhost" / "compiler.pas"), "-o", str(ir)],
                       capture_output=True, text=True)
    if r.returncode != 0 or not ir.exists():
        print("line-coverage: the compiler failed to translate itself\n"
              + r.stdout, file=sys.stderr)
        return None
    r = subprocess.run(["clang", "-Wno-override-module", "-O1", str(ir),
                        str(pasrt), "-lm", "-o", str(exe)],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(f"line-coverage: linking failed\n{r.stderr}", file=sys.stderr)
        return None
    return exe, ir


def sweep(exe, jobs, work):
    def one(idx_job):
        idx, (src, flags) = idx_job
        out = work / f"L{idx}.txt"
        argv = [str(exe), *flags]
        if src is not None:
            argv += [str(src), "-o", str(work / f"o{idx}.ll")]
        try:
            subprocess.run(argv, capture_output=True, timeout=600,
                           env=dict(os.environ, PASCOV_LINES=str(out)))
        except subprocess.TimeoutExpired:
            print(f"line-coverage: {src} timed out", file=sys.stderr)
        return out

    ran = set()
    with concurrent.futures.ThreadPoolExecutor(max_workers=os.cpu_count()) as ex:
        for out in ex.map(one, enumerate(jobs)):
            if out.exists():
                ran.update(int(x) for x in out.read_text().split())
    return ran


def procedures(ir):
    """(start line, name), sorted -- so an uncovered line can be attributed to
    the procedure containing it. The comments ADR-0103 added carry both."""
    return sorted((int(line), name) for name, line in NAMED.findall(ir))


def attribute(lines, procs):
    """Group lines by the procedure they fall in."""
    starts = [p[0] for p in procs]
    import bisect
    out = collections.defaultdict(list)
    for ln in sorted(lines):
        i = bisect.bisect_right(starts, ln) - 1
        out[procs[i][1] if i >= 0 else "(program level)"].append(ln)
    return out


def read_ratchet(root):
    path = root / "tests" / "checks" / RATCHET
    if not path.exists():
        return None
    for line in path.read_text().splitlines():
        if line.startswith("uncovered "):
            return int(line.split()[1])
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root", nargs="?", default=None)
    ap.add_argument("--build", default=None)
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--by-procedure", action="store_true")
    ap.add_argument("--write-ratchet", action="store_true")
    args = ap.parse_args()

    root = pathlib.Path(args.root or
                        pathlib.Path(__file__).resolve().parents[2]).resolve()
    build_dir = pathlib.Path(args.build or root / "build").resolve()

    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        made = build(root, build_dir, work)
        if made is None:
            print("line-coverage: skipped")
            return SKIP
        exe, ir_path = made
        text = ir_path.read_text()
        instrumented = {int(n) for n in HIT.findall(text)}
        procs = procedures(text)
        ran = sweep(exe, coverage.corpus(root), work) & instrumented

    uncovered = instrumented - ran
    pct = 100.0 * len(ran) / len(instrumented) if instrumented else 0.0

    if args.report:
        print(f"statements: {len(ran)}/{len(instrumented)} run ({pct:.1f}%), "
              f"{len(uncovered)} never")
        if args.by_procedure:
            by = attribute(uncovered, procs)
            total = attribute(instrumented, procs)
            for name in sorted(by, key=lambda n: -len(by[n])):
                print(f"  {len(by[name]):5d}/{len(total[name]):-5d}  {name}"
                      f"  ({', '.join(str(x) for x in by[name][:8])}"
                      f"{' ...' if len(by[name]) > 8 else ''})")
        return 0

    if args.write_ratchet:
        by = attribute(uncovered, procs)
        total = attribute(instrumented, procs)
        path = root / "tests" / "checks" / RATCHET
        out = [
            "# Statement coverage of selfhost/compiler.pas over the corpus.",
            "#",
            "# A ratchet, not a catalogue -- and the weaker instrument for it,",
            "# which doc/sop.md §7 records. tests/checks/uncovered_procedures.txt",
            "# carries an argument per entry because there are two; a per-line",
            "# argument is not writable at this scale, so what is kept is the",
            "# count and the per-procedure breakdown, and a regression names the",
            "# procedures that moved rather than only a number.",
            "#",
            "# Regenerate with:  python3 tests/checks/line_coverage.py --write-ratchet",
            "# Doing so is a decision to argue for in the commit message.",
            "",
            f"uncovered {len(uncovered)}",
            f"instrumented {len(instrumented)}",
            "",
        ]
        for name in sorted(total):
            out.append(f"{name} {len(by.get(name, []))}/{len(total[name])}")
        path.write_text("\n".join(out) + "\n")
        print(f"line-coverage: wrote {path.name} "
              f"({len(uncovered)} uncovered of {len(instrumented)})")
        return 0

    want = read_ratchet(root)
    if want is None:
        print("line-coverage: no ratchet recorded; run --write-ratchet",
              file=sys.stderr)
        return 1
    if len(uncovered) > want:
        print(f"line-coverage: {len(uncovered)} statements never run, "
              f"was {want} -- {len(uncovered) - want} lost")
        by = attribute(uncovered, procs)
        for name in sorted(by, key=lambda n: -len(by[n]))[:10]:
            print(f"    {len(by[name]):5d}  {name}")
        print("\nAdd a case, or -- if this is deliberate -- regenerate with "
              "--write-ratchet and say why in the commit message. "
              "See doc/sop.md §5.")
        return 1

    if len(uncovered) < want:
        print(f"line-coverage: {len(uncovered)}/{len(instrumented)} "
              f"({pct:.1f}% run) -- {want - len(uncovered)} better than "
              f"recorded; regenerate with --write-ratchet")
        return 0

    print(f"line-coverage: {len(ran)}/{len(instrumented)} statements run "
          f"({pct:.1f}%), {len(uncovered)} never -- unchanged")
    return 0


if __name__ == "__main__":
    sys.exit(main())
