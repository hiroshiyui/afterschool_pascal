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

"""The specification suite: scenarios written against clauses of the standards.

Every other oracle here starts from the compiler and asks whether it still does
what it did. This one starts from a **clause** and asks what the compiler does
about it -- which is the one direction no oracle in doc/sop.md §1 covers, since
a golden agrees with whoever wrote it and `verify/` proves a model against a
model. A scenario cannot contradict a misreading either, but it *names the
clause it claims to be about*, so a wrong reading is at least findable by
someone holding the standard. ADR-0105 has the argument.

The dialect is a subset of Gherkin, parsed here in about two hundred lines
rather than by a framework, because this repository needs cmake, make and clang
and nothing else -- z3 is its one optional extra and it skips without it.

    @iso7185:6.8.3.9
    Feature: For-statements

      Scenario: the bounds are checked under the entry test
        Given the ISO 7185 program
          \"\"\"
          program p(output);
          ...
          \"\"\"
        When it is compiled and run
        Then it exits successfully
         And it prints nothing

Steps, in full -- there are no others, and an unrecognised one is an **error**
rather than a skip. A step that silently does nothing is a scenario that
asserts nothing, which is the failure this whole suite exists to avoid:

    Given the ISO 7185 program            <docstring>
    Given the Extended Pascal program     <docstring>
    Given the standard input              <docstring>
    When it is compiled and run
    When it is compiled
    Then it exits successfully
    Then it prints                        <docstring>
    Then it prints nothing
    Then it is rejected
    Then the diagnostic includes          <docstring>
    Then it stops at run time
    Then the run-time error includes      <docstring>

Usage:

    python3 tests/spec/run.py --pascalcc tools/pascalcc          # run them
    python3 tests/spec/run.py --coverage                         # clause report
    python3 tests/spec/run.py --pascalcc tools/pascalcc -k for   # by name
"""

import argparse
import os
import pathlib
import re
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
TAG = re.compile(r"@(iso7185|extended):(\d+(?:\.\d+)*)")

STANDARD_OF = {
    "the ISO 7185 program": "iso7185",
    "the Extended Pascal program": "extended",
}


class SpecError(Exception):
    """A fault in a .feature file, as opposed to a compiler that failed."""


# --------------------------------------------------------------------------
# parsing


class Step:
    def __init__(self, keyword, text, doc, line):
        self.keyword, self.text, self.doc, self.line = keyword, text, doc, line


class Scenario:
    def __init__(self, name, tags, steps, path, line):
        self.name, self.tags, self.steps = name, tags, steps
        self.path, self.line = path, line

    def __str__(self):
        return f"{self.path.name}:{self.line}: {self.name}"


def dedent(lines, indent):
    """Docstring content, relative to the indentation of its own delimiter --
    which is Gherkin's rule and the only one that lets a Pascal program keep
    its own indentation inside an indented scenario."""
    out = []
    for line in lines:
        out.append(line[indent:] if line[:indent].strip() == "" else line.lstrip())
    return "\n".join(out)


def parse(path):
    """One .feature file into scenarios. Deliberately strict: this is a
    specification, and a typo that quietly drops an assertion would be worse
    than a parse error."""
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    scenarios, feature_tags, pending_tags = [], [], []
    current, i = None, 0

    while i < len(lines):
        raw = lines[i]
        stripped = raw.strip()
        i += 1

        if not stripped or stripped.startswith("#"):
            continue
        if stripped.startswith("@"):
            pending_tags += TAG.findall(stripped)
            unknown = [t for t in stripped.split() if not TAG.fullmatch(t)]
            if unknown:
                raise SpecError(f"{path.name}:{i}: unrecognised tag {unknown[0]} "
                                "(expected @iso7185:<clause> or @extended:<clause>)")
            continue
        if stripped.startswith("Feature:"):
            feature_tags, pending_tags = pending_tags, []
            continue
        if stripped.startswith("Scenario:"):
            current = Scenario(stripped[len("Scenario:"):].strip(),
                               feature_tags + pending_tags, [], path, i)
            scenarios.append(current)
            pending_tags = []
            continue

        m = re.match(r"(Given|When|Then|And)\s+(.*)$", stripped)
        if not m:
            raise SpecError(f"{path.name}:{i}: not a step or a heading: {stripped!r}")
        if current is None:
            raise SpecError(f"{path.name}:{i}: step outside a scenario")

        keyword, body = m.group(1), m.group(2).strip()
        doc = None
        # A docstring belongs to the step above it.
        j = i
        while j < len(lines) and not lines[j].strip():
            j += 1
        if j < len(lines) and lines[j].strip() == '"""':
            indent = len(lines[j]) - len(lines[j].lstrip())
            body_lines, j = [], j + 1
            while j < len(lines) and lines[j].strip() != '"""':
                body_lines.append(lines[j])
                j += 1
            if j >= len(lines):
                raise SpecError(f"{path.name}:{i}: unterminated docstring")
            doc = dedent(body_lines, indent)
            i = j + 1
        current.steps.append(Step(keyword, body, doc, i))

    if pending_tags:
        raise SpecError(f"{path.name}: tags at end of file belong to nothing")
    return scenarios


