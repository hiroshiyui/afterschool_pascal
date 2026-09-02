#!/usr/bin/env python3
# Afterschool Pascal -- a Pascal compiler written in Pascal.
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

"""Does `pascalc --format` preserve the program it was given? (ADR-0279)

Three claims, over every Pascal source this repository tracks.

**The tokens are the same.** `--dump-tokens` writes one line per token, and
what this compares is every field of it *but the position* -- the kind, the
spelling, the value. That comparison is not a sample of what could go wrong:
the parser sees the token stream and nothing else, so two sources with the
same token stream compile to the same program, by construction. It is the
whole semantic claim and it costs one flag.

**The comments are the same.** `--dump-trivia` writes one line per comment,
and again everything but the position is compared -- the words, and the index
of the token it precedes. A formatter that dropped a comment, reordered two,
or moved one from before a token to after it fails here and nowhere else: the
token stream would be unchanged. Runs of blanks are collapsed, because a
comment carried two levels to the right keeps its shape and so has different
text and the same words; moving one is what a formatter is for.

**Formatting is idempotent.** Format the output again and it must come back
byte for byte. A layout rule that depends on where the input happened to have
its line breaks passes the first two claims and fails this one, which is what
makes this the claim about the *rules* rather than about a run of them.

What none of the three says is that the output is well laid out. There is no
oracle for that and this does not pretend to one -- which is also why nothing
in this tree is formatted by it (doc/sop.md §7).
"""

import random
import subprocess
import sys
import tempfile
from pathlib import Path

# A floor, for variant-check's reason: an instrument that measures nothing
# must not pass by measuring nothing.
FLOOR = 500


def run(pascalc, args):
    # latin-1, not utf-8: a Pascal source may hold any byte a string-literal
    # can (6.1.7), and tests/highchar.pas holds bytes that are no UTF-8 at
    # all. What is compared here is bytes, so the codec has to be one that
    # round-trips every one of them.
    return subprocess.run([str(pascalc), *args], capture_output=True,
                          text=True, encoding="latin-1")


def strip_positions(text, keep_from, squeeze=False):
    """A dump line without its position fields.

    `squeeze` collapses runs of blanks, which is what makes the comment
    comparison a comparison of the commentary: --dump-trivia writes a
    multi-line comment with its newlines folded to spaces, so a comment moved
    two levels to the right has different *text* and the same words. What is
    being asserted is that every comment is still there, still says what it
    said and still stands before the same token -- not that its interior
    indentation is untouched, which is exactly the thing a formatter moves.
    """
    out = []
    for line in text.splitlines():
        parts = line.split(" ")
        if len(parts) > keep_from:
            line = " ".join(parts[keep_from:])
        if squeeze:
            line = " ".join(line.split())
        out.append(line)
    return out


# Walked, and then filtered through git only if git answers. Asking
# `git ls-files` outright is what this harness did until it reached CI, where
# it exits 128 in a container whose checkout git calls dubiously owned -- the
# sweep then read an empty list, in all four jobs, and `clause_citations.py`
# had already recorded that hazard in a comment before this file was written.
# The floor below is what turned it into a failure rather than a green gate
# sweeping nothing, which is the whole reason a floor is there.
#
# The four roots are `variant_check.sh`'s, for its reason: what git *ignores*
# is not part of this, because the count is printed and has to mean the same
# thing on every machine -- a checkout still holding the retired BSI suite
# (ADR-0232 gitignored it) has 224 more sources on disk than a clean clone.
# Naming roots rather than walking from the top also keeps `.claude/worktrees`
# out, a background agent's worktree being a whole second copy of every source
# inside the checkout. An untracked source that is not ignored stays in scope:
# a case added and not yet staged is exactly what a sweep should reach.
ROOTS = ("tests", "selfhost", "lib", "lsp", "examples")


def pascal_sources(root: Path) -> list:
    found = sorted(str(p.relative_to(root))
                   for r in ROOTS for p in (root / r).rglob("*.pas"))
    if not found:
        return found
    ignored = subprocess.run(
        ["git", "-C", str(root), "check-ignore", "--stdin"],
        input="\n".join(found), capture_output=True, text=True)
    # check-ignore exits 1 when nothing matched, which is the ordinary case,
    # and 128 where git will not speak for this checkout at all. Only the
    # first is a list to subtract.
    if ignored.returncode in (0, 1):
        drop = set(ignored.stdout.split())
        found = [f for f in found if f not in drop]
    return found


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2]
    build = Path(sys.argv[sys.argv.index("--build") + 1]) if "--build" in sys.argv else root / "build"
    pascalc = build / "bin" / "pascalc"
    if not pascalc.exists():
        print(f"format-check: {pascalc} is missing -- skipping")
        return 77

    sources = pascal_sources(root)

    # A directory of its own, and not a fixed path under the build tree. The
    # suite is run in parallel (ADR-0281) and what makes that safe is that
    # every harness here works in a directory it created for the run; a fixed
    # path is safe only for as long as nothing else ever wants the same name,
    # which is a property of the *rest* of the tree rather than of this file.
    with tempfile.TemporaryDirectory(prefix="format-check.") as tmp:
        return sweep(pascalc, root, sources, Path(tmp))



