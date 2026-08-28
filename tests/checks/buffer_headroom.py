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

"""How much of each fixed array this compiler's own source still leaves free.

The compiler is the largest Pascal in the tree and the one that has to keep
fitting, and it reads its input into fixed arrays (ADR-0012).

**Since ADR-0233 that is three translations and the answer is the worst of
them.** A component is read in full by every later one -- `--import` names a
source, 6.11.1 putting the interface in the module-heading -- so the peak is
not the program's translation and is not obviously any one of them: measured on
the day of the split, the program held the most *tokens* and ApFront the most
*pool*. Measuring one would have reported 448008 of the pool where the build's
worst is 506825, and called a 27% margin a 55% one. Twice the
loud failure that produced has been the **build**: the array that has to hold
this source is the *seed's*, and raising the constant in the source does not
raise the seed's, so the only way out is to reseed. ADR-0095 did that for the
string pool, at 74 characters over; ADR-0126 for the token array, which was
found with **107 tokens** of headroom left out of 140000 -- 0.08%.

ADR-0095 closed with "nothing measures the headroom", and that sentence is why
it happened a second time. This is the measurement.

**Both arrays are measured, and the pool needed a flag to be.** ADR-0126 could
count the tokens from `--dump-tokens`, which writes one line per token and
cannot write a second because a Pascal string-literal contains no newline
(6.1.7) -- so the line count *is* the token count, exactly, from a flag that
already existed. The pool has no such answer: PoolAdd is called from Sema and
from CodeGen as well as from the lexer -- a type's alias name, a trap message
-- so no count taken over the token stream is its size, only a lower bound.
ADR-0126 wrote down what would close it, and ADR-0148 is that: `--dump-limits`
compiles as usual and then reports both counters against both capacities.

**The capacities are checked as well as the counts.** They are read twice --
from the source, and from what the built compiler reports -- and a
disagreement is a stale `build/bin/pascalc` measuring headroom against a bound
this tree no longer declares, which is the one way this gate could quietly
answer about the wrong compiler.

The threshold is 80%: high enough that ordinary growth does not trip it, low
enough that the reseed it asks for is a scheduled decision rather than a wall
the next commit hits.
"""

import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import components                                    # noqa: E402

THRESHOLD = 0.80

# What --dump-limits reports, and the constant in the source that declares each
# capacity. Adding an array to the flag without adding it here measures one
# fewer than the compiler offers; adding it here without the flag fails loudly.
ARRAYS = [("pool", "poolMax"), ("tokens", "tokMax")]

REPORT = re.compile(r"^([a-z]+) (\d+) of (\d+)$")


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2]
    build = Path(sys.argv[sys.argv.index("--build") + 1]) if "--build" in sys.argv else root / "build"

    pascalc = build / "bin" / "pascalc"
    if not pascalc.exists():
        print(f"buffer-headroom: {pascalc} is missing -- skipping")
        return 77

    text = components.text(root)
    declared = {}
    for array, const in ARRAYS:
        m = re.search(r"^\s*%s\s*=\s*(\d+)" % const, text, re.M)
        if m is None:
            print(f"buffer-headroom: {const} is not declared as a constant any more")
            return 1
        declared[array] = int(m.group(1))

    # Every component, and the worst of the three. `worst` keeps which one it
    # was, because "the pool is 51% full" is a different fact to act on
    # depending on whether it is ApFront or the program that is full.
    reported, worst = {}, {}
    for name in components.COMPONENTS:
        run = subprocess.run(
            [str(pascalc), "--dump-limits",
             *components.translate(root, name), "-o", "/dev/null"],
            capture_output=True, text=True,
        )
        if run.returncode != 0:
            print(f"buffer-headroom: the compiler could not read {name}")
            print(run.stdout[-2000:])
            return 1
        for line in run.stdout.splitlines():
            m = REPORT.match(line)
            if m:
                array, used, cap = m.group(1), int(m.group(2)), int(m.group(3))
                if array not in reported or used > reported[array][0]:
                    reported[array] = (used, cap)
                    worst[array] = name

    failed = False
    for array, const in ARRAYS:
        if array not in reported:
            print(f"buffer-headroom: --dump-limits reported nothing about {array}")
            return 1
        used, cap = reported[array]
        if cap != declared[array]:
            print(f"buffer-headroom: {pascalc} reports {const} as {cap}, and this "
                  f"tree declares {declared[array]} -- the compiler being measured "
                  f"was built from another source, so rebuild before believing "
                  f"any of this")
            return 1
        frac = used / cap
        print(f"buffer-headroom: {array} {used} of {cap}, "
              f"{100 * (1 - frac):.1f}% free (worst: {worst[array]})")
        if frac > THRESHOLD:
            failed = True
            print(
                f"buffer-headroom: {array} is {100 * frac:.1f}% full, over the "
                f"{100 * THRESHOLD:.0f}% mark.\n"
                f"  Raising {const} alone does not help: seed/pascalc.ll carries the\n"
                "  old bound and it is the seed that translates this source. Raise it\n"
                "  on a tree that still builds, then seed/refresh.sh, as ADR-0095 and\n"
                "  ADR-0126 each did -- and say so in the commit, because it rewrites\n"
                "  6 MB."
            )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