# --------------------------------------------------------------------------
# running


class Outcome:
    def __init__(self):
        self.source = self.standard = None
        self.stdin = ""
        self.compiled = None      # True / False, once a When has run
        self.diagnostic = ""
        self.stdout = ""
        self.stderr = ""
        self.status = None
        self.ran = False


def compile_and_maybe_run(out, pascalcc, work, run_it):
    src = work / "scenario.pas"
    src.write_text(out.source)
    exe = work / "scenario"
    proc = subprocess.run([str(pascalcc), f"--std={out.standard}",
                           str(src), "-o", str(exe)],
                          capture_output=True, text=True, timeout=300)
    # pascalcc puts the compiler's diagnostics on stderr; take both so a
    # scenario cannot pass by matching the wrong stream.
    out.diagnostic = proc.stdout + proc.stderr
    out.compiled = proc.returncode == 0
    if not out.compiled or not run_it:
        return
    stdin_path = work / "stdin.txt"
    stdin_path.write_text(out.stdin)
    with open(stdin_path) as fh:
        r = subprocess.run([str(exe)], stdin=fh, capture_output=True,
                           text=True, timeout=300)
    out.ran, out.stdout, out.stderr, out.status = True, r.stdout, r.stderr, r.returncode


def need_doc(step):
    if step.doc is None:
        raise SpecError(f"{step.text!r} needs a \"\"\" block after it")
    return step.doc


def run(scenario, pascalcc, work):
    """Every assertion this scenario makes, or the first that failed."""
    out = Outcome()

    def require_when(what):
        if out.compiled is None:
            raise SpecError(f"{what!r} before any When step")

    for step in scenario.steps:
        text = step.text

        if text in STANDARD_OF:
            out.source, out.standard = need_doc(step), STANDARD_OF[text]
        elif text == "the standard input":
            out.stdin = need_doc(step) + "\n"

        elif text in ("it is compiled and run", "it is compiled"):
            if out.source is None:
                raise SpecError("a When step before any Given program")
            compile_and_maybe_run(out, pascalcc, work,
                                  text == "it is compiled and run")

        elif text == "it exits successfully":
            require_when(text)
            if not out.compiled:
                return f"expected it to compile; the compiler said:\n{out.diagnostic.rstrip()}"
            if out.status != 0:
                return (f"expected exit 0, got {out.status}"
                        + (f"\n{out.stderr.rstrip()}" if out.stderr.strip() else ""))
        elif text == "it prints":
            require_when(text)
            want = need_doc(step)
            if not out.compiled:
                return f"expected it to compile; the compiler said:\n{out.diagnostic.rstrip()}"
            if out.stdout.rstrip("\n") != want.rstrip("\n"):
                return f"expected output:\n{want}\n--- got ---\n{out.stdout.rstrip()}"
        elif text == "it prints nothing":
            require_when(text)
            if out.stdout.strip() != "":
                return f"expected no output, got:\n{out.stdout.rstrip()}"
        elif text == "it is rejected":
            require_when(text)
            if out.compiled:
                return "expected the compiler to refuse it, but it compiled"
        elif text == "the diagnostic includes":
            require_when(text)
            want = need_doc(step).strip()
            if want not in out.diagnostic:
                return f"expected a diagnostic containing:\n{want}\n--- got ---\n{out.diagnostic.rstrip()}"
        elif text == "it stops at run time":
            require_when(text)
            if not out.compiled:
                return f"expected it to compile; the compiler said:\n{out.diagnostic.rstrip()}"
            if not out.ran:
                raise SpecError("'it stops at run time' needs 'When it is compiled and run'")
            if out.status == 0:
                return "expected it to stop at run time, but it exited 0"
        elif text == "the run-time error includes":
            require_when(text)
            want = need_doc(step).strip()
            if want not in out.stderr:
                return f"expected a run-time error containing:\n{want}\n--- got ---\n{out.stderr.rstrip()}"
        else:
            raise SpecError(f"unknown step: {step.keyword} {text!r}")

    if out.compiled is None:
        raise SpecError("no When step, so the scenario asserts nothing")
    return None


