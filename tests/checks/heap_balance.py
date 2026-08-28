#!/usr/bin/env python3
"""Every `new` a corpus program makes, against every `dispose` it gives back.

This is the oracle none of the others can be. Every gate in this tree reads
what a program *prints* -- a golden, a dump, a diagnostic, a second front end's
answer -- and a leak prints nothing. Two records turned on exactly that:
ADR-0181, where a handle inside an unowned heap record was never released and
`ulimit -n 64` found it at the 62nd descriptor; and ADR-0182, whose abandoned
chain was measured as 5.8 MB against 58 MB. Both measurements were taken by
hand, once, and by nothing since.

The runtime counts (ADR-0183): `pas_new` and `pas_dispose` keep a tally and
write it at exit to the file `$PASHEAP_BALANCE` names. This runs the heap-using
part of the corpus with that variable set and compares the balance against
`tests/checks/heap_balance.txt`.

**A nonzero balance is not an error.** No standard obliges a program to dispose
what it created, and plenty here deliberately do not -- a program that ends is
a program whose heap the operating system reclaims. What this catalogue holds
is what each program *does*, and it fails in **both** directions, which is
`verify/`'s KNOWN_GAP rule (ADR-0013) applied once more: a program that starts
leaking is as loud as one that stops. Fix the catalogue in the change that
changed the program, and say in the commit message why the number moved.

The sweep is the heap-using corpus and not all of it: a program that never
calls `new` has a balance of zero for no interesting reason, and running six
hundred of those would cost two minutes to learn nothing. A case counts as
heap-using when its own source, or any component it lists, calls `new`. That
filter is itself checked -- a catalogued case the filter stops selecting is a
failure, so the filter cannot quietly shrink.
"""

import argparse
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
CATALOGUE = ROOT / "tests" / "checks" / "heap_balance.txt"

# `new` as a call, not as a word in a comment. Neither standard admits a space
# between an identifier and its `(`, but the lexer does, so this does too.
NEW_CALL = re.compile(r"\bnew\s*\(", re.IGNORECASE)


def components_of(source):
    """The other program-components, as run_test.sh reads them."""
    sidecar = source.with_suffix(".components")
    if not sidecar.exists():
        return []
    out = []
    for line in sidecar.read_text().splitlines():
        line = line.strip()
        if line:
            out.append((source.parent / line.split()[0]).resolve())
    return out


def uses_heap(source):
    if NEW_CALL.search(source.read_text(errors="replace")):
        return True
    for comp in components_of(source):
        if comp.exists() and NEW_CALL.search(comp.read_text(errors="replace")):
            return True
    return False


def cases():
    """Every corpus case that runs -- a `.out` and no `.err` -- using the heap."""
    found = []
    for directory in ("tests", "tests/extended", "tests/dialect"):
        for source in sorted((ROOT / directory).glob("*.pas")):
            if not source.with_suffix(".out").exists():
                continue
            if source.with_suffix(".err").exists():
                continue
            if uses_heap(source):
                found.append(source)
    return found


def balance(source, pascalcc, work):
    """Run one case through run_test.sh and read what the runtime wrote.

    Through the harness rather than around it: a case may carry components, a
    fixed epoch, standard input or an optimisation level, and a second reader
    of those sidecars would be a second thing to drift (ADR-0034's lesson about
    two harnesses meaning two things about one file).
    """
    name = source.stem
    out = work / (name + ".bal")
    env = dict(os.environ)
    env["PASHEAP_BALANCE"] = str(out)
    done = subprocess.run(
        [str(ROOT / "tests" / "run_test.sh"), pascalcc, str(source)],
        cwd=ROOT, env=env, capture_output=True, text=True)
    if done.returncode != 0:
        return None, done.stderr.strip().splitlines()[:3]
    if not out.exists():
        # The program ran and wrote nothing: it never called `new`, so the
        # atexit hook was never armed. A filtered case that turns out not to
        # allocate is a balance of zero, not a failure.
        return 0, None
    live = 0
    for line in out.read_text().splitlines():
        field = dict(p.split("=", 1) for p in line.split())
        live += int(field["live"])
    return live, None


def read_catalogue():
    known = {}
    if not CATALOGUE.exists():
        return known
    for line in CATALOGUE.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        name, live = line.split()
        known[name] = int(live)
    return known


def write_catalogue(measured):
    with CATALOGUE.open("w") as f:
        f.write(__doc__.split("\n\n")[0] and "")
        f.write(
            "# The heap balance of every corpus case that calls `new`:\n"
            "# how many variables it created and never gave back (ADR-0183).\n"
            "#\n"
            "# A nonzero number is not a defect. No standard obliges a program\n"
            "# to dispose what it created, and a program that is about to end\n"
            "# has an operating system to do it. What this file is for is that\n"
            "# the number cannot move without someone saying why: it fails in\n"
            "# both directions, so a program that starts leaking is as loud as\n"
            "# one that stops.\n"
            "#\n"
            "# Regenerate with:  python3 tests/checks/heap_balance.py --write\n"
            "#                     --pascalcc tools/pascalcc\n")
        for name in sorted(measured):
            f.write("%s %d\n" % (name, measured[name]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pascalcc", default="tools/pascalcc")
    ap.add_argument("--write", action="store_true",
                    help="record what the corpus does now")
    args = ap.parse_args()

    selected = cases()
    if not selected:
        print("heap-balance: no case calls `new` -- the filter reached "
              "nothing, which a corpus this size cannot mean")
        return 1

    measured = {}
    problems = []
    broken = set()
    for source in selected:
        live, err = balance(source, args.pascalcc, WORK)
        if live is None:
            # Reported once. The comparison below would otherwise say this
            # case is catalogued and not swept, which is true and is not the
            # thing that went wrong.
            broken.add(source.stem)
            problems.append("%s: did not run -- %s"
                            % (source.stem, " / ".join(err or [])))
            continue
        measured[source.stem] = live

    if args.write:
        write_catalogue(measured)
        print("heap-balance: %d cases recorded" % len(measured))
        return 0

    known = read_catalogue()
    for name in sorted(set(known) | set(measured)):
        if name in broken:
            continue
        if name not in measured:
            problems.append(
                "%s: catalogued and not swept -- the case went away, or the "
                "filter stopped selecting it" % name)
        elif name not in known:
            problems.append(
                "%s: swept and not catalogued, balance %d -- a new case that "
                "uses the heap needs a line" % (name, measured[name]))
        elif known[name] != measured[name]:
            problems.append(
                "%s: balance was %d, is now %d -- %d variable(s) %s"
                % (name, known[name], measured[name],
                   abs(measured[name] - known[name]),
                   "no longer given back"
                   if measured[name] > known[name] else "now given back"))

    if problems:
        for p in problems:
            print("heap-balance: " + p)
        print()
        print("A balance that moved is a change in what a program gives back."
              "\nIf the change is intended, regenerate the catalogue and say "
              "in the\ncommit message why the number moved. See doc/sop.md.")
        return 1

    total = sum(measured.values())
    print("heap-balance: %d heap-using cases, %d variable(s) outstanding "
          "between them, all as catalogued" % (len(measured), total))
    return 0


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as tmp:
        WORK = Path(tmp)
        sys.exit(main())
