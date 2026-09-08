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

"""Diverse double-compiling (David A. Wheeler), applied to `seed/*.ll`.

The seed is an opaque committed artefact. Its provenance is this repository's
history -- a claim about a chain, not something a reader checks by
inspection -- and that is the trusting-trust problem in its ordinary form.
It is answerable *once*, by building a compiler through an unrelated
implementation and comparing what the two produce:

  A = the v0.1.0 C++ compiler (LLVM's own code generator) translating
      today's selfhost/compiler.pas, then assembled and linked
  B = build/bin/pascalc, which came from seed/*.ll the ordinary way

A and B are then each asked to translate selfhost/compiler.pas, and *those*
two outputs must be identical. A and B themselves are **not** compared --
ADR-0025 settled that two backends' assembler text is not comparable, which
is exactly why the comparison is made one stage further on. What makes it
evidence is that A's code generator is LLVM's and B's is the Pascal one, so
an artefact carrying behaviour its source does not would show up here.

What this does NOT establish: v0.1.0 is this project's own earlier compiler,
so the two implementations are diverse but not independently authored. It
rules out a seed that drifted from the source. It does not rule out a mistake
present in both.

**The window closes on its own and nothing announces it**: this works only
while the v0.1.0 C++ compiler still accepts selfhost/compiler.pas, and every
feature the compiler starts using risks ending that. Skips rather than fails
when it cannot run, as verify-lowering does without z3 -- but a skip is the
thing to read, not to ignore.

**It closed at ADR-0233.** The compiler is three 6.13 program-components now,
and v0.1.0 has no `--import`: it reports `no interface named 'aptypes' has
been exported` and stops. That is the announcement the paragraph above says
nothing makes, made once, here -- the check runs, says THE WINDOW HAS CLOSED
and exits 0, and there is nothing to fix. seed/README.md records the last
result it obtained. Do not try to reopen it by feeding v0.1.0 the components
separately: it cannot link them either.

Converted from `seed/ddc.py` under ADR-0366.

Usage:  seed/ddc.py [build-dir]        (default: build)
"""

import hashlib
import io
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent

# The compilers and build tools this starts inherit both streams, so this
# script's own lines must reach a redirected stdout in the order they were
# written: Python block-buffers it where the shell version's `echo` did not.
sys.stdout.reconfigure(line_buffering=True)


def skip(msg):
    print(f"ddc: SKIP -- {msg}")
    sys.exit(0)


def _copy(chunk):
    """Write a log's own bytes out, in order with this script's own lines: a
    build log is whatever the tools put in it, and decoding it would be a
    second opinion about that."""
    sys.stdout.flush()
    sys.stdout.buffer.write(chunk)
    sys.stdout.buffer.flush()


def _lines(data):
    """A line ends at a newline and at the end of the file, and at nothing
    else -- `bytes.splitlines` would also break at a carriage return, which a
    build tool writes to redraw a line and `tail` does not count."""
    out, start = [], 0
    while start < len(data):
        i = data.find(b"\n", start)
        if i < 0:
            out.append(data[start:])
            break
        out.append(data[start:i + 1])
        start = i + 1
    return out


def tail(path, n):
    """What `tail -<n> <path>` wrote: the last n lines, the file's final one
    unterminated if that is how it ends."""
    _copy(b"".join(_lines(Path(path).read_bytes())[-n:]))


def head(path, n):
    """What `head -<n> <path>` wrote."""
    _copy(b"".join(_lines(Path(path).read_bytes())[:n]))


def differ(a, b):
    """What `cmp <a> <b>` reported about two files already known to differ.

    The first differing byte, one-based, with the line it falls in; or the
    end of the shorter file, which `cmp` says on the second stream, in the
    three forms it has for it -- an empty file, one that stops at a line end,
    and one that stops inside a line. The wording is `cmp`'s own, so that a
    reader of this output reads what they have always read here; the quotes
    are what `cmp` writes in the C locale, where a GNU one in a UTF-8 locale
    writes typographic ones instead.
    """
    da = Path(a).read_bytes()
    db = Path(b).read_bytes()
    for i in range(min(len(da), len(db))):
        if da[i] != db[i]:
            line = da.count(b"\n", 0, i) + 1
            print(f"{a} {b} differ: byte {i + 1}, line {line}")
            return
    short, data = (a, da) if len(da) < len(db) else (b, db)
    newlines = data.count(b"\n")
    where = f"after byte {len(data)}, "
    if not data:
        where = "which is empty"
    elif data.endswith(b"\n"):
        where += f"line {newlines}"
    else:
        where += f"in line {newlines + 1}"
    print(f"cmp: EOF on '{short}' {where}", file=sys.stderr)


def run_logged(cmd, log):
    """Run a command with both streams in a log file, as `>log 2>&1` did."""
    with open(log, "w") as f:
        return subprocess.call(cmd, stdout=f, stderr=f)


def run_inheriting(cmd):
    """Run a command with both streams passed through, and stop the way
    `set -e` did if it fails."""
    rc = subprocess.call(cmd)
    if rc != 0:
        sys.exit(rc)


