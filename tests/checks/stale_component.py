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

# AP 6.7.10's implementation-declaration is in the module-*block*, and is
# reachable from another component all the same: a client looks a method up on
# the exported *type* and never in the export-part (ADR-0411). So the third
# claim above -- that a block change costs no relink -- is true of everything
# in a block except this one construct, and the two claims below are the pair
# that says so. Without the impl digest the first of them links and answers
# **0**: the client passes one argument where the rebuilt module reads two.

METHOD_PROG = """program prog(output);
import counting;
var c: tally;
begin
  c := start;
  writeln('n=', c.Bumped(2).n:1)
end.
"""

# The sixth claim, and the one no ctest case can make. A method is reached by
# a *name* two translations compose the same way (ADR-0411), where every other
# routine a module does not export is named by a counter -- "a fact about the
# order this translation walked the tree in", as AppendProcName puts it. The
# counter happens to agree whenever both translations are handed the same
# components in the same order, which is what `tests/run_test.py` always does:
# it compiles each component with the ones before it and then hands the client
# all of them, in one order. So the corpus cannot tell a composed name from a
# counter, and a build in which the module was translated **alone** and the
# client has another component in front of it can -- which is the ordinary
# situation for a library. Under a counter this link fails with `undefined
# reference to p4`, a symbol no source spells.

OTHER = """module other;
export othering = (twice);
function twice(n: integer): integer;
end;
function twice; begin twice := 2 * n end;
end.
"""

ORDERED_PROG = """program prog(output);
import othering; counting;
var c: tally;
begin c := start; writeln('n=', twice(c.Bumped(2).n):1) end.
"""


def method_module(by_param="by: integer", body="me.n + by"):
    """A module with an inherent implementation, in its two versions.

    The difference is the method's *parameter list*, which is written in the
    block and nowhere else -- there is no heading for it to appear in, that
    being what AP 6.7.10 decided and what makes this digest necessary.
    """
    return f"""module count;
export counting = (tally, start);
type tally = record n: integer end;
function start: tally;
end;
function start; var t: tally; begin t.n := 1; start := t end;
impl tally;
  function Bumped(protected var me: tally; {by_param}): tally;
  var t: tally;
  begin t.n := {body}; Bumped := t end;
end;
end.
"""


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

            # 4. A *method's* heading, which is in the block and is still part
            #    of what a client was translated against.
            (w / "mprog.pas").write_text(METHOD_PROG)
            (w / "count.pas").write_text(method_module())
            if not compile_("-c", "count.pas", "-o", "count.o"):
                show_log(); fail("the method component did not translate")
            if not compile_("mprog.pas", "--import", "count.pas", "count.o",
                            "-o", "mprog"):
                show_log(); fail("a matching method pair did not link")
            got = ran("mprog")
            if got != "n=3":
                fail(f"a matching method pair printed [{got}]")

            # The parameter's *type*, so that the client still compiles --
            # §6.6.3.2 lets an integer actual reach a real value parameter.
            # An argument count would be caught by the client reading the new
            # source; a width is not, and is what a stale object gets wrong.
            (w / "count.pas").write_text(
                method_module("by: real", "me.n + trunc(by)"))
            if compile_("mprog.pas", "--import", "count.pas", "count.o",
                        "-o", "mprog2"):
                print("it linked, and the program printed "
                      f"[{ran('mprog2')}]", file=sys.stderr)
                fail("a stale object linked over a changed method heading")
            said = log.read_text(errors="replace")
            if "was translated from a different" not in said:
                show_log(); fail("the method link failed without saying why")

            # 5. ...and the method's *body*, which no client can see, still
            #    links. A digest over the whole implementation would refuse
            #    this, and refusing too much is what makes a gate ignored.
            (w / "count.pas").write_text(method_module())
            if not compile_("-c", "count.pas", "-o", "count.o"):
                show_log(); fail("translate")
            (w / "count.pas").write_text(
                method_module(body="by + me.n"))
            if not compile_("mprog.pas", "--import", "count.pas", "count.o",
                            "-o", "mprog3"):
                show_log(); fail("a method body forced a relink")
            got = ran("mprog3")
            if got != "n=3":
                fail(f"after a method body change it printed [{got}]")

            # 6. A method is reached by a name and not by a counter: the
            #    module translated on its own, the client translated with a
            #    second component in front of it.
            (w / "count.pas").write_text(method_module())
            (w / "other.pas").write_text(OTHER)
            (w / "oprog.pas").write_text(ORDERED_PROG)
            if not compile_("-c", "count.pas", "-o", "count.o"):
                show_log(); fail("translate")
            if not compile_("-c", "other.pas", "-o", "other.o"):
                show_log(); fail("translate")
            if not compile_("oprog.pas", "--import", "other.pas",
                            "--import", "count.pas", "other.o", "count.o",
                            "-o", "oprog"):
                show_log()
                fail("a method did not link when the client read another "
                     "component first")
            got = ran("oprog")
            if got != "n=6":
                fail(f"a method reached across an ordering printed [{got}]")
        except Fail as e:
            print(f"--- stale-component: {e} ---", file=sys.stderr)
            return 1

    print("stale-component: a changed heading and a changed method are "
          "refused, a comment and a body are not, and a method is reached by "
          "its name")
    return 0


if __name__ == "__main__":
    sys.exit(main())
