#!/usr/bin/env python3
"""Every clause number this repository cites shall be a clause of a standard
it is amending or claiming to implement.

This exists because a citation is the one kind of claim here that *no other
oracle can contradict*. A wrong clause number compiles, runs, passes every
golden, agrees with the other front end and is proved correct by verify/ --
ADR-0072 is the record of one surviving in four documents and a purpose-written
test. `spec-clause-traceability` gates the clause **tags** in tests/spec/, and a
prose citation is not a tag; nothing looked at the other four thousand.

It answers the cheap half of the question and says so. It asks whether a number
*names a clause*, never whether it names the RIGHT clause -- so it would not
have caught ADR-0163's defect, where §6.4.3.4 was cited about an ISO 7185
program and §6.4.3.4 exists in both standards meaning two different things.
That half needs a reader. What this catches is the number that names nothing at
all -- the failure that can persist indefinitely, because nobody chasing it
ever arrives anywhere to be surprised. It found one standing in seven places,
glossed the same way in every one of them; ADR-0164 says which and what it
should have been. Spelling it here would be a citation of it: this gate cannot
tell a mention from a claim, and that is its rule rather than its limitation.

**The inventories are the authority and they are generated** (clauses/extract.sh
from the standards, extract_afterschool.py from the dialect spec), so a citation
this reports may be the *inventory's* defect rather than the citation's --
ADR-0152 found 37 real clauses in no inventory because the extractor read only
lines carrying a title. Check the standard before editing the citation. That is
also why the catalogue exists rather than a hard-coded allowance: 6.6.4.1 is a
number ISO 7185's own §6.2.2.10 cross-references and its index lists, with no
such heading anywhere in the published standard, and naming anything else would
misquote the cross-reference we are following.

Fails in **both** directions, as every catalogue here does: a number that starts
being a clause is as loud as one that stops being, and an entry naming a file
that no longer cites it fails too -- otherwise the catalogue silently becomes a
list of things that used to be true.
"""

import csv
import pathlib
import re
import sys

# A clause of clause 6 -- the language -- which is the only clause anything
# here cites. Components are one or two digits; the guard is what keeps
# 6.2831853071795864769 (two pi, in the runtime) from reading as a clause.
CITE = re.compile(r"(?<![\d.])6(?:\.\d{1,2})+(?![\d.])")

# The Pascal compiler cites without the section sign -- `char` is a byte, so a
# diagnostic cannot carry one (ADR-0058) and the comments follow the source.
SCAN = (".md", ".pas", ".c", ".cpp", ".h", ".py", ".feature", ".tsv", ".sh",
        ".err", ".txt")

CATALOGUE = "tests/checks/nonexistent_clauses.txt"

# Walked rather than asked of `git ls-files`, which exits 128 in a container
# whose checkout git calls dubiously owned -- it did, in three CI jobs, and a
# gate that cannot run is worse than one that is merely narrow. Walking also
# reaches a file that has not been added yet, which is the moment a citation
# can still be fixed without a catalogue entry.
#
# Each skip is a directory whose text is not this repository's to be judged on:
SKIP = {
    ".git",             # not text
    "__pycache__",
    "doc/vendor",       # the standards themselves. No text of either is in
                        # this repository and none may be; they are read
                        # locally and never redistributed. Scanning them would
                        # also drown the report in their own cross-references.
    "tests/bsi/suite",  # BSI's 812 programs, fetched and never committed. Their
                        # headers cite clauses in BSI's numbering ("TEST
                        # 6.4.3.5-4"), which is not ours to correct.
    "runtime/unicode/ucd",  # the Unicode Character Database, fetched and never
                        # committed (runtime/unicode/fetch.sh). Its files
                        # record, against each property, the Unicode *version*
                        # that introduced it -- three numbers separated by
                        # points, in exactly the shape this gate reads a clause
                        # number from. A version is not a citation. Found the
                        # day the database arrived, by this gate failing on
                        # DerivedNormalizationProps.txt (ADR-0190).
                        #
                        # The numbers are not written out here on purpose:
                        # this gate cannot tell a mention from a claim, so
                        # spelling one would fail the check that this comment
                        # explains.
}


