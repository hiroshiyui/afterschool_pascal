#!/usr/bin/env bash
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
# Does a generated project build, run and test itself? (ADR-0348)
#
# **No test case can do this**, which is why it is a harness: every case in the
# corpus is one `.pas` file compiled where it sits, and what is asserted here is
# a *directory* the driver wrote, a config file it then read back, and three
# subcommands that only mean anything together. It is the same argument
# `long-path`, `bare-source-name` and `stale-component` are harnesses for.
#
# **The generated program must actually run**, not merely compile. A skeleton
# that a user's first command rejects is worse than no skeleton, and the
# generated `greet.pas` has already been wrong once: it ended `end.` where a
# module's routine ends `end;`, which no amount of reading the generator caught
# and one run did.
#
# Usage:  tests/checks/new_project.sh [pascalcc]
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
driver=${1:-$root/tools/pascalcc}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

# BSD sed's `-i` takes a mandatory suffix and GNU's an optional one, so the one
# spelling that means "in place" on both is no `-i` at all: a temporary and a
# rename. One expression, one file.
edit() { sed "$1" "$2" > "$2.edit" && mv "$2.edit" "$2"; }

fail() { echo "new-project: $*" >&2; exit 1; }

# --- 1. the skeleton is written, and it is the layout that was decided ------
"$driver" new-project demo >/dev/null || fail "new-project failed"
for f in demo/afterschool-pascal.toml demo/src/demo.pas demo/src/greet.pas \
         demo/test/demo.out demo/.gitignore demo/README.md; do
  [[ -f $f ]] || fail "$f was not written"
done
[[ -d demo/build ]] || fail "demo/build was not made"

# --- 2. it builds, runs and passes its own test -----------------------------
#
# `run` before `build`, deliberately: a user's first command is the one that
# has to work, and it must not depend on having built first.
cd demo
out=$("$driver" run) || fail "'run' failed on a fresh skeleton"
[[ $out == "Hello, world!" ]] || fail "'run' printed '$out'"
"$driver" build >/dev/null || fail "'build' failed"
[[ -x build/demo ]] || fail "'build' wrote no executable"
"$driver" test >/dev/null || fail "'test' failed on a fresh skeleton"

# --- 3. the config is found from a subdirectory, as git finds its own -------
( cd src && "$driver" test >/dev/null ) || fail "'test' failed from src/"

# --- 4. and the test subcommand can *fail*, or it asserts nothing -----------
echo 'something else' > test/demo.out
if "$driver" test >/dev/null 2>&1; then fail "'test' passed a wrong golden"; fi
printf 'Hello, world!\n' > test/demo.out

# --- 5. the reader refuses what it does not understand ----------------------
#
# Each of these is the whole point of a strict subset: a misspelled key in a
# build file is otherwise found by the build being quietly wrong.
cp afterschool-pascal.toml keep.toml
for bad in 'outupt = "x"' '[deps]' 'opt = 2' 'stray = "x"'; do
  cp keep.toml afterschool-pascal.toml
  if [[ $bad == '[deps]' ]]; then printf '[deps]\nk = "v"\n' >> afterschool-pascal.toml
  else printf '%s\n' "$bad" >> afterschool-pascal.toml; fi
  if "$driver" build >/dev/null 2>&1; then
    fail "the reader accepted: $bad"
  fi
done
cp keep.toml afterschool-pascal.toml && rm -f keep.toml

# --- 6. a link flag in the config reaches the link --------------------------
#
# Both directions, because a key nothing acts on is decoration: `-lm` links and
# a library that does not exist must not.
edit 's|^# ldflags.*|ldflags = ["-lm"]|' afterschool-pascal.toml
"$driver" build >/dev/null || fail "ldflags = [\"-lm\"] did not link"
edit 's|^ldflags.*|ldflags = ["-lnosuchlibraryanywhere"]|' afterschool-pascal.toml
if "$driver" build >/dev/null 2>&1; then fail "a bogus ldflag still linked"; fi
edit 's|^ldflags.*|# ldflags = []|' afterschool-pascal.toml

