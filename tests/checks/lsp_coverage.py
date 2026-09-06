#!/usr/bin/env python3
# Afterschool Pascal -- a Pascal dialect that exists to meet modern computing
# requirements.
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
"""Statement coverage of the language server, over the sessions that drive it.

ADR-0350's finding, one directory over. `line_coverage.py` measures the
compiler's three program-components and `lib_coverage.py` the 32 library
modules; `lsp/pasls.pas` is 3814 lines of this dialect -- the second-largest
program in the tree -- and 32 recorded sessions replay against it byte for byte
(ADR-0236, ADR-0241) while *what fraction of it they run* was nobody's
question. A golden says the answers are right; it says nothing about how much
of the server was asked.

**The replay is not reimplemented, and that is the point.** `lsp/run.sh` frames
a session, honours its `.mcp`, `.workspace`, `.scratch` and `.tmpdir` sidecars,
picks a scratch path per session and takes `PASHEAP_BALANCE` out of the
environment twice -- 120 lines that mean something only when they are one copy.
This drives that script and reads what the run left behind, for
`thread-sanitizer`'s reason: a second replayer would be a second opinion about
what a session *is*, and the first divergence would be silent. It follows that
this gate also fails when a golden fails, which is a feature -- a coverage
number taken from a conversation that went wrong measures nothing.

**Attribution, and the same answer as the two gates above.** `$PASCOV_LINES`
records a bare line number with no file, so `lsp/build.sh` is asked (through
`PASLS_COVERAGE_IR`) to instrument `pasls.pas` and none of its thirteen
components: a line is then unambiguously the server's. The *denominator* is the
`pas_cov_hit` sites of the very IR that build wrote, so nothing here keeps a
second idea of what was executable (ADR-0104).

**One thing the attribution trick does not reach, and the number says so.** A
generic routine's body is emitted in the translation that activates it
(AP 6.7.3.5, ADR-0211), so `PasContainer`'s `VecPush` and `MapGet` are compiled
*into* this module and instrumented with it -- carrying **PasContainer's** line
numbers, which collide with the server's own. So the IR is partitioned by
function and each function is asked whose it is: the compiler's own
`--dump-symbols` outline of `pasls.pas` says which routines that source
declares, and a marked function that is not one of them is an instantiation
from elsewhere. Its lines are subtracted from both halves. The count of server
lines lost that way is `ambiguous` in the ratchet and is ratcheted too -- a new
generic call site that eats measurable statements would otherwise *shrink* the
denominator and read as an improvement.

That partition is also what does the per-procedure breakdown, in place of
`line_coverage.py`'s bisect over start lines: a bisect would file a generic
body's line under whichever of the server's procedures happens to begin below
it, which is a wrong name printed with confidence.

A **ratchet**, with `line_coverage.txt`'s weakness: it fails when the number
rises and not when a line stops being reached for a bad reason. What it keeps
against that is the per-procedure breakdown, so a regression names the
procedures that moved rather than only a number.

Usage:  tests/checks/lsp_coverage.py [--build DIR] [--report] [--write-ratchet]
"""
import argparse
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

SKIP = 77
HIT = re.compile(r"call void @pas_cov_hit\(i32 (\d+)\)")
# The comment ADR-0103 put in front of every emitted routine: its name, folded,
# and the line its declaration begins on.
MARK = re.compile(r"^; ([a-z_][a-z_0-9]*) (\d+)$")
# `pasls: N session(s), M failed` -- run.sh's own summary, and the only place
# that knows how many conversations were actually held.
SUMMARY = re.compile(r"^pasls: (\d+) session\(s\), (\d+) failed$", re.M)
RATCHET = "lsp_coverage.txt"

# Floors, for ADR-0282's reason: a sweep that replayed nothing prints a number
# and passes. 32 sessions exist today and the server instruments about 1400
# statements, so neither of these can be tripped by anything but a harness that
# stopped doing its job.
MIN_SESSIONS = 25
MIN_STATEMENTS = 1000


def own_routines(pascalc, src):
    """The (folded name, start line) of every routine `src` itself declares.

    Asked of the compiler rather than read out of the Pascal: `--dump-symbols`
    stops after the parse and answers in Pascal's own words (ADR-0239), and a
    regex over `procedure` in a 3814-line source would be the second reader of
    Pascal-shaped text that ADR-0229 and ADR-0230 each moved a gate off.
    """
    r = subprocess.run([str(pascalc), "--dump-symbols", str(src),
                        "-o", os.devnull], capture_output=True, text=True)
    if r.returncode != 0:
        return None
    out = set()
    for line in r.stdout.splitlines():
        f = line.split()
        # symbol <depth> <kind> <line> <col> <namecol> <endline>
        #        <endcol> <name>
        if len(f) >= 9 and f[0] == "symbol" and f[2] in ("procedure",
                                                         "function"):
            out.add((f[-1], int(f[3])))
    return out