# --------------------------------------------------------------------------
# clause coverage


def triage():
    """clause -> (class, reason), per standard. ADR-0106 has the argument for
    why the denominator needs triaging at all."""
    path = HERE / "clauses" / "triage.tsv"
    out = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("#") or not line.strip():
            continue
        std, clause, klass, reason = (line.split("\t") + ["", "", ""])[:4]
        out.setdefault(std, {})[clause] = (klass, reason)
    return out


def pending_file():
    return HERE / "clauses" / "pending.txt"


def read_pending():
    path = pending_file()
    if not path.exists():
        return None
    return {line.strip() for line in path.read_text().splitlines()
            if line.strip() and not line.startswith("#")}


def check_clauses(scenarios):
    """The gate: fails in both directions, as uncovered_procedures.txt does.

    A clause that stops being cited is a scenario lost. A clause cited that the
    triage calls structural or unimplemented is either a mis-tagged scenario or
    a wrong triage, and both are worth hearing about. A clause that *starts*
    being cited is not a failure to be fixed but a list to regenerate -- said
    in those words, so nobody reads it as a defect."""
    tri, cited = triage(), coverage(scenarios)
    problems = []

    for std, clauses in cited.items():
        known = tri.get(std, {})
        for clause in sorted(clauses):
            if clause not in known:
                problems.append(f"{std} §{clause} is cited by "
                                f"{clauses[clause][0].name!r} but is not a clause "
                                "of that standard")
                continue
            klass, reason = known[clause]
            if klass != "testable":
                problems.append(
                    f"{std} §{clause} is cited by {clauses[clause][0].name!r} "
                    f"but is triaged {klass}: {reason}")

    testable = {f"{std}:{c}" for std, rows in tri.items()
                for c, (k, _) in rows.items() if k == "testable"}
    covered = {f"{std}:{c}" for std, rows in cited.items() for c in rows}
    now_pending = testable - covered

    recorded = read_pending()
    if recorded is None:
        print("spec: no pending list recorded; run --write-pending",
              file=sys.stderr)
        return 1

    lost = sorted(now_pending - recorded)
    gained = sorted(recorded - now_pending)

    for c in lost:
        problems.append(f"{c} was cited by a scenario and is not any more")

    for p in problems:
        print(f"spec: {p}")
    if problems:
        print(f"\nspec: {len(problems)} clause-traceability problems")
        return 1

    if gained:
        print(f"spec: {len(gained)} newly cited clause(s): "
              + ", ".join(gained))
        print("      regenerate the pending list: "
              "python3 tests/spec/run.py --write-pending")
        return 0

    print(f"spec: {len(covered)}/{len(testable)} testable clauses cited, "
          f"{len(now_pending)} pending, none lost or mis-tagged")
    return 0


def inventory():
    out = {}
    for name, std in (("iso7185", "iso7185"), ("iso10206", "extended")):
        path = HERE / "clauses" / f"{name}.tsv"
        if not path.exists():
            continue
        rows = {}
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.startswith("#") or not line.strip():
                continue
            number, _, title = line.partition("\t")
            rows[number.strip()] = title.strip()
        out[std] = rows
    return out


def coverage(scenarios):
    cited = {}
    for s in scenarios:
        for std, clause in s.tags:
            cited.setdefault(std, {}).setdefault(clause, []).append(s)
    return cited


