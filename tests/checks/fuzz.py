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

"""Does this compiler survive input nobody wrote on purpose? (ADR-0275)

Every corpus here is hand-written -- `selfhost/torture.pas` and
`selfhost/badparse/` most deliberately of all -- so every one of them tests
what someone thought of. A hand-written lexer and parser over **fixed
buffers** (ADR-0012) is the canonical target for the other kind of test, and
until this nothing here made the claim at all: ADR-0067's *a claim no test
names is a claim nothing checks*, applied to crash-resistance instead of to
conformance.

**Three families, and the split is what each can prove.**

*Truncation.* Every prefix of a real source, byte by byte. It is exhaustive
rather than random -- the parser meets end-of-file in every state a source can
put it in -- and it is the family most likely to find a missing `aborted`
test, because the parser's rule is that every production and every loop checks
that flag (ADR-0023) and a prefix is how a production runs out of tokens.

*The bounds.* One generated input per fixed buffer and per depth limit, each
asserting the **message**, because ADR-0012's claim is not that a full buffer
is survivable but that it is a *diagnostic*. Two of the five had never been
reached by anything: `too many tokens` and `out of string space` were excluded
from `diagnostic-coverage` as "capacity limits, not diagnostics about a
program being compiled and no golden by design", and both carry a file, a line
and a column. The exclusion was an argument standing in for a case. They stay
out of the goldens -- one of the two inputs is 1.2 MB and neither is worth
committing -- and are catalogued in unreachable_diagnostics.txt with this
harness named as what reaches them.

*Mutation.* A fixed number of deterministic mutations of the corpus. The seed
is fixed, so what runs under `ctest` is a **regression suite of hostile
inputs** and not a search; `--long N` is the search, and is run by hand.
Reporting a random failure on someone else's commit is how a fuzzer in a suite
becomes a fuzzer nobody runs.

    python3 tests/checks/fuzz.py [root] [--build DIR] [--long N] [--seed N]

What it does *not* do is drive the compiled program. Every mutant here is
compiled and nothing runs the result: a mutant that compiles is rare and one
that compiles into a program worth running is rarer, and `sanitizers` already
runs the whole corpus for that.
"""

import argparse
import concurrent.futures
import os
import pathlib
import random
import resource
import subprocess
import sys
import tempfile

SKIP = 77

# A mutant may loop, and a compiler that loops writes IR while it does. 64 MB
# is far above anything this corpus produces and far below what fills a disk;
# the harness that learned this lesson wrote 38 GB before anything noticed.
FSIZE = 64 << 20
ADDRESS = 4 << 30
TIMEOUT = 30


def limits():
    resource.setrlimit(resource.RLIMIT_FSIZE, (FSIZE, FSIZE))
    resource.setrlimit(resource.RLIMIT_AS, (ADDRESS, ADDRESS))
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def survived(pascalc, src, out, flags=()):
    """None if the compiler survived, else why it did not.

    A diagnostic and a non-zero exit are *fine* -- most of this input is
    nonsense and being told so is the right answer. What is not fine is a
    signal, a trap in the compiler's own runtime, or not finishing.
    `procedure-coverage` separates those three the same way and for the same
    reason: an exit status cannot tell a rejection from a crash, a third of
    this compiler's corpus being written to exit 1 (ADR-0269)."""
    try:
        r = subprocess.run([str(pascalc), *flags, str(src), "-o", str(out)],
                           capture_output=True, timeout=TIMEOUT,
                           preexec_fn=limits)
    except subprocess.TimeoutExpired:
        return f"did not finish in {TIMEOUT}s"
    if r.returncode < 0:
        return f"killed by signal {-r.returncode}"
    for ln in r.stderr.decode("utf-8", "replace").splitlines():
        if ln.startswith("runtime error:"):
            return ln
    return None


