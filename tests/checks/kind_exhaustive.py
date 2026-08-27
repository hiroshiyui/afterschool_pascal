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

"""Every case-statement over an enumeration names every constant, or argues.

A Pascal case-statement stops the program when no label matches (ADR-0018), so
a constant left off one of these lists is a **compiler crash** on the first
program that reaches it -- not a wrong answer some golden could hold. That is
why no other gate here can see it: a missing arm is not a statement, so
line-coverage does not count it, and procedure-coverage asks only whether the
procedure was entered. difftest cannot report it either, because src/'s
counterparts are C++ `switch`es with a `default`, so the Pascal crashes where
the C++ answers and there is no disagreement to compare.

It has happened twice, both in `StaticThroughout`. It listed fifteen of sixteen
type kinds and omitted `tyString`, and every schema type containing a
variable-string stopped the compiler until that was found. ADR-0123 then added
`tyOptional` and the same routine crashed again, with all 578 cases, difftest,
irtest, verify, llc and the BSI suite green.

ADR-0124 wrote this check for **one** enumeration, `typeKind`, and `doc/sop.md`
§7 has carried the rest as a known gap ever since: "the parser and both walkers
enumerate the node kinds in long label lists, and this compiler rejects a
duplicate label at build time, which is what caught two of them during
ADR-0123. That is an accident of how those lists are written and not a check."
This is the check, over all twelve.

## What it reads

**Nothing.** Every fact comes from `pascalc --dump-dispatch`, which compiles
the source and reports what it found: the declared enumerations and their
sizes, every case-statement over one, every if-chain that dispatches on a tag,
and the constants each names and misses (ADR-0229, ADR-0230).

This module parsed Pascal with regular expressions until then, and could not
know what the compiler knows for nothing -- which types are enumerations, how
many constants each has, what a selector's type is. It recognised an
enumeration constant by a *naming convention* (a lowercase tag then a capital)
and a routine by a header regex. The two readers were run side by side before
the old one was deleted: they agreed on all 60 case sites, every count and
every missing constant, and the compiler found three if-chains the regex missed
on enumerations it was already looking at.

A case-statement with an `otherwise` is total by construction (§6.9.3.5) and is
required to name nothing. A **variant part** (`case kind: nodeKind of`) is not
a case-statement and never reaches the dump -- §6.4.3.3 requires its labels to
be exactly the tag-type's values and this compiler already enforces that
(ADR-0096), which is a stronger check than this one.

## The catalogue

24 of the 56 case-statements here name a subset on purpose -- `EmitSetBinary`
is entered only for operands Sema has already established are sets, and
`ParseNameList` has five callers passing five contexts. Each is one line of
`partial_cases.txt` keyed by `routine:enumeration:n` -- the n-th such case in
that routine -- recording **how many** constants it names of how many.

The count is the part that pays. When a constant is added to an enumeration,
every partial case over it changes from `17 of 19` to `17 of 20` and fails,
which is exactly the moment `tyString` and `tyOptional` needed a reader and did
not get one. An exhaustive case needs no entry and is simply required to stay
exhaustive.

It fails in five directions:

  * an exhaustive case that stops being exhaustive;
  * a partial case with no entry;
  * an entry whose case is now exhaustive, or has gone -- the entry describes a
    compiler that no longer exists, which is verify/'s KNOWN_GAP rule;
  * an entry whose numerator or denominator moved;
  * a constant named by no case-statement at all -- it was removed from the
    type and left in the enumeration, or added and never used.

What it does **not** do is judge whether an arm is right, or whether a subset
is the right subset. `tyOptional: StaticThroughout := true` would satisfy this
and be wrong. The claim is only that every constant was considered somewhere,
which is what turns a crash into a review.

## The other half: dispatch written as an if-chain

Not every dispatch on a tag is a case-statement. `EmitString` is thirteen arms
of `if e^.kind = nkBinary ... else if e^.kind = nkCall ...`, because its arms
test a node's kind *and* its type in one condition and a case-statement cannot
do that. Twenty-four routines over `nodeKind` alone are written that way, and
until this section none of them was read by anything: ADR-0124 and ADR-0145
both say "case-statement", and mean it.

ADR-0220 is what that cost. `EmitString`'s arm for a literal is keyed on the
node's kind, a constant reaches the code generator as a *designator*, and the
value fell through to an arm that read four bytes of read-only data as a
length. The guard was one node kind too narrow, in the one chain that
dispatches on two axes at once.

A chain is recognised by the compiler, and selected here by the **field it
reads**: `TAG_FIELD` below is `kind`, so `e^.kind = nkVar` is a value asked for
its own kind and `t = tkSemi` is a lookahead asking whether a token happens to
be a semicolon. ADR-0221 chose that scope by matching the text `^.kind` and so
selected it by accident; ADR-0230 keeps the scope and states it. The compiler
reports every chain it finds -- 70 of them, over seven enumerations -- and this
holds the 42 that read a tag to account. The other 28 are visible in the dump
without a catalogue entry being demanded for a parser ladder.

**A trailing bare `else` does not excuse a chain, and that is the difference
from `otherwise`.** §6.9.3.5 makes an `otherwise` total by construction and the
author wrote it as the catch-all for a value-dispatch; a bare `else` at the end
of a tag chain is simply where a kind nobody considered lands, silently. So the
two halves of this gate protect against opposite failures: a constant left off
a case-statement is a **crash** (ADR-0018), and a constant left off a chain is
a **wrong answer**, which is the harder of the two to find and the one no
golden reports.

Entries take a third form, `routine:enum:n chains N of M`, counted separately
from the case-statements in the same routine so the two cannot collide. The
mechanism is the one above and the whole point: adding a node kind moves M from
63 to 64 on all twenty-four, so each is a question somebody has to answer.
"""

