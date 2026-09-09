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
"""The stage-1 code generator, checked by running what it produces -- and then
by closing the bootstrap.

  irtest.py <path-to-the-seed-compiler> [files...]

Every earlier component was checked by *diffing* it against the C++ one, on a
dump both sides write (ADR-0022, ADR-0023, ADR-0024). CodeGen cannot be: the
C++ backend builds an llvm::Module through the API and the Pascal one prints
assembler text, and LLVM's own printer is not a specification -- it renumbers,
it reorders attributes, and it changes between releases. Requiring the Pascal
side to reproduce it byte for byte would be porting LLVM's AsmWriter, not
porting codegen.cpp.

So the oracle here is the same one ADR-0011 already uses for the C++ compiler:
the golden stdout of the program. Compile each case with the Pascal compiler,
assemble and link what it wrote, run it, and compare against the *same*
tests/*.out and tests/*.err the C++ compiler is held to. Two compilers, one
expected answer -- which catches wrongness rather than spelling.

Then the part that is the point of the whole exercise (ADR-0004):

  stage 1 = seed(compiler.pas)           built by the committed seed
  stage 2 = stage1(compiler.pas)         built by a compiler C++ built
  stage 3 = stage2(compiler.pas)         built by a compiler Pascal built

and stage 2 must equal stage 3. It is compared as IR rather than as a binary
because that is what the Pascal compiler emits -- the same fixed point, one
step earlier, and readable when it fails.

Converted from `selfhost/irtest.py` under ADR-0366: a harness is Python 3, and
reaches for the standard library rather than a subprocess. `find`, `sort`,
`sed`, `cp`, `diff`, `head`, `mktemp` and coreutils' `timeout` are gone; what
is still invoked is the toolchain -- the compiler under test and `clang`, which
is what that record exempts. Every message, count, floor and exit status is
what the shell wrote, and the corpus is enumerated in byte order rather than
through a `sort` that follows the operator's locale.
"""

import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.stdout.reconfigure(line_buffering=True)

# Everything this harness writes goes through the byte layer, because it
# interleaves its own sentences with whole files it copies out (gen.err,
# link.err, a diff it just wrote) and the two layers do not share a buffer.


def out(text):
    sys.stdout.buffer.write(text.encode())
    sys.stdout.buffer.flush()


def err(text):
    sys.stderr.buffer.write(text.encode())
    sys.stderr.buffer.flush()


def err_bytes(data):
    sys.stderr.buffer.write(data)
    sys.stderr.buffer.flush()


def cat(path):
    """`cat "$f" >&2` -- and a file that is not there is simply not written,
    every caller here having just created it."""
    try:
        err_bytes(Path(path).read_bytes())
    except OSError:
        pass


def head(paths, n):
    """`head -n <n> f...` on the error stream, headers and all. With more than
    one file GNU head names each and separates them with a blank line, and a
    file it cannot open is reported where it would have appeared -- the shell
    version reaches that whenever a build fails before anything is linked, so
    the wording is kept rather than replaced."""
    many = len(paths) > 1
    printed = 0
    for p in paths:
        try:
            data = Path(p).read_bytes()
        except OSError:
            err("head: cannot open '%s' for reading: "
                "No such file or directory\n" % p)
            continue
        if many:
            err(("\n" if printed else "") + "==> %s <==\n" % p)
        printed += 1
        lines = data.splitlines(keepends=True)[:n]
        err_bytes(b"".join(lines))


