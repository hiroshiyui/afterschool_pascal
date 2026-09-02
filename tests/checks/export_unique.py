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

"""Do any two library modules export one spelling?

ADR-0298. The language has no overloading and 6.11.2 puts every imported
name into one scope, so two modules exporting one spelling can be imported
together only with `only` or `qualified` -- and a program importing forty
modules pays that at every collision, per import, enumeratively. The
language server had two `only` clauses for exactly that reason, and the
day the rule was written down the library held **37** colliding spellings,
not the three anyone had noticed. So the rule is the library's: no two
modules under `lib/` export one spelling, and a program importing all of
`lib/` needs no import-clause at all.

The export-parts are read from the compiler's own token stream
(`--dump-tokens`) and not from the text: an export-list spans lines, carries
comments, and may rename with 6.11.2's `=>`, after which the spelling a
client sees is the one on the right. A regex over Pascal is the shape
`diagnostic-coverage` broke on (ADR-0273); the lexer here is the one the
language has.

Three claims, so that it fails in both directions:

  * every folded spelling is exported by exactly one module;
  * every source under `lib/` is a module with an export-part -- a file
    there that stops being one is a defect and not a file to skip;
  * the sweep read enough to mean anything: fewer than 20 modules or 200
    exports is a failure, `variant-check`'s floor for `variant-check`'s
    reason.
"""

import argparse
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOTS = ("lib", "lib/dialect")
FLOOR_MODULES = 20
FLOOR_EXPORTS = 200


def sources(root: Path) -> list:
    found = sorted(p for r in ROOTS for p in (root / r).glob("*.pas"))
    rel = [str(p.relative_to(root)) for p in found]
    # Filtered through git only where git answers (ADR-0282): `check-ignore`
    # exits 128 in a checkout git calls dubiously owned, and an empty answer
    # read as "nothing ignored" is the right one to fall back to.
    ignored = subprocess.run(["git", "-C", str(root), "check-ignore", "--stdin"],
                             input="\n".join(rel), capture_output=True,
                             text=True)
    if ignored.returncode in (0, 1):
        drop = set(ignored.stdout.split())
        rel = [f for f in rel if f not in drop]
    return rel


def tokens(pascalc: Path, root: Path, name: str):
    """(kind, text) per token, as `--dump-tokens` writes them: `line col kind text`."""
    r = subprocess.run([str(pascalc), "--dump-tokens", name], cwd=root,
                       capture_output=True, text=True, encoding="latin-1")
    if r.returncode != 0:
        return None
    out = []
    for line in r.stdout.splitlines():
        parts = line.split(" ", 3)
        if len(parts) < 3:
            continue
        out.append((parts[2], parts[3] if len(parts) > 3 else ""))
    return out


def exports(toks):
    """The (interface, [spelling]) pairs of every export-part in a token stream.

    6.11.2: `export` name `=` `(` item {`,` item} `)` `;`, an item being an
    identifier, `identifier => identifier` (the right one is what a client
    sees), or `identifier .. identifier` (a range of an enumeration's
    constants -- both ends are exported, and what lies between is not
    named here, so a range is counted as its two ends).
    """
    found = []
    i = 0
    n = len(toks)
    while i < n:
        if toks[i] != ("kw", "export"):
            i += 1
            continue
        i += 1
        if i >= n or toks[i][0] != "ident":
            return None
        iface = toks[i][1]
        i += 1
        if i + 1 >= n or toks[i] != ("op", "=") or toks[i + 1] != ("op", "("):
            return None
        i += 2
        names = []
        while i < n and toks[i] != ("op", ")"):
            if toks[i][0] != "ident":
                return None
            names.append(toks[i][1])
            i += 1
            if i < n and toks[i] == ("op", "=>"):
                if i + 1 >= n or toks[i + 1][0] != "ident":
                    return None
                names[-1] = toks[i + 1][1]
                i += 2
            elif i < n and toks[i] == ("op", ".."):
                if i + 1 >= n or toks[i + 1][0] != "ident":
                    return None
                names.append(toks[i + 1][1])
                i += 2
            if i < n and toks[i] == ("op", ","):
                i += 1
        found.append((iface, names))
        i += 1
    return found


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("root", nargs="?", default=None)
    ap.add_argument("--build", default=None)
    args = ap.parse_args()
    root = Path(args.root) if args.root else Path(__file__).resolve().parents[2]
    build = Path(args.build) if args.build else root / "build"
    pascalc = build / "bin" / "pascalc"
    if not pascalc.exists():
        print(f"export-unique: {pascalc} is missing -- skipping")
        return 77

    by_name = defaultdict(list)     # folded spelling -> [module file]
    modules = 0
    total = 0
    broken = []
    for name in sources(root):
        toks = tokens(pascalc, root, name)
        parts = exports(toks) if toks is not None else None
        if not parts:
            broken.append(name)
            continue
        for iface, names in parts:
            modules += 1
            for s in names:
                total += 1
                by_name[s.lower()].append(f"{name} ({iface})")

    shared = {s: mods for s, mods in by_name.items() if len(mods) > 1}
    if shared:
        print(f"export-unique: {len(shared)} spelling(s) are exported by more "
              f"than one module", file=sys.stderr)
        for s in sorted(shared):
            print(f"    {s}: " + ", ".join(shared[s]), file=sys.stderr)
        print("\n  No two modules under lib/ may export one spelling: the "
              "language has no\n  overloading, so a program importing both "
              "would need `only` or `qualified`\n  at every such collision "
              "(ADR-0298). Rename the less general one.", file=sys.stderr)
        return 1

    if broken:
        print(f"export-unique: {len(broken)} source(s) under lib/ have no "
              f"export-part the lexer and this reader could find",
              file=sys.stderr)
        for name in broken:
            print(f"    {name}", file=sys.stderr)
        print("\n  Everything under lib/ is a module with an export-part; a "
              "file that is not\n  is a defect, not a file to skip.",
              file=sys.stderr)
        return 1

    if modules < FLOOR_MODULES or total < FLOOR_EXPORTS:
        print(f"export-unique: only {modules} export-parts and {total} "
              f"exports were read, and this tree has far more -- the sweep "
              f"found nothing to do", file=sys.stderr)
        return 1

    print(f"export-unique: {total} exports across {modules} modules, and no "
          f"spelling is exported twice")
    return 0


if __name__ == "__main__":
    sys.exit(main())
