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
sed -i 's|^# ldflags.*|ldflags = ["-lm"]|' afterschool-pascal.toml
"$driver" build >/dev/null || fail "ldflags = [\"-lm\"] did not link"
sed -i 's|^ldflags.*|ldflags = ["-lnosuchlibraryanywhere"]|' afterschool-pascal.toml
if "$driver" build >/dev/null 2>&1; then fail "a bogus ldflag still linked"; fi
sed -i 's|^ldflags.*|# ldflags = []|' afterschool-pascal.toml

# --- 6b. and so do the other two keys that reach a tool -------------------
#
# `ldflags` was proved both ways above and its two neighbours were not, which
# is the same decoration risk one key over: a value this reader parses and then
# drops would pass every test here. Asserted by *refusal* rather than by
# effect, because that is what needs no toolchain -- a valid cross target needs
# a sysroot this machine may not have, and a flag clang accepts proves only
# that clang tolerated it.
sed -i 's|^# cflags.*|cflags = ["-nosuchclangflaganywhere"]|' afterschool-pascal.toml
if "$driver" build >/dev/null 2>&1; then fail "a bogus cflag still compiled"; fi
sed -i 's|^cflags.*|# cflags = []|' afterschool-pascal.toml

sed -i 's|^# target.*|target = "nosucharch-unknown-none"|' afterschool-pascal.toml
if "$driver" build >/dev/null 2>&1; then fail "a bogus target still built"; fi
sed -i 's|^target.*|# target = ""|' afterschool-pascal.toml

# ...and the project still builds with both back as comments, so the sed above
# restored a file the reader accepts rather than one it merely tolerated.
"$driver" build >/dev/null || fail "the project stopped building after 6b"

# --- 7. a subcommand is a position, not a word ------------------------------
#
# ADR-0140's rule for a command line: `build.pas` is a source file and must go
# on compiling, or the feature has taken a name away from every user.
cd "$work"
cp demo/src/demo.pas build.pas
cp demo/src/greet.pas greet.pas
"$driver" build.pas -o built >/dev/null || fail "a file named build.pas stopped compiling"
[[ $(./built) == "Hello, world!" ]] || fail "build.pas ran wrongly"

echo "new-project: a generated project builds, runs and tests itself, and the" \
     "reader refuses four malformed files"
