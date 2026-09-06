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
# Does the compiler survive every tool dump over every source? (ADR-0349)
#
# **The dumps a *tool* asks for are the ones with no corpus.** `--dump-symbols`,
# `--dump-uses` and `--dump-words` exist for `lsp/pasls.pas` -- an editor's
# outline, its go-to-definition, and the word lists a completion offers -- and
# an agent reaches the first two through MCP. `tests/dumps/` has one case each,
# over one small source apiece, and that is the whole of what asked.
#
# So a language feature added afterwards is swept by nothing. ADR-0338's traits
# put two new node kinds into a block's declaration list, and `DumpSymBlock`
# read them through the procedure arm: `--dump-symbols` over any source with a
# `trait` in it **stopped the compiler** with 6.5.3.3's wrong-arm read. The
# whole suite was green -- 888 cases -- because no case passes `--dump-symbols`
# over such a source, and the MCP `outline` tool answered with the one line it
# had printed before it died. A person would have read that as an empty file.
#
# This is ADR-0269's question -- *did the compiler survive every invocation?* --
# asked of the dumps instead of of the corpus, and it is a **crash sweep and
# not a golden**: what each dump *says* is `tests/dumps/`'s business, and what
# this asks is only that the compiler is still running afterwards. A source
# that fails to compile is fine; a source that takes the compiler down is not.
#
# Usage:  tests/checks/tool_dumps.sh [pascalc]
set -uo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
pascalc=${1:-$root/build/bin/pascalc}
[[ -x $pascalc ]] || { echo "tool-dumps: $pascalc is not executable" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Every dump a tool asks for. `--dump-imports` is here too: `tools/pascalcc`
# reads it to learn what to translate, so a crash in it is a build that stops
# rather than an editor that goes quiet.
dumps=(--dump-symbols --dump-uses --dump-words --dump-imports)

# `find` over the roots, with git as an *optional filter* -- `variant_check.sh`'s
# shape, and it is the shape for the reason that gate learned: a checkout may
# have a retired corpus or a second build tree on disk, and what is gitignored
# is not a source this project ships.
#
# It was `git ls-files` first, and CI is where that failed. A container runs as
# a different user than the checkout is owned by, so git refuses the repository
# outright -- *detected dubious ownership* -- and the sweep enumerated **zero**
# sources. The floor is what reported it (ADR-0282), doing exactly the job a
# floor is for; every gate here that reaches for git has to survive git
# declining to answer.
#
# The names matter: `lsp/sessions/workspace/` holds a directory named in
# Japanese (ADR-0291's long-path case), which `git ls-files` quotes and escapes
# and `find` does not. The first run of this sweep spent eight "crashes" on
# that before it was a real answer.
sources=$(mktemp)
find "$root/tests" "$root/selfhost" "$root/lib" "$root/lsp" "$root/examples" \
     -name '*.pas' | sort > "$sources"
if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$root" check-ignore --stdin < "$sources" > "$work/ignored.txt" 2>/dev/null || true
  if [[ -s $work/ignored.txt ]]; then
    grep -Fxv -f "$work/ignored.txt" "$sources" > "$work/kept.txt" || true
    mv "$work/kept.txt" "$sources"
  fi
fi
mapfile -t sources < "$sources"

swept=0; crashed=0
for src in "${sources[@]}"; do
  for d in "${dumps[@]}"; do
    swept=$((swept + 1))
    out=$("$pascalc" "$d" "$src" -o "$work/out.ll" 2>&1)
    st=$?
    # A diagnostic is an answer and a non-zero status with one is fine. What is
    # not fine is the runtime saying the program stopped, or a signal.
    if [[ $out == *"runtime error:"* ]] || (( st > 1 )); then
      echo "tool-dumps: $d ${src#"$root"/}" >&2
      printf '%s\n' "$out" | tail -2 | sed 's/^/  /' >&2
      crashed=$((crashed + 1))
    fi
  done
done

# A floor, so a run that globbed nothing cannot pass by sweeping nothing
# (ADR-0282). Four dumps over the tree is thousands; 1000 is well under.
if (( swept < 1000 )); then
  echo "tool-dumps: only $swept invocations, below the floor of 1000" >&2
  exit 1
fi

if (( crashed )); then
  echo "tool-dumps: $crashed of $swept invocations stopped the compiler" >&2
  exit 1
fi
echo "tool-dumps: ${#dumps[@]} dumps over ${#sources[@]} sources," \
     "$swept invocations, and the compiler survived every one"
