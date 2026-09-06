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
"""Line coverage of `runtime/*.c`, over the corpus that links it (ADR-0351).

**5 551 lines of C measured by nothing.** `line_coverage.py` measures the
compiler's three program-components, `lib_coverage.py` measures the 32 library
modules (ADR-0350), and between them they cover every line of Pascal in this
tree. The runtime is the only C here, it is linked into every compiled program,
and which of its lines run was a question no oracle asked. `gcov` left with the
C++ implementation (ADR-0232) and nothing replaced it.

**And it is exactly the half the sanitizers can see.** ADR-0342 established
that AddressSanitizer never instruments compiled Pascal -- clang receives an
already-lowered `.ll` and adds nothing to it -- so `sanitizers` and
`thread-sanitizer` are watching `runtime/*.c` and only that. Clang's
source-based coverage instruments at the same place for the same reason, which
makes this number the *denominator* those two gates were missing: an
uninstrumented line is a line ASan, UBSan, LSan and TSan looked at zero times.

**It is a mode of `sanitize.sh` and not a second harness.** That script already
builds a second `libpasrt.a` with extra flags and links every case against it,
reading each case's `.components`, `.importpath`, `.importenv`, `.opt` and
`.in` sidecars -- 120 lines that took 47 silently unlinked cases out of this
tree once. ADR-0327 refused to copy them for ThreadSanitizer and this refuses
for the same reason; `SANITIZE_MODE=coverage` is the whole of the difference,
plus `SANITIZE_RT_DIR` so the instrumented **objects** outlive the sweep,
llvm-cov reading the coverage mapping out of them.

**The whole corpus runs, and there is no subset.** 47 s for 377 programs, which
is well under the two gates that set this suite's wall clock, so the honesty
question a documented subset would raise does not arise.

A **ratchet**, as `line_coverage.py` and `lib_coverage.py` are and with their
weakness: it fails when the uncovered count rises and not when a line stops
being reached for a bad reason. What is kept is the count and the per-file
breakdown, so a regression names the file that moved.

**What the number does not cover**, and none of it is fixable here:

  - compiled Pascal, deliberately -- that is the other two gates' question;
  - the 195 cases with no `.out`, which are meant to fail at compile time and
    so never reach the runtime at all, and the 12 that want file names on
    their command line, which is `sanitize.sh`'s own documented limit;
  - `tests/dumps/`, `lsp/`, `tests/spec/` and `selfhost/`, which have harnesses
    of their own that this does not drive, and the gate harnesses -- `tls.sh`
    most of all -- for `lib_coverage.txt`'s reason: a number that moves with
    whether a machine has libssl is not a ratchet;
  - a program killed by a signal, the profile being written by an `atexit`
    handler. `pas_runtime_error` goes through `exit()`, so every deliberate
    trap in the corpus is counted.

Usage:  tests/checks/runtime_coverage.py <pascalcc> [<pascalc>] [--write-ratchet]
"""
import argparse
import glob
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

RATCHET = "runtime_coverage.txt"
UNITS = ("pasrt", "pasrt_posix", "pasrt_unicode", "pasrt_task")

# A run that reached nothing prints the same shape of tally as a clean one --
# the empty comparison this repository has been caught by more than once
# (ADR-0282). The corpus yields one profile per process and a few more than one
# per program, some cases starting a child; the floor is set well under what
# exists so a case added or removed does not move it, and far enough above zero
# that a sweep which built the runtime and ran no program cannot pass.
FLOOR_PROFILES = 300