def main():
    builddir = sys.argv[1] if len(sys.argv) > 1 else f"{ROOT}/build"

    for tool, why in (("git", "no git"),
                      ("clang", "no clang"),
                      ("cmake", "no cmake"),
                      ("llvm-config",
                       "no llvm-config: the v0.1.0 C++ compiler links libLLVM")):
        if shutil.which(tool) is None:
            skip(why)

    if subprocess.call(["git", "-C", str(ROOT), "rev-parse", "-q", "--verify",
                        "refs/tags/v0.1.0"],
                       stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL) != 0:
        skip("tag v0.1.0 is not present (a shallow clone has no tags)")

    if not os.access(f"{builddir}/bin/pascalc", os.X_OK):
        skip(f"no {builddir}/bin/pascalc: build first")
    if not os.path.isfile(f"{builddir}/lib/libpasrt.a"):
        skip(f"no {builddir}/lib/libpasrt.a: build first")

    cfg = subprocess.run(["llvm-config", "--cmakedir"],
                         stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    if cfg.returncode != 0:
        skip("llvm-config has no --cmakedir")
    llvmdir = cfg.stdout.decode(errors="surrogateescape").rstrip("\n")
    if not os.path.isdir(llvmdir):
        skip(f"LLVM cmake directory {llvmdir} does not exist")

    work = tempfile.mkdtemp()
    try:
        return check(builddir, llvmdir, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def check(builddir, llvmdir, work):
    print("ddc: extracting v0.1.0 -- the last commit where a C++ compiler could")
    print("     reproduce a compiler from source alone")
    archive = subprocess.run(["git", "-C", str(ROOT), "archive", "v0.1.0"],
                             stdout=subprocess.PIPE)
    # git has said on the second stream why it could not write the archive;
    # the shell version piped into `tar` and reported the empty input as a
    # broken archive instead, this being the one place a pipeline hid a
    # status. The guards above make it unreachable either way.
    if archive.returncode != 0:
        return archive.returncode
    with tarfile.open(fileobj=io.BytesIO(archive.stdout)) as tf:
        tf.extractall(work, filter="data")

    print(f"ddc: building the v0.1.0 C++ compiler against LLVM from {llvmdir}")
    if run_logged(["cmake", "-S", work, "-B", f"{work}/build",
                   "-DCMAKE_BUILD_TYPE=Release", f"-DLLVM_DIR={llvmdir}"],
                  f"{work}/cmake.log") != 0:
        tail(f"{work}/cmake.log", 20)
        skip("v0.1.0 does not configure against this LLVM")
    if run_logged(["cmake", "--build", f"{work}/build", "-j",
                   "--target", "pascalc-s0"], f"{work}/make.log") != 0:
        tail(f"{work}/make.log", 20)
        skip("v0.1.0 does not build against this LLVM")

    # Whether it still *accepts* today's source is the window, and the one
    # outcome worth distinguishing from a broken environment. It is still a
    # skip -- there is nothing to fix -- but it says the answer can no longer
    # be obtained.
    print("ddc: translating today's selfhost/compiler.pas with it")
    if run_logged([f"{work}/build/bin/pascalc-s0", "--std=extended", "-S",
                   f"{ROOT}/selfhost/compiler.pas", "-o", f"{work}/A.ll"],
                  f"{work}/a.log") != 0:
        head(f"{work}/a.log", 10)
        print("ddc: THE WINDOW HAS CLOSED -- the v0.1.0 compiler no longer accepts")
        print("     selfhost/compiler.pas, so this check can never run again.")
        print("     seed/README.md records the last time it passed.")
        return 0

    print("ddc: linking compiler A from that IR")
    run_inheriting(["clang", f"{work}/A.ll", f"{builddir}/lib/libpasrt.a",
                    "-lm", "-o", f"{work}/A_compiler"])

    # No --std= on either: A and B are both built from *today's* compiler.pas,
    # and ADR-0232 removed the flag from it. The line above keeps its
    # `--std=extended` because that one is the v0.1.0 binary, which still has
    # the modes -- which is the whole shape of this check, an old
    # implementation translating a new source.
    print("ddc: A and B each translate selfhost/compiler.pas")
    run_inheriting([f"{work}/A_compiler", f"{ROOT}/selfhost/compiler.pas",
                    "-o", f"{work}/from_A.ll"])
    run_inheriting([f"{builddir}/bin/pascalc", f"{ROOT}/selfhost/compiler.pas",
                    "-o", f"{work}/from_B.ll"])

    a, b = f"{work}/from_A.ll", f"{work}/from_B.ll"
    data = Path(a).read_bytes()
    if data == Path(b).read_bytes():
        print("ddc: PASS -- a compiler built through LLVM's code generator and one")
        print("     built from the seed translate selfhost/compiler.pas to the same")
        print(f"     {len(data)} bytes")
        print(f"ddc: sha256 {hashlib.sha256(data).hexdigest()}")
        return 0

    print("ddc: FAIL -- the two outputs differ, so the seed carries behaviour that")
    print("     selfhost/compiler.pas does not account for. This is the finding the")
    print("     check exists for; do not 'fix' it by refreshing the seed.")
    differ(a, b)
    return 1


if __name__ == "__main__":
    sys.exit(main())