def stamp(path):
    """A GNU `diff -u` header's timestamp, to the nanosecond and with the
    offset, so a failing case reads the way it always has."""
    try:
        ns = os.stat(path).st_mtime_ns
    except OSError:
        ns = time.time_ns()
    whole, frac = divmod(ns, 1000000000)
    local = time.localtime(whole)
    off = local.tm_gmtoff
    sign = "+" if off >= 0 else "-"
    off = abs(off)
    return "%s.%09d %s%02d%02d" % (time.strftime("%Y-%m-%d %H:%M:%S", local),
                                   frac, sign, off // 3600, (off % 3600) // 60)


def _decorate(lines):
    """GNU diff's `\\ No newline at end of file`, which difflib does not
    write."""
    if lines and not lines[-1].endswith("\n"):
        lines = list(lines)
        lines[-1] += "\n\\ No newline at end of file\n"
    return lines


def unified(alabel, apath, alines, blabel, bpath, blines):
    import difflib
    a = _decorate(alines)
    b = _decorate(blines)
    delta = list(difflib.unified_diff(a, b, alabel, blabel,
                                      stamp(apath), stamp(bpath)))
    return "".join(delta)


def read_lines(path):
    return Path(path).read_bytes().decode(errors="surrogateescape") \
        .splitlines(keepends=True)


def diff_u(expected, actual, actual_label=None, actual_path=None):
    """`diff -u expected actual`, returning the diff text -- empty when they
    are the same. The shell compared some of these against a process
    substitution, so the second label is `/dev/fd/63` there and here."""
    a = read_lines(expected)
    b = read_lines(actual)
    if a == b:
        return ""
    return unified(str(expected), str(expected), a,
                   actual_label if actual_label else str(actual),
                   actual_path if actual_path else str(actual), b)


def head_text(text, n):
    return "".join(text.splitlines(keepends=True)[:n])


def die(message, status=1):
    err(message)
    sys.exit(status)


def run(argv, *, stdout=None, stderr=None, stdin=None, env=None,
        timeout=None):
    """The toolchain, with a bound on how long it may take. coreutils'
    `timeout` was a subprocess and a portability note in the shell; here it is
    an argument, and a run that exceeds it answers 124 as that program does."""
    try:
        p = subprocess.run(argv, stdout=stdout, stderr=stderr, stdin=stdin,
                           env=env, timeout=timeout)
        return p.returncode
    except subprocess.TimeoutExpired:
        return 124


def main(argv):
    if len(argv) < 2:
        die("usage: irtest.py <seed-compiler> [files...]\n", 2)
    seedcc = argv[1]
    args = argv[2:]

    here = Path(__file__).resolve().parent
    root = here.parent
    work = Path(tempfile.mkdtemp())
    try:
        return sweep(seedcc, args, here, root, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def sweep(seedcc, args, here, root, work):
    runtime = os.environ.get("AFTERSCHOOL_PASCAL_RUNTIME", "")
    if not runtime:
        runtime = str(Path(seedcc).parent / ".." / "lib" / "libpasrt.a")
    if not Path(runtime).is_file():
        die("irtest: cannot find libpasrt.a (looked at %s)\n" % runtime)

    # Two sizes live in two places that cannot include one another:
    # runtime/pasrt.h, which codegen.cpp includes, and the constants of the
    # Pascal compiler. A disagreement would allocate the wrong number of bytes
    # in every activation record, so they are checked, not trusted.
    def check_size(macro, constant):
        want = []
        for line in read_lines(root / "runtime" / "pasrt.h"):
            rest = line.rstrip("\n")
            prefix = "#define %s " % macro
            if rest.startswith(prefix):
                digits = ""
                for ch in rest[len(prefix):]:
                    if ch in "0123456789":
                        digits += ch
                    else:
                        break
                want.append(digits)
        # The constants are ApTypes' since ADR-0233; asked of every component,
        # so a constant that moves again is found rather than silently
        # answering empty.
        have = ""
        for component in ("aptypes.pas", "apfront.pas", "compiler.pas"):
            for line in read_lines(here / component):
                rest = line.rstrip("\n").lstrip(" ")
                prefix = "%s = " % constant
                if rest.startswith(prefix):
                    digits = ""
                    for ch in rest[len(prefix):]:
                        if ch in "0123456789":
                            digits += ch
                        else:
                            break
                    if rest[len(prefix) + len(digits):].startswith(";"):
                        have = digits
                        break
            if have:
                break
        want_text = "\n".join(want)
        if not want_text or want_text != have:
            die("irtest: %s is %s but the compiler's source says %s\n"
                % (macro, want_text, have))

    check_size("PAS_FILE_SIZE", "fileSize")
    check_size("PAS_JUMP_SIZE", "jumpSize")
    check_size("PAS_HANDLE_SIZE", "handleSize")
    check_size("PAS_DEFER_SIZE", "deferSize")
    check_size("PAS_TASKSET_SIZE", "taskSetSize")
    check_size("PAS_SELECT_ARM_SIZE", "selectArmSize")

    gen_err = work / "gen.err"
    link_err = work / "link.err"

    state = {"ir_files": []}

    # Compile one Pascal source with a stage-1 compiler and link the result.
    #   build(compiler, source.pas, output-binary)
    # `ir_files` is every module this build translated, in order, so a caller
    # can compare *all* of them. The compiler is three program-components since
    # ADR-0233 and the fixed point is about the whole compiler: comparing only
    # the program's IR would let a change in ApTypes or ApFront reproduce
    # itself unnoticed, which is the exact shape of hole the bootstrap check
    # exists to close.
    def build(cc, src, outbin, opt=()):
        # `opt` is what this case is to be assembled and linked at, read from
        # the sidecar and the environment by the caller -- see `case_opt`.
        # Empty for the compiler's own three builds, which have no sidecar and
        # are not corpus cases.
        opt = list(opt)
        src = str(src)
        stem = src[:-4] if src.endswith(".pas") else src
        # `dirname` of a bare name is `.` and not the empty string, which is
        # what the shell's $(dirname) answered.
        srcdir = os.path.dirname(src) or "."
        (work / "ir.ll").unlink(missing_ok=True)
        ir_files = []
        state["ir_files"] = ir_files
        # ISO/IEC 10206:1991 6.13's already-translated program-components. Each
        # is named with its own --import, and each is also translated on its
        # own here, so what is linked is genuinely several objects and not one
        # -- which is the clause's whole point. They used to reach the Pascal
        # compiler concatenated into a single program parameter, a program that
        # cannot name a file being unable to open several; ADR-0081 gave it
        # names.
        objects = []
        imports = []
        paths = []
        resolving = False
        n = 0
        if Path(stem + ".importpath").is_file():
            resolving = True
        # ADR-0244's search path, read exactly as tests/run_test.py reads it --
        # one directory per line, relative to the .pas's own directory. The two
        # harnesses must read a sidecar the same way or a case means two
        # things.
        if Path(stem + ".importpath").is_file():
            for line in read_lines(stem + ".importpath"):
                line = line.rstrip("\n")
                if not line:
                    continue
                paths += ["--import-path", "%s/%s" % (srcdir, line)]
        # ...and the same path as an environment, read the way
        # tests/run_test.py reads it. A fresh environment per invocation rather
        # than an export, so one case's configuration is not the next one's.
        cenv = None
        if Path(stem + ".importenv").is_file():
            first = ""
            for line in read_lines(stem + ".importenv"):
                first = line.rstrip("\n").replace("<dir>", srcdir)
                break
            cenv = dict(os.environ)
            cenv["AFTERSCHOOL_PASCAL_PATH"] = first
            resolving = True
        if Path(stem + ".components").is_file():
            for line in read_lines(stem + ".components"):
                line = line.rstrip("\n")
                if not line:
                    continue
                # One path per line; anything after it is ignored -- see
                # tests/run_test.py. The two harnesses must read the file the
                # same way or a case means two things.
                fields = line.split()
                rel = fields[0] if fields else ""
                comp = "%s/%s" % (srcdir, rel)
                n += 1
                ll = work / ("comp%d.ll" % n)
                ll.unlink(missing_ok=True)
                # With the components listed before it, and not with its own
                # --import: 6.13 lets one component import another and the list
                # is in dependency order, so the import is added after this
                # translation rather than before.
                with open(os.devnull, "wb") as devnull, \
                        open(gen_err, "wb") as ge:
                    rc = run([cc] + imports + [comp, "-o", str(ll)],
                             stdout=devnull, stderr=ge, timeout=600)
                if rc != 0:
                    return 1
                imports += ["--import", comp]
                if not (ll.exists() and ll.stat().st_size > 0):
                    return 1
                ir_files.append(str(ll))
                obj = work / ("c%d.o" % n)
                with open(link_err, "wb") as le:
                    rc = run(["clang"] + opt
                             + ["-Wno-override-module", "-fPIC", "-c",
                                str(ll), "-o", str(obj)], stderr=le)
                if rc != 0:
                    return 2
                objects.append(str(obj))
        # What the compiler resolved for itself, translated and linked here --
        # the half of resolution a compiler cannot do, and the same thing
        # tools/pascalcc does for every other harness. Asked of the compiler
        # rather than worked out from the Pascal, which is the whole point of
        # the flag.
        if resolving:
            resolved = []
            text = ""
            try:
                with open(os.devnull, "wb") as devnull:
                    p = subprocess.run(
                        [cc] + imports + paths + ["--dump-imports", src,
                                                  "-o", os.devnull],
                        stdout=subprocess.PIPE, stderr=devnull, env=cenv,
                        timeout=600)
                text = p.stdout.decode(errors="surrogateescape")
            except subprocess.TimeoutExpired:
                # What the shell's `timeout 600` did inside a process
                # substitution: nothing was resolved, and the translation
                # below is what reports it.
                pass
            for line in text.splitlines():
                if line.startswith("component "):
                    resolved.append(line[len("component "):])
            for c in resolved:
                if c in imports:
                    continue
                n += 1
                ll = work / ("comp%d.ll" % n)
                ll.unlink(missing_ok=True)
                with open(os.devnull, "wb") as devnull, \
                        open(gen_err, "wb") as ge:
                    rc = run([cc] + paths + [c, "-o", str(ll)],
                             stdout=devnull, stderr=ge, env=cenv, timeout=600)
                if rc != 0:
                    return 1
                if not (ll.exists() and ll.stat().st_size > 0):
                    return 1
                ir_files.append(str(ll))
                obj = work / ("c%d.o" % n)
                with open(link_err, "wb") as le:
                    rc = run(["clang"] + opt
                             + ["-Wno-override-module", "-fPIC", "-c",
                                str(ll), "-o", str(obj)], stderr=le)
                if rc != 0:
                    return 2
                objects.append(str(obj))
        with open(os.devnull, "wb") as devnull, open(gen_err, "wb") as ge:
            rc = run([cc, src, "-o", str(work / "ir.ll")] + imports + paths,
                     stdout=devnull, stderr=ge, env=cenv, timeout=600)
        if rc != 0:
            return 1
        ir = work / "ir.ll"
        if not (ir.exists() and ir.stat().st_size > 0):
            return 1
        ir_files.append(str(ir))
        with open(link_err, "wb") as le:
            rc = run(["clang"] + opt + ["-Wno-override-module", str(ir)]
                     + objects + [runtime, "-lm", "-o", str(outbin)],
                     stderr=le)
        if rc != 0:
            return 2
        return 0

    # Which optimisation level to assemble and link a *case* at, with
    # tests/run_test.py's precedence and for its reasons:
    #
    #   name.opt                  this case pins one, because the other level
    #                             hides what it is testing
    #   AFTERSCHOOL_PASCAL_OPT    the whole run wants one
    #   neither                   nothing, which is clang's own default of -O0
    #
    # The two harnesses must read a sidecar the same way or a case means two
    # things -- the argument .components and .importpath are already read
    # under. This one read it in neither direction: `.opt` appeared nowhere in
    # this file and no clang invocation here carried any -O at all, so the
    # three cases that pin `-O0` were getting it by accident, and a sweep
    # asking for a level was ignored. With AFTERSCHOOL_PASCAL_OPT=-O2 set,
    # `tests/for_nested_stack.pas` was assembled with no -O flag on either of
    # its two clang invocations and the whole run carried -O2 zero times.
    #
    # **The default stays bare, and that is deliberate.** doc/sop.md 6 records
    # that this harness links at -O0 and that ADR-0220 was found by it; making
    # the default -O2 to match pascalcc's would spend that. What changes is
    # that -O0 is now what a case asked for rather than what nobody chose,
    # and that a sweep at another level reaches this harness at all.
    def case_opt(stem):
        f = Path(stem + ".opt")
        if f.is_file():
            return ["".join(f.read_text().split())]
        env_opt = os.environ.get("AFTERSCHOOL_PASCAL_OPT", "")
        if env_opt:
            return [env_opt]
        return []

    # Stage 1 is built by the seed -- seed/*.ll assembled into a compiler --
    # where it used to be built by the C++ one. Nothing else about the chain
    # changes: what the fixed point proves is that a compiler built from this
    # source reproduces itself, and which compiler started it off has never
    # been part of that claim (ADR-0004, ADR-0085).
    if build(seedcc, here / "compiler.pas", work / "stage1") != 0:
        err("--- the seed could not compile the Pascal compiler ---\n")
        head([str(gen_err), str(link_err)], 20)
        return 1

    if args:
        files = list(args)
    else:
        # ...and the examples (ADR-0295), which are cases with goldens like any
        # under tests/ and would otherwise be the one corpus the fixed point's
        # compiler never ran.
        #
        # Enumerated in byte order, where the shell piped `find` into `sort`,
        # whose collation follows the operator's locale -- the same names in a
        # different order on a differently configured machine (ADR-0366).
        files = []
        for top in (root / "tests", root / "examples"):
            for dirpath, dirnames, filenames in os.walk(top):
                for fn in filenames:
                    if fn.endswith(".pas"):
                        files.append(os.path.join(dirpath, fn))
        files.sort(key=lambda s: s.encode(errors="surrogateescape"))

    # --- the golden suite, run against what a given stage-1 compiler produces
    counts = {"checked": 0,
              # Two different things, counted apart because one line reporting
              # both as "rejected at compile time" said something false about
              # the larger of them: 262 of the 485 it reported had never been
              # compiled at all.
              "noexpect": 0, "rejected": 0, "failed": 0}

    def golden(cc, stage):
        for f in files:
            stem = f[:-4] if f.endswith(".pas") else f
            name = os.path.basename(stem)
            expected_out = stem + ".out"
            expected_err = stem + ".err"
            stdin_file = stem + ".in"
            if not Path(stdin_file).is_file():
                stdin_file = os.devnull
            # The same fixed-clock hook run_test.py has, and for the same
            # reason: a golden file that names a date can only be compared
            # against a date somebody chose. Unset again afterwards so one case
            # cannot leak into the next.
            if Path(stem + ".epoch").is_file():
                os.environ["SOURCE_DATE_EPOCH"] = \
                    Path(stem + ".epoch").read_text().rstrip("\n")
            else:
                os.environ.pop("SOURCE_DATE_EPOCH", None)

            # A source with no expectation is not a case: ISO/IEC 10206:1991
            # 6.13's separately accepted components live under tests/ and are
            # compiled as part of the cases that import them, never run on
            # their own -- there is no main-program-declaration in one to enter
            # it through.
            if not Path(expected_out).is_file() \
                    and not Path(expected_err).is_file():
                if stage == "stage1":
                    counts["noexpect"] += 1
                continue

            # A case that is *meant* not to compile is not this test's
            # business: tests/run_test.py compares its diagnostics, and what is
            # checked here is what the code generator produces for programs
            # there are programs for.
            #
            # It used to be told which those were by asking the C++ compiler,
            # which is gone (ADR-0085). The question is now answered by the
            # outcome and the expectation together: a build that fails where a
            # .err golden exists is that case doing what it says; a build that
            # fails with no .err is a regression, and is reported rather than
            # skipped. Deciding by expectation alone would let a program that
            # must not compile pass by failing to.
            rc = build(cc, f, work / name, case_opt(stem))
            if rc != 0:
                if Path(expected_err).is_file():
                    if stage == "stage1":
                        counts["rejected"] += 1
                    continue
                if rc == 1:
                    err("--- %s/%s: the Pascal compiler failed on it ---\n"
                        % (stage, name))
                    cat(gen_err)
                else:
                    err("--- %s/%s: the generated IR did not assemble ---\n"
                        % (stage, name))
                    head([str(link_err)], 20)
                counts["failed"] += 1
                continue

            if stage == "stage1":
                counts["checked"] += 1
            # A wrong lowering can make a program *loop* rather than answer
            # wrongly -- a `downto` that steps upward runs 2^31 times before it
            # wraps out. That is a failure like any other, so it is bounded
            # here instead of hanging ctest.
            with open(stdin_file, "rb") as si, \
                    open(work / "actual", "wb") as so, \
                    open(work / "actual.err", "wb") as se:
                status = run([str(work / name), str(work / "file1"),
                              str(work / "file2")],
                             stdin=si, stdout=so, stderr=se, timeout=60)
            if status == 124:
                err("--- %s/%s: the program did not terminate ---\n"
                    % (stage, name))
                counts["failed"] += 1
                continue

            if Path(expected_err).is_file():
                # A program that is supposed to stop: the message is the thing
                # under test.
                if status == 0:
                    err("--- %s/%s: expected a failure, but it succeeded ---\n"
                        % (stage, name))
                    counts["failed"] += 1
                    continue
                # The source path is rewritten as tests/run_test.py rewrites
                # it: since ADR-0293 a trap names the file it happened in, and
                # a golden must not depend on where the checkout lives. Both
                # harnesses must normalise the same way or a case means two
                # things.
                actual = read_lines(work / "actual.err")
                normalised = [line.replace(f, "<source>")
                              .replace((os.path.dirname(f) or ".") + "/",
                                       "<dir>/")
                              for line in actual]
                expect = read_lines(expected_err)
                if expect != normalised:
                    delta = unified(expected_err, expected_err, expect,
                                    "/dev/fd/63", work / "actual.err",
                                    normalised)
                    err("--- %s/%s: runtime error message differs ---\n"
                        % (stage, name))
                    err(head_text(delta, 20))
                    counts["failed"] += 1
                    continue
                if Path(expected_out).is_file():
                    delta = diff_u(expected_out, work / "actual")
                    if delta:
                        err("--- %s/%s: output before the failure differs "
                            "---\n" % (stage, name))
                        err(head_text(delta, 20))
                        counts["failed"] += 1
                continue

            if status != 0:
                err("--- %s/%s: the program exited with status %d ---\n"
                    % (stage, name, status))
                cat(work / "actual.err")
                counts["failed"] += 1
                continue
            # run_test.py folds stderr into stdout for an ordinary case; do the
            # same, so the golden file means the same thing on both sides.
            with open(work / "actual", "ab") as so:
                so.write(Path(work / "actual.err").read_bytes())
            delta = diff_u(expected_out, work / "actual")
            if delta:
                err("--- %s/%s: output differs ---\n" % (stage, name))
                err(head_text(delta, 30))
                counts["failed"] += 1

    golden(work / "stage1", "stage1")

    # --- the bootstrap: stage 2 against stage 3 ---
    if build(work / "stage1", here / "compiler.pas", work / "stage2") != 0:
        err("--- the Pascal compiler could not compile itself ---\n")
        head([str(gen_err), str(link_err)], 20)
        return 1
    stage2_ir = []
    for n, f in enumerate(state["ir_files"], start=1):
        target = work / ("stage2.%d.ll" % n)
        shutil.copyfile(f, target)
        stage2_ir.append(target)

    if build(work / "stage2", here / "compiler.pas", work / "stage3") != 0:
        err("--- stage 2 could not compile the compiler ---\n")
        head([str(gen_err), str(link_err)], 20)
        return 1
    stage3_ir = []
    for n, f in enumerate(state["ir_files"], start=1):
        target = work / ("stage3.%d.ll" % n)
        shutil.copyfile(f, target)
        stage3_ir.append(target)

    if len(stage2_ir) != len(stage3_ir):
        err("--- stage 2 emitted %d modules and stage 3 %d ---\n"
            % (len(stage2_ir), len(stage3_ir)))
        return 1
    for n, f in enumerate(stage2_ir, start=1):
        g = stage3_ir[n - 1]
        if Path(f).read_bytes() != Path(g).read_bytes():
            err("--- stage 2 and stage 3 differ in module %d of %d: "
                "the compiler is not a fixed point ---\n"
                % (n, len(stage2_ir)))
            err(head_text(diff_u(f, g), 40))
            return 1

    # A compiler that reproduces itself and nothing else would pass the line
    # above, so stage 2 is held to the same golden output stage 1 was.
    golden(work / "stage2", "stage2")

    if counts["failed"] != 0:
        err("stage-1 codegen test: %d of %d programs are wrong\n"
            % (counts["failed"], counts["checked"]))
        return 1

    # Three disjoint counts, each taken on the stage-1 sweep alone, and they
    # add up to every .pas under tests/ -- which is the property that makes
    # them checkable. This line used to say two wrong things at once. `skipped`
    # was incremented both where a source has no expectation and where a case
    # was rejected as its .err says, and the line called the sum "rejected at
    # compile time", which is false of the larger part: it is never compiled
    # here at all. And `checked` was not guarded by stage, so it counted every
    # case twice, once per compiler, and the line called that a number of
    # programs.
    out("stage-1 codegen test: %d programs built, ran and match their golden "
        "under both compilers; %d more were rejected, as their .err says; "
        "%d sources carry no expectation and are not cases. "
        "Stage 2 = stage 3: the compiler is a fixed point\n"
        % (counts["checked"], counts["rejected"], counts["noexpect"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
