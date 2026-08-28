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

"""Every procedure of the compiler is entered by some case, or argued not to be.

doc/sop.md §5 says coverage here is argued rather than measured, and the
blind-spot register says the same thing in one line: "§5 is an argument, not a
number." This is the number, for the one granularity at which it can be had
without changing what the compiler emits.

**How it is possible at all.** `-fsanitize-coverage=` is an LLVM *IR* pass, so
clang applies it to the textual .ll this compiler produces -- no front end, no
debug info, no DWARF. That is the whole trick, and it is available only because
ADR-0006 kept textual .ll a first-class output.

**What it measures, and what it does not.** A procedure is covered when some
run entered it. That is coarse: a two-hundred-line procedure entered once
counts, and the `case` arm nobody reaches is invisible. Basic-block coverage
was measured and rejected as a headline -- 8,304 of the compiler's own 26,655
blocks are the bounds-check and nil-check failure paths CodeGen emits for its
own subscripts, which a correct run never enters *by design*, so a third of the
denominator is unreachable and the percentage means nothing. The honest
denominator is lines a human wrote, and reaching it needs the compiler to emit
line information, which is a feature and not a script. Until then: procedures.

**Why an allowlist and not a percentage.** Same rule as
unreachable_diagnostics.txt and verify/'s KNOWN_GAP (ADR-0013): this fails in
**both** directions. A procedure that stops being covered fails, and one listed
here that *becomes* covered fails just as loudly, because the list has then
stopped describing this compiler. A bare percentage would hide which procedure
was lost, and §5's whole argument is that a count nobody names is a claim
nothing checks.

Usage:

    python3 tests/checks/coverage.py [repo-root] [--build DIR] [--report]

`--report` prints the covered/uncovered breakdown and always exits 0; without
it the exit status is the gate. Exits 77 (ctest's skip) when clang cannot build
an instrumented compiler.
"""

import argparse
import bisect
import concurrent.futures
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import components                                    # noqa: E402

SKIP = 77

# `; <spelling> <line>` immediately before the function it names -- written by
# EmitProcBody, which is the only place that knows both. The counter in @pNNN
# follows the order CodeGen walked the tree, so it cannot be recovered from the
# source; this comment is the only mapping that exists.
NAMED = re.compile(r"^; ([a-z_][a-z_0-9]*) (\d+)\n"
                   r"define [^@]*@(p\d+)\(", re.MULTILINE)

DECL = re.compile(r"^\s*(?:procedure|function)\s+([A-Za-z_][A-Za-z_0-9]*)",
                  re.IGNORECASE)


def run(*args, **kw):
    return subprocess.run(args, capture_output=True, text=True, **kw)


