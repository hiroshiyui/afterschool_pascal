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

# Start the language server in MCP mode, for an agent working on *this*
# checkout. `.mcp.json` names this script, and Claude Code starts it in the
# project directory.
#
# It exists because `build.sh` is deliberately not a CMake target -- a server
# wants a binary a user can point an editor at rather than one buried in a
# build tree, and that decision is worth keeping. What an agent needs instead
# is a *stable command*, so this is that command: it finds the compiler, builds
# the server if the binary is missing or older than its sources, and execs it.
#
# Everything it writes for a person goes to standard error, because standard
# output is the protocol (ADR-0236). A failure here is a failure to start, and
# the client shows the stderr.
set -u

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)

# The compiler this server invokes on a document. A build tree first, since
# that is what a developer has; then whatever is on PATH, which is what an
# installed copy gives (ADR-0244).
pascalc=${PASCALC:-}
if [[ -z $pascalc ]]; then
  if [[ -x $root/build/bin/pascalc ]]; then pascalc=$root/build/bin/pascalc
  else pascalc=$(command -v pascalc || true); fi
fi
if [[ -z $pascalc ]]; then
  echo "pasls: no pascalc found: build one (cmake --build build) or set PASCALC" >&2
  exit 1
fi

runtime=${AFTERSCHOOL_PASCAL_RUNTIME:-}
if [[ -z $runtime && -d $root/build/lib ]]; then runtime=$root/build/lib; fi

# The binary goes beside the build tree rather than into it: it is not a build
# product (build.sh says why), and a developer who removes `build/` should not
# be left with a stale server the next `.mcp.json` start would use.
out=${PASLS_BINARY:-$root/build/bin/pasls}
newest=$(ls -t "$here"/pasls.pas "$here"/pasls.components \
                "$root"/lib/dialect/*.pas "$root"/lib/*.pas 2>/dev/null | head -1)
if [[ ! -x $out || ( -n $newest && $newest -nt $out ) ]]; then
  echo "pasls: building the server..." >&2
  mkdir -p "$(dirname "$out")"
  if ! PASCALC="$pascalc" AFTERSCHOOL_PASCAL_RUNTIME="$runtime" \
       "$here/build.sh" "$root/tools/pascalcc" "$out" >&2; then
    echo "pasls: the server did not build" >&2
    exit 1
  fi
fi

export PASLS_COMPILER="$pascalc"
[[ -n $runtime ]] && export AFTERSCHOOL_PASCAL_RUNTIME="$runtime"
exec "$out" --mcp
