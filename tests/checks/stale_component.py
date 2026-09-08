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
#
# **Is an object built from an older heading refused?** (ADR-0245)
#
#   stale_component.sh <path-to-pascalcc>
#
# §6.11.1 makes a module-heading the interface, and until this gate nothing
# noticed that an object had been built from a *different* one.
# doc/implementation-defined.md 2.5 recorded it as a known consequence of
# having no interface artefact, and what it cost was measured before it was
# fixed: with a field inserted in front of two the program knew about, the
# program wrote `a=11 b=22` and read back **`a=11 b=0`**, exit 0, no
# diagnostic from the compiler, the driver or the linker.
#
# It is a catalogue of four claims and each fails on its own. The middle two
# are the interesting pair, because a check that refuses too much trains
# people to rebuild everything and is then worth nothing:
#
#   * a matching pair links and runs;
#   * a **heading** change without a rebuild does not link, and the driver
#     says which module and why;
#   * a change to a *comment* or the layout of the heading still links --
#     tokens are what is digested, not text;
#   * a change to the module's own **block**, which no client can see, still
#     links.
#
# No golden: what is compared is a link succeeding or failing and one line of
# what the program printed, which is the whole of what a build tool can see.
#
# ADR-0366's sixth conversion, from `stale_component.sh` on 2026-09-08, both
# versions compared on every claim and on the arms that make each fail. The
# `edit()` helper that existed because BSD sed's `-i` takes a mandatory suffix
# is gone with the sed: a substitution over a string needs no temporary file
# and no rename.
#
# Usage:  stale_component.py [pascalcc]

import os
import subprocess
import sys
import tempfile
from pathlib import Path

PROG = """program prog(output);
import storing;
var x: item;
begin
  x.a := 11; x.b := 22;
  put(x);
  x := get;
  writeln('a=', x.a:1, ' b=', x.b:1)
end.
"""

# A comment nobody depends on, and a reflow: the interface is the same, and a
# digest over *text* would refuse this.
REFLOWED = """module store;

export storing = (item, put, get);

{ A comment nobody depends on, and a reflow. }
type
  item = record
    a, b: integer
  end;

procedure put(v: item);
function get: item;

end;
var kept: item;
procedure put; begin kept := v end;
function get; begin get := kept end;
to begin do begin kept.a := 0; kept.b := 0 end;
end.
"""

ANSWER = "a=11 b=22"


def heading(extra=""):
    """The heading, in the two versions that differ.

    `tag` goes in *front* of the two fields the program uses, so a stale
    object disagrees about an offset and not merely about a size -- which is
    what makes the wrong answer wrong in a way no golden of the program's own
    could be written to expect.
    """
    return f"""module store;
export storing = (item, put, get);
type item = record {extra} a, b: integer end;
procedure put(v: item);
function get: item;
end;
var kept: item;
procedure put; begin kept := v end;
function get; begin get := kept end;
to begin do begin kept.a := 0; kept.b := 0 end;
end.
"""


class Fail(Exception):
    pass


def main():
    pascalcc = Path(sys.argv[1] if len(sys.argv) > 1 else "tools/pascalcc")
    if not (pascalcc.is_file() and os.access(pascalcc, os.X_OK)):
        print(f"stale-component: no pascalcc at '{pascalcc}'", file=sys.stderr)
        return 1
    pascalcc = pascalcc.resolve()

    with tempfile.TemporaryDirectory() as work:
        w = Path(work)
        log = w / "log"

        def compile_(*args):
            """Run the driver, putting its two streams where `>log 2>&1` did."""
            with open(log, "w") as f:
                return subprocess.call([str(pascalcc), *args], cwd=work,
                                       stdout=f, stderr=f) == 0

        def fail(what):
            raise Fail(what)

        def show_log():
            sys.stderr.write(log.read_text(errors="replace"))

        def ran(exe):
            r = subprocess.run([f"./{exe}"], cwd=work, capture_output=True,
                               text=True, errors="replace")
            return r.stdout.rstrip("\n")

        try:
            (w / "prog.pas").write_text(PROG)
            (w / "store.pas").write_text(heading())
            if not compile_("-c", "store.pas", "-o", "store.o"):
                show_log(); fail("the component did not translate")
            if not compile_("prog.pas", "--import", "store.pas", "store.o",
                            "-o", "prog"):
                show_log(); fail("a matching pair did not link")
            got = ran("prog")
            if got != ANSWER:
                fail(f"a matching pair printed [{got}]")

            # 1. The heading changes and the object does not.
            (w / "store.pas").write_text(heading("tag: integer;"))
            if compile_("prog.pas", "--import", "store.pas", "store.o",
                        "-o", "prog2"):
                print(f"it linked, and the program printed [{ran('prog2')}]",
                      file=sys.stderr)
                fail("a stale object linked")
            said = log.read_text(errors="replace")
            if "was translated from a different" not in said:
                show_log(); fail("the link failed without saying why")
            if "recompile 'store'" not in said:
                show_log(); fail("the diagnosis did not name the module")

            # ...and rebuilding it is the whole of the remedy.
            if not compile_("-c", "store.pas", "-o", "store.o"):
                show_log(); fail("the changed component did not translate")
            if not compile_("prog.pas", "--import", "store.pas", "store.o",
                            "-o", "prog3"):
                show_log(); fail("a rebuilt component did not link")

            # 2. A comment and a reflow in the heading.
            (w / "store.pas").write_text(heading())
            if not compile_("-c", "store.pas", "-o", "store.o"):
                show_log(); fail("translate")
            (w / "store.pas").write_text(REFLOWED)
            if not compile_("prog.pas", "--import", "store.pas", "store.o",
                            "-o", "prog4"):
                show_log(); fail("a comment in the heading forced a relink")
            got = ran("prog4")
            if got != ANSWER:
                fail(f"after a comment change it printed [{got}]")

            # 3. The module's own block, which no client can see.
            (w / "store.pas").write_text(
                (w / "store.pas").read_text().replace("kept", "held"))
            if not compile_("prog.pas", "--import", "store.pas", "store.o",
                            "-o", "prog5"):
                show_log(); fail("a change to the module block forced a relink")
            got = ran("prog5")
            if got != ANSWER:
                fail(f"after a block change it printed [{got}]")
        except Fail as e:
            print(f"--- stale-component: {e} ---", file=sys.stderr)
            return 1

    print("stale-component: a changed heading is refused, a comment and a "
          "block are not")
    return 0


if __name__ == "__main__":
    sys.exit(main())
