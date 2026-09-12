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



def own_statements(text, source):
    """The instrumented lines of `source`'s own routines, and the routines dropped.

    The IR is walked in order: a `; name line` marker opens a routine and every
    `pas_cov_hit` until the next marker belongs to it. A routine whose marker
    does not point at a line of this source declaring it came from somewhere
    else -- a generic body emitted here (AP 6.7.3.5) -- and neither its lines
    nor its name are this module's to answer for.
    """
    src = source.read_text(errors="surrogateescape").split("\n")
    own, dropped, keep = set(), [], False
    for line in text.split("\n"):
        mark = re.match(r"^; (\w+) (\d+)$", line)
        if mark:
            name, at = mark.group(1), int(mark.group(2))
            here = src[at - 1] if 0 < at <= len(src) else ""
            keep = re.match(r"^\s*(function|procedure)\s+" + re.escape(name)
                            + r"\b", here, re.I) is not None
            if not keep:
                dropped.append(name)
            continue
        hit = HIT.search(line)
        if hit and keep:
            own.add(int(hit.group(1)))
    return own, dropped


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
    #
    # **Only the statements this module wrote.** A generic's body is emitted in
    # the translation that activates it (AP 6.7.3.5), so a client of
    # `PasContainer` carries `VecPush` and six more in its own IR -- with
    # `PasContainer`'s line numbers, which index into *this* module's source
    # and land on whatever text is there. They inflated the denominator by 18
    # lines in `pastoml.pas` alone, and, being another file's numbering, they
    # collided differently whenever this file's length changed: the ratchet
    # moved three times in one day for edits that touched no statement, twice
    # for a comment. Each needed a commit message to establish that nothing
    # had happened.
    #
    # A routine is this module's when the `; name line` marker the IR writes
    # before it (ADR-0103) points at a line of this source that *declares* that
    # routine. A foreign one points wherever its own file's numbering falls.
    # Checked over all 33 modules when this was written: 479 own routines, all
    # matching, and 28 foreign, which are the same seven `Vec` routines in the
    # four modules that use them.
    denom, procs, foreign = {}, {}, {}
    for m in mods:
        if instr[m] is None:
            continue
        text = instr[m].read_text()
        procs[m] = sorted((int(l), n) for n, l in NAMED.findall(text))
        denom[m], foreign[m] = own_statements(text, m)

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
        # **Run it the way the suite runs it** (ADR-0378). `run_test.py` hands
        # every case two writable scratch paths and feeds it `<stem>.in` when
        # there is one; this sweep passed no arguments and fed `/dev/null`,
        # so a case whose header names external files stopped at its first
        # statement -- `lib_fs.pas` and six others -- and three that read
        # their input reached only the statements before the first `read`.
        # The lines were counted as unreached, which is a number that means
        # "the sweep did not run this" while reading as "the corpus does not
        # cover this". `lib_fs_tempdir.pas` exists as the parameterless
        # workaround and is now a case about `TemporaryDirectory` rather than
        # a stand-in.
        stdin_file = src.with_suffix(".in")
        timed_out = False
        try:
            with (open(stdin_file, "rb") if stdin_file.is_file()
                  else open(os.devnull, "rb")) as fin:
                subprocess.run([str(exe), str(cwd / "file1"),
                                str(cwd / "file2")],
                               capture_output=True, timeout=15,
                               cwd=str(cwd), stdin=fin,
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
    # (ADR-0282). The library is 33 modules and thousands of statements.
    if total_ins < 2000:
        print(f"lib-coverage: only {total_ins} statements instrumented, "
              f"below the floor of 2000", file=sys.stderr)
        return 1

    # What the attribution above dropped, said out loud, and checked. A routine
    # excluded from its module's denominator is a statement nothing will ever
    # be asked about, so the one direction this must not fail in is *quietly*:
    # a rule that stopped recognising a declaration would improve every ratchet
    # row at once and look like progress.
    #
    # The check is not a ratio -- `paslspdiag` has six routines of its own and
    # seven instantiations, which is legitimate and would fail any ratio worth
    # setting. It is that a dropped name is not declared in this source **at
    # all**: a routine wrongly dropped is one whose declaration is right there,
    # and a generic's is in the module that wrote it.
    dropped_total = 0
    for m in mods:
        if m not in denom:
            continue
        dropped_total += len(foreign[m])
        src = m.read_text(errors="surrogateescape")
        for name in sorted(set(foreign[m])):
            if re.search(r"^\s*(function|procedure)\s+" + re.escape(name)
                         + r"\b", src, re.I | re.M):
                print(f"lib-coverage: {m.relative_to(root).as_posix()} "
                      f"declares '{name}' and its statements were dropped as "
                      f"another module's -- the marker a routine is recognised "
                      f"by has stopped matching its declaration",
                      file=sys.stderr)
                return 1
    if dropped_total:
        names = sorted({n for m in foreign for n in foreign[m]})
        print(f"lib-coverage: {dropped_total} routine instantiation(s) across "
              f"{sum(1 for m in foreign if foreign[m])} module(s) belong to "
              f"another module and are not counted here "
              f"({', '.join(names)}) -- a generic's body is emitted in the "
              f"translation that activates it (AP 6.7.3.5)")

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
            "# PasHttps are exercised by tests/checks/tls.py, which is a gate",
            "# harness and not a corpus case, so this sweep never links them.",
            "# Driving it from here was rejected for the reason ADR-0346",
            "# learned the same day: tls.py skips without libssl, so the number",
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
    was, was_ins = {}, {}
    prev_unc = prev_ins = None
    for line in path.read_text().splitlines():
        if line.startswith("uncovered "):
            prev_unc = int(line.split()[1])
        elif line.startswith("instrumented "):
            prev_ins = int(line.split()[1])
        elif line and not line.startswith("#") and "/" in line:
            n, r = line.rsplit(" ", 1)
            was[n] = int(r.split("/")[0])
            was_ins[n] = int(r.split("/")[1])
    if prev_unc is None or prev_ins is None:
        print("lib-coverage: the ratchet names no total", file=sys.stderr)
        return 1

    # **The denominator is a claim too, and it was decoration** (ADR-0378).
    # `instrumented` and each row's `n/M` were written by --write-ratchet and
    # read by nothing: the header said 3521 while the run measured 3556 and
    # the gate passed, which is exactly the defect ADR-0354 closed in
    # `runtime-coverage` and it was here in a second gate the same week. A
    # denominator that moves unremarked is the half a ratchet on the numerator
    # cannot see -- a module losing statements takes uncovered ones with it and
    # the number improves. So both totals are compared, in both directions, and
    # so is every module's own; a legitimate change to `lib/` re-ratchets and
    # says what moved, which is the whole cost and the whole point.
    if total_ins != prev_ins:
        print(f"lib-coverage: {total_ins} statements instrumented, where the "
              f"ratchet says {prev_ins}. `lib/` gained or lost executable "
              f"statements, which is fine and is not this gate's to guess at:\n"
              f"  python3 tests/checks/lib_coverage.py --write-ratchet\n"
              f"and say in the commit message what moved.", file=sys.stderr)
        return 1
    drift = [(name, was_ins[name], ins) for name, unc, ins in rows
             if name in was_ins and was_ins[name] != ins]
    if drift:
        for name, before, now in drift:
            print(f"lib-coverage: {name} is {now} statements where the ratchet "
                  f"says {before}", file=sys.stderr)
        print("  python3 tests/checks/lib_coverage.py --write-ratchet",
              file=sys.stderr)
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
