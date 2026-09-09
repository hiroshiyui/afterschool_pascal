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

r"""A number a document quotes from a gate is still that gate's answer.

**This is the one shape the documentation procedure is structurally blind
to.** `.claude/skills/docs-engineering/SKILL.md` audits what a document says
about the *code*, and a document quoting a *gate* is a different question --
it says so itself, in the paragraph beginning "That last shape is the one this
skill is structurally blind to". Saying so has not been enough. Two audits of
`doc/sop.md` §7 have now found the register clean and the documents around it
carrying stale numbers, six of them on 2026-09-09:

    target32          597 of 598 where README said 573 of 574
    valgrind-corpus   389 programs where CLAUDE.md said 377
    sanitizers        389 programs where CLAUDE.md said 383
    thread-sanitizer  fifteen qualify where CLAUDE.md said eleven
    lib-coverage      33 modules where two files said 32
    (the triage)      144 and 390 rows where §7 said 51 and some 340

Every one was found by running the gate and by nothing else. A person who
reads the sentence cannot tell a number that was true when it was written from
one that is true now, and neither can any other oracle here.

**What makes this cheap is that the gates already print their own answers.**
`ctest` records every case's output in `build/Testing/Temporary/LastTest.log`,
so the numbers are there for the reading -- the gate's own summary line, in
the gate's own words -- and nothing has to be re-run. `valgrind-corpus` alone
is 170 seconds; a check that re-ran what it quotes would be a second suite.

**So this is not a `ctest` case, and cannot be**: during a run that log holds
whatever has finished so far, and a case reading it would be reading a
previous run or a partial one. It is a script, run after the suite -- by hand
and by a CI step -- which is `seed_current.py`'s shape and for a related
reason (ADR-0233).

The catalogue is `tests/checks/quoted_numbers.txt`: a document, the gate whose
answer it quotes, and a pattern matched against the document. **Every number
the pattern captures must appear in that gate's summary**, and both directions
are checked -- a pattern that stops matching is a sentence reworded away from
its row, which is how a catalogue rots.

Usage:  tests/checks/quoted_numbers.py [--log PATH] [--root DIR]
"""

import argparse
import os
import pathlib
import re
import subprocess
import sys

CATALOGUE = "tests/checks/quoted_numbers.txt"
# What the gates measure. A log written before any of this changed is a log
# about a tree that no longer exists.
WATCHED = ("selfhost", "lib", "lsp", "runtime", "tests", "examples", "tools")
DEFAULT_LOG = "build/Testing/Temporary/LastTest.log"
FLOOR = 8          # rows a catalogue must hold, or it is watching nothing

# This tree spells a small count as a word, deliberately and everywhere, so a
# check that could only read digits would be a check that asks documents to
# stop writing English. `fifteen qualify` is exactly one of the six.
WORDS = {w: i for i, w in enumerate(
    ("zero one two three four five six seven eight nine ten eleven twelve "
     "thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty"
     ).split())}


def numbers(text):
    """Every integer in a line, digits or English, spaces and commas ignored.

    A gate writes `3 556` and a document may write `3,556` or `3556`."""
    out = set()
    for m in re.finditer(r"\d[\d  ,]*", text):
        out.add(int(re.sub(r"[  ,]", "", m.group(0))))
    for w, n in WORDS.items():
        if re.search(rf"\b{w}\b", text, re.IGNORECASE):
            out.add(n)
    return out


# `ctest` writes no summary of its own into this log -- it writes the running
# `<n>/<total> Testing: <name>` before each case, which is where the size of
# the suite is. One synthetic gate rather than a second mechanism, because
# *how many cases there are* is the number two documents quote and the one a
# reader is likeliest to trust.
RUNNING = re.compile(r"^\s*\d+/(\d+) Testing: ")
SKIPPED = re.compile(r"\s*(skipped|skipping|no )", re.IGNORECASE)


