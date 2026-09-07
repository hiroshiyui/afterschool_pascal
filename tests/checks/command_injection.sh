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

# A path holding chr(0) -- JSON spells it \u0000 -- used to stop the server at
# the first foreign crossing (ADR-0122's trap, at PasFS.Exists), so one request
# ended the session and every request after it went unanswered. The third
# request here is the ordinary one and must be answered; the second must be
# refused and not obeyed.
python3 - > "$work/nul.jsonl" <<'PEOF'
import json
nul = chr(0)
print(json.dumps({"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"gate","version":"1"}}}))
print(json.dumps({"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"outline","arguments":{"path":"/tmp/x" + nul + "y.pas"}}}))
print(json.dumps({"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"outline","arguments":{"path":"$PAYLOAD"}}}))
PEOF
sed -i "s|\$PAYLOAD|$work/$payload|" "$work/nul.jsonl"
out=$(PASLS_COMPILER=$pascalc PASLS_SCRATCH=$work/scratch "$work/pasls" --mcp < "$work/nul.jsonl" 2>&1)
case $out in
  *'"id":3'*'program Payload'*) ;;
  *) fail "a path holding chr(0) ended the session; the request after it was not answered: $out" ;;
esac
case $out in
  *'"id":2,"error"'*) ;;
  *) fail "a path holding chr(0) was not refused: $out" ;;
esac

# And the scratch files: with PASLS_SCRATCH unset the server must put them in
# a directory of its own under TMPDIR, not beside everybody else's -- a name
# composed at the top of a shared directory is one another user can plant a
# link at first -- and must take that directory away when it exits.
mkdir -p "$work/tmp"
# Seen from inside the compiler, because the directory is gone by the time the
# server has exited: PASLS_COMPILER is a command, and this one looks round
# before it compiles.
cat >"$work/spy" <<SPY
#!/usr/bin/env bash
ls -A "\$TMPDIR" >"$work/seen"
exec "$pascalc" "\$@"
SPY
chmod +x "$work/spy"
TMPDIR=$work/tmp PASLS_COMPILER=$work/spy "$work/pasls" --mcp < "$work/nul.jsonl" >/dev/null 2>&1
seen=$(tr '\n' ' ' <"$work/seen" 2>/dev/null)
case $seen in
  pasls-??????' ') ;;
  *) fail "while the server ran, TMPDIR held [$seen] and not one private pasls-XXXXXX directory" ;;
esac
if [[ -n $(ls -A "$work/tmp") ]]; then
  fail "the private scratch directory was left behind at exit: $(ls "$work/tmp")"
fi

if [[ $fails -eq 0 ]]; then
  echo "command-injection: a path holding an apostrophe, a semicolon and a" \
       "command is a path -- outline and diagnostics both read it and neither" \
       "ran it; one holding chr(0) is refused without ending the session; and" \
       "the scratch files live in a private directory that is gone at exit"
  exit 0
fi
exit 1