def report(scenarios):
    inv, cited, tri = inventory(), coverage(scenarios), triage()
    print(f"specification suite: {len(scenarios)} scenarios\n")
    for std, label in (("iso7185", "ISO 7185:1990"),
                       ("extended", "ISO/IEC 10206:1991")):
        clauses = inv.get(std, {})
        have = cited.get(std, {})
        known = [c for c in have if c in clauses]
        unknown = sorted(c for c in have if c not in clauses)
        rows = tri.get(std, {})
        testable = [c for c, (k, _) in rows.items() if k == "testable"]
        other = len(rows) - len(testable)
        hit = [c for c in known if rows.get(c, ("", ""))[0] == "testable"]
        pct = 100.0 * len(hit) / len(testable) if testable else 0.0
        print(f"{label}: {len(hit)}/{len(testable)} testable clauses cited "
              f"({pct:.1f}%), {sum(len(v) for v in have.values())} citations")
        print(f"  {other} of its {len(clauses)} headings carry no requirement a "
              "scenario could exercise")
        for c in unknown:
            print(f"  ! {c} is cited but is not a clause of this standard")
    print("\nThe denominator is the *testable* clauses, triaged in "
          "clauses/triage.tsv (ADR-0106).\nRun --check-clauses for the gate.")


# --------------------------------------------------------------------------


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pascalcc", default=None)
    ap.add_argument("--coverage", action="store_true")
    ap.add_argument("--check-clauses", action="store_true",
                    help="the traceability gate; needs no compiler")
    ap.add_argument("--write-pending", action="store_true")
    ap.add_argument("-k", default=None, help="only scenarios whose name matches")
    ap.add_argument("feature", nargs="*",
                    help="feature files to run; all of them when none is named")
    args = ap.parse_args()

    # Named files let CMake register one case per feature, so a failure names
    # the clause area rather than "the spec suite".
    features = ([pathlib.Path(f) for f in args.feature] if args.feature
                else sorted((HERE / "features").glob("*.feature")))
    scenarios = []
    try:
        for path in features:
            scenarios += parse(path)
    except SpecError as e:
        print(f"spec: {e}", file=sys.stderr)
        return 1

    if not scenarios:
        print("spec: no scenarios found", file=sys.stderr)
        return 1

    if args.coverage:
        report(scenarios)
        return 0

    if args.write_pending:
        tri, cited = triage(), coverage(scenarios)
        testable = {f"{std}:{c}" for std, rows in tri.items()
                    for c, (k, _) in rows.items() if k == "testable"}
        covered = {f"{std}:{c}" for std, rows in cited.items() for c in rows}
        rest = sorted(testable - covered,
                      key=lambda s: (s.split(":")[0],
                                     [int(x) for x in s.split(":")[1].split(".")]))
        pending_file().write_text(
            "# Testable clauses no scenario cites yet (ADR-0106).\n"
            "#\n"
            "# Not a list of gaps to be ashamed of -- it is the work queue, and\n"
            "# the gate reads it so that a clause leaving this list without the\n"
            "# list being regenerated fails. Regenerate deliberately:\n"
            "#\n"
            "#     python3 tests/spec/run.py --write-pending\n"
            "#\n"
            "# and say in the commit message which clause gained a scenario.\n\n"
            + "\n".join(rest) + "\n")
        print(f"spec: {len(rest)} clauses pending -> {pending_file().name}")
        return 0

    if args.check_clauses:
        return check_clauses(scenarios)

    if not args.pascalcc:
        print("spec: --pascalcc is required to run scenarios", file=sys.stderr)
        return 2
    pascalcc = pathlib.Path(args.pascalcc).resolve()
    if not pascalcc.exists():
        print(f"spec: {pascalcc} does not exist", file=sys.stderr)
        return 1

    chosen = [s for s in scenarios if not args.k or args.k.lower() in s.name.lower()]
    failed = []
    with tempfile.TemporaryDirectory() as tmp:
        for n, s in enumerate(chosen):
            work = pathlib.Path(tmp) / str(n)
            work.mkdir()
            try:
                why = run(s, pascalcc, work)
            except SpecError as e:
                why = f"the scenario itself is wrong: {e}"
            except subprocess.TimeoutExpired:
                why = "timed out"
            if why:
                failed.append((s, why))
                print(f"FAIL  {s}\n      {why}".replace("\n", "\n      "))

    print(f"\nspec: {len(chosen) - len(failed)}/{len(chosen)} scenarios passed")
    if failed:
        print(f"spec: {len(failed)} failed")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