def summaries(log, gate):
    """The lines a gate wrote about itself.

    A gate's own summary begins with its name and a colon -- the convention
    every check in this directory follows -- so the lines are found without
    knowing which ctest case wrote them. `sanitize.py` is the exception worth
    naming: it runs in four modes and writes `sanitize[address]:`, so the
    catalogue names the mode."""
    if gate == "ctest":
        totals = {m.group(1) for m in
                  (RUNNING.match(ln) for ln in log.split("\n")) if m}
        return [f"ctest: {t} cases in the suite" for t in sorted(totals)]
    said = [ln for ln in log.split("\n") if ln.strip().startswith(gate + ":")]
    # **A gate that skipped still writes a line**, and it is not an answer:
    # `target32: skipped -- clang cannot link for i386-pc-linux-gnu` carries
    # the numbers 32 and 386 out of the triple, and comparing a document
    # against those reports the document as wrong. Anchored after the colon,
    # because `sanitize[address]`'s real summary ends `209 skipped` and that
    # one *is* an answer.
    return [ln for ln in said if not SKIPPED.match(ln.strip()[len(gate) + 1:])]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=str(
        pathlib.Path(__file__).resolve().parents[2]))
    ap.add_argument("--log", default=None)
    args = ap.parse_args()
    root = pathlib.Path(args.root)
    log_path = pathlib.Path(args.log) if args.log else root / DEFAULT_LOG

    # A skip is right by hand -- the log is a suite run's leavings and a
    # developer may not have made one -- and wrong in a job that has just run
    # the suite, which is `require-consistency`'s rule (ADR-0330): a gate that
    # can skip needs somewhere that refuses to let it.
    require = os.environ.get("QUOTED_NUMBERS_REQUIRE")

    def absent(why):
        if require:
            print(f"quoted-numbers: {why} -- and QUOTED_NUMBERS_REQUIRE is "
                  f"set, so this is a failure rather than a skip",
                  file=sys.stderr)
            return 1
        print(f"quoted-numbers: {why}", file=sys.stderr)
        return 77

    if not log_path.exists():
        return absent(f"no {log_path}; run the suite first -- "
                      f"ctest --test-dir build -j\"$(nproc)\"")

    # **A stale log is worse than none**, because it answers. If anything the
    # gates measure has been touched since the run that wrote it, the numbers
    # in it are about a tree that no longer exists -- so this refuses rather
    # than comparing, and the refusal names the newer file.
    #
    # The roots are walked rather than asked of `git ls-files`, which exits
    # 128 in a container whose checkout git calls dubiously owned -- the
    # hazard `format_check.py` records and `markdown-links` was caught by on
    # its first CI run. An answer of *nothing is newer* has to mean the tree
    # was not touched, never that git declined to say.
    stamp = log_path.stat().st_mtime
    newer = [str(f.relative_to(root))
             for r in WATCHED for f in (root / r).rglob("*")
             if f.is_file() and f.stat().st_mtime > stamp]
    if newer:
        return absent(f"{log_path.name} is older than {len(newer)} tracked "
                      f"file(s) -- {newer[0]} among them. The numbers in it "
                      f"are about a tree that has changed; run the suite "
                      f"again")

    log = log_path.read_text(encoding="utf-8", errors="replace")
    fails, rows, checked, unchecked = [], 0, 0, []
    for raw in (root / CATALOGUE).read_text().split("\n"):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = [p.strip() for p in line.split("|")]
        if len(parts) != 3:
            fails.append(f"{CATALOGUE}: a row is <document> | <gate> | "
                         f"<pattern>, and this is not: {line[:60]}")
            continue
        doc, gate, pattern = parts
        rows += 1
        target = root / doc
        if not target.exists():
            fails.append(f"{CATALOGUE} names {doc}, which does not exist")
            continue
        said = summaries(log, gate)
        if not said:
            # **Not every gate runs in every job.** `target32`, the four
            # `sanitize` modes and `runtime-nonposix` each have a job of their
            # own here, so a `test` job's log holds no answer from them --
            # and neither does a developer's run on a machine without a
            # 32-bit libc or mingw-w64. The row is *reported unchecked*
            # rather than failed, which is `setjmp-arity`'s arrangement
            # (ADR-0371): compare where the answer is available, say plainly
            # where it was not, and refuse only if nothing could be compared.
            unchecked.append(f"{doc} <- {gate}")
            continue
        theirs = set()
        for ln in said:
            theirs |= numbers(ln)
        text = target.read_text(encoding="utf-8", errors="replace")
        hits = list(re.finditer(pattern, text))
        if not hits:
            fails.append(f"{doc}: nothing matches /{pattern}/ any more -- the "
                         f"sentence was reworded and the row went stale with "
                         f"it, which is how a catalogue stops watching")
            continue
        for m in hits:
            for got in m.groups():
                checked += 1
                mine = numbers(got)
                if not mine:
                    fails.append(f"{doc}: /{pattern}/ captured '{got}', which "
                                 f"is not a number")
                elif not mine <= theirs:
                    where = text[:m.start()].count("\n") + 1
                    fails.append(
                        f"{doc}:{where}: says {got}, and {gate} answers "
                        f"{sorted(theirs)} -- the sentence quotes a number the "
                        f"gate no longer reports:\n      {said[0].strip()[:150]}")

    if rows < FLOOR:
        fails.append(f"{CATALOGUE} holds {rows} row(s), below the floor of "
                     f"{FLOOR} -- a catalogue that names nothing passes")
    if rows and not checked:
        fails.append(f"not one of {rows} row(s) could be compared -- every "
                     f"gate they name is absent from this log, so this is not "
                     f"a suite run this catalogue is about")
    if fails:
        print("quoted-numbers:", file=sys.stderr)
        for f in fails:
            print("  " + f, file=sys.stderr)
        return 1
    note = ""
    if unchecked:
        note = (f"; {len(unchecked)} row(s) unchecked, their gate not having "
                f"run here -- " + ", ".join(sorted(unchecked)))
    print(f"quoted-numbers: {checked} number(s) quoted across "
          f"{rows - len(unchecked)} of {rows} row(s) are each still what the "
          f"gate reports{note}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
