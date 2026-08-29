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

# **Is this compiler installable anywhere?** (ADR-0244)
#
#   install_layout.sh <build-directory>
#
# Every other harness here drives the compiler out of the build tree, with
# PASCALC and AFTERSCHOOL_PASCAL_RUNTIME saying where that tree is -- which is
# exactly the configuration an installed copy does not have. So the claim
# "put it anywhere and point PATH at it" was made by no oracle at all, and it
# is a claim with four parts, each of which fails on its own:
#
#   * `cmake --install` puts the compiler, the driver, the runtime and the
#     library where the layout says.
#   * `pascalcc` finds `pascalc` *beside itself* rather than in a build tree
#     whose path is compiled into nothing.
#   * it finds `libpasrt.a` the same way, or the link fails.
#   * it adds the installed library to the search path when the environment
#     says nothing, so `import PasError` resolves with no configuration.
#
# The program below is compiled in a directory that is neither the checkout nor
# the install, with the environment emptied of every AFTERSCHOOL_ and PASCALC
# variable and PATH holding the install's bin and the system's. If it prints
# what it should, all four hold at once.
set -u

build=${1:-build}
[[ -d $build ]] || { echo "install-layout: no build directory '$build'" >&2
                     exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

prefix=$work/prefix
if ! cmake --install "$build" --prefix "$prefix" >"$work/install.log" 2>&1; then
  echo "--- cmake --install failed ---" >&2
  cat "$work/install.log" >&2
  exit 1
fi

# The layout, named here rather than only in CMakeLists.txt: a file that stops
# being installed is a claim that stopped being true, and the message should
# say which file rather than that a program did not run.
for f in bin/pascalc bin/pascalcc lib/libpasrt.a \
         lib/afterschool/pastext.pas lib/afterschool/dialect/paserror.pas; do
  if [[ ! -e $prefix/$f ]]; then
    echo "--- install-layout: $f was not installed ---" >&2
    exit 1
  fi
done

mkdir -p "$work/elsewhere"
cat >"$work/elsewhere/greet.pas" <<'EOF'
program greet(output);
import PasError;
       PasFS;
begin
  writeln('installed: ', ErrorText(errNone));
  writeln('here: ', Exists('greet.pas'))
end.
EOF

# Nothing of this checkout in the environment, and PATH is how the compiler is
# found -- which is the sentence being tested. `env -i` would lose HOME and
# the locale as well, and clang wants a usable environment, so the four
# variables that could point back at the build tree are unset by name.
if ! ( cd "$work/elsewhere"
       unset PASCALC AFTERSCHOOL_PASCAL_RUNTIME AFTERSCHOOL_PASCAL_PATH \
             AFTERSCHOOL_PASCAL_TARGET AFTERSCHOOL_PASCAL_OPT
       export PATH="$prefix/bin:$PATH"
       pascalcc greet.pas -o greet ) >"$work/build.log" 2>&1; then
  echo "--- install-layout: the installed compiler could not build it ---" >&2
  cat "$work/build.log" >&2
  exit 1
fi

got=$(cd "$work/elsewhere" && ./greet)
want='installed: no error
here: TRUE'
if [[ $got != "$want" ]]; then
  echo "--- install-layout: the program printed something else ---" >&2
  echo "expected:" >&2; echo "$want" >&2
  echo "actual:" >&2; echo "$got" >&2
  exit 1
fi

# **Every installed module reachable by its own name.** The search is
# `<directory>/<interface name>.pas` and nothing opens a file to find out what
# it declares (ADR-0244), so the convention that a library module's file is
# named after the interface it exports is load-bearing and was checked by
# nothing: a module renamed, or one exporting an interface under another name,
# would simply stop being resolvable and every existing case would still pass.
#
# One program per module, importing it and nothing else. It has to *compile*
# and not merely resolve, because resolving finds a file with the right name
# and only Sema knows whether that file declares the interface.
modules=0
for f in "$prefix"/lib/afterschool/*.pas "$prefix"/lib/afterschool/dialect/*.pas
do
  [[ -e $f ]] || continue
  name=$(basename "${f%.pas}")
  printf 'program probe(output);\nimport %s;\nbegin end.\n' "$name" \
    >"$work/elsewhere/probe.pas"
  if ! ( cd "$work/elsewhere"
         unset PASCALC AFTERSCHOOL_PASCAL_RUNTIME AFTERSCHOOL_PASCAL_PATH \
               AFTERSCHOOL_PASCAL_TARGET AFTERSCHOOL_PASCAL_OPT
         export PATH="$prefix/bin:$PATH"
         pascalcc -S probe.pas -o /dev/null ) >"$work/probe.log" 2>&1; then
    echo "--- install-layout: '$name' is not reachable as import $name ---" >&2
    cat "$work/probe.log" >&2
    exit 1
  fi
  modules=$((modules + 1))
done
if [[ $modules -lt 20 ]]; then
  echo "--- install-layout: only $modules library modules were installed ---" >&2
  exit 1
fi

echo "install-layout: installed to a prefix, found on PATH," \
     "$modules library modules reachable by name"