def corpus(root):
    """Every source the suite compiles, with the flags it compiles it under.

    Mirrors what CMakeLists.txt registers rather than re-deciding it: a
    name.components case is translated with its components imported, because
    that path is reached in no other way. Until ADR-0232 each group carried a
    standard as well, the directory picking it (ADR-0033) and a name.std
    sidecar overriding it (ADR-0082); there is one language now, so a group is
    only a list of files and the directories are kept for what they enumerate.
    """
    jobs = []
    groups = [
        sorted((root / "tests").glob("*.pas")),
        sorted((root / "tests" / "extended").glob("*.pas")),
        sorted((root / "tests" / "extended" / "components").glob("*.pas")),
        # The dialect. Listed here for the same reason the dump corpus was
        # added after ADR-0103: a case this does not enumerate contributes no
        # coverage, so the lines it reaches report as unreached while an oracle
        # reaches them on every run -- which was worth 195 statements the last
        # time it happened.
        sorted((root / "tests" / "dialect").glob("*.pas")),
        # And the dialect's §6.13 components, for the reason the line above
        # gives about the dialect itself: a module-only translation reaches
        # arms of RunCodeGen a program never does, and until ADR-0216 one of
        # them was missing five statements nothing here could report as
        # unreached -- because nothing here compiled such a component at all.
        sorted((root / "tests" / "dialect" / "components").glob("*.pas")),
        sorted((root / "selfhost" / "badparse").glob("*.pas")),
        sorted((root / "selfhost" / "badsema").glob("*.pas")),
        [root / "selfhost" / "torture.pas"],
        # Every program-component, and each on its own: a module-only
        # translation reaches arms of RunCodeGen a program never does
        # (ADR-0216), and since ADR-0233 the compiler's own sources are two
        # such modules. The .components sidecar beside compiler.pas supplies
        # the imports, through the branch below.
        components.sources(root),
    ]
    for files in groups:
        for f in files:
            if not f.exists():
                continue
            flags = []
            comps = f.with_suffix(".components")
            if comps.exists():
                for rel in comps.read_text().split():
                    flags += ["--import", str(f.parent / rel)]
            elif f.name in components.COMPONENTS:
                # A component of the compiler's own has no sidecar of its
                # own -- the list lives beside the program (ADR-0233) -- and
                # translating it without its imports stops in Sema on the
                # first type it cannot see, which reaches no code generator
                # at all. That is the opposite of why it is in this corpus.
                flags = components.imports(root, f.name)
            jobs.append((f, flags))

    # The dump cases carry their own flag, and it is the reason they exist: the
    # dumps are reached by no ordinary case, which is what this harness found.
    for f in sorted((root / "tests" / "dumps").glob("*.pas")):
        flags = f.with_suffix(".flags")
        jobs.append((f, [flags.read_text().strip() if flags.exists()
                         else "--dump-all"]))

    # ...and the same corpus again under --dump-all. It was added because
    # `selfhost/difftest.sh` drove it that way on every run, comparing the
    # three dump sections of two front ends over every Pascal source in the
    # tree; ADR-0232 retired that harness with the conformance surface it
    # compared, and the sweep stays, because what it measures is the walkers
    # and not the oracle that used to read them.
    #
    # Without it the measurement said the dump walkers were barely reached --
    # `dumpexpr` 75 statements never run of 186, `dumpstmt` 11, `dumpgroup` 18
    # -- because the only dump flags here were the six cases in tests/dumps/.
    # Sweeping the whole corpus leaves `dumpexpr` at 1 and `dumpstmt` and
    # `dumpgroup` at 0, and takes the whole figure from 649 statements never
    # run to 454. Those 195 were reported as unreached while an oracle in the
    # suite reached them every time it ran.
    #
    # That is doc/sop.md §7's "coverage.py sees the sources, not the harnesses"
    # closed for the one harness whose flags this file could mirror -- and the
    # row stays for the shell harnesses that build compilers of their own:
    # irtest.sh, producttest.sh and verify.py are invisible here.
    for src, flags in list(jobs):
        if src is not None and not any(f.startswith("--dump") for f in flags):
            jobs.append((src, flags + ["--dump-all"]))

    # Two invocations that compile nothing. They are here because this harness
    # can only run what it can enumerate, and the shell harnesses -- irtest.sh,
    # producttest.sh, verify.py -- drive the compiler in ways no glob finds.
    # That is a limitation of the instrument and is recorded in doc/sop.md §7;
    # these two are added rather than left to misreport, because
    # `--version` *is* asserted (producttest.sh compares it against
    # CMakeLists.txt) and `-h` is too (producttest.sh checks it documents every
    # flag ParseArgs accepts). Running them here claims only what is true: some
    # case enters these procedures.
    hello = str(root / "tests" / "hello.pas")
    jobs.append((None, ["--version"]))
    jobs.append((None, ["-h"]))

    # --dump-limits is the third of that kind and the one whose asserter is a
    # ctest case rather than a shell harness: tests/checks/buffer_headroom.py
    # drives it over selfhost/compiler.pas on every run and reads both counters
    # out of it (ADR-0148). It gets no case in tests/dumps/ on purpose -- the
    # pool figure moves whenever Sema or CodeGen interns something new, so its
    # golden would be regenerated for reasons that have nothing to do with it,
    # and CLAUDE.md's rule is that regenerating a golden is a decision. What
    # buffer_headroom.py asserts instead is stronger than a golden anyway: the
    # capacities it reports must equal the constants this tree declares.
    jobs.append((root / "selfhost" / "compiler.pas",
                 components.imports(root) + ["--dump-limits"]))

    # ADR-0156's --target=, both ways. The accepting arm is driven over an
    # ordinary program because what it changes is two lines of the module the
    # code generator writes; the refusing arm is a driver message, which
    # diagnostic_coverage.py filters out as not being about a program, so
    # nothing but this reaches it. selfhost/producttest.sh is what asserts both.
    jobs.append((hello, ["--target=aarch64-linux-gnu"]))
    jobs.append((None, ["--target=riscv64-linux-gnu", hello]))

    # The command-line error paths, for the same reason and with the same
    # caveat: producttest.sh is what asserts each message and its non-zero
    # exit. They are here because nothing else drives them --
    # diagnostic_coverage.py filters `pascalc: ` messages out as driver output,
    # so the gate that counts messages is blind to these by construction, and
    # line_coverage.py is what found the branches unrun (ADR-0104).
    # A command line as long as the compiler admits, and one word longer.
    # `Arg` is argMax + 1 arms of `binding(argN)`, and nothing in the corpus is
    # invoked with more than a handful of arguments -- so twelve of those arms
    # were reported unreached the moment the bound was raised, which is the
    # ratchet doing exactly its job, and forty-eight more the second time it
    # was raised. The filler is a repeated `--dump-limits`
    # because it is a flag that is a no-op when written twice: what is being
    # exercised is the *position*, not the option. It was `--std=iso7185`
    # until ADR-0232 removed the modes, and producttest.sh fills its own
    # copy of this check the same way.
    filler = ["--dump-limits"] * 69          # + source + -o + name = argMax
    jobs.append((hello, list(filler)))
    jobs.append((hello, filler + ["--emit-llvm"]))     # ...and one over it

    # A source compiled with no flag at all -- which is now every source
    # (ADR-0232), and is kept as a job because the argument loop's
    # no-more-arguments arm is reached no other way.
    jobs.append((hello, []))

    jobs.append((None, ["--no-such-flag", hello]))
    jobs.append((None, [hello, "-o"]))       # -o with nothing after it
    jobs.append((None, [hello, "--import"]))  # --import with nothing after it
    jobs.append((None, [hello, str(root / "tests" / "arith.pas")]))
    return jobs


