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

import subprocess
import sys
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


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2]
    build = Path(sys.argv[sys.argv.index("--build") + 1]) if "--build" in sys.argv else root / "build"
    pascalc = build / "bin" / "pascalc"
    if not pascalc.exists():
        print(f"format-check: {pascalc} is missing -- skipping")
        return 77

    sources = subprocess.run(
        ["git", "ls-files", "*.pas"], cwd=root, capture_output=True, text=True
    ).stdout.split()

    work = build / "format-check"
    work.mkdir(parents=True, exist_ok=True)
    formatted = work / "formatted.pas"
    again = work / "again.pas"

    checked, skipped, bad = 0, 0, []
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
          f"({skipped} the lexer rejects)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
