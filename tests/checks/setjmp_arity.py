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

"""Does the `_setjmp` this compiler emits have the arity the target's C
library gives it? (ADR-0371)

`_setjmp` is **the one foreign function the emitted module names** -- every
other symbol in it is `pas_*` or an LLVM intrinsic (`foreign-reserved`,
ADR-0121). It is there because ISO C makes `setjmp` a *macro* whose expansion
must appear in a very restricted set of contexts, so what a module can name is
whatever that macro expands to; and the two platforms this compiler admits
disagree about its **arity** rather than its spelling:

    glibc, Darwin   setjmp(x)  ->  _setjmp(x)
    Win64           setjmp(x)  ->  _setjmp((x), frame)

Windows unwinds through SEH and the second argument is the frame the unwinder
walks from. Emitting the one-argument call there is a wrong arity, which is
undefined behaviour with **no diagnostic anywhere**: LLVM does not compare a
direct call against a declaration under opaque pointers, so the module
verifies, assembles and links, and the defect is a corrupted unwind at run
time on a platform this tree cannot run. That is `doc/sop.md` §7's row about
an `external` declaration nobody checks, arrived at from the other side --
here the declaration is one this compiler *writes*.

So it is checked the way `foreign-layout` checks a record: **the source states
a claim, a C compiler holding the real header judges it.** For every target
the compiler admits, both of these are compiled and their `@_setjmp` calls
compared:

    a C probe          clang --target=<t>, calling ISO C's setjmp
    a Pascal probe     pascalc --target=<t>, with a non-local goto

and the module's own `declare` has to agree with its calls, or one function
has two signatures in one module.

**A target is compared only where clang has that target's headers**, and it
says which it could not reach. Asking clang for a triple whose sysroot is not
installed fails cleanly -- `'setjmp.h' file not found` -- rather than falling
back to the host's header and answering about the wrong C library, which was
checked before this was relied on.

**The floor that the answers are not all the same is therefore conditional.**
A gate comparing three targets that happen to agree proves nothing about
target-dependence -- but on a machine with no mingw-w64 the only target with
the other arity is precisely the one that cannot be compared, so demanding it
everywhere would fail for want of a cross toolchain rather than for a defect.
`SETJMP_ARITY_REQUIRE` is what demands it, and the `non-posix` job -- which
installs mingw-w64 for `runtime-nonposix` -- is where it is set (ADR-0330).
Without it this compares what it can and says what it could not.

Skips (77) without clang. Not without a target: the compiler names its own,
so a fifth is compared without this file being edited (ADR-0144).
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.stdout.reconfigure(line_buffering=True)
sys.stderr.reconfigure(line_buffering=True)

ROOT = Path(__file__).resolve().parent.parent.parent
PASCALC = os.environ.get("PASCALC", str(ROOT / "build" / "bin" / "pascalc"))
CLANG = os.environ.get("APASCAL_CLANG", "clang")

# A non-local goto is what makes the compiler emit the call at all: the label
# is in the outer block and the jump is from a procedure nested in it.
PASCAL_PROBE = """program sj(output);
label 1;
procedure Inner;
begin
  goto 1
end;
begin
  Inner;
1:
  writeln('arrived')
end.
"""

C_PROBE = "#include <setjmp.h>\njmp_buf b;\nint f(void){ return setjmp(b); }\n"

CALL = re.compile(r"call i32 @_setjmp\(([^)]*)\)")
DECL = re.compile(r"declare i32 @_setjmp\(([^)]*)\)")


def arity(args):
    args = args.strip()
    return 0 if not args else len(args.split(","))


def run(argv, **kw):
    return subprocess.run(argv, capture_output=True, text=True,
                          errors="surrogateescape", **kw)


def targets():
    """The targets the compiler emits for, read from its own refusal --
    ADR-0144's rule, and the same question target_layout.py asks."""
    r = run([PASCALC, "--target=+no-such-target",
             str(ROOT / "tests" / "hello.pas"), "-o", os.devnull])
    for line in (r.stdout + r.stderr).splitlines():
        m = re.match(r"pascalc: this compiler emits for (.*)$", line.strip())
        if m:
            names = re.split(r",\s*|\s+and\s+", m.group(1))
            return [n for n in names if n]
    print("setjmp-arity: the compiler did not name its targets; the "
          "--target= refusal said:\n" + r.stdout + r.stderr, file=sys.stderr)
    sys.exit(1)


