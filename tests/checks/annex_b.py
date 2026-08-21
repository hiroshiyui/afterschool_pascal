#!/usr/bin/env python3
"""Does every dialect construct still get the answer Annex B says it gets?

`doc/afterschool-pascal-spec.md`'s Annex B records what `--std=iso7185` and
`--std=extended` say about each construct the dialect adds. That is a
*conformance* question even though the feature is not one (AP 5.3): ADR-0117's
containment is a promise about what the two modes accept, and ADR-0154's rule
is that a dialect feature may still change what they **say** -- a diagnostic
naming the mode being the only way to tell a program it was compiled under the
wrong one.

Until this gate, the annex was a table nothing read. It also claimed the two
modes agree, and they do not: ISO 7185 has no substring notation, so its parser
stops at the `..` where Extended Pascal parses `a[i..j]` and Sema refuses it.
Nobody noticed because nobody probed -- which is the failure `doc/sop.md` §1
names, a claim no test names being a claim nothing checks (ADR-0067).

What it does: reads the table, and for each row requires the pair of cases the
`Case` column names to exist, to be refused, and for each golden to contain the
message the table states for that mode.

It fails in **both** directions. A row whose cases are missing fails, which is
a construct documented and unchecked. A `*_refused` case under `tests/` or
`tests/extended/` that no row names fails, which is a construct checked and
undocumented -- and that is the direction that matters, because it is what a
sixth dialect feature would trip.

It does not compile anything. The `.err` goldens are the compiler's own answer,
compared by `run_test.sh` on every run and by `selfhost/difftest.sh` against the
reference front end; this asks whether the *specification* still describes
them.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SPEC = os.path.join(ROOT, "doc", "afterschool-pascal-spec.md")

# Where a case for each mode lives. The directory is what tells every harness
# here which standard a source is written in, so it is what tells this one too.
# Where a case for each mode lives, and what it is called there. The directory
# is what tells every harness here which standard a source is written in, so it
# is what tells this one too -- but a ctest name is flat across the two corpora
# and `foo` under tests/ collides with `foo` under tests/extended/, which is why
# selfhost/badparse/ and badsema/ are prefixed by directory. The suffix is that
# same constraint met the same way, and it earns its keep: a case named
# `_refused_iso` says which mode's answer it pins without being opened.
DIRS = [("iso7185", os.path.join(ROOT, "tests"), "_refused_iso"),
        ("extended", os.path.join(ROOT, "tests", "extended"), "_refused")]

HEADER = re.compile(r"^\|\s*Case\s*\|\s*Construct\s*\|"
                    r"\s*`--std=iso7185`\s*says\s*\|"
                    r"\s*`--std=extended`\s*says\s*\|\s*$")

def die(msg):
    sys.stderr.write("annex-b: " + msg + "\n")
    sys.exit(1)


def cell(text):
    """One table cell, with the backticks the annex writes its messages in."""
    t = text.strip()
    if t.startswith("`") and t.endswith("`"):
        return t[1:-1]
    return t


def table():
    """Annex B's rows: (case, construct, {mode: message})."""
    rows, inside = [], False
    for line in open(SPEC):
        if HEADER.match(line):
            inside = True
            continue
        if inside:
            if not line.startswith("|"):
                break
            parts = [c for c in line.strip().strip("|").split("|")]
            if len(parts) != 4:
                die("a row of Annex B has %d cells, not 4: %s"
                    % (len(parts), line.strip()))
            if set(parts[0].strip()) <= set("- "):
                continue                      # the |---|---| separator
            rows.append((cell(parts[0]), cell(parts[1]),
                         {"iso7185": cell(parts[2]),
                          "extended": cell(parts[3])}))
    if not rows:
        die("no Annex B table found in %s -- the heading row this gate keys on "
            "is `| Case | Construct | ... |`, and a renamed column is a table "
            "nothing reads rather than a failure, so it is one" % SPEC)
    return rows


def main():
    rows = table()
    named = set()
    problems = []

    for case, construct, says in rows:
        for mode, d, suffix in DIRS:
            src = os.path.join(d, case + suffix + ".pas")
            err = os.path.join(d, case + suffix + ".err")
            rel = os.path.relpath(src, ROOT)
            named.add(rel)
            if not os.path.exists(src):
                problems.append("%s (%s) has no case at %s" % (construct, mode, rel))
                continue
            if not os.path.exists(err):
                problems.append("%s has no .err golden, so nothing requires it "
                                "to be refused" % rel)
                continue
            golden = open(err).read()
            want = says[mode]
            if want not in golden:
                problems.append(
                    "%s does not say what Annex B states for %s.\n"
                    "      annex:  %s\n      golden: %s"
                    % (rel, mode, want, golden.strip().replace("\n", "\n              ")))

    # ...and the other direction: a case naming no row.
    for _, d, suffix in DIRS:
        for f in sorted(os.listdir(d)):
            if f.endswith(suffix + ".pas"):
                rel = os.path.relpath(os.path.join(d, f), ROOT)
                if rel not in named:
                    problems.append(
                        "%s is a refusal case Annex B does not name. Add a row, "
                        "or rename the case if it is not about a dialect "
                        "construct" % rel)

    if problems:
        sys.stderr.write("annex-b: the specification and the cases disagree.\n")
        for p in problems:
            sys.stderr.write("    " + p + "\n")
        sys.stderr.write(
            "\nAnnex B of doc/afterschool-pascal-spec.md records what each "
            "conformance mode says\nabout each dialect construct. It is a "
            "conformance claim (ADR-0117, ADR-0154), so it\nneeds a case per "
            "mode and a golden that matches.\n")
        sys.exit(1)

    print("annex-b: %d dialect constructs, %d cases, and every golden says what "
          "the annex does" % (len(rows), 2 * len(rows)))


if __name__ == "__main__":
    main()