def sources(root):
    """Every file whose citations this repository is answerable for."""
    out = []
    for path in sorted(root.rglob("*")):
        if not path.is_file() or not path.name.endswith(SCAN):
            continue
        rel = path.relative_to(root).as_posix()
        parts = rel.split("/")
        if any(p in SKIP or p.startswith("build") for p in parts):
            continue
        if any(rel.startswith(s + "/") for s in SKIP):
            continue
        out.append(rel)
    return out


def inventory(root):
    """Every clause number the three specifications carry a heading for."""
    known = set()
    for name in ("iso7185.tsv", "iso10206.tsv", "afterschool.tsv"):
        path = root / "tests/spec/clauses" / name
        with open(path, newline="", encoding="utf-8") as fh:
            for row in csv.reader(fh, delimiter="\t"):
                if len(row) >= 2 and row[0] and row[0][0].isdigit():
                    known.add(row[0])
    return known


def catalogued(root):
    """number -> set of files it is allowed in, or None meaning anywhere."""
    out = {}
    path = root / CATALOGUE
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        # An entry starts at column 0; an indented line continues the argument
        # of the entry above it, so the arguments can be written as prose.
        if not line.strip() or line.startswith(("#", " ", "\t")):
            continue
        parts = line.split(None, 2)
        if len(parts) < 2:
            continue
        number, where = parts[0], parts[1]
        if where == "anywhere":
            out[number] = None
        else:
            out.setdefault(number, set())
            if out[number] is not None:
                out[number].add(where)
    return out


def main():
    root = pathlib.Path(__file__).resolve().parents[2]
    known = inventory(root)
    allow = catalogued(root)

    files = sources(root)
    total = 0
    found = {}          # number -> {file, ...}
    for name in files:
        if not name.endswith(SCAN):
            continue
        # The catalogue names numbers for a living: its occurrences of one are
        # the entries themselves, not citations of it. Reading it as a citer
        # would make every entry require an entry.
        if name == CATALOGUE:
            continue
        try:
            text = (root / name).read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        for match in CITE.finditer(text):
            total += 1
            number = match.group(0)
            if number not in known:
                found.setdefault(number, set()).add(name)

    problems = []

    # A citation naming no clause, in a place the catalogue does not allow.
    for number in sorted(found):
        permitted = allow.get(number, set()) if number in allow else set()
        if permitted is None:
            continue
        for name in sorted(found[number] - permitted):
            problems.append(
                f"{name}: cites {number}, which no clause of ISO 7185, "
                f"ISO/IEC 10206:1991 or the dialect specification carries")

    # The other direction: an entry that has stopped being needed.
    for number, permitted in sorted(allow.items()):
        if number in known:
            problems.append(
                f"{CATALOGUE}: {number} is a clause after all -- the "
                f"inventories carry it now, so the entry is stale")
            continue
        if permitted is None:
            if number not in found:
                problems.append(
                    f"{CATALOGUE}: {number} is allowed anywhere and is cited "
                    f"nowhere -- drop the entry")
            continue
        for name in sorted(permitted - found.get(number, set())):
            problems.append(
                f"{CATALOGUE}: {number} is allowed in {name}, which no longer "
                f"cites it -- drop that line")

    # Reported rather than assumed: an empty problem list is what a clean run
    # and a run that scanned nothing both produce.
    print(f"clause-citations: {total} citations of clause 6 across "
          f"{len(files)} files; {len(known)} clauses known")
    if problems:
        for line in problems:
            print(line)
        print(f"\nCheck the standard before editing a citation: the "
              f"inventories are generated and have been wrong (ADR-0152). If "
              f"the number is the standard's own, add it to {CATALOGUE} with "
              f"the argument.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