# The claim for `--format --range=L:H` (ADR-0284), and it is the *semantic*
# one rather than the layout one. A range's output cannot be compared with the
# whole file's: a boundary inside a construct forces a line break there, which
# the whole-file format would not have -- that is inherent to formatting part
# of a file and every language server does it. What survives is the claim that
# matters, and it is the same one the whole-file sweep makes: the tokens must
# be the tokens the input has on those lines, in that order.
#
# Two ranges per source, chosen from a fixed seed so the suite is a regression
# corpus and not a search -- ADR-0275's rule, met again.
RANGE_SEED = 4831


def token_stream(pascalc, path, work):
    r = run(pascalc, ["--dump-tokens", str(path)])
    if r.returncode != 0:
        return None
    out = []
    for line in r.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[0].isdigit():
            out.append((int(parts[0]), " ".join(parts[2:])))
    return out


def check_range(pascalc, src, name, work, bad) -> int:
    whole = token_stream(pascalc, src, work)
    if whole is None:
        return 0
    lines = src.read_text(encoding="latin-1").count("\n") + 1
    if lines < 8:
        return 0
    rng = random.Random(RANGE_SEED + len(name))
    frag = work / "range.pas"
    for _ in range(2):
        lo = rng.randint(1, lines - 3)
        hi = rng.randint(lo + 1, lines - 1)
        r = run(pascalc, ["--format", f"--range={lo}:{hi}", str(src)])
        if r.returncode != 0:
            bad.append(f"{name}: --range={lo}:{hi} failed where --format did not")
            return 0
        frag.write_text(r.stdout, encoding="latin-1")
        got = token_stream(pascalc, frag, work)
        if got is None:
            bad.append(f"{name}: --range={lo}:{hi} produced something the lexer rejects")
            return 0
        want = [k for ln, k in whole if lo <= ln <= hi and k != "eof"]
        have = [k for _, k in got if k != "eof"]
        if want != have:
            where = next((i for i, (x, y) in enumerate(zip(want, have)) if x != y),
                         min(len(want), len(have)))
            bad.append(f"{name}: --range={lo}:{hi} changed the token stream "
                       f"({len(want)} wanted, {len(have)} got, first differing at "
                       f"{where})")
            return 0
    return 1


def sweep(pascalc: Path, root: Path, sources: list, work: Path) -> int:
    formatted = work / "formatted.pas"
    again = work / "again.pas"

    checked, skipped, ranged, bad = 0, 0, 0, []
    for name in sources:
        src = root / name
        first = run(pascalc, ["--format", str(src)])
        if first.returncode != 0:
            # A source the *lexer* rejects has no token stream to preserve.
            # Nothing else stops --format, so this is a small and honest set.
            skipped += 1
            continue
        formatted.write_text(first.stdout, encoding="latin-1")

        for flag, keep in (("--dump-tokens", 2), ("--dump-trivia", 5)):
            a = run(pascalc, [flag, str(src)])
            b = run(pascalc, [flag, str(formatted)])
            if a.returncode != 0 or b.returncode != 0:
                bad.append(f"{name}: {flag} failed on the formatted source")
                break
            squeeze = flag == "--dump-trivia"
            wanted = strip_positions(a.stdout, keep, squeeze)
            got = strip_positions(b.stdout, keep, squeeze)
            if wanted != got:
                for i, (x, y) in enumerate(zip(wanted, got)):
                    if x != y:
                        bad.append(f"{name}: {flag} differs at record {i + 1}\n"
                                   f"      was: {x}\n      now: {y}")
                        break
                else:
                    bad.append(f"{name}: {flag} has {len(wanted)} records "
                               f"before formatting and {len(got)} after")
                break
        else:
            second = run(pascalc, ["--format", str(formatted)])
            if second.returncode != 0:
                bad.append(f"{name}: the formatted source could not be formatted again")
            elif second.stdout != first.stdout:
                again.write_text(second.stdout, encoding="latin-1")
                first_lines = first.stdout.splitlines()
                second_lines = second.stdout.splitlines()
                for i, (x, y) in enumerate(zip(first_lines, second_lines)):
                    if x != y:
                        bad.append(f"{name}: formatting is not idempotent, line {i + 1}\n"
                                   f"      once:  {x!r}\n      twice: {y!r}")
                        break
                else:
                    bad.append(f"{name}: formatting is not idempotent "
                               f"({len(first_lines)} lines then {len(second_lines)})")
            else:
                checked += 1
                ranged += check_range(pascalc, src, name, work, bad)

    if bad:
        print(f"format-check: {len(bad)} of {len(sources)} sources are not "
              f"preserved by --format", file=sys.stderr)
        for line in bad[:20]:
            print(f"    {line}", file=sys.stderr)
        if len(bad) > 20:
            print(f"    ... and {len(bad) - 20} more", file=sys.stderr)
        return 1

    if checked < FLOOR:
        print(f"format-check: only {checked} sources were formatted, and this "
              f"tree has far more than that -- the sweep found nothing to do",
              file=sys.stderr)
        return 1

    print(f"format-check: {checked} sources format to the same tokens and the "
          f"same comments, and format again to the same text "
          f"({skipped} the lexer rejects); {ranged} of them keep their token "
          f"stream when only part of them is asked for")
    return 0


if __name__ == "__main__":
    sys.exit(main())
