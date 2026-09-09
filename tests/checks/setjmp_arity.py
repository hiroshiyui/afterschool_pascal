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
whatever that macro expands to -- and platforms need not agree about its
**arity**, nor even about whether it is a macro:

    glibc           setjmp(x)  ->  _setjmp(x)          a macro
    Darwin          _setjmp(x)                          a function of its own,
                                                        beside setjmp
    Win64           setjmp(x)  ->  _setjmp((x), frame)  a macro, and SEH
                                                        -- no longer admitted
                                                        (ADR-0380)

Emitting the wrong arity is undefined behaviour with **no diagnostic
anywhere**: LLVM does not compare a direct call against a declaration under
opaque pointers, so the module verifies, assembles and links, and the defect
is a corrupted unwind at run time. That is `doc/sop.md` §7's row about an
`external` declaration nobody checks, arrived at from the other side -- here
the declaration is one this compiler *writes*.

**Every admitted target agrees today, and the check is not therefore idle.**
Win64 was the one that disagreed and it is gone, so what this compares is no
longer *two platforms against each other* but **each platform against its own
header** -- which is the claim that was always load-bearing, and the one a
sixth target would falsify without anybody noticing.

So it is checked the way `foreign-layout` checks a record: **the source states
a claim, a C compiler holding the real header judges it.** For every target
the compiler admits, both of these are compiled and their `@_setjmp` calls
compared:

    a C probe          clang --target=<t> -- ISO C's setjmp where that is a
                       macro naming `_setjmp`, and `_setjmp` itself where it
                       is not, which is Darwin
    a Pascal probe     pascalc --target=<t>, with a non-local goto

and the module's own `declare` has to agree with its calls, or one function
has two signatures in one module.

**A target is compared only where clang has that target's headers**, and it
says which it could not reach. Asking clang for a triple whose sysroot is not
installed fails cleanly -- `'setjmp.h' file not found` -- rather than falling
back to the host's header and answering about the wrong C library, which was
checked before this was relied on.

**`SETJMP_ARITY_REQUIRE` demands that something was compared**, and no more.
It demanded *two distinct arities* while a target existed that had the other
one; ADR-0380 removed it, and a floor that could only be met by re-admitting a
platform nobody runs is a floor that would be met by editing the target list
rather than by checking anything.

Skips (77) without clang, and where clang has the headers for no admitted
target. Not without a target: the compiler names its own, so a sixth is
compared without this file being edited (ADR-0144).
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

# **Two probes, because two families answer differently.** What the emitted
# module names is `_setjmp`, and the question is the arity *that* takes on a
# target -- not what ISO C's `setjmp` happens to be spelled as.
#
#   glibc, mingw   `setjmp` is a macro that expands to `_setjmp`, so the first
#                  probe's own IR names it and carries the arity
#   Darwin         `setjmp` is a *function* and `_setjmp` is a second one
#                  beside it, so the first probe emits `@setjmp` and says
#                  nothing; the second names `_setjmp` itself
#
# The emitter uses `_setjmp` on every target for the reason glibc and Darwin
# share: it is the one that does not save the signal mask, which costs a
# `sigprocmask` syscall (ADR-0371 measured it at 265 ns against 2.4).
C_PROBE = "#include <setjmp.h>\njmp_buf b;\nint f(void){ return setjmp(b); }\n"
C_PROBE_DIRECT = ("#include <setjmp.h>\njmp_buf b;\n"
                  "int f(void){ return _setjmp(b); }\n")

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
    (work / "sjd.c").write_text(C_PROBE_DIRECT)
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
        if m:
            want = arity(m.group(1))
        else:
            # `setjmp` did not expand to `_setjmp` here, which is Darwin: the
            # two are separate functions rather than a macro and its
            # expansion. Ask about `_setjmp` directly, since that is the name
            # the emitted module carries.
            r = run([CLANG, "--target=" + t, "-O0", "-S", "-emit-llvm",
                     str(work / "sjd.c"), "-o", "-"])
            m = CALL.search(r.stdout) if r.returncode == 0 else None
            if not m:
                fails.append("clang for %s emitted no call to @_setjmp from "
                             "either probe -- neither ISO C's setjmp nor a "
                             "direct call names it, so this target does not "
                             "have the function the emitted module declares"
                             % t)
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
        # **A clang that can answer for none of the admitted targets cannot
        # ask this question at all**, and a check that cannot ask says so
        # rather than failing -- `foreign-layout` with no C compiler and
        # `target-sizes` with only the host do the same.
        #
        # The three positions a runner is in, written down because reasoning
        # about one machine is how this check was wrong twice:
        #
        #   Linux                  the targets whose headers are installed,
        #                          and it names the ones it could not reach
        #   macOS                  the host Darwin target, since ADR-0372
        #                          admitted the two triples that made it
        #                          comparable there -- before them Apple
        #                          clang had a sysroot for no admitted target
        #                          and this arm was taken on every run
        if require:
            fails.append("SETJMP_ARITY_REQUIRE is set and clang has the "
                         "headers for none of the admitted targets, so this "
                         "job asked nothing")
        else:
            print("setjmp-arity: skipped, clang here has the headers for "
                  "none of the %d admitted target(s)" % len(rows))
            return 77
    # **What the variable demands is that something was compared, and no
    # more.** It demanded *two distinct arities* until ADR-0380, which was the
    # discriminating claim while a target existed whose `_setjmp` took a second
    # argument -- Win64's, through SEH. That target is gone and every one left
    # takes the buffer alone, so the floor would now be a demand this tree
    # cannot meet and would have to be met by re-admitting a platform nobody
    # runs. The check's own comment named this: *if a target with the other
    # arity was removed, this check goes with it*. It does not go. What it
    # claims is the half that was always the point -- **the emitted call and
    # its `declare` agree with the real header of each target clang can answer
    # for** -- and a wrong arity is undefined behaviour with no diagnostic
    # whether or not any two targets disagree.
    #
    # Not requiring reachability of *every* admitted target is deliberate and
    # was learned: no job guarantees a sysroot for all of them, and the
    # container that sets this variable has cross libcs for aarch64 and armhf
    # and none for i386 (ADR-0330).

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

    print("setjmp-arity: %d of %d admitted target(s) compared, %d distinct "
          "arit(ies), every emitted call and declaration matching what clang "
          "says `_setjmp` takes there"
          % (len(compared), len(rows), len(seen)))
    return 0


sys.exit(main())
