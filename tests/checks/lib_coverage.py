#!/usr/bin/env python3
# Afterschool Pascal -- a Pascal compiler written in Pascal.
# Copyright (C) 2026 Hui-Hong You
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the GNU
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <https://www.gnu.org/licenses/>.
"""Statement coverage of `lib/`, over the cases that import it (ADR-0350).

`line_coverage.py` beside this file measures the compiler's three
program-components and nothing else, so 11 160 lines across 32 library modules
-- the largest body of this dialect outside the compiler -- were measured by
nothing. Every module *is* imported by some case, which is
`procedure-coverage`'s question; what fraction of one runs was nobody's.

**The attribution problem, and the same answer.** `$PASCOV_LINES` records bare
line numbers with no file, so a program linking six modules yields six sources'
lines in one heap. `line_coverage.py` solves it by instrumenting exactly one
component per build; this does the same, one *module* at a time, and a line is
then unambiguously that module's.

**What makes it affordable.** A module's IR does not depend on which other
module was instrumented, and neither does an importing program's -- so each
module is translated twice (plain and instrumented), each program once, and
only the *link* is repeated per pair. 125 pairs cost 115 translations rather
than 500.

**What it cannot see, and the number says so.** A *generic* routine's body is
re-read and emitted in the translation that activates it (AP 6.7.3.5,
ADR-0211), which is the client's -- so it is instrumented there and not in the
module. `lib/dialect/passortx.pas` is the extreme case: its own IR carries
**no** coverage sites and the importing program's carries 187. Attributing
those back would need the compiler to record which *file* a counter belongs to,
and `$PASCOV_LINES` is bare line numbers; that is a feature and not a fix here.
So a module whose routines are generic reports a denominator of 0, which means
*nothing here is measurable this way* and never *everything here is covered* --
the run prints those modules by name so the two cannot be confused.

A **ratchet**, as `line_coverage.py` is and with its weakness: it fails when
the number rises and not when a line stops being reached for a bad reason. A
per-line argument is not writable at this scale, so what is kept is the count
and the per-module breakdown.

Usage:  tests/checks/lib_coverage.py [--build DIR] [--report] [--write-ratchet]
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

HIT = re.compile(r"call void @pas_cov_hit\(i32 (\d+)\)")
# The IR writes `; name line` before each routine (ADR-0103), and this
# matched `; name at line N`, which nothing emits -- so it found nothing
# and `procs` was dead. Caught by review rather than by a test, because a
# regex that matches nothing produces an empty breakdown and no error.
NAMED = re.compile(r"^; (\w+) (\d+)$", re.M)
RATCHET = "lib_coverage.txt"

# The corpus roots a case may live in. `lib/` itself is not among them: a
# module is measured, never a driver.
CASE_ROOTS = ("tests", "tests/extended", "tests/dialect", "examples")


def modules(root):
    """Every library module, by path, in a stable order."""
    return sorted(list((root / "lib").glob("*.pas")) +
                  list((root / "lib" / "dialect").glob("*.pas")))


def imports_of(pascalc, root, src):
    """The library modules a case needs, in the order they must be translated.

    Asked of the compiler rather than parsed out of the source: resolution is
    transitive and post-order (ADR-0244), and a second reader of `import` would
    be a second opinion about what a program depends on.
    """
    r = subprocess.run(
        [str(pascalc), "--dump-imports",
         "--import-path", str(root / "lib"),
         "--import-path", str(root / "lib" / "dialect"), str(src)],
        capture_output=True, text=True)
    if r.returncode != 0:
        return None
    out = []
    for line in r.stdout.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[0] == "component":
            p = (root / parts[1]) if not parts[1].startswith("/") \
                else pathlib.Path(parts[1])
            if "lib/" in str(p):
                out.append(p)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", default="build")
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--write-ratchet", action="store_true")
    ap.add_argument("root", nargs="?")
    args = ap.parse_args()

    root = pathlib.Path(args.root or
                        pathlib.Path(__file__).resolve().parents[2])
    build = pathlib.Path(args.build)
    if not build.is_absolute():
        build = root / build
    pascalc = build / "bin" / "pascalc"
    pasrt = build / "lib" / "libpasrt.a"
    if not pascalc.exists() or not pasrt.exists() or not shutil.which("clang"):
        print(f"lib-coverage: no compiler at {pascalc} -- build first",
              file=sys.stderr)
        return 77

    import tempfile
    work = pathlib.Path(tempfile.mkdtemp(prefix="libcov."))
    try:
        return run(root, pascalc, pasrt, work, args)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def translate(pascalc, root, target, deps, out, instrument):
    """One module or program to IR, with its dependencies named as imports."""
    argv = [str(pascalc)]
    if instrument:
        argv.append("--coverage")
    for d in deps:
        argv += ["--import", str(d)]
    argv += [str(target), "-o", str(out)]
    r = subprocess.run(argv, capture_output=True, text=True)
    return out if r.returncode == 0 and out.exists() else None


def run(root, pascalc, pasrt, work, args):
    mods = modules(root)
    by_path = {m: i for i, m in enumerate(mods)}

    # Which case exercises which module. A case with no library import is not
    # this gate's business and is dropped here rather than linked and run.
    cases = []
    for rel in CASE_ROOTS:
        for src in sorted((root / rel).glob("*.pas")):
            deps = imports_of(pascalc, root, src)
            if deps:
                cases.append((src, deps))
    if not cases:
        print("lib-coverage: no case imports a library module", file=sys.stderr)
        return 1

    # Translate each module twice and each program once, and cache. This is
    # what keeps the pair count off the translation count.
    plain, instr = {}, {}
    for m in mods:
        deps = imports_of(pascalc, root, m) or []
        deps = [d for d in deps if d != m]
        plain[m] = translate(pascalc, root, m, deps,
                             work / f"p{by_path[m]}.ll", False)
        instr[m] = translate(pascalc, root, m, deps,
                             work / f"i{by_path[m]}.ll", True)

    progs = {}
    for i, (src, deps) in enumerate(cases):
        progs[src] = translate(pascalc, root, src, deps,
                               work / f"m{i}.ll", False)

    # The denominator: one `pas_cov_hit` per instrumented statement, read from
    # the same IR the numerator comes out of, so nothing keeps a second idea of
    # what was executable.
    denom, procs = {}, {}
    for m in mods:
        if instr[m] is None:
            continue
        text = instr[m].read_text()
        denom[m] = {int(n) for n in HIT.findall(text)}
        procs[m] = sorted((int(l), n) for n, l in NAMED.findall(text))

    jobs = []
    for src, deps in cases:
        if progs[src] is None:
            continue
        for m in deps:
            if m in denom and plain.get(m) and instr.get(m):
                jobs.append((src, deps, m))

    def one(idx_job):
        idx, (src, deps, subject) = idx_job
        irs = [str(instr[d] if d == subject else plain[d]) for d in deps]
        if any(x == "None" for x in irs):
            return subject, set(), False
        exe = work / f"e{idx}"
        r = subprocess.run(["clang", "-Wno-override-module", "-O1",
                            str(progs[src]), *irs, str(pasrt), "-lm",
                            "-o", str(exe)], capture_output=True, text=True)
        if r.returncode != 0:
            return subject, set(), False
        lines = work / f"L{idx}.txt"
        # Short, and reported rather than swallowed. A case that opens a socket
        # and waits for a peer contributes nothing to a coverage number once it
        # has stopped executing statements, and the first run of this sweep
        # spent four minutes at 15% of a core waiting for several of them --
        # `PASCOV_LINES` is written as the program runs, so what a timed-out
        # case did reach is still counted. What must not happen is the wait
        # being invisible: a sweep that quietly gives up is a sweep whose
        # number means something different from what it says.
        # Run in a directory of the sweep's own, not the checkout. A corpus
        # case that writes a file writes it where it runs, and the first run of
        # this gate left five of them in the repository root -- `.lib_file.p`,
        # `.stream.q` and the rest. A measurement that dirties the tree it
        # measures is one somebody will stop running.
        cwd = work / f"run{idx}"
        cwd.mkdir(exist_ok=True)
        timed_out = False
        try:
            subprocess.run([str(exe)], capture_output=True, timeout=15,
                           cwd=str(cwd), stdin=subprocess.DEVNULL,
                           env=dict(os.environ, PASCOV_LINES=str(lines)))
        except subprocess.TimeoutExpired:
            timed_out = True
        if not lines.exists():
            return subject, set(), timed_out
        return subject, {int(x) for x in lines.read_text().split()}, timed_out

    hit = collections.defaultdict(set)
    waited = 0
    with concurrent.futures.ThreadPoolExecutor(
            max_workers=os.cpu_count()) as ex:
        for subject, ran, slow in ex.map(one, enumerate(jobs)):
            hit[subject] |= ran
            waited += 1 if slow else 0

    rows, total_unc, total_ins = [], 0, 0
    for m in mods:
        if m not in denom:
            continue
        unc = len(denom[m] - hit[m])
        rows.append((m.relative_to(root).as_posix(), unc, len(denom[m])))
        total_unc += unc
        total_ins += len(denom[m])

    # A floor, so a run that linked nothing cannot pass by measuring nothing
    # (ADR-0282). The library is 32 modules and thousands of statements.
    if total_ins < 2000:
        print(f"lib-coverage: only {total_ins} statements instrumented, "
              f"below the floor of 2000", file=sys.stderr)
        return 1

    if args.report:
        for name, unc, ins in rows:
            if unc:
                pct = 100.0 * (ins - unc) / ins
                print(f"{unc:5d}/{ins:<5d} {pct:5.1f}%  {name}")
        print(f"\n{total_unc} uncovered of {total_ins} "
              f"({100.0 * (total_ins - total_unc) / total_ins:.1f}% covered)"
              + (f", {waited} case(s) gave up at 15s" if waited else ""))
        return 0

    text = ["# Statement coverage of lib/, over the cases that import it",
            "# (ADR-0350).",
            "#",
            "# A ratchet, as tests/checks/line_coverage.txt is and with its",
            "# weakness: it fails when the number rises, and a line that stops",
            "# being reached for a bad reason is invisible to it. What is kept",
            "# is the count and the per-module breakdown, so a regression names",
            "# the modules that moved rather than only a number.",
            "#",
            "# **Two modules read 0 and are not uncovered.** PasTls and",
            "# PasHttps are exercised by tests/checks/tls.sh, which is a gate",
            "# harness and not a corpus case, so this sweep never links them.",
            "# Driving it from here was rejected for the reason ADR-0346",
            "# learned the same day: tls.sh skips without libssl, so the number",
            "# would move with whether a machine has a package, and a ratchet",
            "# whose answer depends on the toolchain is not a ratchet. What",
            "# covers them is `tls`, with TLS_REQUIRE and a CI job refusing to",
            "# let it pass by skipping.",
            "#",
            "# Regenerate with:  python3 tests/checks/lib_coverage.py"
            " --write-ratchet",
            "# Doing so is a decision to argue for in the commit message.",
            "",
            f"uncovered {total_unc}",
            f"instrumented {total_ins}",
            ""]
    for name, unc, ins in rows:
        text.append(f"{name} {unc}/{ins}")
    body = "\n".join(text) + "\n"

    path = root / "tests" / "checks" / RATCHET
    if args.write_ratchet:
        path.write_text(body)
        print(f"lib-coverage: wrote {path.relative_to(root)}: "
              f"{total_unc} uncovered of {total_ins}")
        return 0

    if not path.exists():
        print(f"lib-coverage: no ratchet at {path} -- "
              f"run with --write-ratchet", file=sys.stderr)
        return 1
    was = {}
    prev_unc = None
    for line in path.read_text().splitlines():
        if line.startswith("uncovered "):
            prev_unc = int(line.split()[1])
        elif line and not line.startswith("#") and "/" in line:
            n, r = line.rsplit(" ", 1)
            was[n] = int(r.split("/")[0])
    if prev_unc is None:
        print("lib-coverage: the ratchet names no total", file=sys.stderr)
        return 1
    if total_unc > prev_unc:
        print(f"lib-coverage: {total_unc} statements never run, was "
              f"{prev_unc} -- {total_unc - prev_unc} lost", file=sys.stderr)
        import bisect
        for m in mods:
            if m not in denom:
                continue
            name = m.relative_to(root).as_posix()
            unc = len(denom[m] - hit[m])
            if unc <= was.get(name, 0):
                continue
            print(f"  {name}: {was.get(name, 0)} -> {unc} of {len(denom[m])}",
                  file=sys.stderr)
            # Which routines the lost lines are in. A module is the gate's
            # unit, but a module is hundreds of statements and a procedure is
            # what somebody goes and looks at -- `line_coverage.py` names one
            # for the same reason.
            starts = [q[0] for q in procs[m]]
            where = collections.Counter()
            for line in sorted(denom[m] - hit[m]):
                i = bisect.bisect_right(starts, line) - 1
                where[procs[m][i][1] if i >= 0 else "(module level)"] += 1
            for proc, n in where.most_common(6):
                print(f"      {n:4d} in {proc}", file=sys.stderr)
        return 1
    note = ""
    # **Both directions**, which is what separates a catalogue from a ratchet
    # and is `verify/`'s KNOWN_GAP rule (ADR-0013) said about a number. An
    # improvement left unrecorded is not free: the floor stays where it was, so
    # a later regression back to it passes, and the slack accumulates silently
    # until the gate is measuring nothing anybody chose. `line-coverage` is
    # one-directional and `doc/sop.md` §7 counts that as a cost; this one and
    # its two siblings do not add to the count (ADR-0350).
    if total_unc < prev_unc:
        print(f"lib-coverage: {total_unc} statements never run, was "
              f"{prev_unc} -- {prev_unc - total_unc} FEWER, which is good and "
              f"must be recorded: the ratchet still admits {prev_unc}, so a "
              f"regression back to it would pass.\n"
              f"  python3 tests/checks/lib_coverage.py --write-ratchet\n"
              f"and say in the commit message what covered them.",
              file=sys.stderr)
        return 1

    slow = f", {waited} case(s) gave up at 15s" if waited else ""
    generic = [n for n, unc, ins in rows if ins == 0]
    print(f"lib-coverage: {total_ins - total_unc} of {total_ins} statements "
          f"across {len(rows)} modules "
          f"({100.0 * (total_ins - total_unc) / total_ins:.1f}%){slow}{note}")
    if generic:
        print(f"lib-coverage: {len(generic)} module(s) have nothing to "
              f"measure here, their routines being generic and emitted in the "
              f"client (AP 6.7.3.5): " + ", ".join(generic))
    return 0


if __name__ == "__main__":
    sys.exit(main())
