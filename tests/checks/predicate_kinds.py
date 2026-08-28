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

"""What every type predicate answers about every kind of type (ADR-0194).

`kind-exhaustive` reads every `case ... of` over an enumeration and requires
every constant to be named, which is what makes adding a `typeKind` safe
*there*. It cannot see a **predicate**, and three defects in three increments
lived in one:

  * `IsMemory` was `IsStructured or IsOwned or IsVarString`, so a text was not
    memory, so the relational operators took it for a simple type and emitted
    `icmp` on an aggregate -- IR clang refuses (ADR-0191);
  * the code generator's comparison dispatch, the same shape one level down;
  * `EmitAssign` selecting the string store with `IsStringType`, so a text
    target fell through to a schema tuple-comparison that compared a
    *string's* capacity against a text's and stopped the program (ADR-0193).

None of the three is a case-statement. All three were found by writing a
program that used the new type, which is not a thing a gate does.

**This is a prompt, not a proof**, and the distinction is worth stating. The
catalogue records the answer each predicate gives today; it does not know which
answer is right, and a wrong cell written into it passes. What it buys is that
adding a kind changes `of N` on every row, so every one of the 36 predicates
has to be looked at once -- which is exactly the moment all three defects
needed a reader and did not get one. `partial_cases.txt` is the same
instrument for the same reason (ADR-0145).

**Two halves**, as `buffer-headroom` has since ADR-0148. The compiler answers
(`--dump-predicates`), and the *source* says which predicates exist -- so a
predicate added without a row in the dump fails here rather than passing
unseen. A gate holding both halves of its own comparison cannot fail, which is
what ADR-0144 found `foreign_reserved.py` doing.

**And a second question, asked once**, when a kind is added rather than on
every run. `--like OLD NEW` prints every predicate that answers differently
about two kinds and, under each, the call sites in `selfhost/compiler.pas`. It
exists because the gate above is satisfied by a *correct* row: a text is not a
string-type, `IsStringType 1 of 22` is right, and the defect was at a call site
that asked `IsStringType` when it meant "does this take the string store?".
Naming the kind the new one resembles is what no tool can derive and a person
knows; what follows from it is mechanical. For `--like tyString tyText` that is
three predicates over 45 call sites, and all three defects above are in the
list (ADR-0198).

Usage:
    python3 tests/checks/predicate_kinds.py [--build build] [--write]
    python3 tests/checks/predicate_kinds.py --like tyString tyText
"""

import argparse
import pathlib
import re
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
import components                                    # noqa: E402
CATALOGUE = HERE / "predicate_kinds.txt"

# Any program at all: the subject is the compiler, and the dump reports after a
# whole run only for consistency with the two dumps beside it.
PROBE = ROOT / "tests" / "hello.pas"


def declared_predicates(text):
    """Every `function Is...(t: typePtr): boolean` the source declares.

    The signature is the definition of "a type-classifying predicate" here, and
    it is a narrow one on purpose: a routine taking anything else is asking a
    question about more than a type, and a routine answering anything else is
    not classifying. Widening this is a decision -- it would pull in
    `Assignable` and the rest, which `predicate-callers` already sweeps from
    the other end.
    """
    return re.findall(
        r"^function (Is[A-Za-z0-9_]+)\(t: typePtr\): boolean;", text, re.M)


def parse_dump(out):
    """`kinds N` and then one `Name c of N: kinds...` line per predicate."""
    rows, total = {}, None
    order = []
    for line in out.splitlines():
        line = line.rstrip()
        if not line:
            continue
        m = re.match(r"^kinds (\d+):(.*)$", line)
        if m:
            total = int(m.group(1))
            listed = m.group(2).split()
            if len(listed) != total:
                return None, None, None, (
                    f"the dump says {total} kinds and names {len(listed)}")
            rows["kinds"] = listed
            continue
        m = re.match(r"^(\S+) (\d+) of (\d+):(.*)$", line)
        if not m:
            return None, None, None, f"unrecognised line: {line!r}"
        name, count, of, kinds = m.group(1), int(m.group(2)), int(m.group(3)), \
            m.group(4).split()
        if count != len(kinds):
            return None, None, None, (
                f"{name} says {count} and names {len(kinds)}")
        rows[name] = (of, kinds)
        order.append(name)
    if total is None:
        return None, None, None, "the dump named no kind count"
    return total, rows, order, None


