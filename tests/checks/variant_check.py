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
#
#
# The AST is a variant record, and this is the only thing that checks it is
# read through the arm its tag selects.
#
# `selfhost/compiler.pas` has exactly one variant record -- `case kind:` appears
# once in 36,000 lines -- and it is the AST: 63 arms, read by the parser, Sema,
# both dump walkers and the code generator. ISO/IEC 10206:1991 6.5.3.3 makes
# reading a field of an inactive variant an **error**, and 3.1 lets a processor
# leave an error undetected. A wrong-arm read of a node is silent rubbish, and
# if the field is a pointer the next walk follows it.
#
# ADR-0118 is the rule that catches it: a write to a variant's field activates
# that variant, and a read of an inactive one traps. It was a *dialect* rule
# while there were conformance modes to keep it out of, and ADR-0223 was about
# building the compiler a second way to get it -- under `--std=afterschool`,
# used as a reader and never as the product. ADR-0232 removed the modes, so
# there is nothing to select and nothing to build twice: the guards are in
# whatever this compiler emits.
#
#     1 occurrence of the trap message -- a string constant
#                      the compiler *emits* into programs it compiles
#  2821 guards
#
# What is left is the sweep, which is the half that was ever doing the work:
# compile the compiler with itself, then read 1019 sources with the result and
# require none of them to trap.
#
# **What it cannot see.** 6.4.3.3 permits a variant part with no tag field, and
# there is then nothing to compare against -- doc/sop.md 7 carries that row. The
# AST's variant part has a tag, so this covers it; a second variant record added
# without one would be outside this silently.
#
# It compiles rather than runs: every pass that touches a node runs during a
# compilation, and running the compiled program tells you nothing about the
# compiler's own AST.
#
# ADR-0366's third conversion. It was `variant_check.sh` until 2026-09-08, and
# both versions were compared on the real tree and on every failure arm before
# the shell one was removed. Two latent differences went with it: the corpus
# was `find` piped into `sort`, whose collation follows `LANG`, and the git
# filter leaned on GNU grep keeping every line when handed an empty pattern
# file -- POSIX says an empty pattern set matches nothing, so a BSD grep could
# have emptied the corpus and left the floor to report it.
#
# Usage:  tests/checks/variant_check.py [pascalc] [libpasrt.a]

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

GUARD = "variant: the tag selects another arm"
TRAP = "runtime error: variant:"
ROOTS = ("tests", "selfhost", "lib", "lsp", "examples", "tools")

# It refuses to pass by asking nothing, in both directions: too few guards in
# the built compiler, and too few sources swept by it.
GUARD_FLOOR = 100
SOURCE_FLOOR = 500

SKIP = 77


def head20(*paths):
    """`head -20` over one or more files, headers and all.

    With more than one file `head` writes `==> name <==` before each and a
    blank line between them, and this reproduces that: the message is what a
    person reads when the compiler cannot compile itself.
    """
    out = []
    for i, p in enumerate(paths):
        if len(paths) > 1:
            if i:
                out.append("")
            out.append(f"==> {p} <==")
        try:
            with open(p, encoding="utf-8", errors="replace") as f:
                out.extend(line.rstrip("\n") for _, line in zip(range(20), f))
        except OSError:
            pass
    return out


def build_guarded(cc, root, work):
    """The compiler's own source, translated by the compiler.

    A failure here is not a skip -- the source this repository ships must
    compile with the binary this repository built, or the fixed point
    irtest.sh proves is about something else.

    Three program-components since ADR-0233, in the order
    selfhost/compiler.components gives, each translated with the ones before
    it as `--import` and all three linked together. The guards are counted
    over all three modules: they are one compiler, and ApTypes is where the
    AST's variant part is *declared*.
    """
    components = [ln for ln in
                  (root / "selfhost/compiler.components").read_text().split("\n")
                  if ln.strip()] + ["compiler.pas"]
    modules, imports = [], []
    for n, component in enumerate(components, 1):
        ll = os.path.join(work, f"ap{n}.ll")
        gen_out = os.path.join(work, "gen.out")
        gen_err = os.path.join(work, "gen.err")
        with open(gen_out, "w") as so, open(gen_err, "w") as se:
            rc = subprocess.call([str(cc), *imports,
                                  str(root / "selfhost" / component),
                                  "-o", ll], stdout=so, stderr=se)
        if rc != 0:
            print(f"variant-check: the compiler does not compile {component}",
                  file=sys.stderr)
            for line in head20(gen_out, gen_err):
                print(line, file=sys.stderr)
            return None
        imports += ["--import", str(root / "selfhost" / component)]
        modules.append(ll)
    return modules


