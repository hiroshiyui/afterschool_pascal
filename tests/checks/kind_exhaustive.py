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

Both halves come from the source.

  * **The enumerations.** Any `name = (c1, c2, ...)` whose every constant is a
    lowercase tag followed by a capital -- `tkEof`, `nkInt`, `spNone`. That is
    this compiler's own convention and it is what makes a label identify its
    enumeration without a symbol table.
  * **The case-statements.** `case <expr> of`, with the labels collected at
    the statement's *own* nesting depth, so a nested case is not credited to
    the one containing it. A **variant part** (`case kind: nodeKind of`) is not
    a case-statement and is excluded -- §6.4.3.3 requires its labels to be
    exactly the tag-type's values and this compiler already enforces that
    (ADR-0096), which is a stronger check than this one.

A case-statement with an `otherwise` is total by construction (§6.9.3.5) and is
required to name nothing.

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

A chain is recognised by the shape of its conditions -- `<expr>^.kind = c`,
a value asked for its own tag -- and by nothing else. That is what makes the
scope self-selecting rather than a judgement: `Check(tkSemicolon)` is a
lookahead predicate and not a dispatch, so the parser's long `if Check(...)`
ladders are outside this and stay outside it however long they get. Three
enumerations qualify today, and they qualify because of how they are written:
`nodeKind`, `symKind` and `typeKind`.

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
CONST = re.compile(r"^[a-z]{2,3}[A-Z0-9]")
ENUM = re.compile(r"^\s*([A-Za-z0-9_]+)\s*=\s*\(")

# `case <expr> of` at the end of a line, which is how every one of them is
# written -- and `case <name>: <type> of`, which is a variant part rather than
# a statement and is excluded.
HEADER = re.compile(r"^\s*(?:function|procedure)\s+([A-Za-z0-9_]+)",
                    re.IGNORECASE)

# A case-statement's arms nest with begin/case/record, and `end` closes any of
# them. Counting words is enough once comments and string literals are gone.
OPENERS = ("begin", "case", "record")


def word(w):
    return re.compile(r"(?<![A-Za-z0-9_])" + w + r"(?![A-Za-z0-9_])",
                      re.IGNORECASE)


WORDS = {w: word(w) for w in OPENERS + ("end", "otherwise")}

# A label list, and a line that is only the front of one. A list may run over
# several lines with a comment between them, so a fragment ending in a comma is
# held until the line that closes it -- StaticThroughout writes fourteen
# constants over three lines that way, and a reader that lost them would call
# an exhaustive case partial.


