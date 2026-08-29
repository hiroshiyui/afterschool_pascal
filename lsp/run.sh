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

# Build the language server and replay every recorded session against it.
#
#   run.sh <path-to-pascalcc> [<path-to-pascalc>]
#
# The second is what the server invokes on a document; it defaults to $PASCALC
# and then to whatever `pascalc` is on PATH, which is how tests/checks/
# heap_balance.py drives this without being told twice where the compiler is.
#
# A session needs its own harness, and the reason is the same one tests/dumps/
# has: what is compared here is not what a compiled program printed but what a
# *protocol* did, and the two differ in three ways tests/run_test.sh has no
# sidecar for.
#
#   * The input is framed. `Content-Length: N<CR><LF><CR><LF>` and then exactly
#     N bytes, so a .in file would have to be maintained with the byte counts
#     written into it by hand and rewritten whenever a message changed. The
#     session files here are one JSON message per line and this script computes
#     the frames, which is what keeps them readable and correct at once.
#   * The output is framed too, and the goldens hold the real carriage returns
#     and the real byte counts -- so a change to what the server renders fails
#     here even when the JSON still parses.
#   * The server is a *server*: it needs a compiler to invoke and a scratch
#     path to write, neither of which is a thing a test case is handed.
#
#   sessions/name.jsonl   one JSON-RPC message per line, framed by this script;
#                         a blank line or one beginning with # is a comment,
#                         because a session is worth annotating and JSON has
#                         nowhere to say why a message is there. %ROOT% in a
#                         message becomes the path of this checkout
#   sessions/name.out     the exact bytes the server writes to standard output
#   sessions/name.note    what it writes to standard error; absent means none
#   sessions/name.workspace  a marker: this session names files on disk, so its
#                         golden is normalised before the diff -- see below
#   sessions/name.scratch a scratch path for this session, one line, in place
#                         of the work directory's. It exists for the sessions
#                         that are about a path the server *cannot* write, and
#                         so must name one no work directory would be
#   sessions/name.tmpdir  a marker: this session is about the scratch path the
#                         server picks when it is told none. PASLS_SCRATCH is
#                         left unset, TMPDIR is a directory of this session's
#                         own, and what is checked afterwards is the name of
#                         the file left in it -- which must carry the server's
#                         own process id (ADR-0242). Every other session sets
#                         the path, so this is the only one that can see it
#   sessions/name.mcp     a marker: this session is MCP and not LSP. The server
#                         is started with --mcp, the framing is one JSON
#                         message to a line rather than Content-Length, and it
#                         runs in the checkout -- an MCP client launches its
#                         server as a subprocess and an agent's subprocess
#                         starts in the tree it is working on (ADR-0241)
set -u