def render(total, rows, order):
    out = [
        "# What every type predicate answers about every kind of type.",
        "#",
        "# Generated from the compiler's own --dump-predicates (ADR-0194), and",
        "# checked against it on every run. `N of M` is the point: adding a",
        "# typeKind moves M on every line, so each of the 36 predicates has to",
        "# be looked at once -- which is the moment three defects in three",
        "# increments needed a reader and did not get one (ADR-0191,",
        "# ADR-0193).",
        "#",
        "# The answer is for a type of that kind with nothing else set: no",
        "# element, no flags, no fields. So a predicate that also reads a flag",
        "# reports its flag-clear answer, and one that looks through Base()",
        "# reports tySubrange as false. Both are stated rather than hidden.",
        "#",
        "# This records what the answers ARE and not what they should be. A",
        "# wrong cell written here passes; what cannot pass is nobody looking.",
        "#",
        "# Regenerate with:",
        "#   python3 tests/checks/predicate_kinds.py --write",
        "# Doing so is a decision to argue for in the commit message.",
        "",
        "kinds " + str(total) + ":" + "".join(" " + k for k in rows["kinds"]),
        "",
    ]
    for name in order:
        of, kinds = rows[name]
        out.append(f"{name} {len(kinds)} of {of}:"
                   + ("".join(" " + k for k in kinds)))
    return "\n".join(out) + "\n"


def call_sites(sources, name):
    """Every line calling `name`, less its own declaration and definition.

    A predicate here is one or two lines -- `begin Is... := ... end` -- so the
    definition matches its own name and would head every list. Both are dropped
    by position rather than by pattern: the declaration is the line the gate
    already greps for, and the definition is the line after it.
    """
    pat = re.compile(r"\b" + re.escape(name) + r"\(")
    decl = re.compile(r"^function " + re.escape(name) + r"\(")
    out = []
    for path in sources:
        out += _sites_in(path.name, path.read_text(), pat, decl)
    return out


def _sites_in(name_of_file, text, pat, decl):
    out, skip = [], -2
    for i, line in enumerate(text.splitlines(), 1):
        if decl.match(line):
            skip = i
            continue
        if i == skip + 1:
            continue
        if pat.search(line):
            out.append((name_of_file, i, line.rstrip()))
    return out


