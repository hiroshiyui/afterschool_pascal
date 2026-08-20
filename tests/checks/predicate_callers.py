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

"""A type `Assignable` refuses is refused by every caller of `Assignable`.

`Assignable` is not a rule about assignment. It is *the* compatibility
predicate, and eighteen routines ask it -- assignment, the relational
operators, an actual parameter, a set member, a case selector, a `for`
statement's bounds, an array index, a structured value's component. ADR-0058
wrote the sentence this gate exists for:

    A permission granted in a shared predicate leaks to every caller.

That sentence has now cost twice. AP §6.4.5 made two slices compatible so one
`array of` parameter accepts either; the relational operators ask compatibility
too, so `a[1..2] = a[3..4]` reached CodeGen and emitted invalid IR (ADR-0139).
Assignment was the *second* caller of the same permission, found four commits
later, and it was worse: `p := r` between two slice formals compared
`tb^.kind = fb^.kind`, said yes for any two slices whatever their component
types, and copied one array's contents over another's -- a silent
out-of-bounds write at both -O0 and -O2, exit 0 (ADR-0143).

Both times the fix was a probe over the positions someone thought of. This is
the sweep over the positions the *source* contains.

## What it checks

`Assignable` opens with a run of arms that answer `false` for a type whatever
it is being compared with:

    else if IsFile(toT) or IsFile(fromT) then Assignable := false

Each names a type that is **not a value** -- ISO 7185 §6.8.2.2 gives a file no
assignment and §6.7.2.5 no relational operators; a procedural parameter is not
a value either; and AP §6.4.9 says the same of a slice. Those arms are read
from the source, so the type list is derived rather than remembered.

The claim is then one property, asked of the built compiler for every
(caller, type) pair:

    a program that puts such a type in that position is **refused**.

Not "refused with these words" -- the messages are `diagnostic-coverage`'s
business and the `.err` goldens'. A verdict cannot drift into agreeing with
whoever wrote it, which is what a golden here would do.

## What it does not check

It does not judge whether the refusal happens *at* the call site. A guard
placed ahead of the predicate refuses the same program and passes this gate --
which is ADR-0143's second defect, and `doc/sop.md` §7 carries it. What this
answers is the question that was never asked: **has every caller been
considered at all?** If ADR-0139 had had to answer for eighteen positions, the
assignment hole would have been on the list that day.

It fails in four directions:

  * a position that starts accepting -- the leak itself;
  * an exception in the catalogue that starts refusing -- the entry is
    describing a compiler that no longer exists (verify/'s KNOWN_GAP rule);
  * a routine that calls `Assignable` and is not in POSITIONS, or one whose
    call-site count moved -- a new caller with no answer;
  * a type refused unconditionally by `Assignable` with no wrapper here -- a
    new type-rule with no sweep behind it. That is the forward-looking half,
    and the one the next extension of `Assignable` will meet.
"""

import argparse
import pathlib
import re
import subprocess
import sys
import tempfile

SOURCE = "selfhost/compiler.pas"
CATALOGUE = "predicate_callers.txt"

PREDICATE = "Assignable"

# The arms at the top of `Assignable` that answer false for a type outright:
#
#     else if IsFile(toT) or IsFile(fromT) then
#       Assignable := false
#
# Read from the source so that a fourth one cannot be added without this gate
# demanding a wrapper for it.
REFUSES = re.compile(
    r"else\s+if\s+Is([A-Za-z0-9_]+)\(toT\)\s+or\s+Is\1\(fromT\)\s+then\s*"
    r"Assignable\s*:=\s*false", re.IGNORECASE)

# How `u` and `v` are given the type under test, and how the program's own
# block supplies actuals for them. Every wrapper puts them in the same place --
# two names in scope of one procedure `q` -- so that one snippet serves all
# three. The key is the name in `IsXxx`, lowercased.
WRAPPERS = {
    "file": {
        "formals": "var u, v: text",
        "extra": "var f1, f2: text;\n",
        "call": "q(f1, f2)",
    },
    "proctype": {
        "formals": "procedure u(x: integer); procedure v(x: integer)",
        "extra": "procedure dummy(x: integer); begin x := x end;\n",
        "call": "q(dummy, dummy)",
    },
    "slice": {
        "formals": "var u, v: array of integer",
        "extra": "",
        "call": "q(arr, arr)",
    },
}

# Everything a snippet may name, declared once so that a snippet is the one
# thing that differs between probes.
PREAMBLE = """program probe(output);
type
  sel = 1..2;
  rec = record k: integer; case c: sel of 1: (a: integer); 2: (b: integer) end;
  arrt = array [1..3] of integer;
  chart = array [1..3] of char;
  packt = packed array [1..3] of char;
  sett = set of 0..9;
  sch(d: integer) = record m: array [1..d] of integer end;
  schp = ^sch;
var
  i: integer;
  r: rec;
  arr: arrt;
  ch: chart;
  pk: packt;
  st: sett;
  nf: file of integer;
  df: file [1..10] of integer;
  ps: schp;
"""