import os
import pathlib
import subprocess
import re
import sys

SOURCE = "selfhost/compiler.pas"
CATALOGUE = "partial_cases.txt"

# A constant of one of these enumerations: two or three lowercase letters and
# then a capital or a digit. Every enumeration in compiler.pas is written this
# way, and it is what lets a label name its own enumeration.
# The field a *tag* dispatch reads. See dispatch().
TAG_FIELD = "kind"



def dispatch(pascalc, source):
    """Ask the compiler what it dispatches on (ADR-0229).

    This used to be `cases()`, which read the source with regular expressions
    -- and could not know what the compiler knows for nothing: which types are
    enumerations, how many constants each has, and what a selector's type
    actually is. It recognised an enumeration constant by a naming convention
    and a routine by a header regex, and `doc/sop.md` §7 already calls the
    source-parsing oracle the weaker of the two.

    Returns the sites in source order and the constants no case-statement
    names. Identifiers come back case-folded, because the lexer folds them and
    the pool holds the folded spelling; the catalogue is matched
    case-insensitively so it can go on being written the way the source spells
    it.
    """
    out = subprocess.run([str(pascalc), "--dump-dispatch", str(source),
                          "-o", os.devnull],
                         capture_output=True, text=True)
    if out.returncode != 0:
        print(f"kind-exhaustive: {pascalc} --dump-dispatch failed:\n"
              f"{out.stdout}{out.stderr}", file=sys.stderr)
        sys.exit(1)
    site = re.compile(r"^case ([A-Za-z0-9_]+):([A-Za-z0-9_?]+):(\d+) names "
                      r"(\d+) of (\d+)( otherwise)? at (\d+):(\d+)"
                      r"(?: missing (.*))?$")
    # A chain says which field it tested, and that is what selects a *tag*
    # dispatch from a lookahead: `e^.kind = nkVar` asks a value for its own
    # kind, `t = tkSemi` asks whether a token happens to be a semicolon.
    # ADR-0221 chose that scope by matching the text `^.kind`; ADR-0230 keeps
    # it and states it, so the compiler reports every chain and this selects.
    chain = re.compile(r"^chain ([A-Za-z0-9_]+):([A-Za-z0-9_?]+):(\d+) on "
                       r"([A-Za-z0-9_?]+) names (\d+) of (\d+) at "
                       r"(\d+):(\d+)(?: missing (.*))?$")
    never = re.compile(r"^unused ([A-Za-z0-9_]+) ([A-Za-z0-9_]+)$")
    decl = re.compile(r"^enum ([A-Za-z0-9_]+) (\d+)$")
    sites, unused, chains_, enums = [], set(), [], {}
    for raw in out.stdout.splitlines():
        line = raw.rstrip()
        if not line:
            continue
        m = site.match(line)
        if m:
            sites.append((m.group(1), m.group(2), int(m.group(3)),
                          int(m.group(4)), int(m.group(5)),
                          bool(m.group(6)), int(m.group(7)),
                          (m.group(9) or "").split()))
            continue
        m = chain.match(line)
        if m:
            if m.group(4) == TAG_FIELD:
                chains_.append((m.group(1), m.group(2), int(m.group(3)),
                                int(m.group(5)), int(m.group(6)),
                                int(m.group(7)), (m.group(9) or "").split()))
            continue
        m = never.match(line)
        if m:
            unused.add((m.group(1), m.group(2)))
            continue
        m = decl.match(line)
        if m:
            enums[m.group(1)] = int(m.group(2))
            continue
        print(f"kind-exhaustive: --dump-dispatch wrote a line this does not "
              f"understand: {line!r}", file=sys.stderr)
        sys.exit(1)
    return sites, unused, chains_, enums


