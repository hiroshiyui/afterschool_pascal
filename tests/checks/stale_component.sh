#!/usr/bin/env bash
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
set -u

pascalcc=${1:-tools/pascalcc}
[[ -x $pascalcc ]] || { echo "stale-component: no pascalcc at '$pascalcc'" >&2
                        exit 1; }
pascalcc=$(cd "$(dirname "$pascalcc")" && pwd)/$(basename "$pascalcc")

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work" || exit 1

# The heading, in the two versions that differ. `tag` goes in *front* of the
# two fields the program uses, so a stale object disagrees about an offset and
# not merely about a size -- which is what makes the wrong answer wrong in a
# way no golden of the program's own could be written to expect.
heading() {
  cat <<EOF
module store;
export storing = (item, put, get);
type item = record $1 a, b: integer end;
procedure put(v: item);
function get: item;
end;
var kept: item;
procedure put; begin kept := v end;
function get; begin get := kept end;
to begin do begin kept.a := 0; kept.b := 0 end;
end.
EOF
}

cat >prog.pas <<'EOF'
program prog(output);
import storing;
var x: item;
begin
  x.a := 11; x.b := 22;
  put(x);
  x := get;
  writeln('a=', x.a:1, ' b=', x.b:1)
end.
EOF

fail() { echo "--- stale-component: $* ---" >&2; exit 1; }

heading "" >store.pas
"$pascalcc" -c store.pas -o store.o >log 2>&1 ||
  { cat log >&2; fail "the component did not translate"; }
"$pascalcc" prog.pas --import store.pas store.o -o prog >log 2>&1 ||
  { cat log >&2; fail "a matching pair did not link"; }
got=$(./prog)
[[ $got == "a=11 b=22" ]] || fail "a matching pair printed [$got]"

# 1. The heading changes and the object does not.
heading "tag: integer;" >store.pas
if "$pascalcc" prog.pas --import store.pas store.o -o prog2 >log 2>&1; then
  echo "it linked, and the program printed [$(./prog2)]" >&2
  fail "a stale object linked"
fi
grep -q "was translated from a different" log ||
  { cat log >&2; fail "the link failed without saying why"; }
grep -q "recompile 'store'" log ||
  { cat log >&2; fail "the diagnosis did not name the module"; }

# ...and rebuilding it is the whole of the remedy.
"$pascalcc" -c store.pas -o store.o >log 2>&1 ||
  { cat log >&2; fail "the changed component did not translate"; }
"$pascalcc" prog.pas --import store.pas store.o -o prog3 >log 2>&1 ||
  { cat log >&2; fail "a rebuilt component did not link"; }

# 2. A comment and a reflow in the heading: the interface is the same, and a
#    digest over *text* would refuse this.
heading "" >store.pas
"$pascalcc" -c store.pas -o store.o >log 2>&1 || { cat log >&2; fail "translate"; }
cat >store.pas <<'EOF'
module store;

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
EOF
"$pascalcc" prog.pas --import store.pas store.o -o prog4 >log 2>&1 ||
  { cat log >&2; fail "a comment in the heading forced a relink"; }
got=$(./prog4)
[[ $got == "a=11 b=22" ]] || fail "after a comment change it printed [$got]"

# 3. The module's own block, which no client can see.
sed -i 's/kept/held/g' store.pas
"$pascalcc" prog.pas --import store.pas store.o -o prog5 >log 2>&1 ||
  { cat log >&2; fail "a change to the module block forced a relink"; }
got=$(./prog5)
[[ $got == "a=11 b=22" ]] || fail "after a block change it printed [$got]"

echo "stale-component: a changed heading is refused, a comment and a block are not"
