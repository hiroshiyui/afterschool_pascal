#!/usr/bin/env python3
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

"""Build the language server and replay every recorded session against it.

  run.py <path-to-pascalcc> [<path-to-pascalc>]

The second is what the server invokes on a document; it defaults to $PASCALC
and then to whatever `pascalc` is on PATH, which is how tests/checks/
heap_balance.py drives this without being told twice where the compiler is.

A session needs its own harness, and the reason is the same one tests/dumps/
has: what is compared here is not what a compiled program printed but what a
*protocol* did, and the two differ in three ways tests/run_test.py has no
sidecar for.

  * The input is framed. `Content-Length: N<CR><LF><CR><LF>` and then exactly
    N bytes, so a .in file would have to be maintained with the byte counts
    written into it by hand and rewritten whenever a message changed. The
    session files here are one JSON message per line and this script computes
    the frames, which is what keeps them readable and correct at once.
  * The output is framed too, and the goldens hold the real carriage returns
    and the real byte counts -- so a change to what the server renders fails
    here even when the JSON still parses.
  * The server is a *server*: it needs a compiler to invoke and a scratch
    path to write, neither of which is a thing a test case is handed.

  sessions/name.jsonl   one JSON-RPC message per line, framed by this script;
                        a blank line or one beginning with # is a comment,
                        because a session is worth annotating and JSON has
                        nowhere to say why a message is there. %ROOT% in a
                        message becomes the path of this checkout
  sessions/name.out     the exact bytes the server writes to standard output
  sessions/name.note    what it writes to standard error; absent means none
  sessions/name.workspace  a marker: this session names files on disk, so its
                        golden is normalised before the diff -- see below
  sessions/name.scratch a scratch path for this session, one line, in place
                        of the work directory's. It exists for the sessions
                        that are about a path the server *cannot* write, and
                        so must name one no work directory would be
  sessions/name.tmpdir  a marker: this session is about the scratch path the
                        server picks when it is told none. PASLS_SCRATCH is
                        left unset, TMPDIR is a directory of this session's
                        own, and what is checked afterwards is the name of
                        the file left in it -- which must carry the server's
                        own process id (ADR-0242). Every other session sets
                        the path, so this is the only one that can see it
  sessions/name.notmpdir a marker: PASLS_SCRATCH is left unset and TMPDIR
                        names a directory no machine has, so the server can
                        make no directory of its own (ADR-0363). What is
                        pinned is that it still answers, and where it says
                        nothing can be written
  sessions/name.mcp     a marker: this session is MCP and not LSP. The server
                        is started with --mcp, the framing is one JSON
                        message to a line rather than Content-Length, and it
                        runs in the checkout -- an MCP client launches its
                        server as a subprocess and an agent's subprocess
                        starts in the tree it is working on (ADR-0241)

Converted from shell under ADR-0366; the shell version's output is what this
was required to reproduce byte for byte, over every session and on every arm.
"""

import difflib
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.stdout.reconfigure(line_buffering=True)

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent

SPY = """#!/usr/bin/env python3
# A compiler that looks round before it compiles: the scratch directory is
# gone when the server exits (ADR-0363), so the only moment anything can see
# it is while the server is asking the compiler about a document.
# `PASLS_COMPILER` is a command and this is one.
import os, sys
with open(%r, 'w') as f:
    for n in os.listdir(os.environ['TMPDIR']):
        f.write(n + '\\n')
os.environ.pop('PASHEAP_BALANCE', None)
os.execvp(%r, [%r] + sys.argv[1:])
"""


def read_exact(p):
    """A golden, byte for byte.

    `Path.read_text()` translates newlines: it turns `\r\n` into `\n`, so a
    golden holding LSP framing compares equal to output that has lost its
    carriage returns -- which is precisely the claim these goldens exist to
    make. Read with translation off.
    """
    with open(p, 'r', encoding='utf-8', errors='surrogateescape',
              newline='') as f:
        return f.read()


def split_lines(text):
    """Lines as `diff` counts them: broken at `\n` and nowhere else.
    `str.splitlines` also breaks at a bare carriage return, and every golden
    here is LSP framing."""
    out = text.split('\n')
    tail = out.pop()
    lines = [ln + '\n' for ln in out]
    if tail:
        lines.append(tail)
    return lines


