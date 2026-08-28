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

"""Every global this compiler emits by name is a foreign name it refuses.

ADR-0121 lets a program name a linker symbol: `external 'cbrt'`. LLVM's
assembler refuses a second declaration of any global, however identical the
two are -- so a program naming one the compiler already emits is answered with
an error about a file nobody wrote. `ReservedForeignName` in
selfhost/compiler.pas turns that into a diagnostic, and it does so from a
short list of bare names, which is a second copy of what the emitter writes.

A second copy is exactly the thing that drifts, so this compares them, and it
fails in **both** directions:

  * a name the emitter writes that the predicate would let through -- the
    collision is back, and the next person to add `declare double @cbrt(double)`
    would break a program that had been compiling;
  * a name the predicate reserves that the emitter no longer writes -- the
    program is being refused something it could have had, which is the same
    rule verify/'s KNOWN_GAP has and doc/sop.md applies to five catalogues.

What it reads are the `declare` and `define` **string literals** in the
compiler source, which is where every fixed global name is written out. Names
the compiler *composes* -- the counters, and 6.13's linkage names -- are not
literals and are covered structurally instead: every one of them either holds
a dot or is a letter and digits, which is what the predicate tests for. That
half cannot drift without the naming scheme itself changing.
"""

import argparse
import re
import subprocess
import tempfile
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import components                                    # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
# The predicate is in ApTypes and the emitter's literals are in the program
# (ADR-0233), and this gate's question is about the compiler rather than about
# a file: it reads the refusal out of one component and the names it has to
# cover out of another. Nothing here is line-addressed, so the three are one
# text.
SOURCE = "selfhost/" + "/".join(components.COMPONENTS)

# A Pascal string literal on one line, and the LLVM globals inside it.
LITERAL = re.compile(r"'((?:[^']|'')*)'")
GLOBAL = re.compile(r"@([A-Za-z_][A-Za-z0-9_.]*)")

# The predicate's own words, read back out of the source rather than repeated
# here -- a third copy would be a third thing to drift.
# The *definition*, not the heading: 6.11.1 puts an exported routine's heading
# in the module-heading and leaves the block repeating the name alone, so
# `function ReservedForeignName` now matches twice and the first match is an
# interface entry with no body. Requiring a `begin` picks the body out.
PREDICATE = re.compile(
    r"function ReservedForeignName\b[^;]*;\n(?:var[^\n]*\n)*begin\n.*?\nend;",
    re.DOTALL)
POOL_IS = re.compile(r"PoolIs\(at, len, '([^']*)'\)")
POOL_STARTS = re.compile(r"PoolStarts\(at, len, '([^']*)'\)")

# What the predicate answers without consulting a list. Kept in step with the
# comment above it; a change to the naming scheme changes both.
COMPOSED = re.compile(r"(?:[ps][0-9]+|frame[0-9]+)\Z")

# The three shapes a fixed global name is written in. `declare` and `define`
# were the whole of it until ADR-0144, which is how `@frame1` -- the program's
# level-0 activation record, emitted as an `internal global` before the first
# function that indexes one -- stayed outside what this gate could compare
# while colliding with a foreign name a program was entitled to bind.
EMITTING = ("declare ", "define ", "internal global", " global ", " alias ")


def emitted_names(text):
    """Every fixed global name the emitter writes, from its own literals."""
    names = set()
    for line in text.splitlines():
        for lit in LITERAL.findall(line):
            if not any(k in lit for k in EMITTING):
                continue
            names.update(GLOBAL.findall(lit))
    return names


def predicate_words(text):
    body = PREDICATE.search(text)
    if body is None:
        raise SystemExit(
            "foreign-reserved: ReservedForeignName is not in "
            f"any of {', '.join(components.COMPONENTS)}.\n"
            f"If it was renamed, update this check -- a "
            "check that cannot find what it is about must fail loudly, not "
            "pass.")
    body = body.group(0)
    exact = {w.rstrip() for w in POOL_IS.findall(body)}
    prefixes = {w.rstrip() for w in POOL_STARTS.findall(body)}
    if not exact or not prefixes:
        raise SystemExit(
            "foreign-reserved: ReservedForeignName names no words this check "
            "can read. Update the check, or the predicate.")
    return exact, prefixes


def covered(name, exact, prefixes):
    return ("." in name
            or COMPOSED.match(name) is not None
            or any(name.startswith(p) for p in prefixes)
            or name in exact)