def message(pascalc, src, out, flags=()):
    """What the compiler said, or a reason it said nothing usable. Its
    diagnostics go to `output` (ADR-0083), no standard Pascal program having a
    second stream, so this reads standard output."""
    why = survived(pascalc, src, out, flags)
    if why is not None:
        return None, why
    r = subprocess.run([str(pascalc), *flags, str(src), "-o", str(out)],
                       capture_output=True, timeout=TIMEOUT, preexec_fn=limits)
    first = r.stdout.decode("utf-8", "replace").splitlines()
    return (first[0] if first else ""), None


def seeds(root):
    """The hand-written corpora, which is what there is to mutate. Sources
    only -- a `.components` case's imports are read from beside it and a
    mutant has none, so every one of these is compiled alone."""
    out = []
    for pat in ("tests/*.pas", "tests/extended/*.pas", "tests/dialect/*.pas",
                "selfhost/badparse/*.pas", "selfhost/badsema/*.pas"):
        out += sorted(root.glob(pat))
    out.append(root / "selfhost" / "torture.pas")
    return [f.read_bytes() for f in out if f.exists() and f.stat().st_size < 60000]


# --- the bounds ------------------------------------------------------------
#
# Each entry generates one source and names the message it must produce. The
# message is compared as a *prefix* of the first line the compiler wrote, so
# the file, line and column in front of it are skipped and the capacity itself
# is included -- `tokMax` moving is a change to this gate and should be.

def bounds():
    """(name, source, the message it must produce, the flags to produce it).

    All but one are reached by an ordinary compilation. The exception is the
    trivia table, which the lexer fills only when something asked for it
    (ADR-0279) -- so the input that overruns it is a program the compiler
    compiles without complaint, and what fails is the request.
    """
    deep = 1200                       # maxDepth is 1000
    return [
        ("expression nesting",
         "program p(output);\nbegin\n  writeln("
         + "(" * deep + "1" + ")" * deep + ")\nend.\n",
         "nesting is too deep: this compiler accepts 1000 levels", ()),
        ("statement nesting",
         "program p(output);\nbegin\n" + "begin\n" * deep
         + "end\n" * deep + "end.\n",
         "nesting is too deep: this compiler accepts 1000 levels", ()),
        ("type-denoter nesting",
         "program p(output);\ntype t = " + "array [1..2] of " * deep
         + "integer;\nbegin end.\n",
         "nesting is too deep: this compiler accepts 1000 levels", ()),
        # A flat operator chain, which is what the depth counter is bounded
        # against separately: it is one level for the parser and `deep` of
        # them for Sema and CodeGen, so the spine-building loops count their
        # own iterations toward the same limit.
        ("operator chain",
         "program p(output);\nvar x: integer;\nbegin\n  x := "
         + "+".join(["1"] * deep) + "\nend.\n",
         "nesting is too deep: this compiler accepts 1000 levels", ()),
        ("token buffer",
         "program p(output);\nvar x: integer;\nbegin\n"
         + "  x := 1;\n" * 80000 + "  x := 2\nend.\n",
         "too many tokens: this compiler accepts 300000", ()),
        # Distinct spellings, because the pool is what holds them and a name
        # written twice costs it nothing.
        ("string pool",
         "program p(output);\nvar\n"
         + "".join(f"  v{i:0>198d}: integer;\n" for i in range(6000))
         + "begin end.\n",
         "out of string space: this compiler keeps 1000000 characters", ()),
        ("identifier length",
         "program p(output);\nvar " + "a" * 300 + ": integer;\nbegin end.\n",
         "identifier is too long: this compiler keeps 255 characters", ()),
        ("string literal length",
         "program p(output);\nbegin\n  writeln('" + "x" * 300
         + "')\nend.\n",
         "string literal is too long: this compiler keeps 255 characters", ()),
        ("unterminated comment",
         "program p(output);\nbegin end.\n{" + "x" * 4000,
         "unterminated comment", ()),
        ("unterminated literal",
         "program p(output);\nbegin writeln('" + "x" * 100 + "\nend.\n",
         "unterminated string literal", ()),
        # 6.1.8's comments, which are recorded only under --format and
        # --dump-trivia and so are the one bound here that an ordinary
        # compilation cannot reach. Twenty thousand and one of the shortest
        # comment there is.
        ("comment table",
         "program p(output);\n" + "{}" * 20001 + "begin end.\n",
         "this source has more than 20000 comments, which is more than "
         "--format can keep in order",
         ("--format",)),
    ]