def partition(text):
    """Every emitted function, as (name, decl line) -> the lines it hits.

    The emitter is sequential and prints a function whole (ADR-0025), so a
    `define` opens one and a `}` in the first column closes it. The main
    program's body carries no name comment and is keyed None, which is where
    the statements of the program-block itself land.
    """
    funs, mark, key, inside = {}, None, None, False
    for line in text.splitlines():
        m = MARK.match(line)
        if m:
            mark = (m.group(1), int(m.group(2)))
            continue
        if line.startswith("define"):
            key, inside, mark = mark, True, None
            funs.setdefault(key, set())
            continue
        if line == "}":
            key, inside = None, False
            continue
        h = HIT.search(line)
        if h and inside:
            funs[key].add(int(h.group(1)))
    return funs


def replay(root, pascalc, build_dir, work):
    """Build an instrumented server and hold all 32 conversations with it.

    Returns (IR text, reached lines, session count) or None -- and None is a
    *failure*, never a skip: a replay that went wrong is the one thing this
    must not report as "nothing to say" (line_coverage.py's note).
    """
    ir = work / "pasls.ll"
    lines = work / "lines.txt"
    env = dict(os.environ,
               PASCALC=str(pascalc),
               AFTERSCHOOL_PASCAL_RUNTIME=str(build_dir / "lib"),
               PASLS_COVERAGE_IR=str(ir),
               PASCOV_LINES=str(lines))
    # The branch half of `--coverage` is not this gate's question, and an
    # inherited path would have the server append to a file nothing reads.
    env.pop("PASCOV_BRANCHES", None)
    try:
        r = subprocess.run([str(root / "lsp" / "run.sh"),
                            str(root / "tools" / "pascalcc"), str(pascalc)],
                           capture_output=True, text=True, timeout=900,
                           cwd=str(root), env=env)
    except subprocess.TimeoutExpired:
        print("lsp-coverage: the session replay did not finish in 900s",
              file=sys.stderr)
        return None
    if r.returncode != 0:
        print("lsp-coverage: the sessions did not replay -- a coverage number "
              "taken from a conversation that went wrong measures nothing",
              file=sys.stderr)
        print(r.stdout[-4000:], file=sys.stderr)
        print(r.stderr[-4000:], file=sys.stderr)
        return None
    m = SUMMARY.search(r.stdout)
    if not m:
        print("lsp-coverage: lsp/run.sh printed no summary line",
              file=sys.stderr)
        return None
    if not ir.exists():
        print(f"lsp-coverage: lsp/build.sh wrote no IR to {ir} -- does it "
              f"still honour PASLS_COVERAGE_IR?", file=sys.stderr)
        return None
    reached = set()
    if lines.exists():
        reached = {int(x) for x in lines.read_text().split()}
    return ir.read_text(), reached, int(m.group(1))


def measure(text, own, reached):
    """The three sets the whole gate is stated in.

    `mine` is what `pasls.pas` declares plus the program-block; `generic` is
    what an imported module supplied and this translation emitted (AP 6.7.3.5);
    the denominator is the first minus the second, because a line in both
    cannot be attributed to either.
    """
    funs = partition(text)
    mine = {k: v for k, v in funs.items() if k is None or k in own}
    generic = {k: v for k, v in funs.items() if k is not None and k not in own}
    server = set().union(*mine.values()) if mine else set()
    foreign = set().union(*generic.values()) if generic else set()
    denom = server - foreign
    by_proc = {}
    for k, v in mine.items():
        by_proc[k[0] if k else "(program level)"] = v & denom
    return denom, reached & denom, server & foreign, sorted(
        {k[0] for k in generic}), by_proc