def corpus(root):
    """Every `.pas` under the roots, minus what git ignores.

    The count is the point: this gate prints how many sources it compiled and
    two documents quote that number, so it has to mean the same thing on every
    machine. It did not. A checkout that still has the retired BSI suite on
    disk (ADR-0232 gitignored it) finds 224 more sources here than a clean
    clone does -- and every one of them is conforming ISO 7185 this compiler
    cannot compile at all, so they cost time and add nothing. A second build
    tree would do the same. Untracked sources that are *not* ignored stay in
    scope: a case added and not yet staged is exactly what a sweep should
    reach.
    """
    found = []
    for name in ROOTS:
        for dirpath, _dirs, files in os.walk(root / name):
            for f in files:
                if f.endswith(".pas"):
                    found.append(os.path.join(dirpath, f))
    found.sort(key=os.fsencode)
    if not found:
        return found
    try:
        r = subprocess.run(["git", "-C", str(root), "check-ignore", "--stdin"],
                           input="\n".join(found) + "\n",
                           capture_output=True, text=True)
        ignored = {ln for ln in r.stdout.split("\n") if ln}
    except OSError:
        ignored = set()
    return [p for p in found if p not in ignored]


def main():
    root = Path(__file__).resolve().parent.parent.parent
    cc = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "build/bin/pascalc"
    runtime = (Path(sys.argv[2]) if len(sys.argv) > 2
               else root / "build/lib/libpasrt.a")

    if not (cc.is_file() and os.access(cc, os.X_OK)):
        print(f"variant-check: no compiler at {cc}", file=sys.stderr)
        return 1
    if shutil.which("clang") is None:
        print("variant-check: no clang, so the guarded compiler cannot be "
              "linked", file=sys.stderr)
        return SKIP

    with tempfile.TemporaryDirectory() as work:
        modules = build_guarded(cc, root, work)
        if modules is None:
            return 1

        guards = 0
        for module in modules:
            with open(module, encoding="utf-8", errors="replace") as f:
                guards += sum(1 for line in f if GUARD in line)
        if guards < GUARD_FLOOR:
            print(f"variant-check: the guarded build has {guards} variant "
                  "guards in it. ADR-0118's check is not being emitted, so "
                  "this would pass by asking nothing -- which is the one way "
                  "it must not pass", file=sys.stderr)
            return 1

        exe = os.path.join(work, "pascalc-ap")
        link_err = os.path.join(work, "link.err")
        with open(link_err, "w") as se:
            rc = subprocess.call(["clang", "-O2", "-Wno-override-module",
                                  *modules, str(runtime), "-lm", "-o", exe],
                                 stderr=se)
        if rc != 0:
            print("variant-check: the guarded compiler did not link",
                  file=sys.stderr)
            for line in head20(link_err):
                print(line, file=sys.stderr)
            return 1

        out_ll = os.path.join(work, "out.ll")
        checked = trapped = 0
        for src in corpus(root):
            # Every dump runs, so both walkers are exercised and not only the
            # four passes -- ADR-0104's coverage corpus drives them the same
            # way and for the same reason.
            r = subprocess.run([exe, "--dump-all", src, "-o", out_ll],
                               capture_output=True, text=True,
                               errors="replace")
            checked += 1
            # The runtime's own wording, on the runtime's own stream. Matching
            # the bare message anywhere would match `--dump-all` of
            # compiler.pas printing the string literal the emitter carries --
            # which it did, on the first run.
            hits = [ln for ln in r.stderr.split("\n") if ln.startswith(TRAP)]
            if hits:
                print(f"--- {src}: the compiler read a node through the wrong "
                      "arm ---", file=sys.stderr)
                for ln in hits[:3]:
                    print(ln, file=sys.stderr)
                trapped += 1

    if checked < SOURCE_FLOOR:
        print(f"variant-check: only {checked} sources were compiled, and the "
              "corpus is larger than that -- a run that reaches nothing "
              "passes for the same reason a clean one does", file=sys.stderr)
        return 1
    if trapped:
        print(f"variant-check: {trapped} of {checked} sources made the "
              "compiler read a node through an arm its tag does not select",
              file=sys.stderr)
        return 1
    print(f"variant-check: {checked} sources compiled by a compiler carrying "
          f"{guards} variant guards; every node was read through the arm its "
          "tag selects")
    return 0


if __name__ == "__main__":
    sys.exit(main())