def catalogue(path):
    """Two entry forms, `#` a comment:

        routine:enum:n names N of M   -- a case-statement naming a subset
        enum:CONSTANT unused          -- a constant no case-statement names
    """
    listed, unused, chained = {}, {}, {}
    partial = re.compile(r"^([A-Za-z0-9_]+):([A-Za-z0-9_]+):(\d+)\s+names\s+"
                         r"(\d+)\s+of\s+(\d+)\b")
    chain = re.compile(r"^([A-Za-z0-9_]+):([A-Za-z0-9_]+):(\d+)\s+chains\s+"
                       r"(\d+)\s+of\s+(\d+)\b")
    never = re.compile(r"^([A-Za-z0-9_]+):([A-Za-z0-9_]+)\s+unused\b")
    for n, raw in enumerate(path.read_text().splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        m = partial.match(line)
        if m:
            listed[(m.group(1), m.group(2), int(m.group(3)))] = (
                n, int(m.group(4)), int(m.group(5)))
            continue
        m = chain.match(line)
        if m:
            chained[(m.group(1), m.group(2), int(m.group(3)))] = (
                n, int(m.group(4)), int(m.group(5)))
            continue
        m = never.match(line)
        if m:
            unused[(m.group(1), m.group(2))] = n
            continue
        print(f"kind-exhaustive: {path.name}:{n}: expected "
              f"`routine:enum:n names N of M`, `routine:enum:n chains N of M` "
              f"or `enum:CONSTANT unused`, found {line!r}", file=sys.stderr)
        sys.exit(1)
    return listed, unused, chained


def main():
    root = pathlib.Path(__file__).resolve().parents[2]
    build = pathlib.Path(sys.argv[sys.argv.index("--build") + 1]) \
        if "--build" in sys.argv else root / "build"
    pascalc = build / "bin" / "pascalc"
    if not pascalc.exists():
        print(f"kind-exhaustive: {pascalc} is not built", file=sys.stderr)
        return 77

    listed, unused, chained = catalogue(
        pathlib.Path(__file__).with_name(CATALOGUE))

    # The catalogue is written the way the source spells a name; the compiler
    # folds identifiers, so it answers in lower case. Fold the keys to match,
    # and keep the written spelling for the messages.
    listed = {(r.lower(), e.lower(), n): (line, a, b, r, e)
              for (r, e, n), (line, a, b) in listed.items()}
    unused = {(e.lower(), c.lower()): (n, e, c)
              for (e, c), n in unused.items()}

    found, never_named, found_chains, enums = dispatch(pascalc,
                                                       root / SOURCE)
    if not found or not enums:
        print("kind-exhaustive: --dump-dispatch reported no enumeration or no "
              "case-statement over one at all", file=sys.stderr)
        return 1

    bad = []
    partial = total = 0
    for routine, enum, n, named, count, other, line, missing in found:
        if other:
            continue
        total += 1
        key = (routine, enum, n)
        entry = listed.pop(key, None)
        shown = f"{entry[3]}" if entry else routine
        shown_enum = f"{entry[4]}" if entry else enum
        if not missing:
            if entry:
                bad.append(f"{CATALOGUE}:{entry[0]} argues that "
                           f"{shown}'s case over {shown_enum} names a subset, "
                           f"and it names every one -- strike the entry")
            continue
        partial += 1
        if entry is None:
            bad.append(f"{SOURCE}:{line} ({routine}) names "
                       f"{named} of {count} {enum} constants "
                       f"and argues for none of it -- missing "
                       f"{', '.join(missing[:6])}"
                       f"{' ...' if len(missing) > 6 else ''}")
            bad.append(f"  a constant left off is a crash, not a wrong answer "
                       f"(ADR-0018). Add `{routine}:{enum}:{n} names "
                       f"{named} of {count}` to {CATALOGUE} "
                       f"with the reason no other constant reaches it")
        elif (entry[1], entry[2]) != (named, count):
            bad.append(f"{CATALOGUE}:{entry[0]} says {shown}'s case over "
                       f"{shown_enum} names {entry[1]} of {entry[2]}; it names "
                       f"{named} of {count} -- "
                       f"{'the enumeration grew and this case did not' if entry[2] != count else 'an arm was added or removed'}")

    for key, entry in sorted(listed.items(), key=lambda kv: kv[1][0]):
        bad.append(f"{CATALOGUE}:{entry[0]} names {entry[3]}:{entry[4]}:"
                   f"{key[2]}, and there is no such case-statement")

    # The chain half. Same five directions as the case half, and the reason a
    # chain naming every constant still needs no entry is the same too: there
    # is nothing left for a reader to be asked about.
    if not found_chains:
        print("kind-exhaustive: --dump-dispatch reported no if-chain "
              f"dispatching on a field named {TAG_FIELD!r} at all",
              file=sys.stderr)
        return 1
    chained = {(r.lower(), e.lower(), n): (line, a, b, r, e)
               for (r, e, n), (line, a, b) in chained.items()}
    chain_partial = 0
    for routine, enum, n, named, count, line, missing in found_chains:
        entry = chained.pop((routine, enum, n), None)
        if not missing:
            if entry:
                bad.append(f"{CATALOGUE}:{entry[0]} argues that {entry[3]}'s "
                           f"if-chain over {entry[4]} names a subset, and it "
                           f"names every one -- strike the entry")
            continue
        chain_partial += 1
        if entry is None:
            bad.append(f"{SOURCE}:{line} ({routine}) dispatches on "
                       f"{named} of {count} {enum} constants in "
                       f"an if-chain and argues for none of it -- missing "
                       f"{', '.join(missing[:6])}"
                       f"{' ...' if len(missing) > 6 else ''}")
            bad.append(f"  unlike a case-statement, a constant left off a "
                       f"chain is a wrong answer and not a crash -- it takes "
                       f"the trailing `else` in silence (ADR-0220). Add "
                       f"`{routine}:{enum}:{n} chains {named} of "
                       f"{count}` to {CATALOGUE} with the reason "
                       f"the rest do not belong")
        elif (entry[1], entry[2]) != (named, count):
            bad.append(f"{CATALOGUE}:{entry[0]} says {entry[3]}'s if-chain "
                       f"over {entry[4]} names {entry[1]} of {entry[2]}; it "
                       f"names {named} of {count} -- "
                       f"{'the enumeration grew and this chain did not' if entry[2] != count else 'an arm was added or removed'}")
    for key, entry in sorted(chained.items(), key=lambda kv: kv[1][0]):
        bad.append(f"{CATALOGUE}:{entry[0]} names {entry[3]}:{entry[4]}:"
                   f"{key[2]} as an if-chain, and there is no such chain")

    # The constants no case-statement names at all, which the compiler unions
    # over the *declared* enumerations rather than over the sites -- an
    # enumeration no case mentions has every constant unnamed and appears at
    # no site to be found at. `stdKind` is exactly that one.
    for key in sorted(never_named):
        if unused.pop(key, None) is None:
            bad.append(f"{key[1]} is named by no case-statement at all -- "
                       f"it is unused, or {key[0]} outlived it. Add "
                       f"`{key[0]}:{key[1]} unused` to {CATALOGUE} with what "
                       f"dispatches on it instead")
    for key, (n, e, c) in sorted(unused.items(), key=lambda kv: kv[1][0]):
        bad.append(f"{CATALOGUE}:{n} argues that {c} is named by no "
                   f"case-statement; the compiler says otherwise -- either an "
                   f"arm now names it, or {e} no longer has it")

    if bad:
        for b in bad:
            print(f"kind-exhaustive: {b}", file=sys.stderr)
        return 1

    print(f"kind-exhaustive: {total} case-statements over "
          f"{len(enums)} enumerations; {total - partial} name every constant "
          f"and {partial} argue for a subset. "
          f"{len(found_chains)} tag-dispatch if-chains, {chain_partial} of "
          f"them arguing for a subset")
    return 0


if __name__ == "__main__":
    sys.exit(main())
