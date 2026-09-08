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
# A second backend configuration, and the one question it can answer that
# nothing else here can: **is the compiler binary itself miscompiled?**
#
# `selfhost/irtest.sh` compiles the compiler with itself twice and requires
# stage 2 to equal stage 3. That is the bootstrap's own check and it is a strong
# one, but both stages are produced by *the same binary* -- so a code generator
# in `clang` that got one corner of `selfhost/compiler.pas` wrong would produce a
# wrong compiler that reproduced itself exactly, and the fixed point would hold.
# Every golden would agree too, because every golden was written by that binary.
# The suite builds `pascalc` exactly one way.
#
# So this builds it a second way -- a different backend, driven directly, at a
# different optimisation level -- and requires the two binaries to *compute the
# same thing*: byte-identical IR for the same source. Two machine-code programs
# that disagree about what `compiler.pas` means is a miscompilation, and it is
# the only shape of defect this catches that another oracle would not.
#
# **What it is not.** `llc` is not a stronger validity check on the IR than
# `clang` is: they share LLVM's parser and verifier, and reject the same module
# with the same message -- measured on a type mismatch and a function
# redefinition, not assumed. Nor does it add relocation-model coverage -- the
# object path of `tools/pascalcc` already passes `-fPIC` and the executable path
# links PIE, so the whole corpus is built as position-independent code today.
# Don't add this to the list of oracles in doc/sop.md as "a second reader of the
# IR"; **within one run it is one LLVM configured two ways**, because `llc` and
# `clang` come from one distribution package set and are the same version.
#
# **Which LLVM that is varies by where this runs, and that is worth knowing.**
# The `second-backend` CI job is debian:trixie, where both are 19.1.7; a
# developer's machine at the time of writing had 21.1.8; `seed/*.ll` was
# emitted by clang 21. So the comparison is repeated on different LLVMs over
# time rather than made between two at once, which is a weaker thing than it
# sounds like and still not nothing: a miscompilation that hides here has to be
# present in every version this has run under. That is why the version is
# printed on every invocation -- a green bar means nothing without knowing which
# LLVM produced it, and this check is the one place that is the whole story.
#
# Don't "strengthen" this by pinning a second LLVM version alongside the first.
# It would be a genuine second reader, and it would also put an apt repository
# and a version pin into a job whose entire justification is that the documented
# build needs nothing of LLVM's (ADR-0085). If that trade is ever made, it needs
# a record saying so.
#
# It skips when `llc` is absent, as verify-lowering does without z3 and
# bsi-validation-suite does without the suite: `llc` comes from LLVM, and
# ADR-0085's claim is that the *build* needs nothing of LLVM's. Making this a
# hard requirement would falsify that claim rather than test it.
#
# ADR-0366's eighth conversion, from `llc_check.sh` on 2026-09-08.
#
# Usage:  tests/checks/llc_check.py <build-dir>

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SKIP = 77

# `llc` defaults to a non-PIC relocation model while the system linker defaults
# to PIE, and the mismatch fails at link time with a message about
# `R_X86_64_32 against .bss` that reads like a code generator defect. It is an
# argument to llc. `clang` compiling the .ll chooses the model itself, which is
# why nothing else here has ever met this.
LLC_FLAGS = ["-relocation-model=pic"]


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True,
                          errors="replace", **kw)


def head(text, n):
    return "\n".join(text.split("\n")[:n])