def skip(message, require):
    """77 unless a job asked for the real answer (ADR-0330)."""
    if require:
        sys.stderr.write("runtime-coverage: %s -- and "
                         "RUNTIME_COVERAGE_REQUIRE is set\n" % message)
        return 1
    sys.stderr.write("runtime-coverage: skipped -- %s\n" % message)
    return 77


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("pascalcc", nargs="?")
    ap.add_argument("pascalc", nargs="?")
    ap.add_argument("--write-ratchet", action="store_true")
    args = ap.parse_args()

    root = pathlib.Path(__file__).resolve().parent.parent.parent
    pascalcc = args.pascalcc or str(root / "tools" / "pascalcc")
    pascalc = args.pascalc or os.environ.get(
        "PASCALC", str(root / "build" / "bin" / "pascalc"))
    require = os.environ.get("RUNTIME_COVERAGE_REQUIRE", "")

    # llvm-profdata and llvm-cov are a separate package from clang on most
    # distributions, exactly as compiler-rt is -- so this is asked the way
    # `sanitize.sh` asks for its checker, before anything is built.
    for tool in ("llvm-profdata", "llvm-cov", "clang", "ar"):
        if shutil.which(tool) is None:
            return skip("no %s" % tool, require)

    work = tempfile.mkdtemp(prefix="runtime-coverage-")
    try:
        raw = os.path.join(work, "raw")
        rt = os.path.join(work, "rt")
        os.makedirs(raw)
        os.makedirs(rt)

        env = dict(os.environ)
        env["SANITIZE_MODE"] = "coverage"
        env["SANITIZE_RT_DIR"] = rt
        # `%p` and not a fixed name: 377 programs run in one directory and each
        # would otherwise overwrite the last, which is a sweep reporting the
        # coverage of whichever case happened to be alphabetically final. The
        # path is absolute because `sanitize.sh` runs each program with its own
        # working directory.
        env["LLVM_PROFILE_FILE"] = os.path.join(raw, "%p.profraw")
        env["PASCALC"] = pascalc
        # A skip inside the harness is this gate's skip, so its own refusal
        # variable is set from ours rather than left to the caller: a job that
        # asked for the real answer here must not get a 77 from one layer down.
        if require:
            env["SANITIZE_REQUIRE"] = require

        run = subprocess.run(
            [str(root / "tests" / "checks" / "sanitize.sh"), pascalcc, pascalc],
            env=env)
        if run.returncode == 77:
            return skip("sanitize.sh has nothing to run under", require)
        if run.returncode != 0:
            sys.stderr.write("runtime-coverage: the corpus sweep failed\n")
            return 1

        profiles = sorted(glob.glob(os.path.join(raw, "*.profraw")))
        if len(profiles) < FLOOR_PROFILES:
            sys.stderr.write(
                "runtime-coverage: only %d profile(s) written, below the floor "
                "of %d -- a run that executed nothing reports the same shape "
                "of number as a clean one\n" % (len(profiles), FLOOR_PROFILES))
            return 1

        merged = os.path.join(work, "all.profdata")
        m = subprocess.run(["llvm-profdata", "merge", "-sparse", "-o", merged]
                           + profiles, capture_output=True, text=True)
        if m.returncode != 0:
            sys.stderr.write("runtime-coverage: llvm-profdata merge failed:\n")
            sys.stderr.write(m.stderr[:2000])
            return 1

        # llvm-cov takes the first object as a positional and every further one
        # behind `-object`, which is why this is not a uniform list.
        paths = [os.path.join(rt, unit + ".o") for unit in UNITS]
        objs = [paths[0]]
        for p in paths[1:]:
            objs += ["-object", p]
        # `-summary-only`: the per-line detail is a report for a person and
        # this wants four numbers. The objects are the *instrumented* ones the
        # sweep linked, so the function hashes cannot disagree with the profile.
        e = subprocess.run(["llvm-cov", "export", "-summary-only",
                            "-instr-profile=" + merged] + objs,
                           capture_output=True, text=True)
        if e.returncode != 0:
            sys.stderr.write("runtime-coverage: llvm-cov export failed:\n")
            sys.stderr.write(e.stderr[:2000])
            return 1
        data = json.loads(e.stdout)["data"][0]
    finally:
        shutil.rmtree(work, ignore_errors=True)

    rows = []
    for f in data["files"]:
        name = os.path.basename(f["filename"])
        # A header contributes no executable line and llvm-cov lists it anyway;
        # a row of 0/0 in the ratchet would be a name with nothing behind it.
        if f["summary"]["lines"]["count"] == 0:
            continue
        lines = f["summary"]["lines"]
        rows.append(("runtime/" + name,
                     lines["count"] - lines["covered"], lines["count"]))
    rows.sort()
    total = data["totals"]["lines"]
    total_unc = total["count"] - total["covered"]
    total_ins = total["count"]
    branches = data["totals"]["branches"]

    if len(rows) != len(UNITS):
        sys.stderr.write(
            "runtime-coverage: %d translation unit(s) measured, and the "
            "runtime has %d -- a unit added here needs a row in the ratchet, "
            "and one that vanished is a build this gate no longer describes\n"
            % (len(rows), len(UNITS)))
        return 1

    text = ["# Line coverage of runtime/*.c, over the corpus that links it",
            "# (ADR-0351).",
            "#",
            "# The runtime is the only C in this tree and every compiled",
            "# program links it; until this gate, which of its lines run was a",
            "# question nothing asked. It is also exactly what the sanitizers",
            "# see, ADR-0342 having established that AddressSanitizer never",
            "# instruments compiled Pascal -- so an uncovered line here is a",
            "# line ASan, UBSan, LSan and TSan looked at zero times.",
            "#",
            "# A ratchet, as tests/checks/line_coverage.txt and",
            "# tests/checks/lib_coverage.txt are and with their weakness: it",
            "# fails when the count rises, and a line that stops being reached",
            "# for a bad reason is invisible to it. What is kept is the count",
            "# and the per-file breakdown, so a regression names the file that",
            "# moved rather than only a number.",
            "#",
            "# runtime/pasrt_posix.c is the low row and the reason is in its",
            "# name: it is the sockets, the directory walk, the process and",
            "# the clock, and their error paths ask what a corpus running on a",
            "# working machine cannot arrange -- a failed bind, a directory",
            "# that vanished mid-walk. tests/checks/tls.sh drives more of it",
            "# and is not swept here, for lib_coverage.txt's reason: a number",
            "# that moves with whether a machine has libssl is not a ratchet.",
            "#",
            "# Regenerate with:",
            "#   tests/checks/runtime_coverage.py tools/pascalcc --write-ratchet",
            "# Doing so is a decision to argue for in the commit message.",
            "",
            "uncovered %d" % total_unc,
            "instrumented %d" % total_ins,
            ""]
    for name, unc, ins in rows:
        text.append("%s %d/%d" % (name, unc, ins))
    body = "\n".join(text) + "\n"

    path = root / "tests" / "checks" / RATCHET
    if args.write_ratchet:
        path.write_text(body)
        print("runtime-coverage: wrote %s: %d uncovered of %d"
              % (path.relative_to(root), total_unc, total_ins))
        return 0

    if not path.exists():
        sys.stderr.write("runtime-coverage: no ratchet at %s -- run with "
                         "--write-ratchet\n" % path)
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
        sys.stderr.write("runtime-coverage: the ratchet names no total\n")
        return 1

    if total_unc > prev_unc:
        sys.stderr.write(
            "runtime-coverage: %d lines of the runtime never run, was %d -- "
            "%d lost\n" % (total_unc, prev_unc, total_unc - prev_unc))
        for name, unc, ins in rows:
            if unc > was.get(name, 0):
                sys.stderr.write("  %s: %d -> %d of %d\n"
                                 % (name, was.get(name, 0), unc, ins))
        return 1

    note = "" if total_unc == prev_unc else \
        " -- %d fewer than the ratchet; --write-ratchet" % (prev_unc - total_unc)
    print("runtime-coverage: %d of %d lines across %d translation units "
          "(%.1f%%), %d of %d branches (%.1f%%)%s"
          % (total_ins - total_unc, total_ins, len(rows),
             100.0 * (total_ins - total_unc) / total_ins,
             branches["covered"], branches["count"], branches["percent"], note))
    return 0


if __name__ == "__main__":
    sys.exit(main())