def main():
    if shutil.which(CLANG) is None:
        print("setjmp-arity: skipped, no %s to judge the call against" % CLANG)
        return 77
    if not Path(PASCALC).exists():
        print("setjmp-arity: no compiler at %s" % PASCALC, file=sys.stderr)
        return 1

    require = os.environ.get("SETJMP_ARITY_REQUIRE", "")
    work = Path(tempfile.mkdtemp())
    try:
        return check(work, require)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def check(work, require):
    (work / "sj.c").write_text(C_PROBE)
    (work / "sj.pas").write_text(PASCAL_PROBE)

    names = targets()
    fails, seen, rows = [], set(), []

    for t in names:
        r = run([CLANG, "--target=" + t, "-O0", "-S", "-emit-llvm",
                 str(work / "sj.c"), "-o", "-"])
        if r.returncode != 0:
            # A target clang cannot compile for is this machine's business,
            # not the compiler's -- say which, and go on.
            rows.append((t, None, None, None))
            continue
        m = CALL.search(r.stdout)
        if not m:
            fails.append("clang emitted no call to @_setjmp for %s, so ISO C's "
                         "setjmp expands to something else there and this "
                         "gate's premise does not hold" % t)
            continue
        want = arity(m.group(1))

        out = work / ("sj-%s.ll" % t)
        r = run([PASCALC, "--target=" + t, str(work / "sj.pas"), "-o", str(out)])
        if r.returncode != 0 or not out.exists():
            fails.append("this compiler could not emit for %s, which it says "
                         "it admits:\n%s" % (t, r.stdout + r.stderr))
            continue
        text = out.read_text()
        calls = {arity(m.group(1)) for m in CALL.finditer(text)}
        decls = {arity(m.group(1)) for m in DECL.finditer(text)}
        if not calls:
            fails.append("the module for %s calls @_setjmp nowhere, so the "
                         "probe stopped exercising the non-local goto" % t)
            continue
        if len(calls) != 1:
            fails.append("the module for %s calls @_setjmp with %s arguments "
                         "in one module" % (t, sorted(calls)))
            continue
        got = calls.pop()
        rows.append((t, want, got, sorted(decls)))
        seen.add(got)

        if got != want:
            fails.append("for %s clang calls @_setjmp with %d argument(s) and "
                         "this compiler emits %d -- a wrong arity is undefined "
                         "behaviour with no diagnostic, LLVM not comparing a "
                         "direct call against its declaration" % (t, want, got))
        if decls != {got}:
            fails.append("the module for %s declares @_setjmp with %s "
                         "argument(s) and calls it with %d -- one function, "
                         "two signatures" % (t, decls, got))

    compared = [r for r in rows if r[1] is not None]
    missing = [r[0] for r in rows if r[1] is None]

    if not compared:
        fails.append("no target could be compared at all -- clang has the "
                     "headers for none of them, so this asked nothing")
    elif require:
        # **The discriminating claim, and it is only available where the
        # toolchain can answer for a target with the other arity** (ADR-0330).
        if missing:
            fails.append("SETJMP_ARITY_REQUIRE is set and clang has no headers "
                         "for %s -- install the cross toolchain, or this job is "
                         "not asking the question it says it is"
                         % ", ".join(missing))
        elif len(seen) < 2:
            fails.append("every compared target wanted %d argument(s), so "
                         "nothing here exercised the target-dependence this "
                         "gate exists for. If a target with the other arity "
                         "was removed, this check goes with it" % seen.pop())

    for t, want, got, decls in rows:
        if want is None:
            print("setjmp-arity: %-24s not compared -- clang has no headers "
                  "for it here" % t)
        else:
            print("setjmp-arity: %-24s %d argument(s), and clang agrees"
                  % (t, got))

    if fails:
        print("setjmp-arity: the emitted call and the target's C library "
              "disagree:", file=sys.stderr)
        for f in fails:
            print("        " + f, file=sys.stderr)
        return 1

    note = ""
    if len(seen) < 2 and not require:
        note = (" -- no target with a differing arity could be reached here, "
                "so the `non-posix` job is where that half is required")
    print("setjmp-arity: %d of %d admitted target(s) compared, %d distinct "
          "arit(ies), every emitted call and declaration matching what clang "
          "emits for ISO C's setjmp%s"
          % (len(compared), len(rows), len(seen), note))
    return 0


sys.exit(main())