# --- mutation --------------------------------------------------------------

FRAGMENTS = [b"(", b")", b"[", b"]", b"^", b"'", b"{", b"}", b"(*", b"*)",
             b"..", b":=", b";", b".", b"begin", b"end", b"record", b"case",
             b"of", b"array", b"packed", b"file", b"set", b"999999999999",
             b"1e", b".5", b"0", b"@", b"$", b"\t", b"\0"]


def mutate(rng, data, pool):
    """One to three edits, deliberately few. A heavily mutated source is
    rejected in its first few tokens and never reaches Sema; the point of
    starting from a real program is to arrive somewhere deep with it."""
    for _ in range(rng.randint(1, 3)):
        n = len(data)
        if n == 0:
            return b"program p; begin end."
        i = rng.randrange(n)
        k = rng.randrange(7)
        if k == 0:                                        # flip a byte
            data = data[:i] + bytes([rng.randrange(256)]) + data[i + 1:]
        elif k == 1:                                      # delete a run
            data = data[:i] + data[min(n, i + rng.randint(1, 200)):]
        elif k == 2:                                      # splice in another
            o = rng.choice(pool)
            a = rng.randrange(len(o))
            data = data[:i] + o[a:a + rng.randint(1, 400)] + data[i:]
        elif k == 3:                                      # repeat a run
            j = min(n, i + rng.randint(1, 300))
            data = data[:j] + data[i:j] * rng.randint(1, 3) + data[j:]
        elif k == 4:                                      # truncate
            data = data[:i]
        elif k == 5:                                      # insert a fragment
            data = data[:i] + rng.choice(FRAGMENTS) + data[i:]
        else:                                             # insert noise
            data = (data[:i]
                    + bytes(rng.randrange(256) for _ in range(rng.randint(1, 40)))
                    + data[i:])
        if len(data) > 400000:
            data = data[:400000]
    return data


GOLDEN = "fuzz_bounds.err"

GOLDEN_HEADER = """\
# The messages tests/checks/fuzz.py's bounds family requires, one per line.
#
# It is a `.err` golden with no case beside it, and that is deliberate: two of
# these are reachable only by a source too big to commit -- 300 KB of
# semicolons for the token buffer, 1.2 MB of distinct identifiers for the
# string pool -- so fuzz.py generates the input and this file records what the
# compiler must say about it. What makes it a golden rather than a note is
# that diagnostic_coverage.py globs `tests/**/*.err`, so a message named here
# is a message named by a golden.
#
# Both directions are checked. fuzz.py fails if this file and its own table
# disagree, so neither can drift; regenerate with
#
#     python3 tests/checks/fuzz.py --write-golden
#
# Until ADR-0275 the first two lines below were *excluded* from
# diagnostic-coverage, as "capacity limits, not diagnostics about a program
# being compiled and no golden by design". Both carry a file, a line and a
# column, and the compiler writes them about a program it was handed. The
# exclusion was an argument standing in for a case.
"""


def read_golden(root):
    path = root / "tests" / "checks" / GOLDEN
    if not path.exists():
        return None
    return [ln for ln in path.read_text().splitlines()
            if ln.strip() and not ln.startswith("#")]


def write_golden(root, wants):
    path = root / "tests" / "checks" / GOLDEN
    path.write_text(GOLDEN_HEADER + "\n" + "\n".join(wants) + "\n")
    return path


