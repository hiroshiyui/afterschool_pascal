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

"""How much of the token array this compiler's own source still leaves free.

`selfhost/compiler.pas` is the largest Pascal in the tree and the one that has
to keep fitting, and it reads its input into fixed arrays (ADR-0012). Twice the
loud failure that produced has been the **build**: the array that has to hold
this source is the *seed's*, and raising the constant in the source does not
raise the seed's, so the only way out is to reseed. ADR-0095 did that for the
string pool, at 74 characters over; ADR-0126 for the token array, which was
found with **107 tokens** of headroom left out of 140000 -- 0.08%.

ADR-0095 closed with "nothing measures the headroom", and that sentence is why
it happened a second time. This is the measurement.

**Only the token array is measured.** `--dump-tokens` writes one line per token
and a Pascal string-literal cannot contain a newline (6.1.7), so the line count
*is* the token count -- exact, and it needs nothing of the compiler that is not
already a documented flag. The string pool has no such answer: PoolAdd is called
from Sema and from CodeGen as well as from the lexer -- a type's alias name, a
trap message -- so no count taken over the token stream is its size, only a
lower bound. doc/sop.md §7 carries that gap. A `--dump-limits` reporting poolLen
and tokCount would close it exactly, and is the move if the pool bites again.

The threshold is 80%: high enough that ordinary growth does not trip it, low
enough that the reseed it asks for is a scheduled decision rather than a wall
the next commit hits.
"""

import re
import subprocess
import sys
from pathlib import Path

THRESHOLD = 0.80


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2]
    build = Path(sys.argv[sys.argv.index("--build") + 1]) if "--build" in sys.argv else root / "build"

    source = root / "selfhost" / "compiler.pas"
    pascalc = build / "bin" / "pascalc"
    if not pascalc.exists():
        print(f"buffer-headroom: {pascalc} is missing -- skipping")
        return 77

    text = source.read_text(encoding="utf-8", errors="replace")
    m = re.search(r"^\s*tokMax\s*=\s*(\d+)", text, re.M)
    if m is None:
        print("buffer-headroom: tokMax is not declared as a constant any more")
        return 1
    tok_max = int(m.group(1))

    std = (root / "selfhost" / "compiler.std").read_text().strip()
    run = subprocess.run(
        [str(pascalc), f"--std={std}", "--dump-tokens", str(source), "-o", "/dev/null"],
        capture_output=True, text=True,
    )
    if run.returncode != 0:
        print("buffer-headroom: the compiler could not read its own source")
        print(run.stdout[-2000:])
        return 1
    used = sum(1 for line in run.stdout.splitlines() if line)

    frac = used / tok_max
    print(f"buffer-headroom: {used} of {tok_max} tokens, {100 * (1 - frac):.1f}% free")
    if frac > THRESHOLD:
        print(
            f"buffer-headroom: the token array is {100 * frac:.1f}% full, over the "
            f"{100 * THRESHOLD:.0f}% mark.\n"
            "  Raising tokMax alone does not help: seed/pascalc.ll carries the old\n"
            "  bound and it is the seed that translates this source. Raise tokMax on a\n"
            "  tree that still builds, then seed/refresh.sh, as ADR-0095 and ADR-0126\n"
            "  each did -- and say so in the commit, because it rewrites 6 MB."
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
