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

"""Every pointer field of an AST node is set before the node is used.

The AST is the **only** variant record in this compiler -- `case kind:` appears
once in 36,000 lines -- and a variant record has no member initialisers. A
field of the arm the tag selects holds whatever `new` returned until something
writes it, and a `nodePtr` holding a value that is neither nil nor a node is
the one shape from which nothing downstream can recover: the walk follows it.

There are two ways a field gets a value, and the compiler uses both on purpose:

  * **NewNode clears it.** Its own comment says which fields those are -- "what
    Sema will fill in ... a C++ struct gets these from its member initialisers;
    a variant record has none". `vrSym`, `fdResolved`, `clSlot` and 60 others.
  * **The construction site assigns it.** The structural fields the *parser*
    fills -- `ifCond`, `bnLhs`, `arElem` -- are set within a few lines of
    `NewNode` returning, and clearing them first would be a store nothing
    reads.

Neither is written down anywhere a reader can check, and the split is not
arbitrary: it is who fills the field. This asks that every pointer field is on
one side of it or the other.

## What it reads

Both halves from the source, as `kind-exhaustive` does.

  * **The arms and their fields**, from the `case kind: nodeKind of` block --
    every field whose type is a pointer, those being the ones a wrong value
    kills. An integer field holding rubbish is a wrong answer; a pointer field
    holding rubbish is a walk into memory that is not a node.
  * **NewNode's cleared set**, from the assignments in its own `case k of`.
  * **Every construction site**, `v := NewNode(nkK, ...)`, and the assignments
    to `v^.f` that follow it inside the same routine.

A site is required to assign every pointer field of its kind that NewNode does
not clear. The routine is the boundary rather than a line count, because a
parser production builds a node and fills it before returning and there is no
shorter scope that is true of all of them.

## What it does not do

It does not ask whether the *value* assigned is right, and it cannot see a
field filled through a second variable or by a routine the node is handed to.
Both would report a false positive rather than a false pass, which is the safe
direction: an entry in the catalogue is then the answer, with the reason.

It says nothing about integer fields. `svArm` is initialised to -1 because -1
means "no arm", and that is a decision about a value, not about whether the
field was written -- exactly what this cannot judge.
"""

import pathlib
import re
import sys

SOURCE = "selfhost/compiler.pas"
CATALOGUE = "ast_fields.txt"

POINTER = ("nodePtr", "symPtr", "fieldPtr", "rangePtr", "numPtr", "typePtr",
           "variantPtr", "constGlobalPtr")
HEADER = re.compile(r"^\s*(?:function|procedure)\s+([A-Za-z0-9_]+)",
                    re.IGNORECASE)
SITE = re.compile(r"\b([A-Za-z0-9_]+)\s*:=\s*NewNode\s*\(\s*(nk[A-Za-z0-9_]+)")


def strip(text):
    """Blank out { } comments and ' ' literals, keeping every newline."""
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


def arms(text):
    """kind -> [pointer field names], from the one variant record here."""
    key = "case kind: nodeKind of"
    if key not in text:
        raise SystemExit(
            "ast-fields: the AST's variant part is not in " + SOURCE +
            "; a check that cannot find its landmark must fail loudly")
    body = text[text.index(key):]
    body = body[:body.index("\n  end;")]
    out = {}
    for labels, fields in re.findall(
            r"\n\s{6}([A-Za-z0-9_,\s]+?):\s*\(([^)]*)\)", body):
        names = []
        for group in fields.split(";"):
            if ":" not in group:
                continue
            lhs, rhs = group.split(":", 1)
            if any(p in rhs for p in POINTER):
                names += [n.strip() for n in lhs.split(",") if n.strip()]
        for label in [x.strip() for x in labels.split(",") if x.strip()]:
            out[label] = names
    return out


