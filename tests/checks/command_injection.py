#!/usr/bin/env python3
"""Is a path this program was *given* still only a path? (ADR-0362)

`lsp/pasls.pas` built a shell command and wrapped the source path in
apostrophes. A path holding an apostrophe closes that quoting and what
follows it is a command -- so a file named

    a'; touch PWNED; echo '.pas

ran `touch PWNED` when an editor, or under MCP whatever is driving the
model, asked for its outline. The fix is `PasProcess.Execute`: the words are
carried as words and no shell reads them.

**It needs a harness of its own** for `long-path`'s reason met a fourth time:
no test case can choose how it is *named*, every case here being compiled
where it sits under a name a glob found. And it is a gate rather than a
session because `lsp/run.sh` compares a conversation byte for byte and a
workspace file with a semicolon in its name would have to be quoted by every
sweep that walks the tree.

It fails in **both** directions. A payload that runs is the defect; a payload
path that stops *working* is the other half, and the outline of that file is
checked against what it declares -- quoting the path more cleverly would pass
the first assertion and fail this one.

Converted from shell under ADR-0366. Two things the shell version needed are
simply gone rather than translated, and neither is part of the question: the
`sed` that spliced the payload path into a JSON line, which built invalid
JSON for any path holding a quote or a backslash and is now `json.dumps` with
the real path; and the `sed -i` portability wrapper it was written for. The
spy compiler is Python for the same reason the gate is.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent

INIT = {"jsonrpc": "2.0", "id": 1, "method": "initialize",
        "params": {"protocolVersion": "2025-06-18", "capabilities": {},
                   "clientInfo": {"name": "gate", "version": "1"}}}

PAYLOAD_SOURCE = """program Payload(output);
var wanted: integer;
begin
  wanted := 1;
  writeln(wanted)
end.
"""

SPY = """#!/usr/bin/env python3
# Seen from inside the compiler, because the directory is gone by the time the
# server has exited: PASLS_COMPILER is a command, and this one looks round
# before it compiles.
import os, sys
with open(%r, 'w') as f:
    for n in sorted(os.listdir(os.environ['TMPDIR'])):
        f.write(n + '\\n')
