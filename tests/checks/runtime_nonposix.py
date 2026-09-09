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

"""How far is the runtime from a target that is not POSIX? (ADR-0369)

Every target this tree compiles the runtime for is `*-linux-gnu`.
`target-sizes` builds `runtime/*.c` for nine triples and all nine are Linux,
so nothing here notices the runtime drifting further from a platform that is
not POSIX -- which was a row in doc/sop.md 7 and is what this closes.

`runtime-isoc` is the neighbouring gate and asks a different question. It
bounds each translation unit by the headers it *may* include, which is a
claim about this source. This asks whether those headers are **there**, on a
target that does not have them, and whether the unit compiles once they are.

**A floor becomes a list, and that is the whole of why this is worth
writing.** A missing header is a fatal error, so compiling `pasrt_posix.c`
reports `netdb.h` and stops: doc/roadmap.md's Windows row had to say "the
rest of its 1 177 lines was never reached". Each `#include <...>` is
therefore probed on its own -- one one-line translation unit per header --
and what comes back is *every* header the target lacks. Measured that way
`pasrt_posix.c` wants seven and already has ten, and which seven is the
finding: sockets, the terminal and `posix_spawn`, not the directory walk and
not the file model.

Two claims against tests/checks/nonposix_headers.txt, each failing in both
directions (ADR-0013's KNOWN_GAP rule applied to a port):

  1. every translation unit's status -- `compiles` or `blocked`
  2. for each unit, the exact set of its headers the target has not got

So a unit that stops compiling, a unit that starts, a header that goes
missing and a header that arrives are four different failures. Progress is a
commit that edits the catalogue, which is the point: a port that closes a
blocker has to say so.

**It reads no diagnostic text.** The status of a unit is an exit status and
the presence of a header is an exit status; nothing here matches a compiler's
words, which are the operator's locale and the compiler's version (ADR-0366).
The first lines of a failure are printed for a reader, and no claim rests on
them.

Skips (77) without a cross compiler for a non-POSIX target;
NONPOSIX_REQUIRE refuses to pass by skipping (ADR-0330).

  APASCAL_NONPOSIX_CC   the compiler to ask; default x86_64-w64-mingw32-gcc
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# Python block-buffers a redirected stdout where `echo` does not (ADR-0366).
sys.stdout.reconfigure(line_buffering=True)
sys.stderr.reconfigure(line_buffering=True)

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
CATALOGUE = HERE / "nonposix_headers.txt"

# The runtime is four translation units and the count is a claim of its own:
# a fifth appearing with no row is a unit nobody asked this question of.
UNIT_FLOOR = 4
# ...and a sweep that finds no header at all has probed nothing. `pasrt.c`
# alone names ten that are present on any hosted implementation.
PROBE_FLOOR = 20

INCLUDE = re.compile(r"(?m)^[ \t]*#[ \t]*include[ \t]*<([^>]+)>")

# The compiler is asked in the C locale so that a *failure* here is the same
# failure everywhere. Nothing below parses its words, but a reader is shown
# them, and a report half in Japanese was one of ADR-0366's findings.
ENV = dict(os.environ, LC_ALL="C")


def read_catalogue():
    """Rows, in the catalogue's own words: `unit <name> <status>` and
    `header <unit> <header>`. Comments and blank lines are not rows."""
    units, headers = {}, {}
    for n, line in enumerate(CATALOGUE.read_text().split("\n"), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        f = line.split()
        if len(f) == 3 and f[0] == "unit" and f[2] in ("compiles", "blocked"):
            units[f[1]] = f[2]
        elif len(f) == 3 and f[0] == "header":
            headers.setdefault(f[1], set()).add(f[2])
        else:
            print("runtime-nonposix: %s:%d is not a row: %s"
                  % (CATALOGUE.name, n, line), file=sys.stderr)
            sys.exit(1)
    return units, headers


def main():
    cc = os.environ.get("APASCAL_NONPOSIX_CC", "x86_64-w64-mingw32-gcc")
    require = os.environ.get("NONPOSIX_REQUIRE", "")

    if shutil.which(cc) is None:
        if require:
            print("runtime-nonposix: NONPOSIX_REQUIRE is set and there is no "
                  "%s -- install a mingw-w64 cross compiler" % cc,
                  file=sys.stderr)
            return 1
        print("runtime-nonposix: skipped, no %s (a cross compiler for a "
              "target that is not POSIX)" % cc)
        return 77

    # A driver on PATH that cannot compile anything is a third state, and
    # `target-sizes` learned it the hard way: Debian ships the driver and its
    # C library separately, so without the runtime package the compiler runs,
    # finds no <stdio.h>, and every unit below would be reported blocked for
    # a reason that is about this machine.
    work = Path(tempfile.mkdtemp())
    try:
        return check(cc, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def compiles(cc, src, args=()):
    """Does this translation unit compile for the target? An exit status and
    the first lines of the failure, never the words of a diagnostic."""
    r = subprocess.run([cc, "-std=c11", "-fsyntax-only", str(src)] + list(args),
                       capture_output=True, text=True, env=ENV,
                       errors="surrogateescape")
    return r.returncode == 0, r.stderr


def probe(cc, work, text):
    """One header, asked for on its own. A file per probe rather than one
    reused, so a stale write cannot be read as an answer."""
    src = work / ("probe%d.c" % probe.n)
    probe.n += 1
    src.write_text(text)
    return compiles(cc, src)


probe.n = 0


def check(cc, work):
    units, headers = read_catalogue()

    ok, err = probe(cc, work, "#include <stdio.h>\nint main(void){return 0;}\n")
    if not ok:
        print("runtime-nonposix: %s is on PATH and cannot compile a program "
              "that includes <stdio.h>, so its C library is not installed. "
              "That is this machine and not the runtime:" % cc,
              file=sys.stderr)
        sys.stderr.write("".join(err.splitlines(True)[:10]))
        return 1

    sources = sorted((ROOT / "runtime").glob("*.c"),
                     key=lambda p: p.name)
    if len(sources) < UNIT_FLOOR:
        print("runtime-nonposix: %d translation unit(s) under runtime/, and "
              "the floor is %d -- a sweep that finds nothing must fail rather "
              "than report a clean run (ADR-0282)"
              % (len(sources), UNIT_FLOOR), file=sys.stderr)
        return 1

    fails = []
    probed = 0
    missing_found = {}
    status_found = {}

    for src in sources:
        name = src.name
        text = src.read_text()

        # Claim 2 first, because it is what makes claim 1 readable: every
        # header this unit names, asked for on its own, so a fatal error on
        # the first tells us nothing about the seventh.
        absent = set()
        for h in sorted(set(INCLUDE.findall(text))):
            probed += 1
            there, _ = probe(cc, work, "#include <%s>\n" % h)
            if not there:
                absent.add(h)
        missing_found[name] = absent

        # Claim 1: the unit itself.
        # The source in place, not a copy: a diagnostic naming a scratch
        # file is one a reader cannot act on.
        ok, err = compiles(cc, src, ["-I", str(ROOT / "runtime"), "-O2"])
        status_found[name] = "compiles" if ok else "blocked"
        if not ok and name in units and units[name] == "blocked":
            # Shown, never parsed. A reader wants to know why; the claim
            # above rests on the exit status alone.
            head = "".join(err.splitlines(True)[:3]).rstrip("\n")
            if head:
                print("runtime-nonposix: %s is blocked, and it begins:" % name)
                for line in head.split("\n"):
                    print("          " + line)

    if probed < PROBE_FLOOR:
        fails.append("only %d header probe(s) were compiled and the floor is "
                     "%d -- this gate cannot pass by asking nothing"
                     % (probed, PROBE_FLOOR))

    # --- both directions, on both claims ---
    for name in sorted(set(status_found) | set(units)):
        want = units.get(name)
        got = status_found.get(name)
        if want is None:
            fails.append("runtime/%s is a translation unit the catalogue does "
                         "not name -- add a `unit` row saying whether it "
                         "compiles for a target that is not POSIX" % name)
        elif got is None:
            fails.append("%s names runtime/%s, which is not there any more -- "
                         "remove the row" % (CATALOGUE.name, name))
        elif want != got:
            if got == "compiles":
                fails.append("runtime/%s is catalogued `blocked` and now "
                             "compiles for %s. That is progress and it has to "
                             "be recorded: change the row to `compiles` and "
                             "remove its header rows" % (name, cc))
            else:
                fails.append("runtime/%s is catalogued `compiles` and no "
                             "longer does under %s -- the port went backwards"
                             % (name, cc))

    for name in sorted(set(missing_found) | set(headers)):
        want = headers.get(name, set())
        got = missing_found.get(name, set())
        for h in sorted(want - got):
            fails.append("%s says runtime/%s wants <%s>, which this target "
                         "has -- either the header arrived or the unit "
                         "stopped naming it; remove the row" % (
                             CATALOGUE.name, name, h))
        for h in sorted(got - want):
            fails.append("runtime/%s includes <%s>, which %s has not got and "
                         "the catalogue does not name -- add a `header` row"
                         % (name, h, cc))

    if fails:
        print("runtime-nonposix: the runtime and %s disagree with %s:"
              % (cc, CATALOGUE.name), file=sys.stderr)
        for f in fails:
            print("        " + f, file=sys.stderr)
        return 1

    n_blocked = sum(1 for v in units.values() if v == "blocked")
    n_ok = len(units) - n_blocked
    n_hdr = sum(len(v) for v in headers.values())
    print("runtime-nonposix: %s -- %d of %d translation unit(s) compile, %d "
          "are blocked, and %d header(s) across %d probe(s) are the whole of "
          "what this target has not got"
          % (cc, n_ok, len(units), n_blocked, n_hdr, probed))
    return 0


sys.exit(main())
