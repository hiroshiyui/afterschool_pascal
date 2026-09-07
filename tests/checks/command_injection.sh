#!/usr/bin/env bash
# Is a path this program was *given* still only a path? (ADR-0362)
#
# `lsp/pasls.pas` built a shell command and wrapped the source path in
# apostrophes. A path holding an apostrophe closes that quoting and what
# follows it is a command -- so a file named
#
#     a'; touch PWNED; echo '.pas
#
# ran `touch PWNED` when an editor, or under MCP whatever is driving the
# model, asked for its outline. The fix is `PasProcess.Execute`: the words are
# carried as words and no shell reads them.
#
# **It needs a harness of its own** for `long-path`'s reason met a fourth time:
# no test case can choose how it is *named*, every case here being compiled
# where it sits under a name a glob found. And it is a gate rather than a
# session because `lsp/run.sh` compares a conversation byte for byte and a
# workspace file with a semicolon in its name would have to be quoted by every
# sweep that walks the tree.
#
# It fails in **both** directions. A payload that runs is the defect; a payload
# path that stops *working* is the other half, and the outline of that file is
# checked against what it declares -- quoting the path more cleverly would pass
# the first assertion and fail this one.
set -uo pipefail

pascalcc=${1:?usage: command_injection.sh <pascalcc> [pascalc]}
pascalc=${2:-${PASCALC:-pascalc}}
root=$(cd "$(dirname "$0")/../.." && pwd)
[[ $pascalcc == */* ]] && pascalcc=$(cd "$(dirname "$pascalcc")" && pwd)/$(basename "$pascalcc")
[[ $pascalc == */* ]] && pascalc=$(cd "$(dirname "$pascalc")" && pwd)/$(basename "$pascalc")

work=$(mktemp -d)
work=$(cd "$work" && pwd)
trap 'rm -rf "$work"' EXIT
fails=0
fail() { echo "command-injection: $*" >&2; fails=$((fails + 1)); }

if ! "$root/lsp/build.sh" "$pascalcc" "$work/pasls" >"$work/build.log" 2>&1; then
  echo "--- the language server did not build ---" >&2
  cat "$work/build.log" >&2
  exit 1
fi

# The payload is a *marker file*, not damage: what is being proved is that
# something ran, and the cheapest proof of that is something appearing.
# A bare name, and the server is started here: a marker holding a `/` could
# not be part of a file name at all.
cd "$work" || exit 1
marker=PWNED
payload="a'; touch $marker; echo '.pas"
cat > "$payload" <<'PEOF'
program Payload(output);
var wanted: integer;
begin
  wanted := 1;
  writeln(wanted)
end.
PEOF

ask() {                       # ask <tool> <path>; prints the server's replies
  {
    printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"gate","version":"1"}}}'
    printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"%s","arguments":{"path":"%s"}}}\n' \
           "$1" "$2"
  } | PASLS_COMPILER=$pascalc PASLS_SCRATCH=$work/scratch \
      "$work/pasls" --mcp 2>&1
}

out=$(ask outline "$work/$payload")


[[ -e $marker ]] && fail "the path ran a command: $marker was created"

# The other direction. `outline` stops after the parse, so this is the whole
# of what the file declares -- and it is only reachable if the path arrived
# whole.
case $out in
  *'program Payload'*) ;;
  *) fail "the outline of the payload file is missing 'program Payload': $out" ;;
esac
case $out in
  *'var wanted'*) ;;
  *) fail "the outline did not reach 'wanted', so the path was cut: $out" ;;
esac

# And the same again through `diagnostics`, which is the other tool and takes
# a different road to the same command -- it reads the sidecars first.
rm -f "$marker"
out=$(ask diagnostics "$work/$payload")
[[ -e $marker ]] && fail "diagnostics ran a command from the path"
case $out in
  *'"isError":false'*) ;;
  *) fail "the payload file did not compile through diagnostics: $out" ;;
esac

if [[ $fails -eq 0 ]]; then
  echo "command-injection: a path holding an apostrophe, a semicolon and a" \
       "command is a path -- outline and diagnostics both read it and neither" \
       "ran it"
  exit 0
fi
exit 1