def gnu_date(p):
    ns = p.stat().st_mtime_ns
    t = time.localtime(ns // 10**9)
    return '%s.%09d %s' % (time.strftime('%Y-%m-%d %H:%M:%S', t),
                           ns % 10**9, time.strftime('%z', t))


def diff_u(a, b):
    """`diff -u a b`, printed where the shell printed it -- standard output."""
    d = difflib.unified_diff(
        split_lines(read_exact(a)), split_lines(read_exact(b)),
        str(a), str(b), gnu_date(a), gnu_date(b))
    lines = list(d)
    if not lines:
        return False
    sys.stdout.writelines(lines)
    return True


def absolutise(p):
    q = Path(p)
    if q.parent == Path(''):
        return str(q)
    return str(Path(os.path.realpath(q.parent)) / q.name)


def frame(session, root, mcp):
    """One JSON message per line becomes one frame per message.

    A body must not gain a newline it did not have: the byte count in the
    header is the whole of what says where it ends. MCP's stdio framing needs
    no count -- "Messages are delimited by newlines, and MUST NOT contain
    embedded newlines" -- so a session file's line *is* the frame, and the two
    differ only in the header, which is the whole of what the second transport
    cost (ADR-0241).
    """
    out = b''
    for line in session.read_text().split('\n'):
        if not line or line[0] == '#':
            continue
        # A session that opens a real file has to name it, and an absolute
        # path is the checkout's. The count below is computed after the
        # substitution, so the frame is still exact -- it is the *golden* that
        # cannot be, which is what the .workspace marker is about.
        line = line.replace('%ROOT%', root)
        body = line.encode('utf-8', 'surrogateescape')
        if mcp:
            out += body + b'\n'
        else:
            out += b'Content-Length: %d\r\n\r\n' % len(body) + body
    return out


def main(argv):
    if len(argv) < 1:
        print('usage: run.py <pascalcc> [<pascalc>]', file=sys.stderr)
        return 2
    pascalcc = argv[0]
    pascalc = argv[1] if len(argv) > 1 else os.environ.get('PASCALC',
                                                           'pascalc')
    # Absolute, because the server is started in the checkout and a relative
    # compiler path would then name nothing. `PASLS_COMPILER` is a *command*
    # and may be a bare name on PATH, which is left alone.
    if '/' in pascalcc:
        pascalcc = absolutise(pascalcc)
    if '/' in pascalc:
        pascalc = absolutise(pascalc)

    work = Path(tempfile.mkdtemp())
    try:
        return replay(pascalcc, pascalc, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def replay(pascalcc, pascalc, work):
    root = str(ROOT)

    # ADR-0183's balance belongs to the *server*, and two other Pascal
    # programs run inside this script: `pascalcc` builds it, and the server
    # then invokes `pascalc` once per document. Both are Pascal programs on
    # the same runtime, so an inherited PASHEAP_BALANCE would have them count
    # their own allocations into the same file -- which is
    # `tests/run_test.py`'s hazard, met twice over. It is taken out of the
    # environment here, put back only around the server, and stripped again
    # from what the server starts.
    heap_balance = os.environ.pop('PASHEAP_BALANCE', '')

    r = subprocess.run([str(HERE / 'build.py'), pascalcc, str(work / 'pasls')],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print('--- the language server did not build ---', file=sys.stderr)
        sys.stderr.write(r.stdout + r.stderr)
        return 1

    failed = 0
    checked = 0
    for session in sorted((HERE / 'sessions').glob('*.jsonl')):
        stem = str(session)[:-len('.jsonl')]
        name = Path(stem).name
        expected_out = Path(stem + '.out')
        expected_note = Path(stem + '.note')
        if not expected_out.is_file():
            print('--- %s: no golden (%s) ---' % (name, expected_out),
                  file=sys.stderr)
            failed += 1
            continue
        checked += 1
        mcp = Path(stem + '.mcp').is_file()
        (work / (name + '.in')).write_bytes(frame(session, root, mcp))

        # The scratch path is per session and inside the work directory. The
        # default the server would pick is under TMPDIR and carries its pid,
        # so two servers would not collide -- but two *runs of this suite*
        # would still hand the same session the same name, and a session is
        # entitled to a path nothing else has touched.
        scratch = str(work / (name + '.pas'))
        if Path(stem + '.scratch').is_file():
            scratch = Path(stem + '.scratch').read_text().rstrip('\n')

        # The one session that is about the name the server picks for itself.
        # Its TMPDIR is empty and its own.
        own_tmpdir = None
        if Path(stem + '.tmpdir').is_file():
            own_tmpdir = work / (name + '.tmp')
            own_tmpdir.mkdir(parents=True, exist_ok=True)

        env = dict(os.environ)
        if heap_balance:
            env['PASHEAP_BALANCE'] = heap_balance
        # `env -u` rather than a wrapper script, and it works because
        # PASLS_COMPILER is a *command* and not a path -- the server pastes it
        # in front of the file name it computed.
        env['PASLS_COMPILER'] = 'env -u PASHEAP_BALANCE ' + pascalc
        seen_at = work / (name + '.seen')
        if own_tmpdir is not None:
            env['TMPDIR'] = str(own_tmpdir)
            spy = work / (name + '.spy')
            spy.write_text(SPY % (str(seen_at), pascalc, pascalc))
            spy.chmod(0o755)
            env['PASLS_COMPILER'] = str(spy)
            env.pop('PASLS_SCRATCH', None)
        elif Path(stem + '.notmpdir').is_file():
            env['TMPDIR'] = '/no-such-directory-at-all'
            env.pop('PASLS_SCRATCH', None)
        else:
            env['PASLS_SCRATCH'] = scratch

        out_path = work / (name + '.out')
        note_path = work / (name + '.note')
        # In the checkout, because an MCP server has no `rootUri` to be told
        # and takes its workspace from where it was started. An LSP session
        # names no file it does not spell out, so the directory is nothing to
        # it either way.
        with open(work / (name + '.in'), 'rb') as fin, \
                open(out_path, 'wb') as fout, open(note_path, 'wb') as fnote:
            status = subprocess.run(
                [str(work / 'pasls')] + (['--mcp'] if mcp else []),
                cwd=ROOT, env=env, stdin=fin, stdout=fout,
                stderr=fnote).returncode
        if status != 0:
            print('--- %s: the server exited with status %d ---'
                  % (name, status), file=sys.stderr)
            sys.stderr.write(note_path.read_text(errors='surrogateescape'))
            failed += 1
            continue

        # A session that names files on disk echoes their URIs back, and an
        # absolute path is as long as the checkout's -- so neither the path
        # nor the Content-Length that counts it can be written down once and
        # compared everywhere. The root is written back as %ROOT% and the
        # counts are blanked, and what such a session pins is the *behaviour*:
        # the sessions that name no file pin the framing, and they are the
        # majority.
        actual, note_actual = out_path, note_path
        if Path(stem + '.workspace').is_file():
            norm = read_exact(out_path)
            norm = norm.replace(root, '%ROOT%')
            norm = re.sub(r'Content-Length: [0-9]*', 'Content-Length: -', norm)
            actual = work / (name + '.norm')
            actual.write_bytes(norm.encode('utf-8', 'surrogateescape'))
            note_actual = work / (name + '.note.norm')
            note_actual.write_bytes(
                read_exact(note_path).replace(root, '%ROOT%').encode(
                    'utf-8', 'surrogateescape'))

        if diff_u(expected_out, actual):
            print('--- %s: the session differs (expected vs actual above) ---'
                  % name, file=sys.stderr)
            failed += 1
            continue

        if own_tmpdir is not None:
            # What the server chose when it was told nothing: a directory of
            # its own under TMPDIR, made for it by the system (ADR-0363), with
            # the document inside. It was one file named `pasls-<pid>.pas` at
            # the top of TMPDIR (ADR-0242), which kept two servers apart and
            # kept nothing else out -- a name anyone sharing the directory
            # could compose first and plant a link at. Seen from inside the
            # compiler, because afterwards it is gone.
            try:
                seen = sorted(seen_at.read_text().split())
            except OSError:
                seen = []
            ok = (len(seen) == 1 and seen[0].startswith('pasls-')
                  and len(seen[0]) == len('pasls-XXXXXX'))
            if not ok:
                print('--- %s: while the server ran, TMPDIR held [%s] and not '
                      'one private pasls-XXXXXX directory ---'
                      % (name, ' '.join(seen + [''])), file=sys.stderr)
                failed += 1
                continue
            # And nothing afterwards: the server takes its directory away. A
            # session that ended without `exit` would leave it, and this one
            # ends with one.
            left = sorted(p.name for p in own_tmpdir.iterdir())
            if left:
                print('--- %s: after the server exited, TMPDIR still holds '
                      '[%s] ---' % (name, ' '.join(left + [''])),
                      file=sys.stderr)
                failed += 1
                continue

        if expected_note.is_file():
            if diff_u(expected_note, note_actual):
                print('--- %s: what the server told the user differs ---'
                      % name, file=sys.stderr)
                failed += 1
                continue
        elif note_actual.stat().st_size:
            print('--- %s: the server wrote to standard error and no .note '
                  'says so ---' % name, file=sys.stderr)
            sys.stderr.write(note_actual.read_text(errors='surrogateescape'))
            failed += 1
            continue

        print('%s: ok' % name)

    if checked == 0:
        print('--- no sessions were replayed ---', file=sys.stderr)
        return 1
    print('pasls: %d session(s), %d failed' % (checked, failed))
    return 0 if failed == 0 else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