# One entry per *position* -- a place in the grammar that reaches a call of
# `Assignable`. `routine` is the routine in compiler.pas the call sits in, and
# `sites` is how many calls that routine makes, so a routine that grows one is
# a failure asking for a position rather than a silent addition.
#
# `decl` snippets go in q's own declaration part; the rest are statements in
# q's body.
POSITIONS = [
    # (id, routine, sites, kind, snippet)
    ("schema-discriminant", "ProduceFromSchema", 1, "decl",
     "var x: sch(u);"),
    ("initial-state", "CheckInitialState", 1, "decl",
     "var x: integer value u;"),
    ("actual-parameter", "CheckArguments", 1, "stmt",
     "takes(u)"),
    ("set-member", "CheckSetMember", 2, "stmt",
     "st := [u]"),
    ("set-value", "CheckSetValue", 1, "stmt",
     "st := sett[u]"),
    ("arithmetic-operand", "CheckBinary", 12, "stmt",
     "i := u + 1"),
    ("set-membership", "CheckBinary", 12, "stmt",
     "if u in st then i := 1"),
    ("relational-operand", "CheckBinary", 12, "stmt",
     "if u = v then i := 1"),
    ("record-value-field", "CheckComponentValue", 1, "stmt",
     "r := rec[k: u; case c: 1 of [a: 0]]"),
    ("array-value-selector", "CheckArrayValue", 1, "stmt",
     "arr := arrt[u: 1; otherwise 0]"),
    ("variant-value-tag", "CheckVariantPartValue", 1, "stmt",
     "r := rec[k: 0; case c: u of [a: 0]]"),
    ("array-index", "CheckExpr", 1, "stmt",
     "i := arr[u]"),
    ("write-argument", "CheckWrite", 1, "stmt",
     "write(nf, u)"),
    ("read-argument", "CheckRead", 1, "stmt",
     "read(nf, u)"),
    ("new-tuple", "CheckNewTuple", 1, "stmt",
     "new(ps, u)"),
    ("unpack-index", "CheckStdProc", 2, "stmt",
     "unpack(pk, ch, u)"),
    ("seek-position", "CheckStdProc", 2, "stmt",
     "seekread(df, u)"),
    ("case-selector", "CheckCase", 1, "stmt",
     "case u of 1: i := 1 end"),
    ("assignment", "CheckStmt", 5, "stmt",
     "u := v"),
    ("for-in-control", "CheckStmt", 5, "stmt",
     "for u in st do i := 1"),
    ("for-bounds", "CheckStmt", 5, "stmt",
     "for w := u to v do i := 1"),
]


def program(wrapper, kind, snippet):
    """The whole probe: preamble, q with the snippet in it, and a valid block."""
    decls = snippet if kind == "decl" else ""
    body = snippet if kind == "stmt" else "i := 1"
    return (PREAMBLE + wrapper["extra"] +
            "procedure takes(z: integer); begin z := z end;\n" +
            f"procedure q({wrapper['formals']});\n"
            f"var w: integer;\n{decls}\nbegin\n"
            f"  {body}\nend;\n"
            "begin\n"
            f"  {wrapper['call']}\n"
            "end.\n")


def refused_types(text):
    """The types `Assignable` answers false for outright, from its own source."""
    return [m.group(1).lower() for m in REFUSES.finditer(re.sub(r"\s+", " ",
                                                                text))]


def callers(text):
    """routine -> number of calls of `Assignable` it makes."""
    hdr = re.compile(r"^\s*(?:function|procedure)\s+([A-Za-z0-9_]+)",
                     re.IGNORECASE)
    call = re.compile(r"(?<![A-Za-z0-9_])" + PREDICATE +
                      r"(?![A-Za-z0-9_])\s*\(", re.IGNORECASE)
    counts, cur = {}, "?"
    for line in strip(text).splitlines():
        m = hdr.match(line)
        if m:
            cur = m.group(1)
        if cur != PREDICATE and call.search(line):
            counts[cur] = counts.get(cur, 0) + len(call.findall(line))
    return counts