if [[ $# -lt 1 ]]; then
  echo "usage: run.sh <pascalcc> [<pascalc>]" >&2
  exit 2
fi

pascalcc=$1
pascalc=${2:-${PASCALC:-pascalc}}
root=$(cd "$(dirname "$0")/.." && pwd)
# Absolute, because the server is started in the checkout and a relative
# compiler path would then name nothing. `PASLS_COMPILER` is a *command* and
# may be a bare name on PATH, which is left alone.
[[ $pascalcc == */* ]] && pascalcc=$(cd "$(dirname "$pascalcc")" && pwd)/$(basename "$pascalcc")
[[ $pascalc == */* ]] && pascalc=$(cd "$(dirname "$pascalc")" && pwd)/$(basename "$pascalc")
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# ADR-0183's balance belongs to the *server*, and two other Pascal programs run
# inside this script: `pascalcc` builds it, and the server then invokes
# `pascalc` once per document. Both are Pascal programs on the same runtime, so
# an inherited PASHEAP_BALANCE would have them count their own allocations into
# the same file -- which is `tests/run_test.sh`'s hazard, met twice over. It is
# taken out of the environment here, put back only around the server, and
# stripped again from what the server starts.
heap_balance="${PASHEAP_BALANCE:-}"
unset PASHEAP_BALANCE

if ! "$here/build.sh" "$pascalcc" "$work/pasls" >"$work/build.log" 2>&1; then
  echo "--- the language server did not build ---" >&2
  cat "$work/build.log" >&2
  exit 1
fi

# One JSON message per line becomes one frame per message. `printf %s` and not
# echo, because a body must not gain a newline it did not have: the byte count
# in the header is the whole of what says where it ends.
frame() {
  local LC_ALL=C
  local line
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    [[ ${line:0:1} != '#' ]] || continue
    # A session that opens a real file has to name it, and an absolute path is
    # the checkout's. The count below is computed after the substitution, so
    # the frame is still exact -- it is the *golden* that cannot be, which is
    # what the .workspace marker is about.
    line=${line//%ROOT%/$root}
    printf 'Content-Length: %d\r\n\r\n%s' "${#line}" "$line"
  done
}

# MCP's stdio framing, which needs no count: "Messages are delimited by
# newlines, and MUST NOT contain embedded newlines." So a session file's line
# *is* the frame, and this differs from `frame` only in dropping the header --
# which is the whole of what the second transport cost (ADR-0241).
frame_lines() {
  local LC_ALL=C
  local line
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    [[ ${line:0:1} != '#' ]] || continue
    line=${line//%ROOT%/$root}
    printf '%s\n' "$line"
  done
}

failed=0
checked=0
for session in "$here"/sessions/*.jsonl; do
  name=$(basename "${session%.jsonl}")
  expected_out="${session%.jsonl}.out"
  expected_note="${session%.jsonl}.note"
  if [[ ! -f $expected_out ]]; then
    echo "--- $name: no golden ($expected_out) ---" >&2
    failed=$((failed + 1))
    continue
  fi
  checked=$((checked + 1))
  if [[ -f ${session%.jsonl}.mcp ]]; then
    frame_lines <"$session" >"$work/$name.in"
  else
    frame <"$session" >"$work/$name.in"
  fi
  # The scratch path is per session and inside the work directory. The default
  # the server would pick is under TMPDIR and carries its pid, so two servers
  # would not collide -- but two *runs of this suite* would still hand the same
  # session the same name, and a session is entitled to a path nothing else has
  # touched.
  #
  # `env -u` rather than a wrapper script, and it works because PASLS_COMPILER
  # is a *command* and not a path -- the server pastes it in front of the file
  # name it computed.
  scratch="$work/$name.pas"
  if [[ -f ${session%.jsonl}.scratch ]]; then
    scratch=$(<"${session%.jsonl}.scratch")
  fi
  # The one session that is about the name the server picks for itself. Its
  # TMPDIR is empty and its own, and the server's pid is captured so the file
  # left in it can be named exactly -- `$!` and `wait`, because a pid is not a
  # thing a subshell can hand back after the fact.
  own_tmpdir=
  [[ -f ${session%.jsonl}.tmpdir ]] && own_tmpdir="$work/$name.tmp"
  [[ -n $own_tmpdir ]] && mkdir -p "$own_tmpdir"
  mode=()
  [[ -f ${session%.jsonl}.mcp ]] && mode=(--mcp)
  ( if [[ -n $heap_balance ]]; then export PASHEAP_BALANCE="$heap_balance"; fi
    # In the checkout, because an MCP server has no `rootUri` to be told and
    # takes its workspace from where it was started. An LSP session names no
    # file it does not spell out, so the directory is nothing to it either way.
    cd "$root" || exit 1
    export PASLS_COMPILER="env -u PASHEAP_BALANCE $pascalc"
    if [[ -n $own_tmpdir ]]; then
      export TMPDIR="$own_tmpdir"
      unset PASLS_SCRATCH
    else
      export PASLS_SCRATCH="$scratch"
    fi
    "$work/pasls" "${mode[@]+"${mode[@]}"}" \
      <"$work/$name.in" >"$work/$name.out" 2>"$work/$name.note" &
    server=$!
    wait $server
    server_status=$?
    printf '%s\n' "$server" >"$work/$name.pid"
    exit $server_status )
  status=$?
  if [[ $status -ne 0 ]]; then
    echo "--- $name: the server exited with status $status ---" >&2
    cat "$work/$name.note" >&2
    failed=$((failed + 1))
    continue
  fi
  # A session that names files on disk echoes their URIs back, and an absolute
  # path is as long as the checkout's -- so neither the path nor the
  # Content-Length that counts it can be written down once and compared
  # everywhere. The root is written back as %ROOT% and the counts are blanked,
  # and what such a session pins is the *behaviour*: the sessions that name no
  # file pin the framing, and they are the majority.
  actual="$work/$name.out"
  note_actual="$work/$name.note"
  if [[ -f ${session%.jsonl}.workspace ]]; then
    sed -e "s|$root|%ROOT%|g" \
        -e 's/Content-Length: [0-9]*/Content-Length: -/g' \
        "$work/$name.out" >"$work/$name.norm"
    sed -e "s|$root|%ROOT%|g" "$work/$name.note" >"$work/$name.note.norm"
    actual="$work/$name.norm"
    note_actual="$work/$name.note.norm"
  fi
  if ! diff -u "$expected_out" "$actual"; then
    echo "--- $name: the session differs (expected vs actual above) ---" >&2
    failed=$((failed + 1))
    continue
  fi
  if [[ -n $own_tmpdir ]]; then
    # What the server chose when it was told nothing: one file, under TMPDIR,
    # named for the process that wrote it. A name that carried no pid would be
    # a name a second server would collide with, and nothing else here can see
    # that -- every other session hands the server a path.
    left=$(cd "$own_tmpdir" && ls -A | sort | tr '\n' ' ')
    pid=$(<"$work/$name.pid")
    # Two files and not one: the compiler is told to write its IR beside the
    # source it was handed, so the `.ll` carries the same name. Both are named
    # here, because "everything this server left is its own" is the property
    # and a second server's leavings would be a second pair.
    want="pasls-$pid.pas pasls-$pid.pas.ll "
    if [[ $left != "$want" ]]; then
      echo "--- $name: TMPDIR holds [$left] and not [$want] ---" >&2
      failed=$((failed + 1))
      continue
    fi
  fi
  if [[ -f $expected_note ]]; then
    if ! diff -u "$expected_note" "$note_actual"; then
      echo "--- $name: what the server told the user differs ---" >&2
      failed=$((failed + 1))
      continue
    fi
  elif [[ -s $note_actual ]]; then
    echo "--- $name: the server wrote to standard error and no .note says so ---" >&2
    cat "$note_actual" >&2
    failed=$((failed + 1))
    continue
  fi
  echo "$name: ok"
done

if [[ $checked -eq 0 ]]; then
  echo "--- no sessions were replayed ---" >&2
  exit 1
fi
echo "pasls: $checked session(s), $failed failed"
[[ $failed -eq 0 ]]