def strip(text):
    """Blank out { } comments and ' ' literals, keeping every newline.

    Line numbers have to survive, because what this reports is a line number
    in a 24,000-line file and nothing else would let a reader find the arm.
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


def enumerations(lines):
    """name -> [constants], for every enumeration written the house way."""
    found = {}
    for i, line in enumerate(lines):
        m = ENUM.match(line)
        if not m:
            continue
        text, j = "", i
        while j < len(lines):
            text += lines[j] + " "
            if ")" in lines[j]:
                break
            j += 1
        if ")" not in text:
            continue
        inner = text[text.index("(") + 1:text.rindex(")")]
        names = [n.strip() for n in inner.split(",") if n.strip()]
        if names and all(CONST.match(n) for n in names):
            found[m.group(1)] = names
    return found


# procedure into the next one's arms, which is how a first draft credited
# `EmitComplexPow` with naming `nkStr`.
CHAIN_IF = re.compile(r"^(\s*)if(?![A-Za-z0-9_])", re.IGNORECASE)
CHAIN_ELIF = re.compile(r"^(\s*)else if(?![A-Za-z0-9_])", re.IGNORECASE)
THEN = re.compile(r"(?<![A-Za-z0-9_])then(?![A-Za-z0-9_])", re.IGNORECASE)
# The dispatch shape, and the whole of what selects a chain: a value asked for
# its own tag. `Check(tkSemicolon)` is a lookahead predicate and does not match.
TAGTEST = re.compile(r"\^\.kind\s*=\s*([A-Za-z0-9_]+)")


def chains(lines, enums):
    """Every if-chain dispatching on a tag: line, routine, enum, constants.

    A chain naming constants of two enumerations answers for each separately --
    `EmitString` tests `nodeKind`, `binaryOp` and `builtinKind` in one set of
    conditions, which is the ordinary case for a chain and never happens to a
    case-statement. Only the tag tests count, so `binaryOp` and `builtinKind`
    are absent here: they are compared as `e^.bnOp = opAdd`, a field that is
    not a tag.
    """
    members = {c: e for e, cs in enums.items() for c in cs}
    owner, cur = [], "?"
    for line in lines:
        m = HEADER.match(line)
        if m:
            cur = m.group(1)
        owner.append(cur)

    def condition(i):
        """The condition at line i, up to and including the line with `then`."""
        text = []
        for j in range(i, min(i + 8, len(lines))):
            text.append(lines[j])
            if THEN.search(lines[j]):
                break
        return " ".join(text)

    out, i = [], 0
    while i < len(lines):
        m = CHAIN_IF.match(lines[i])
        if not m or CHAIN_ELIF.match(lines[i]):
            i += 1
            continue
        indent = m.group(1)
        conds, last, j = [condition(i)], i, i + 1
        while j < len(lines):
            if HEADER.match(lines[j]):
                break
            m2 = CHAIN_ELIF.match(lines[j])
            if m2 and m2.group(1) == indent:
                conds.append(condition(j))
                last = j
                j += 1
            elif re.match("^" + indent + r"else(?![A-Za-z0-9_])", lines[j],
                          re.IGNORECASE):
                break
            else:
                j += 1
        if len(conds) >= 2:
            by = {}
            for c in conds:
                for name in TAGTEST.findall(c):
                    enum = members.get(name)
                    if enum:
                        by.setdefault(enum, set()).add(name)
            for enum, seen in sorted(by.items()):
                # One arm is a test, not a dispatch. Two is the smallest thing
                # a reader could have got wrong by leaving a third off.
                if len(seen) >= 2:
                    out.append((i + 1, owner[i], enum, seen))
        i = last + 1
    return out


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
    never = re.compile(r"^unused ([A-Za-z0-9_]+) ([A-Za-z0-9_]+)$")
    sites, unused = [], set()
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
        m = never.match(line)
        if m:
            unused.add((m.group(1), m.group(2)))
            continue
        print(f"kind-exhaustive: --dump-dispatch wrote a line this does not "
              f"understand: {line!r}", file=sys.stderr)
        sys.exit(1)
    return sites, unused


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

    lines = strip((root / SOURCE).read_text()).splitlines()
    listed, unused, chained = catalogue(
        pathlib.Path(__file__).with_name(CATALOGUE))

    # The case half comes from the compiler (ADR-0229); the chain half still
    # reads the source, and `enumerations()` is what it needs to do that.
    enums = enumerations(lines)
    if not enums:
        print(f"kind-exhaustive: no enumeration in {SOURCE}; the pattern this "
              f"reads for must have changed", file=sys.stderr)
        return 1

    # The catalogue is written the way the source spells a name; the compiler
    # folds identifiers, so it answers in lower case. Fold the keys to match,
    # and keep the written spelling for the messages.
    listed = {(r.lower(), e.lower(), n): (line, a, b, r, e)
              for (r, e, n), (line, a, b) in listed.items()}
    unused = {(e.lower(), c.lower()): (n, e, c)
              for (e, c), n in unused.items()}

    found, never_named = dispatch(pascalc, root / SOURCE)
    if not found:
        print("kind-exhaustive: --dump-dispatch reported no case-statement "
              "over an enumeration at all", file=sys.stderr)
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
    found_chains = chains(lines, enums)
    if not found_chains:
        print("kind-exhaustive: no if-chain dispatching on a tag was found; "
              "the pattern this reads for must have changed", file=sys.stderr)
        return 1
    chain_ord, chain_partial = {}, 0
    for line, routine, enum, seen in found_chains:
        missing = [c for c in enums[enum] if c not in seen]
        n = chain_ord[(routine, enum)] = chain_ord.get((routine, enum), 0) + 1
        entry = chained.pop((routine, enum, n), None)
        if not missing:
            if entry:
                bad.append(f"{CATALOGUE}:{entry[0]} argues that {routine}'s "
                           f"if-chain over {enum} names a subset, and it names "
                           f"every one -- strike the entry")
            continue
        chain_partial += 1
        if entry is None:
            bad.append(f"{SOURCE}:{line} ({routine}) dispatches on "
                       f"{len(seen)} of {len(enums[enum])} {enum} constants in "
                       f"an if-chain and argues for none of it")
            bad.append(f"  unlike a case-statement, a constant left off a "
                       f"chain is a wrong answer and not a crash -- it takes "
                       f"the trailing `else` in silence (ADR-0220). Add "
                       f"`{routine}:{enum}:{n} chains {len(seen)} of "
                       f"{len(enums[enum])}` to {CATALOGUE} with the reason "
                       f"the rest do not belong")
        elif (entry[1], entry[2]) != (len(seen), len(enums[enum])):
            bad.append(f"{CATALOGUE}:{entry[0]} says {routine}'s if-chain over "
                       f"{enum} names {entry[1]} of {entry[2]}; it names "
                       f"{len(seen)} of {len(enums[enum])} -- "
                       f"{'the enumeration grew and this chain did not' if entry[2] != len(enums[enum]) else 'an arm was added or removed'}")
    for key, (n, _, _) in sorted(chained.items(), key=lambda kv: kv[1][0]):
        bad.append(f"{CATALOGUE}:{n} names {key[0]}:{key[1]}:{key[2]} as an "
                   f"if-chain, and there is no such chain")

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