def build_instrumented(root, build, work):
    """An instrumented copy of the compiler, from IR the *current* source
    produced.

    Not build/pascalc.ll: that is what the seed emitted, and the seed is the
    previous release's compiler (ADR-0085), so it predates any change being
    measured -- including the name comments this harness reads. Stage 2 is the
    compiler built from the source in the tree, so stage 2 is what gets
    measured."""
    # None means *skip* -- something this machine does not have -- and False
    # means the measurement is broken, which must fail. They were one value
    # until ADR-0233's split, and the day the compiler stopped being able to
    # translate its own source this gate reported a missing clang (doc/sop.md
    # §7). A gate that answers "skipped" to a real break fails in no direction
    # at all.
    pascalc = build / "bin" / "pascalc"
    pasrt = build / "lib" / "libpasrt.a"
    if not pascalc.exists() or not pasrt.exists():
        print(f"coverage: no compiler at {pascalc} -- build first", file=sys.stderr)
        return None
    if not shutil.which("clang"):
        print("coverage: clang is not on PATH", file=sys.stderr)
        return None

    # Three program-components since ADR-0233, each translated with the ones
    # before it as `--import` and each instrumented on its own: a procedure of
    # ApFront is a procedure of the compiler, and instrumenting the program
    # alone would report every one of them as entered by nothing.
    irs = []
    for name in components.COMPONENTS:
        ir = work / (name[:-4] + ".ll")
        r = run(str(pascalc), *components.translate(root, name),
                "-o", str(ir))
        if r.returncode != 0 or not ir.exists():
            print(f"coverage: the compiler failed to translate {name}\n"
                  + r.stdout, file=sys.stderr)
            return False
        irs.append((name, ir))

    shim, exe = work / "covrt.o", work / "pascalc-cov"
    # Compiled and linked in two steps on purpose: passing -fsanitize-coverage
    # to the *link* makes clang add libclang_rt.ubsan_standalone.a, which
    # Debian's packages do not ship. The pass is applied at compile time and
    # the callbacks come from covrt.c, so the link needs nothing.
    covos = [work / (name[:-4] + ".o") for name, _ in irs]
    steps = [("instrumenting " + name,
              ("clang", "-Wno-override-module", "-c", "-O0",
               "-fsanitize-coverage=func,trace-pc-guard,pc-table",
               str(ir), "-o", str(o)))
             for (name, ir), o in zip(irs, covos)]
    steps += [
        ("the callback shim", ("clang", "-c", "-O1",
                               str(root / "tests" / "checks" / "covrt.c"),
                               "-o", str(shim))),
        # -no-pie so a reported address is the one `nm` prints, with no load
        # base to subtract and no chance of subtracting the wrong one.
        ("linking", ("clang", "-no-pie", *[str(o) for o in covos], str(shim),
                     str(pasrt), "-lm", "-o", str(exe))),
    ]
    for what, cmd in steps:
        r = run(*cmd)
        if r.returncode != 0:
            print(f"coverage: {what} failed\n{r.stderr}", file=sys.stderr)
            return False
    return exe, irs


def procedures(irs, root):
    """pNNN -> (spelling, line), with the spelling as the source writes it.

    The comment carries the case-folded spelling, the lexer having folded it
    (§6.1.3), so the *line* is what recovers the original -- and checking that
    the declaration on that line folds to the same word is what keeps this a
    mapping rather than a guess. A disagreement means the comment and the
    source have drifted, which is worth failing over rather than papering."""
    out = {}
    for name, ir in irs:
        src = (root / "selfhost" / name).read_text().splitlines()
        for folded, line, sym in NAMED.findall(ir.read_text()):
            n = int(line)
            spelling = folded
            if 1 <= n <= len(src):
                m = DECL.match(src[n - 1])
                if m and m.group(1).lower() == folded:
                    spelling = m.group(1)
            out[sym] = (spelling, n, name)
    return out