def like(rows, old, new, source):
    """What the compiler still says is true of OLD and not of NEW.

    `source` is the list of component paths; a site is reported in the file it
    is in (ADR-0233).

    The direction matters. A predicate true of the old kind and false of the
    new one is a guard the new kind falls *out* of, which is where every defect
    ADR-0194 lists actually was; a predicate true of the new one and false of
    the old is the new kind's own, and is listed second and without call sites
    because it is what the increment just wrote.
    """
    kinds = rows["kinds"]
    for k in (old, new):
        if k not in kinds:
            print(f"predicate-kinds: no kind named {k}; the dump knows "
                  + " ".join(kinds), file=sys.stderr)
            return 1

    falls_out, brought_in = [], []
    for name, value in rows.items():
        if name == "kinds":
            continue          # the kind list, not a predicate's answer
        answers = value[1]
        a, b = old in answers, new in answers
        if a and not b:
            falls_out.append(name)
        elif b and not a:
            brought_in.append(name)

    print(f"{new} against {old}: {len(falls_out)} predicates answer yes to "
          f"{old} and no to {new}.")
    print()
    print(f"Each call site below is a question -- when this guard asks "
          f"\"{old}?\" and means \"does this take that path?\", a {new} takes "
          f"the wrong branch. That is where three defects in three increments "
          f"were (ADR-0191, ADR-0193), and the row for each of these "
          f"predicates in the catalogue is *correct*, which is why the gate "
          f"cannot see them.")
    total = 0
    for name in falls_out:
        sites = call_sites(source, name)
        total += len(sites)
        print()
        print(f"  {name} -- {len(sites)} call sites")
        for where, n, line in sites:
            print(f"    selfhost/{where}:{n}: {line.strip()}")
    print()
    print(f"{total} call sites over {len(falls_out)} predicates.")
    if brought_in:
        print()
        print(f"{new} answers yes where {old} answers no to: "
              + ", ".join(brought_in) + " -- the new kind's own, listed "
              "without sites because they are what this increment wrote.")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", default="build")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--like", nargs=2, metavar=("OLD", "NEW"),
                    help="every predicate answering differently about two "
                         "kinds, with the call sites of each -- the question "
                         "to ask once, when a kind is added")
    args = ap.parse_args()

    compiler = ROOT / args.build / "bin" / "pascalc"
    if not compiler.exists():
        print(f"predicate-kinds: no {compiler} -- build first", file=sys.stderr)
        return 1

    proc = subprocess.run(
        [str(compiler), "--dump-predicates", str(PROBE), "-o", "/dev/null"],
        capture_output=True, text=True)
    if proc.returncode != 0:
        print("predicate-kinds: --dump-predicates failed:", file=sys.stderr)
        print(proc.stdout + proc.stderr, file=sys.stderr)
        return 1

    total, rows, order, err = parse_dump(proc.stdout)
    if err:
        print(f"predicate-kinds: {err}", file=sys.stderr)
        return 1

    if args.like:
        return like(rows, args.like[0], args.like[1],
                    components.sources(ROOT))

    # --- half one: the source says which predicates exist -------------------
    # Every component: the type predicates are ApTypes' since ADR-0233 and the
    # gate's question is about the compiler. Reading one file would have made
    # eight predicates look undeclared while the compiler went on answering
    # for them, which is how this failed on the day of the split.
    declared = declared_predicates(components.text(ROOT))
    missing = [p for p in declared if p not in rows]
    extra = [p for p in rows if p not in declared and p != "kinds"]
    if missing:
        print("predicate-kinds: the source declares a type predicate that "
              "--dump-predicates does not report:", file=sys.stderr)
        for p in missing:
            print(f"          {p}", file=sys.stderr)
        print("        Add a Row(...) for it in DumpPredicates. A predicate "
              "nothing reports is a predicate this gate cannot watch, which "
              "is the hole it exists to close (ADR-0194).", file=sys.stderr)
        return 1
    if extra:
        print("predicate-kinds: --dump-predicates reports something the "
              "source does not declare as a type predicate:", file=sys.stderr)
        for p in extra:
            print(f"          {p}", file=sys.stderr)
        print("        Strike its Row(...), or give it the signature the "
              "others have.", file=sys.stderr)
        return 1

    fresh = render(total, rows, order)
    if args.write:
        CATALOGUE.write_text(fresh)
        print(f"predicate-kinds: wrote {CATALOGUE.name} "
              f"({len(order)} predicates over {total} kinds)")
        return 0

    if not CATALOGUE.exists():
        print(f"predicate-kinds: no {CATALOGUE} -- run with --write",
              file=sys.stderr)
        return 1

    have = CATALOGUE.read_text()
    if have != fresh:
        import difflib
        diff = list(difflib.unified_diff(
            have.splitlines(), fresh.splitlines(),
            "catalogue", "compiler", lineterm=""))
        for line in diff[:40]:
            print(line, file=sys.stderr)
        print("", file=sys.stderr)
        print("predicate-kinds: a type predicate answers differently than "
              "the catalogue records.", file=sys.stderr)
        print("        If a kind was added, every `of N` moved and each of "
              "these rows is a question: should this predicate be true of the "
              "new kind? Three defects in three increments were a `no` nobody "
              "was asked about (ADR-0191, ADR-0193).", file=sys.stderr)
        print("        If the kind resembles one that already exists, "
              "`--like <old> <new>` lists every predicate that answers "
              "differently and every call site of each -- which is where a "
              "*correct* row still hides a defect (ADR-0198).",
              file=sys.stderr)
        print("        Regenerate with --write when the answers are right, "
              "and say in the commit message which ones changed and why.",
              file=sys.stderr)
        return 1

    print(f"predicate-kinds: {len(order)} type predicates over {total} kinds "
          f"answer as the catalogue records, and the source declares no other")
    return 0


if __name__ == "__main__":
    sys.exit(main())