def cleared(lines):
    """The fields NewNode assigns, and the line range it occupies."""
    lo = next((n for n, l in enumerate(lines)
               if l.startswith("function NewNode(")), None)
    if lo is None:
        raise SystemExit("ast-fields: NewNode is not in " + SOURCE)
    hi = next(n for n, l in enumerate(lines) if n > lo and "NewNode := n" in l)
    body = "\n".join(lines[lo:hi])
    return set(re.findall(r"n\^\.([A-Za-z0-9_]+)\s*:=", body)), lo, hi


def catalogue(path):
    """`kind.field at routine:line` -- a site argued for, `#` a comment."""
    listed = {}
    form = re.compile(r"^(nk[A-Za-z0-9_]+)\.([A-Za-z0-9_]+)\s+at\s+"
                      r"([A-Za-z0-9_]+):(\d+)\b")
    if not path.exists():
        return listed
    for n, raw in enumerate(path.read_text().splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        m = form.match(line)
        if not m:
            print(f"ast-fields: {path.name}:{n}: expected "
                  f"`nkKind.field at Routine:line`, found {line!r}",
                  file=sys.stderr)
            sys.exit(1)
        listed[(m.group(1), m.group(2), m.group(3), int(m.group(4)))] = n
    return listed


def main():
    root = pathlib.Path(__file__).resolve().parents[2]
    text = strip((root / SOURCE).read_text())
    lines = text.splitlines()
    fields = arms(text)
    done, lo, hi = cleared(lines)
    listed = catalogue(pathlib.Path(__file__).with_name(CATALOGUE))

    owner, bound, cur, at = [], [], "?", 0
    for n, line in enumerate(lines):
        m = HEADER.match(line)
        if m:
            cur, at = m.group(1), n
        owner.append(cur)
        bound.append(at)

    bad, sites, checked = [], 0, 0
    for n, line in enumerate(lines):
        if lo <= n <= hi:
            continue
        m = SITE.search(line)
        if not m:
            continue
        var, kind = m.group(1), m.group(2)
        if kind not in fields:
            bad.append(f"{SOURCE}:{n + 1} builds a {kind}, which is not an "
                       f"arm of the AST's variant part")
            continue
        want = [f for f in fields[kind] if f not in done]
        if not want:
            continue
        sites += 1
        end = next((k for k in range(n + 1, len(lines))
                    if HEADER.match(lines[k])), len(lines))
        window = "\n".join(lines[n:end])
        for f in want:
            checked += 1
            if re.search(r"\b" + re.escape(var) + r"\^\." + f + r"\s*:=",
                         window):
                continue
            key = (kind, f, owner[n], n + 1)
            if listed.pop(key, None) is not None:
                continue
            bad.append(
                f"{SOURCE}:{n + 1} ({owner[n]}) builds a {kind} and never "
                f"assigns {var}^.{f}, which NewNode does not clear either -- "
                f"so it holds whatever new() returned")
            bad.append(
                f"  either clear it in NewNode's arm for {kind}, or assign it "
                f"here. If it is filled somewhere this cannot see, add "
                f"`{kind}.{f} at {owner[n]}:{n + 1}` to {CATALOGUE} with where")

    for key, n in sorted(listed.items(), key=lambda kv: kv[1]):
        bad.append(f"{CATALOGUE}:{n} argues for {key[0]}.{key[1]} at "
                   f"{key[2]}:{key[3]}, and there is no such unset field there")

    never = []
    for kind, names in sorted(fields.items()):
        for f in names:
            if f in done:
                continue
            if not re.search(r"\^\." + f + r"\s*:=", text):
                never.append(f"{kind}.{f} is assigned nowhere and cleared "
                             f"nowhere -- it is dead, or the arm outlived it")
    bad += never

    if bad:
        for b in bad:
            print(f"ast-fields: {b}", file=sys.stderr)
        return 1

    print(f"ast-fields: {len(fields)} arms of the AST's variant part, "
          f"{sum(len(v) for v in fields.values())} pointer fields; "
          f"{len(done)} cleared by NewNode and {checked} assignments checked "
          f"over {sites} construction sites")
    return 0


if __name__ == "__main__":
    sys.exit(main())