def strip(text):
    """Blank out { } comments and ' ' literals, keeping every newline.

    `Assignable` is named in a dozen comments explaining what it decides, and
    a comment is not a call site.
    """
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == "{":
            j = text.find("}", i)
            j = n - 1 if j < 0 else j
            out.append(re.sub(r"[^\n]", " ", text[i:j + 1]))
            i = j + 1
        elif c == "'":
            j = i + 1
            while j < n and text[j] != "'":
                j += 1
            out.append(re.sub(r"[^\n]", " ", text[i:min(j + 1, n)]))
            i = j + 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def catalogue(path):
    """The argued acceptances: `position type` per line, `#` a comment."""
    listed = {}
    for n, line in enumerate(path.read_text().splitlines(), 1):
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split()
        if len(parts) != 2:
            print(f"predicate-callers: {path.name}:{n}: expected "
                  f"`position type`, found {line!r}", file=sys.stderr)
            sys.exit(1)
        listed[(parts[0], parts[1])] = n
    return listed


def accepts(pascalc, src, work):
    """Does the compiler accept this program? The verdict, and nothing else."""
    p = work / "probe.pas"
    p.write_text(src)
    r = subprocess.run([pascalc, "--std=afterschool", str(p),
                        "-o", str(work / "probe.ll")],
                       capture_output=True, text=True)
    return r.returncode == 0, (r.stdout + r.stderr).strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pascalc", default="build/bin/pascalc")
    ap.add_argument("--show", action="store_true",
                    help="print the verdict and message for every pair")
    args = ap.parse_args()

    root = pathlib.Path(__file__).resolve().parents[2]
    text = (root / SOURCE).read_text()
    listed = catalogue(pathlib.Path(__file__).with_name(CATALOGUE))

    bad = []

    # --- the type list, read from the predicate's own refusal arms ---
    types = refused_types(text)
    if not types:
        print(f"predicate-callers: no unconditional refusal arm in "
              f"{PREDICATE}; the pattern this reads for must have changed",
              file=sys.stderr)
        return 1
    for t in types:
        if t not in WRAPPERS:
            bad.append(f"{PREDICATE} refuses `{t}` outright and this gate has "
                       f"no wrapper for it -- a new type-rule with no sweep "
                       f"behind it. Add one to WRAPPERS and answer every "
                       f"position")
    for t in WRAPPERS:
        if t not in types:
            bad.append(f"this gate carries a wrapper for `{t}` and "
                       f"{PREDICATE} no longer refuses it outright -- either "
                       f"the arm went, or it moved behind a condition")

    # --- the caller census, so a new call site cannot arrive unanswered ---
    counts = callers(text)
    recorded = {}
    for _, routine, sites, _, _ in POSITIONS:
        recorded[routine] = sites
    for routine, n in sorted(counts.items()):
        if routine not in recorded:
            bad.append(f"{routine} calls {PREDICATE} and no position here "
                       f"reaches it -- a caller with no answer")
        elif recorded[routine] != n:
            bad.append(f"{routine} calls {PREDICATE} {n} times and this gate "
                       f"records {recorded[routine]} -- give the new call "
                       f"site a position, or correct the count")
    for routine in sorted(recorded):
        if routine not in counts:
            bad.append(f"this gate has a position in {routine} and it no "
                       f"longer calls {PREDICATE}")

    if bad:
        for b in bad:
            print(f"predicate-callers: {b}", file=sys.stderr)
        return 1

    # --- the property, asked of the built compiler ---
    pairs, swept = 0, set()
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        for pos, _, _, kind, snippet in POSITIONS:
            for t in types:
                pairs += 1
                ok, msg = accepts(args.pascalc,
                                  program(WRAPPERS[t], kind, snippet), work)
                key = (pos, t)
                swept.add(key)
                if args.show:
                    first = msg.splitlines()[0] if msg else ""
                    print(f"  {'accepted' if ok else 'refused '}  "
                          f"{pos:<22} {t:<9} {first}")
                if ok and key not in listed:
                    bad.append(f"a {t} is **accepted** in {pos} -- "
                               f"{PREDICATE} refuses it and this caller does "
                               f"not. Either the caller asks a different "
                               f"question, or the permission has leaked")
                    if msg:
                        bad.append(f"  the compiler said: {msg.splitlines()[0]}")
                elif not ok and key in listed:
                    bad.append(f"{CATALOGUE}:{listed[key]} argues that a {t} "
                               f"is accepted in {pos}, and it is refused -- "
                               f"the entry describes a compiler that no "
                               f"longer exists; strike it")

    for (pos, t), n in sorted(listed.items(), key=lambda kv: kv[1]):
        if (pos, t) not in swept:
            bad.append(f"{CATALOGUE}:{n} names {pos}/{t}, which is not a pair "
                       f"this gate sweeps -- a position or a type that has "
                       f"gone")

    if bad:
        for b in bad:
            print(f"predicate-callers: {b}", file=sys.stderr)
        return 1

    print(f"predicate-callers: {len(POSITIONS)} positions x {len(types)} "
          f"types = {pairs} pairs; every caller of {PREDICATE} refuses what "
          f"{PREDICATE} refuses")
    return 0


if __name__ == "__main__":
    sys.exit(main())
