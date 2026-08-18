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

"""model_drift.resolve_base, against a repository built for the purpose.

The model-drift gate itself is CI-only -- it needs a push range, which no local
run has. Its *base resolution* is not: it is a pure question about one
repository, and it is the half that has actually broken. A force-push reports a
base that is a real 40-hex SHA and is not in the repository any more, and the
obvious way to ask git whether that is a commit answers yes; the workflow asked
it that way and the job died in `git diff` (run 32131932455).

So this is the part that gets a case, and the fourth one below is the case:
revert `git cat-file -e "$rev^{commit}"` to `git rev-parse --verify "$rev"` and
it is the only one that fails.
"""

import importlib.util
import os
import pathlib
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent

spec = importlib.util.spec_from_file_location(
    "model_drift", HERE / "model_drift.py")
model_drift = importlib.util.module_from_spec(spec)
spec.loader.exec_module(model_drift)

# A 40-hex string that is a well-formed object name and is not in the
# repository under test -- which is what a force-push hands the gate.
DISCARDED = "e99beb6fbf7d4a3c3ae1fc4dd01519637900145c"
ALL_ZERO = "0" * 40

failures = []


def check(what, got, want):
    if got == want:
        print(f"  ok   {what}: {got}")
    else:
        print(f"  FAIL {what}: got {got}, wanted {want}")
        failures.append(what)


def git(*args):
    subprocess.run(("git",) + args, check=True, capture_output=True)


def rev(spec_):
    return subprocess.run(("git", "rev-parse", spec_), check=True,
                          capture_output=True, text=True).stdout.strip()


with tempfile.TemporaryDirectory() as tmp:
    os.chdir(tmp)
    git("init", "-q", ".")
    git("config", "user.email", "t@example.invalid")
    git("config", "user.name", "t")
    git("commit", "-q", "--allow-empty", "-m", "one")
    root = rev("HEAD")
    git("commit", "-q", "--allow-empty", "-m", "two")
    git("commit", "-q", "--allow-empty", "-m", "three")
    head, parent = rev("HEAD"), rev("HEAD^")
    empty_tree = subprocess.run(
        ("git", "hash-object", "-t", "tree", "/dev/null"),
        check=True, capture_output=True, text=True).stdout.strip()

    print("resolve_base:")
    check("a base that is here is kept",
          model_drift.resolve_base(root, head), root)
    check("no base at all falls back to the single commit",
          model_drift.resolve_base("", head), f"{head}^")
    check("an all-zero base falls back to the single commit",
          model_drift.resolve_base(ALL_ZERO, head), f"{head}^")
    check("a discarded 40-hex base falls back to the single commit",
          model_drift.resolve_base(DISCARDED, head), f"{head}^")
    check("a head with no parent falls back to the empty tree",
          model_drift.resolve_base("", root), empty_tree)

    # Whatever it returned has to be usable as the left half of a range --
    # dying in `git diff` one line later is the failure this is about.
    print("and each answer is a range git will take:")
    for base in (root, model_drift.resolve_base("", head),
                 model_drift.resolve_base("", root)):
        target = root if base == empty_tree else head
        done = subprocess.run(("git", "diff", "--name-only",
                               f"{base}..{target}"), capture_output=True)
        check(f"git diff {base[:8]}..{target[:8]}", done.returncode, 0)

    # And `parent` is what the fallback spells, so it must name that commit.
    check("the fallback names the parent commit", rev(f"{head}^"), parent)

if failures:
    print(f"\n{len(failures)} check(s) failed")
    sys.exit(1)
print("\nmodel-drift base resolution: every case as intended")