# --- 6b. and so do the other two keys that reach a tool -------------------
#
# `ldflags` was proved both ways above and its two neighbours were not, which
# is the same decoration risk one key over: a value this reader parses and then
# drops would pass every test here. Asserted by *refusal* rather than by
# effect, because that is what needs no toolchain -- a valid cross target needs
# a sysroot this machine may not have, and a flag clang accepts proves only
# that clang tolerated it.
edit 's|^# cflags.*|cflags = ["-nosuchclangflaganywhere"]|' afterschool-pascal.toml
if "$driver" build >/dev/null 2>&1; then fail "a bogus cflag still compiled"; fi
edit 's|^cflags.*|# cflags = []|' afterschool-pascal.toml

edit 's|^# target.*|target = "nosucharch-unknown-none"|' afterschool-pascal.toml
if "$driver" build >/dev/null 2>&1; then fail "a bogus target still built"; fi
edit 's|^target.*|# target = ""|' afterschool-pascal.toml

# ...and the project still builds with both back as comments, so the sed above
# restored a file the reader accepts rather than one it merely tolerated.
"$driver" build >/dev/null || fail "the project stopped building after 6b"

# --- 7. the reader is TOML, and not a subset of it (ADR-0361) --------------
#
# Every assertion here fails against the `awk` subset this replaced, which is
# the point: two of them are documents it *accepted* and read wrongly, which
# is worse than the ones it refused.
#
# A comma inside a quoted string. The old reader split an array on every
# comma, so `-Wl,-rpath,/nosuchdir` was three malformed strings and the file
# was rejected. Both directions, because a reader that dropped the key would
# also link: the rpath must link, and a linker option that does not exist must
# not -- which it can only do if the whole string arrived.
# Two elements, so that dropping the second is as visible as splitting the
# first.
edit 's|^# ldflags.*|ldflags = ["-Wl,-rpath,/nosuchdir", "-lm"]|' afterschool-pascal.toml
"$driver" build >/dev/null || fail 'a comma inside a quoted ldflag did not link'
edit 's|^ldflags.*|ldflags = ["-Wl,-rpath,/nosuchdir", "-Wl,--no-such-linker-option,x"]|' \
    afterschool-pascal.toml
if "$driver" build >/dev/null 2>&1; then
  fail 'the second element of an ldflags list never reached the link'
fi
edit 's|^ldflags.*|# ldflags = []|' afterschool-pascal.toml

# A `#` inside a quoted string. The old reader stripped from the first one
# before looking at anything, so this silently built `build/demo` -- a wrong
# answer with a zero exit status, which is the failure this whole tree is
# written against.
edit 's|^output .*|output      = "build/demo#1"|' afterschool-pascal.toml
"$driver" build >/dev/null || fail 'a # inside a quoted output path did not build'
[[ -x 'build/demo#1' ]] || fail 'the # in build/demo#1 was cut off the path'
edit 's|^output .*|output      = "build/demo"|' afterschool-pascal.toml

# A number where the driver wants a string. The old reader refused this
# because `2` is not `"..."`; this one parses it happily as a TOML integer and
# has to refuse it on the *schema* instead, which is a different check that
# has to be there.
edit 's|^opt .*|opt         = 2|' afterschool-pascal.toml
if "$driver" build >/dev/null 2>&1; then fail 'build.opt = 2 was accepted'; fi
edit 's|^opt .*|opt         = "-O2"|' afterschool-pascal.toml

# And a refusal names a column as well as a line, which is the whole of what a
# real parser has over a line-at-a-time one.
cp afterschool-pascal.toml keep.toml
printf '[build]\nopt = \n' > afterschool-pascal.toml
msg=$("$driver" build 2>&1 || true)
[[ $msg == *"afterschool-pascal.toml:2:7:"* ]] ||
  fail "a syntax error did not name its line and column: $msg"
cp keep.toml afterschool-pascal.toml && rm -f keep.toml
"$driver" build >/dev/null || fail "the project stopped building after 7"

# --- 8. a subcommand is a position, not a word ------------------------------
#
# ADR-0140's rule for a command line: `build.pas` is a source file and must go
# on compiling, or the feature has taken a name away from every user.
cd "$work"
cp demo/src/demo.pas build.pas
cp demo/src/greet.pas greet.pas
"$driver" build.pas -o built >/dev/null || fail "a file named build.pas stopped compiling"
[[ $(./built) == "Hello, world!" ]] || fail "build.pas ran wrongly"

echo "new-project: a generated project builds, runs and tests itself, and the" \
     "reader reads TOML rather than a subset of it"