def report_rows(by_proc, uncovered):
    rows = []
    for name in sorted(by_proc):
        total = by_proc[name]
        if not total:
            continue
        rows.append((name, len(total & uncovered), len(total)))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root", nargs="?", default=None)
    ap.add_argument("--build", default=None)
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--write-ratchet", action="store_true")
    args = ap.parse_args()

    root = pathlib.Path(args.root or
                        pathlib.Path(__file__).resolve().parents[2]).resolve()
    build_dir = pathlib.Path(args.build or root / "build").resolve()
    pascalc = build_dir / "bin" / "pascalc"
    pasrt = build_dir / "lib" / "libpasrt.a"
    if not pascalc.exists() or not pasrt.exists() or not shutil.which("clang"):
        print(f"lsp-coverage: no compiler at {pascalc} -- build first")
        return SKIP

    own = own_routines(pascalc, root / "lsp" / "pasls.pas")
    if own is None:
        print("lsp-coverage: the compiler could not read lsp/pasls.pas, and "
              "that is a failure and not a skip", file=sys.stderr)
        return 1

    with tempfile.TemporaryDirectory(prefix="lspcov.") as tmp:
        got = replay(root, pascalc, build_dir, pathlib.Path(tmp))
        if got is None:
            return 1
        text, reached, sessions = got

    denom, ran, ambiguous, generics, by_proc = measure(text, own, reached)
    uncovered = denom - ran

    if sessions < MIN_SESSIONS:
        print(f"lsp-coverage: only {sessions} session(s) replayed, below the "
              f"floor of {MIN_SESSIONS} -- a sweep that holds no conversation "
              f"must not pass by measuring nothing", file=sys.stderr)
        return 1
    if len(denom) < MIN_STATEMENTS:
        print(f"lsp-coverage: only {len(denom)} statements instrumented, "
              f"below the floor of {MIN_STATEMENTS}", file=sys.stderr)
        return 1

    rows = report_rows(by_proc, uncovered)
    pct = 100.0 * len(ran) / len(denom)

    if args.report:
        for name, unc, ins in sorted(rows, key=lambda r: -r[1]):
            if unc:
                print(f"{unc:5d}/{ins:<5d} {100.0 * (ins - unc) / ins:5.1f}%"
                      f"  {name}")
        print(f"\n{len(uncovered)} uncovered of {len(denom)} ({pct:.1f}% "
              f"covered) over {sessions} sessions; {len(ambiguous)} line(s) "
              f"unmeasurable, shared with a generic body")
        return 0

    body = "\n".join([
        "# Statement coverage of lsp/pasls.pas, over the sessions",
        "# lsp/run.sh replays against it (ADR-0236, ADR-0241).",
        "#",
        "# A ratchet, as tests/checks/line_coverage.txt is and with its",
        "# weakness: it fails when the number rises, and a line that stops",
        "# being reached for a bad reason is invisible to it. What is kept",
        "# against that is the per-procedure breakdown, so a regression names",
        "# the procedures that moved rather than only a number.",
        "#",
        "# `ambiguous` is ratcheted too, and is not slack. A generic",
        "# routine's body is emitted in the translation that activates it",
        "# (AP 6.7.3.5), so PasContainer's vectors and maps are compiled",
        "# into this module carrying *their* line numbers; a server line",
        "# sharing a number with one of them is measurable by neither and",
        "# is subtracted from both halves. A new generic call site that ate",
        "# more of them would otherwise shrink the denominator and read",
        "# as an improvement.",
        "#",
        "# The thirteen lib/ components the server imports are not measured",
        "# here -- only pasls.pas is instrumented, because $PASCOV_LINES",
        "# records a bare line number and two files' lines would be one heap.",
        "# tests/checks/lib_coverage.py is their gate (ADR-0350), over the",
        "# corpus rather than over these sessions.",
        "#",
        "# Regenerate with:  python3 tests/checks/lsp_coverage.py"
        " --write-ratchet",
        "# Doing so is a decision to argue for in the commit message.",
        "",
        f"uncovered {len(uncovered)}",
        f"instrumented {len(denom)}",
        f"ambiguous {len(ambiguous)}",
        f"sessions {sessions}",
        "",
    ] + [f"{name} {unc}/{ins}" for name, unc, ins in rows]) + "\n"

    path = root / "tests" / "checks" / RATCHET
    if args.write_ratchet:
        path.write_text(body)
        print(f"lsp-coverage: wrote {path.name} ({len(uncovered)} uncovered "
              f"of {len(denom)}, {len(ambiguous)} unmeasurable)")
        return 0

    if not path.exists():
        print(f"lsp-coverage: no ratchet at {path} -- run with "
              f"--write-ratchet", file=sys.stderr)
        return 1
    want, wamb, was = None, None, {}
    for line in path.read_text().splitlines():
        if line.startswith("uncovered "):
            want = int(line.split()[1])
        elif line.startswith("ambiguous "):
            wamb = int(line.split()[1])
        elif line and not line.startswith("#") and "/" in line:
            n, r = line.rsplit(" ", 1)
            was[n] = int(r.split("/")[0])
    if want is None or wamb is None:
        print("lsp-coverage: the ratchet names no total", file=sys.stderr)
        return 1

    # Both are asked before either is reported, so a change that loses a
    # statement *and* makes one unmeasurable names both rather than the first.
    bad = 0
    if len(uncovered) > want:
        print(f"lsp-coverage: {len(uncovered)} statements never run, was "
              f"{want} -- {len(uncovered) - want} lost", file=sys.stderr)
        for name, unc, ins in sorted(rows, key=lambda r: -r[1]):
            if unc > was.get(name, 0):
                print(f"    {name}: {was.get(name, 0)} -> {unc} of {ins}",
                      file=sys.stderr)
        bad += 1
    if len(ambiguous) > wamb:
        print(f"lsp-coverage: {len(ambiguous)} statements share a line number "
              f"with a generic body and are measured by nothing, was {wamb}",
              file=sys.stderr)
        bad += 1
    if bad:
        print("\nAdd a session, or -- if this is deliberate -- regenerate "
              "with --write-ratchet and say why in the commit message. "
              "See doc/sop.md §5.", file=sys.stderr)
        return 1

    note = "" if len(uncovered) == want else \
        f" -- {want - len(uncovered)} fewer than the ratchet; --write-ratchet"
    print(f"lsp-coverage: {len(ran)} of {len(denom)} statements run over "
          f"{sessions} sessions ({pct:.1f}%), {len(ambiguous)} unmeasurable "
          f"in {len(generics)} generic "
          f"bod{'y' if len(generics) == 1 else 'ies'}"
          f"{note}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