def run_family(pascalc, work, inputs, jobs):
    """(name, bytes, expected-prefix-or-None) -> list of complaints."""
    def one(item):
        idx, (name, data, want, flags) = item
        src = work / f"m{idx}.pas"
        out = work / f"m{idx}.ll"
        src.write_bytes(data if isinstance(data, bytes) else data.encode())
        if want is None:
            why = survived(pascalc, src, out, flags)
            got = None
        else:
            got, why = message(pascalc, src, out, flags)
        keep = why is not None or (want is not None and
                                   (got is None or want not in got))
        if not keep:
            src.unlink(missing_ok=True)
            out.unlink(missing_ok=True)
            return None
        if why is not None:
            return name, f"{why}", src
        return name, f"said {got!r}, wanted {want!r}", src

    bad = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as ex:
        for r in ex.map(one, enumerate(inputs)):
            if r is not None:
                bad.append(r)
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root", nargs="?", default=None)
    ap.add_argument("--build", default=None)
    ap.add_argument("--long", type=int, default=None,
                    help="a campaign of N mutations instead of the fixed suite")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--keep", default=None,
                    help="a directory to leave failing inputs in")
    ap.add_argument("--write-golden", action="store_true",
                    help=f"rewrite tests/checks/{GOLDEN} from the bounds table")
    args = ap.parse_args()

    root = pathlib.Path(args.root or
                        pathlib.Path(__file__).resolve().parents[2]).resolve()
    build = pathlib.Path(args.build or root / "build").resolve()
    pascalc = build / "bin" / "pascalc"
    if not pascalc.exists():
        print(f"fuzz: no compiler at {pascalc} -- build first", file=sys.stderr)
        return SKIP

    wants = [w for _, _, w, _ in bounds()]
    if args.write_golden:
        print(f"fuzz: wrote {write_golden(root, wants)}")
        return 0
    have = read_golden(root)
    if have is None or have != wants:
        print(f"fuzz: tests/checks/{GOLDEN} does not list what the bounds "
              f"table expects", file=sys.stderr)
        for a, b in zip(have or [], wants):
            if a != b:
                print(f"    golden: {a!r}\n    table:  {b!r}", file=sys.stderr)
        if have is not None and len(have) != len(wants):
            print(f"    {len(have)} lines in the golden, {len(wants)} in the "
                  f"table", file=sys.stderr)
        print("\nRegenerate with --write-golden and say why in the commit "
              "message: diagnostic-coverage reads this file as the golden "
              "that names these messages.", file=sys.stderr)
        return 1

    pool = seeds(root)
    if len(pool) < 100:
        print(f"fuzz: only {len(pool)} seeds found -- the corpus cannot be "
              f"that small", file=sys.stderr)
        return 1

    rng = random.Random(args.seed)
    mutants = args.long if args.long is not None else 1500

    # Every prefix of one real source, at one-byte steps up to a length no
    # corpus source exceeds by much, then coarser. Exhaustive where it is
    # cheap and thinning where it is not.
    control = (root / "tests" / "control.pas").read_bytes()
    trunc = [("truncation", control[:i], None, ())
             for i in range(0, len(control) + 1)]
    torture = (root / "selfhost" / "torture.pas").read_bytes()
    trunc += [("truncation", torture[:i], None, ())
              for i in range(0, len(torture) + 1, 7)]

    fixed = list(bounds())
    muts = [("mutation", mutate(rng, rng.choice(pool), pool), None, ())
            for _ in range(mutants)]

    jobs = os.cpu_count() or 4
    keep = pathlib.Path(args.keep) if args.keep else None
    if keep:
        keep.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        bad = []
        for label, family in (("truncation", trunc), ("bounds", fixed),
                              ("mutation", muts)):
            found = run_family(pascalc, work, family, jobs)
            print(f"fuzz: {len(family)} {label} inputs, "
                  f"{len(found)} unsurvived")
            bad += found
        if bad:
            for name, why, src in bad[:20]:
                dest = src
                if keep:
                    dest = keep / src.name
                    dest.write_bytes(src.read_bytes())
                print(f"    {name}: {why}\n      {dest}", file=sys.stderr)
            if not keep:
                print("\nRe-run with --keep DIR to save the inputs; the "
                      "temporary directory above is already gone.",
                      file=sys.stderr)
            return 1

    print(f"fuzz: {len(trunc) + len(fixed) + len(muts)} inputs, "
          f"every one refused as a diagnostic or accepted -- "
          f"no signal, no trap, none unfinished")
    return 0


if __name__ == "__main__":
    sys.exit(main())