def main():
    root = Path(__file__).resolve().parent.parent.parent
    build = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "build"
    pascalc = build / "bin/pascalc"
    runtime = build / "lib/libpasrt.a"

    # `LLC_REQUIRE` turns the skip below into a failure, which is what a job
    # that installed llvm wants (ADR-0330's convention, ADR-0331's second
    # host). The x86-64 job used to refuse a skip by grepping its own log;
    # reading the variable here means the gate refuses it the same way whoever
    # runs it, and `require-consistency` keeps the variable and the workflow in
    # step.
    if shutil.which("llc") is None:
        if os.environ.get("LLC_REQUIRE"):
            print("llc-second-backend: llc is not installed, and LLC_REQUIRE "
                  "is set", file=sys.stderr)
            return 1
        print("llc-second-backend: llc is not installed -- skipping")
        print("  (Debian/Ubuntu: apt-get install llvm)")
        return SKIP

    for f in (pascalc, runtime):
        if not f.exists():
            print(f"llc-second-backend: {f} is missing -- build first",
                  file=sys.stderr)
            return 1

    # Which LLVM proved it, and which machine. Worth printing: this check
    # compares two backend configurations of one LLVM, so the version is the
    # whole of what it was -- and the target is the whole of *which* code
    # generator it was, which is the half that went unsaid while the aarch64
    # job proved x86-64.
    ver = [ln for ln in run(["llc", "--version"]).stdout.split("\n")
           if "version" in ln.lower()]
    print(f"llc-second-backend: {ver[0].lstrip() if ver else ''}")
    env_target = os.environ.get("AFTERSCHOOL_PASCAL_TARGET", "")
    print("llc-second-backend: target "
          f"{env_target or 'x86_64 by default'}")

    # Which target the emitted IR states, and it has to be said here.
    # `AFTERSCHOOL_PASCAL_TARGET` is read by `tools/pascalcc` (ADR-0156) and by
    # nothing else -- the compiler itself reads only `AFTERSCHOOL_PASCAL_PATH`
    # (ADR-0244) -- and this script drives `pascalc` directly, so without this
    # the modules below carry the default `x86_64-pc-linux-gnu` however the
    # variable is set. It must name the **host**, because this gate links what
    # `llc` produced and then runs it.
    target = [f"--target={env_target}"] if env_target else []

    with tempfile.TemporaryDirectory() as work:
        w = Path(work)
        err = w / "err"

        # ---- 1. llc accepts every module this compiler emits -------------
        #
        # Cheap, and it is the half that would notice IR only clang's *driver*
        # tolerates.
        accepted = 0
        cases = sorted((root / "tests").glob("*.pas"), key=lambda p: os.fsencode(str(p)))
        cases += sorted((root / "tests/extended").glob("*.pas"),
                        key=lambda p: os.fsencode(str(p)))
        for src in cases:
            # An error-path case has no module to assemble; it is expected not
            # to compile.
            if src.with_suffix(".err").exists():
                continue
            if run([str(pascalc), *target, str(src), "-o", str(w / "t.ll")]).returncode:
                continue
            r = run(["llc", *LLC_FLAGS, str(w / "t.ll"), "-o", str(w / "t.s")])
            if r.returncode:
                print(f"llc-second-backend: llc rejected the module for {src}",
                      file=sys.stderr)
                print(head(r.stderr, 10), file=sys.stderr)
                return 1
            accepted += 1

        # The committed seed is a module too, and the largest here. It is
        # matched with a glob: the seed is one module per program-component
        # once it has been refreshed after ADR-0233, and how many that is is
        # the seed's business.
        for seed in sorted((root / "seed").glob("*.ll"),
                           key=lambda p: os.fsencode(str(p))):
            r = run(["llc", *LLC_FLAGS, str(seed), "-o", str(w / "seed.s")])
            if r.returncode:
                rel = os.path.relpath(seed, root)
                print(f"llc-second-backend: llc rejected {rel}", file=sys.stderr)
                print(head(r.stderr, 10), file=sys.stderr)
                return 1
            accepted += 1

        # ---- 2. a compiler built a second way computes the same thing -----
        #
        # Three program-components since ADR-0233, in the order
        # selfhost/compiler.components gives; every one of them is translated,
        # built a second way and compared, because a miscompilation of ApFront
        # is as much a wrong compiler as a miscompilation of the code
        # generator.
        comps = [ln for ln in
                 (root / "selfhost/compiler.components").read_text().split("\n")
                 if ln.strip()] + ["compiler.pas"]
        imports = []
        for n, component in enumerate(comps, 1):
            subprocess.check_call([str(pascalc), *target, *imports,
                                   str(root / "selfhost" / component),
                                   "-o", str(w / f"ref{n}.ll")])
            imports += ["--import", str(root / "selfhost" / component)]

        # Two backend configurations, both unlike the build's. -O0 is the one
        # that matters: it shares almost no code with the -O2 pipeline the
        # build used, so an optimiser that miscompiled the compiler cannot
        # hide in both.
        for level in ("-O0", "-O2"):
            objs = []
            for k in range(1, len(comps) + 1):
                s = w / f"cc{level}.{k}.s"
                o = w / f"cc{level}.{k}.o"
                subprocess.check_call(["llc", level, *LLC_FLAGS,
                                       str(w / f"ref{k}.ll"), "-o", str(s)])
                subprocess.check_call(["clang", level, "-c", str(s), "-o", str(o)])
                objs.append(str(o))
            exe = w / f"pascalc{level}"
            subprocess.check_call(["clang", level, *objs, str(runtime), "-lm",
                                   "-o", str(exe)])
            imports = []
            for n, component in enumerate(comps, 1):
                out = w / f"out{level}.{n}.ll"
                subprocess.check_call([str(exe), *target, *imports,
                                       str(root / "selfhost" / component),
                                       "-o", str(out)])
                imports += ["--import", str(root / "selfhost" / component)]
                ref = w / f"ref{n}.ll"
                if ref.read_bytes() != out.read_bytes():
                    print(f"llc-second-backend: a compiler built with llc "
                          f"{level} translates", file=sys.stderr)
                    print(f"  selfhost/{component} differently from the one "
                          "this build", file=sys.stderr)
                    print("  ships. Two machine-code programs disagree about "
                          "what the", file=sys.stderr)
                    print("  source means,", file=sys.stderr)
                    print("  so one of them is miscompiled.", file=sys.stderr)
                    d = run(["diff", "-u", str(ref), str(out)]).stdout
                    print(head(d, 40), file=sys.stderr)
                    return 1

    print(f"llc-second-backend: llc assembled {accepted} modules, and "
          f"compilers built from its -O0 and -O2 output translate all "
          f"{len(comps)} program-components identically to this build's")
    return 0


if __name__ == "__main__":
    sys.exit(main())
