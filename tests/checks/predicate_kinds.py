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

Usage:
    python3 tests/checks/predicate_kinds.py [--build build] [--write]
"""

import argparse
import pathlib
import re
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
SOURCE = ROOT / "selfhost" / "compiler.pas"
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", default="build")
    ap.add_argument("--write", action="store_true")
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

    # --- half one: the source says which predicates exist -------------------
    declared = declared_predicates(SOURCE.read_text())
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
        print("        Regenerate with --write when the answers are right, "
              "and say in the commit message which ones changed and why.",
              file=sys.stderr)
        return 1

    print(f"predicate-kinds: {len(order)} type predicates over {total} kinds "
          f"answer as the catalogue records, and the source declares no other")
    return 0


if __name__ == "__main__":
    sys.exit(main())