# A program exercising the globals a compilation actually writes: an activation
# record, a string constant, the output file's alias, the runtime's arena
# pointer, a nested procedure's frame, a set and a real.
GROUND_TRUTH_PROGRAM = """program probe(output);
type col = (red, green); st = set of col;
var s: st; r: real; a: array [1..3] of integer; i: integer;
procedure inner(n: integer);
begin
  if n > 0 then inner(n - 1)
end;
begin
  s := [red]; r := 1.5; i := 1; a[i] := 2;
  inner(2);
  writeln('probe ', r:3:1, ' ', a[1]:1, ' ', (red in s))
end.
"""


def written_globals(pascalcc, workdir):
    """Every `@name` the compiler actually writes, read from its own output.

    Harvesting the emitter's *string literals* cannot see a composed name:
    `@frame1` is `AppendLit('frame')` followed by a counter, so no literal in
    the source contains it and the regex over literals never had a chance
    (ADR-0144). The IR the compiler writes does contain it, and that is ground
    truth rather than a second copy of anything.
    """
    src = workdir / "gt.pas"
    src.write_text(GROUND_TRUTH_PROGRAM)
    out = workdir / "gt.ll"
    done = subprocess.run(
        [pascalcc, "-S", str(src), "-o", str(out)],
        capture_output=True, text=True)
    if done.returncode != 0:
        raise SystemExit("foreign-reserved: the ground-truth probe did not "
                         f"compile:\n{done.stdout}{done.stderr}")
    names = set()
    for line in out.read_text().splitlines():
        m = re.match(r"@([A-Za-z_][A-Za-z0-9_.$]*)\s*=", line)
        if m:
            names.add(m.group(1))
    return names


def refuses(pascalcc, name, workdir):
    """Ask the compiler itself whether it refuses this foreign name.

    The three helpers above read the *source* of the predicate, which makes
    them a second copy of it -- and a second copy is what this gate exists to
    police everywhere else. Adding `frame[0-9]+` to COMPOSED without adding it
    to the compiler left the gate green (ADR-0144), because both halves of the
    comparison were this file.

    So the answer that decides is the compiler's. Every emitted name is offered
    to it as a foreign name and must be refused. Nothing here can drift,
    because nothing here is a copy of anything.
    """
    src = workdir / "p.pas"
    src.write_text(
        "program p(output);\n"
        f"function probe(x: integer): integer; external '{name}';\n"
        "begin writeln(probe(1)) end.\n")
    done = subprocess.run(
        [pascalcc, "-S", str(src),
         "-o", str(workdir / "p.ll")],
        capture_output=True, text=True)
    return done.returncode != 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pascalcc", help="ask the compiler, not only its source")
    args = ap.parse_args()

    text = components.text(ROOT)
    emitted = emitted_names(text)
    exact, prefixes = predicate_words(text)

    leaked = sorted(n for n in emitted if not covered(n, exact, prefixes))
    stale = sorted(w for w in exact if w not in emitted)

    unrefused = []
    written = set()
    if args.pascalcc:
        # A name with a `.` or a `$` in it is not an identifier and cannot be
        # written as a foreign name at all, so there is nothing to ask.
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            written = written_globals(args.pascalcc, work)
            for n in sorted(emitted | written):
                if "." in n or "$" in n:
                    continue
                if not refuses(args.pascalcc, n, work):
                    unrefused.append(n)
    for n in unrefused:
        print(f"foreign-reserved: the emitter writes @{n} and the compiler "
              "ACCEPTS it as a foreign name -- LLVM will refuse the module")

    for n in leaked:
        print(f"foreign-reserved: the emitter writes @{n} and "
              "ReservedForeignName would let a program declare it")
    for w in stale:
        print(f"foreign-reserved: ReservedForeignName reserves '{w}' and the "
              "emitter no longer writes it")

    if leaked or stale or unrefused:
        print()
        print("ADR-0121: a foreign name that is also one this compiler emits")
        print("makes LLVM refuse the module, with a message about a file")
        print("nobody wrote. The predicate is what turns that into a")
        print("diagnostic, and it is a second copy of this list -- so add the")
        print("new name to it, or stop reserving the one that went away.")
        return 1

    if args.pascalcc:
        print(f"foreign-reserved: {len(emitted)} names from the emitter's "
              f"literals and {len(written)} from the IR it wrote, "
              "each offered back to the compiler and refused")
    else:
        print(f"foreign-reserved: {len(emitted)} emitted names, "
              f"{len(exact)} reserved by name and "
              f"{len(prefixes)} by prefix -- all accounted for")
    return 0


if __name__ == "__main__":
    sys.exit(main())