def symbols(exe):
    """Every pNNN in the binary, sorted by address, for mapping a PC back."""
    r = run("nm", "--defined-only", str(exe))
    syms = []
    for line in r.stdout.splitlines():
        parts = line.split()
        if len(parts) == 3 and parts[1] in "tT" and re.fullmatch(r"p\d+", parts[2]):
            syms.append((int(parts[0], 16), parts[2]))
    syms.sort()
    return syms


def sweep(exe, jobs, work):
    """Run the corpus, and return every address reached.

    Compile failures are expected and ignored: a third of the corpus exists to
    be rejected, and those runs reach error paths nothing else does."""
    def one(idx_job):
        idx, (src, flags) = idx_job
        out = work / f"hit{idx}.txt"
        env = dict(os.environ, PASCOV_OUT=str(out))
        if idx == 0:
            env["PASCOV_PCS"] = str(work / "pcs.txt")
        # A job with no source carries its *complete* argument list, so that a
        # case testing a missing operand ("-o" with nothing after it) is not
        # quietly repaired by an appended one.
        argv = [str(exe), *flags]
        if src is not None:
            argv += [str(src), "-o", str(work / f"o{idx}.ll")]
        try:
            subprocess.run(argv, capture_output=True, timeout=300, env=env)
        except subprocess.TimeoutExpired:
            print(f"coverage: {src} timed out", file=sys.stderr)
        return out

    hits = set()
    with concurrent.futures.ThreadPoolExecutor(max_workers=os.cpu_count()) as ex:
        for out in ex.map(one, enumerate(jobs)):
            if out.exists():
                hits.update(int(x, 16) for x in out.read_text().split())
    return hits


def allowed(root):
    """The procedures accepted as unentered, each with the argument for it."""
    path = root / "tests" / "checks" / "uncovered_procedures.txt"
    if not path.exists():
        return set()
    return {line[2:].strip() for line in path.read_text().splitlines()
            if line.startswith("= ")}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root", nargs="?", default=None)
    ap.add_argument("--build", default=None)
    ap.add_argument("--report", action="store_true")
    args = ap.parse_args()

    root = pathlib.Path(args.root or
                        pathlib.Path(__file__).resolve().parents[2]).resolve()
    build = pathlib.Path(args.build or root / "build").resolve()

    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        built = build_instrumented(root, build, work)
        if built is False:
            print("coverage: the instrumented compiler could not be built, "
                  "and that is a failure and not a skip", file=sys.stderr)
            return 1
        if built is None:
            print("coverage: skipped")
            return SKIP
        exe, irs = built

        names = procedures(irs, root)
        syms = symbols(exe)
        if not syms or not names:
            print("coverage: no instrumented procedures found -- the IR or the "
                  "name comments changed shape; see NAMED in this script",
                  file=sys.stderr)
            return 1

        addrs = [a for a, _ in syms]
        hits = sweep(exe, corpus(root), work)
        entered = set()
        for pc in hits:
            i = bisect.bisect_right(addrs, pc) - 1
            if i >= 0:
                entered.add(syms[i][1])

    total = len(syms)
    covered = len(entered)
    # Keyed on the spelling, not on the line: a line number moves with every
    # edit above it, and an allowlist that churned on unrelated changes would
    # be rewritten without being read.
    uncovered = {names.get(sym, (sym, 0, "?"))[0]
                 for _, sym in syms if sym not in entered}
    listed = allowed(root)

    if args.report:
        print(f"procedures: {covered}/{total} entered "
              f"({100.0 * covered / total:.1f}%)")
        for name in sorted(uncovered, key=str.lower):
            at = next((f"{f}:{l}" for n, l, f in names.values() if n == name),
                      "?")
            mark = " " if name in listed else "*"
            print(f"  {mark} {name}  ({at})")
        print("\n* = not in tests/checks/uncovered_procedures.txt")
        return 0

    missing = sorted(uncovered - listed, key=str.lower)
    revived = sorted(listed - uncovered, key=str.lower)

    for name in missing:
        at = next((f"{f}:{l}" for n, l, f in names.values() if n == name), "?")
        print(f"no case enters this procedure ({at}): {name}")
    for name in revived:
        print("listed as unentered, but some case now enters it -- either the "
              f"corpus grew or the argument was wrong: {name}")

    if missing or revived:
        print()
        print(f"coverage: {covered}/{total} procedures entered "
              f"({100.0 * covered / total:.1f}%); "
              f"{len(missing)} unentered and unlisted, "
              f"{len(revived)} wrongly listed")
        print("Write a case, or -- if no program can reach it -- add it to "
              "tests/checks/uncovered_procedures.txt with the argument for "
              "why. See doc/sop.md §5.")
        return 1

    print(f"coverage: {covered}/{total} procedures entered "
          f"({100.0 * covered / total:.1f}%), "
          f"{len(listed)} argued unreachable, none unlisted")
    return 0


if __name__ == "__main__":
    sys.exit(main())
