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

"""Does a harness start the program under test through the runner? (ADR-0384)

Every harness here has executed what it built, and that is right for exactly
as long as what it built runs on the machine that built it. `--target=` admits
`wasm32-wasi` since ADR-0383, where it does not: a `.wasm` is started by a
runtime, with the program's arguments and its scratch directory handed over
explicitly. `AFTERSCHOOL_PASCAL_RUNNER` is that seam -- a command, split on
blanks and prepended -- and this is what says the seam is *there*.

**A seam with no user is plumbing, and plumbing is what rots.** Nothing in
this tree runs a wasm program yet: the runtime does not build for the target
(ADR-0382), so the corpus gate that would exercise this does not exist. So the
runner is exercised here instead, by a wrapper that is not a WASI runtime at
all -- it records the command it was handed and then `exec`s it. What is being
checked is the *shape* of the invocation, which is the half a real runtime
depends on and the half that silently stops being true.

Three claims, and the third is the one a careless fix would break.

  1. `tests/run_test.py` starts the program through the runner, and hands it
     the two scratch paths it always hands it. Every ctest case runs through
     that harness, so this is the claim that covers the corpus.
  2. `selfhost/irtest.py` does the same for the program it compiled.
  3. ...and **neither wraps the toolchain**. `irtest.py` builds a stage-1
     `pascalc` and then runs it over the corpus; that compiler is a program
     for the machine this script runs on however the corpus is being emitted.
     Wrapping it would hand a native binary to a runtime for another target,
     and the failure would look like the compiler being broken.

And a fourth, which is the floor: with the variable unset, the wrapper must
record **nothing**. A gate whose evidence is "the log has lines in it" passes
just as well when something else is writing them.

Usage:  tests/checks/runner_seam.py [--pascalcc P] [--seed S]
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.stdout.reconfigure(line_buffering=True)
sys.stderr.reconfigure(line_buffering=True)

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent

# One case, and it is `hello.pas` on purpose: what is under test is the shape
# of an invocation and not what a program computes, so the cheapest case in
# the corpus is the honest one. `irtest.py` builds a stage-1 compiler before
# it runs anything, which is what makes even one case cost seconds.
CASE = ROOT / "tests" / "hello.pas"

# The wrapper: it writes down the command it was given, one line, and then
# becomes that command. Python and not a shell script, which is ADR-0366's
# rule and `helper-portability`'s claim -- and it matters here beyond style,
# a shell wrapper being where an argument with a blank in it would quietly
# become two.
WRAPPER = """#!/usr/bin/env python3
import os, sys
with open(os.environ["RUNNER_SEAM_LOG"], "a") as f:
    f.write("\\t".join(sys.argv[1:]) + "\\n")
os.execv(sys.argv[1], sys.argv[1:])
"""


def lines(log):
    return [l for l in log.read_text().split("\n") if l.strip()] \
        if log.is_file() else []


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pascalcc", default=str(ROOT / "tools" / "pascalcc"))
    ap.add_argument("--seed", default=str(ROOT / "build" / "bin" / "pascalc-seed"))
    args = ap.parse_args()

    for what, path in (("driver", args.pascalcc), ("seed compiler", args.seed)):
        if not Path(path).exists():
            print("runner-seam: no %s at %s -- build first" % (what, path),
                  file=sys.stderr)
            return 1

    work = Path(tempfile.mkdtemp())
    try:
        return check(work, args)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def check(work, args):
    wrapper = work / "record.py"
    wrapper.write_text(WRAPPER)
    wrapper.chmod(0o755)
    log = work / "log"
    fails = []

    def sweep(argv, use_runner, drop=()):
        """One harness, run once, with the wrapper armed or not."""
        if log.is_file():
            log.unlink()
        env = dict(os.environ, RUNNER_SEAM_LOG=str(log))
        for name in drop:
            env.pop(name, None)
        if use_runner:
            env["AFTERSCHOOL_PASCAL_RUNNER"] = str(wrapper)
        else:
            env.pop("AFTERSCHOOL_PASCAL_RUNNER", None)
        r = subprocess.run(argv, capture_output=True, text=True, env=env,
                           cwd=str(ROOT), errors="surrogateescape")
        return r, lines(log)

    # Each harness is run the way its own ctest case runs it, which is not
    # the same environment: `selfhost-codegen` sets none, and `irtest.py`
    # then works the runtime out from where the seed compiler is, while
    # `AFTERSCHOOL_PASCAL_RUNTIME` under ctest names a *directory* for
    # `pascalcc`'s benefit. Handing irtest that directory as its archive is
    # how this gate first failed under ctest and passed by hand.
    harnesses = [
        ("tests/run_test.py",
         [sys.executable, str(ROOT / "tests" / "run_test.py"),
          args.pascalcc, str(CASE)],
         ()),
        ("selfhost/irtest.py",
         [sys.executable, str(ROOT / "selfhost" / "irtest.py"),
          args.seed, str(CASE)],
         ("AFTERSCHOOL_PASCAL_RUNTIME",)),
    ]

    for name, argv, drop in harnesses:
        # Claim 4 first: unset means unused, so the evidence below is this
        # variable's and nothing else's.
        r, seen = sweep(argv, use_runner=False, drop=drop)
        if r.returncode != 0:
            fails.append("%s does not pass %s even without a runner, so this "
                         "gate can say nothing about it:\n%s"
                         % (name, CASE.name, (r.stdout + r.stderr)[-800:]))
            continue
        if seen:
            fails.append("%s started something through the wrapper with "
                         "AFTERSCHOOL_PASCAL_RUNNER unset -- %d line(s), the "
                         "first being `%s`. The floor of this gate is that an "
                         "unset variable is an unused wrapper"
                         % (name, len(seen), seen[0]))

        # Claims 1 to 3.
        r, seen = sweep(argv, use_runner=True, drop=drop)
        if r.returncode != 0:
            fails.append("%s fails %s when the program is started through a "
                         "runner that only records and execs:\n%s"
                         % (name, CASE.name, (r.stdout + r.stderr)[-800:]))
            continue
        if not seen:
            fails.append("%s started the program directly: nothing reached "
                         "the runner. A harness that executes what it built "
                         "cannot run a case for a target it did not build "
                         "for (ADR-0384)" % name)
            continue
        prog = [l for l in seen if l.split("\t")[0].endswith("hello")]
        if not prog:
            fails.append("%s put something through the runner and it was not "
                         "the program: %s" % (name, "; ".join(seen)[:200]))
        else:
            got = prog[0].split("\t")
            if len(got) != 3:
                fails.append("%s started the program through the runner with "
                             "%d argument(s) and the harness hands it two "
                             "scratch paths: %s"
                             % (name, len(got) - 1, prog[0][:200]))
        # Claim 3: the toolchain is never the thing wrapped.
        tools = [l for l in seen
                 if Path(l.split("\t")[0]).name.startswith(("pascalc", "clang"))]
        if tools:
            fails.append("%s started the *toolchain* through the runner: `%s`. "
                         "A compiler is a program for the machine this runs "
                         "on whatever it emits for" % (name, tools[0][:200]))

    if fails:
        print("runner-seam:", file=sys.stderr)
        for f in fails:
            print("  " + f, file=sys.stderr)
        return 1
    print("runner-seam: %d harness(es) start the program under test through "
          "AFTERSCHOOL_PASCAL_RUNNER with its two scratch arguments, start no "
          "part of the toolchain through it, and start nothing through it when "
          "it is unset" % len(harnesses))
    return 0


sys.exit(main())