os.execv(%r, [%r] + sys.argv[1:])
"""


def absolutise(p):
    """`$(cd dir && pwd)/base`: an absolute path with the directory's symlinks
    resolved and the name left as written."""
    q = Path(p)
    if q.parent == Path(''):
        return str(q)
    return str(Path(os.path.realpath(q.parent)) / q.name)


def main(argv):
    if not argv:
        print('usage: command_injection.py <pascalcc> [pascalc]',
              file=sys.stderr)
        return 1
    pascalcc = argv[0]
    pascalc = argv[1] if len(argv) > 1 else os.environ.get('PASCALC',
                                                           'pascalc')
    if '/' in pascalcc:
        pascalcc = absolutise(pascalcc)
    if '/' in pascalc:
        pascalc = absolutise(pascalc)

    work = Path(os.path.realpath(tempfile.mkdtemp()))
    try:
        return check(pascalcc, pascalc, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def check(pascalcc, pascalc, work):
    fails = []

    def fail(msg):
        print('command-injection: ' + msg, file=sys.stderr)
        fails.append(msg)

    r = subprocess.run([str(ROOT / 'lsp' / 'build.py'), pascalcc,
                        str(work / 'pasls')], capture_output=True, text=True)
    if r.returncode != 0:
        print('--- the language server did not build ---', file=sys.stderr)
        sys.stderr.write(r.stdout + r.stderr)
        return 1

    # The payload is a *marker file*, not damage: what is being proved is that
    # something ran, and the cheapest proof of that is something appearing.
    # A bare name, and the server is started here: a marker holding a `/`
    # could not be part of a file name at all.
    marker = work / 'PWNED'
    payload = "a'; touch PWNED; echo '.pas"
    (work / payload).write_text(PAYLOAD_SOURCE)

    def serve(lines):
        """Feed the server a conversation and answer with its two streams."""
        env = dict(os.environ)
        env['PASLS_COMPILER'] = pascalc
        env['PASLS_SCRATCH'] = str(work / 'scratch')
        r = subprocess.run([str(work / 'pasls'), '--mcp'],
                           input=''.join(l + '\n' for l in lines),
                           cwd=work, env=env, capture_output=True, text=True)
        return (r.stdout + r.stderr).rstrip('\n')

    def ask(tool, path):
        return serve([json.dumps(INIT),
                      json.dumps({"jsonrpc": "2.0", "id": 2,
                                  "method": "tools/call",
                                  "params": {"name": tool,
                                             "arguments": {"path": path}}})])

    out = ask('outline', str(work / payload))

    if marker.exists():
        fail('the path ran a command: PWNED was created')

    # The other direction. `outline` stops after the parse, so this is the
    # whole of what the file declares -- and it is only reachable if the path
    # arrived whole.
    if 'program Payload' not in out:
        fail("the outline of the payload file is missing 'program Payload': "
             + out)
    if 'var wanted' not in out:
        fail("the outline did not reach 'wanted', so the path was cut: " + out)

    # And the same again through `diagnostics`, which is the other tool and
    # takes a different road to the same command -- it reads the sidecars
    # first.
    if marker.exists():
        marker.unlink()
    out = ask('diagnostics', str(work / payload))
    if marker.exists():
        fail('diagnostics ran a command from the path')
    if '"isError":false' not in out:
        fail('the payload file did not compile through diagnostics: ' + out)

    # A path holding chr(0) -- JSON spells it \\u0000 -- used to stop the
    # server at the first foreign crossing (ADR-0122's trap, at PasFS.Exists),
    # so one request ended the session and every request after it went
    # unanswered. The third request here is the ordinary one and must be
    # answered; the second must be refused and not obeyed.
    conversation = [
        json.dumps(INIT),
        json.dumps({"jsonrpc": "2.0", "id": 2, "method": "tools/call",
                    "params": {"name": "outline",
                               "arguments": {"path": "/tmp/x\0y.pas"}}}),
        json.dumps({"jsonrpc": "2.0", "id": 3, "method": "tools/call",
                    "params": {"name": "outline",
                               "arguments": {"path": str(work / payload)}}}),
    ]
    (work / 'nul.jsonl').write_text(''.join(l + '\n' for l in conversation))
    out = serve(conversation)
    i = out.find('"id":3')
    if i < 0 or 'program Payload' not in out[i:]:
        fail('a path holding chr(0) ended the session; the request after it '
             'was not answered: ' + out)
    if '"id":2,"error"' not in out:
        fail('a path holding chr(0) was not refused: ' + out)

    # And the scratch files: with PASLS_SCRATCH unset the server must put them
    # in a directory of its own under TMPDIR, not beside everybody else's -- a
    # name composed at the top of a shared directory is one another user can
    # plant a link at first -- and must take that directory away when it
    # exits.
    tmp = work / 'tmp'
    tmp.mkdir(parents=True, exist_ok=True)
    seen_at = work / 'seen'
    spy = work / 'spy'
    spy.write_text(SPY % (str(seen_at), pascalc, pascalc))
    spy.chmod(0o755)
    env = dict(os.environ)
    env['TMPDIR'] = str(tmp)
    env['PASLS_COMPILER'] = str(spy)
    env.pop('PASLS_SCRATCH', None)
    subprocess.run([str(work / 'pasls'), '--mcp'],
                   input=(work / 'nul.jsonl').read_text(),
                   cwd=work, env=env, capture_output=True, text=True)
    try:
        seen = seen_at.read_text().split()
    except OSError:
        seen = []
    if len(seen) != 1 or len(seen[0]) != len('pasls-XXXXXX') or \
       not seen[0].startswith('pasls-'):
        fail('while the server ran, TMPDIR held [%s] and not one private '
             'pasls-XXXXXX directory' % ' '.join(seen + ['']))
    left = sorted(p.name for p in tmp.iterdir())
    if left:
        fail('the private scratch directory was left behind at exit: %s'
             % '\n'.join(left))

    if not fails:
        print('command-injection: a path holding an apostrophe, a semicolon '
              'and a command is a path -- outline and diagnostics both read '
              'it and neither ran it; one holding chr(0) is refused without '
              'ending the session; and the scratch files live in a private '
              'directory that is gone at exit')
        return 0
    return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
