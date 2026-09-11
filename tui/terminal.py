#!/usr/bin/env python3
"""Does the shell emit what the model decided? (ADR-0402)

`tui/run.py` compares what `tui/apedit.pas` **decided** -- a plane of
characters and a plane of roles -- and the shell that turns a role into an
escape sequence is held by nothing.  That gap is a `doc/sop.md` §7 row
ADR-0389 promised, ADR-0391 promised again and ADR-0393 closed one half of:
`tui-palette` reads `RoleColour` and `RoleRgb` and holds every pairing in
them to a floor, so the *table* is checked and what `PutRow` does with it is
not.  A shell painting every row in one colour passes all twenty sessions and
both halves of the palette gate.

This closes it, by driving the real `build/bin/apide` under a pseudo-terminal
and reading the bytes back.

**It is not the PTY binding ADR-0262 declined**, and the distinction is the
whole argument for doing it this way.  That record refused a binding *in this
language* on the grounds that a case needing one becomes a test of the
binding.  Nothing here is in the language: `pty.fork` is Python's, the way
`lsp/run.py`'s pipe is, and what is under test is a compiled program's output
on its standard output.

**The expectation is not recorded, it is derived.**  A golden of escape bytes
would agree with whatever wrote it, which is the standing rule everywhere in
this tree and is exactly how `crPrompt` came to be drawn on no screen.  So
each script is replayed *twice* -- once through `tui/session.pas`, which
prints the character plane, the run decomposition and the cursor, and once
through `apide` under a terminal -- and the two are required to agree, with
`tui/palette.py`'s own parse of the two colour tables standing between a role
and a colour.  Three independent things then have to be wrong together for
this to pass.

Three claims, each in both directions:

  - **every run the shell writes is a run the model decided**, at the same
    columns, with the same characters, and no run the model decided is
    missing;
  - **the colour of a run is the table's colour for that run's role**, and
    the table is the one the terminal asked for -- the script is driven twice
    over, with `COLORTERM` set and unset, so the fallback nobody looks at is
    read as often as the scheme;
  - **the frame is bracketed and the cursor lands where the model put it** --
    hidden before the first row, shown after the last, and left at the cell
    the session's `cursor` line names.

What it still does not reach is a real terminal doing with these bytes what
the sequences say, which is not checkable here at all.  That half of the row
stays open and `doc/sop.md` says so.

It is `tui/terminal.py` and not `tui/pty.py` because `import pty` in a file
of that name finds itself and not the standard library's -- which Python says
plainly, and is the sort of thing this tree calls a probe rather than a
guess.

Run it directly, or as the `tui-terminal` case.
"""

import os
import pty
import re
import select
import shutil
import struct
import subprocess
import sys
import tempfile
import termios
import fcntl
import pathlib
import time

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
SESSIONS = HERE / 'sessions'

sys.path.insert(0, str(HERE))
import palette                                          # noqa: E402

ESC = '\x1b'

# A script this cannot drive is one that asks the *model* to do something a
# person at a terminal cannot ask for: `say` is the shell's own message line
# and `fault` is a compiler's output being landed on.  A `push` after a key
# is the same thing -- loading a file is what `push` stands for and a shell
# does it once, before the first keystroke.
UNDRIVABLE = ('say', 'fault')

# A floor, because a harness that drives nothing prints a number and passes.
# It is the shape of every sweep here and the defect `format-check` shipped.
FLOOR = 8


def winsize(fd, rows, cols):
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', rows, cols, 0, 0))


def bytes_for(word, arg):
    """The bytes a directive presses, exactly as `tui/session.pas` feeds them.

    Written out rather than shared, because there is nothing to share it
    through -- but it is the one thing here stated twice, and the reason it
    is safe is that a disagreement makes the *screens* differ and this fails.
    """
    if word == 'keys':
        return arg.encode('utf-8')
    if word == 'ctrl':
        return bytes([ord(arg[0]) - 64]) if arg else b''
    if word == 'esc':
        return (ESC + '[' + arg).encode('utf-8')
    if word == 'ss3':
        return (ESC + 'O' + arg).encode('utf-8')
    if word == 'func':
        n = int(arg)
        par = n + 10 if n <= 5 else (n + 11 if n <= 10 else n + 12)
        return (ESC + '[' + str(par) + '~').encode('utf-8')
    raise KeyError(word)


def read_script(path):
    """A session script, split into what the shell is *started* with and what
    it is *typed*.  Answers None where a person at a terminal could not have
    driven it."""
    name, rows, cols, lines, steps = '', 8, 24, [], []
    typed = False
    for raw in path.read_text(encoding='utf-8').splitlines():
        # `Word1` and `Rest` in `tui/session.pas`: the first blank ends the
        # directive and everything after it is the argument, **unstripped**.
        # A `push   writeln(1)` line is two spaces of indentation the editor
        # is meant to hold, and trimming it here made nine frames disagree
        # about the document rather than about the shell.
        word, sep, arg = raw.partition(' ')
        if not sep:
            word, arg = raw, ''
        if word in ('', '#'):
            continue
        if word in UNDRIVABLE:
            return None
        if word == 'name':
            # A shell is handed its document's name once, as an argument, and
            # `saveas.keys` renames one halfway through -- which is the whole
            # subject of that script and is the model's business, not this
            # one's.
            if typed:
                return None
            name = arg
        elif word == 'size':
            # **A session may resize between frames and a terminal may not.**
            # `session.pas` takes the size as a directive, so a script can
            # draw at 7x20 and again at 7x30; the shell asks `TermSize` on
            # every frame and would follow an ioctl, but only on a frame some
            # *key* provoked, and a script that resizes and draws provokes
            # none.  Rather than drive half of one, such a script is left to
            # `run.py`, which is the harness the question belongs to.
            if steps:
                return None
            rows, cols = (int(v) for v in arg.split())
        elif word == 'push':
            if typed:
                return None
            lines.append(arg)
        elif word == 'draw':
            steps.append(('draw', b''))
        else:
            typed = True
            steps.append(('keys', bytes_for(word, arg)))
    # A script with no `name` is an editor started with no argument, which is
    # a thing a person does; one with lines to load and no name to load them
    # from is not.
    if lines and not name:
        return None
    if not steps:
        return None
    return name, rows, cols, lines, steps


def frames_of(golden):
    """The frames a `.screen` golden holds: (chars, runs, cursor) per `draw`.

    A frame is three bordered blocks -- characters, roles, runs -- and then a
    `cursor r,c` line.  The runs block is the decomposition `PutRow` walks,
    which is why nothing here has to re-derive it: the model already wrote it
    down and this asks whether the shell wrote the same thing out.
    """
    out, block, blocks = [], None, []
    for line in golden.read_text(encoding='utf-8').splitlines():
        if line.startswith('+-') and line.endswith('-+'):
            if block is None:
                block = []
            else:
                blocks.append(block)
                block = None
            continue
        if block is not None:
            body = line[1:]
            if body.endswith('|'):
                body = body[:-1]
            block.append(body)
            continue
        m = re.match(r'cursor (\d+),(\d+)$', line)
        if m and len(blocks) == 3:
            chars, _roles, runs = blocks
            out.append((chars, [parse_runs(r) for r in runs],
                        (int(m.group(1)), int(m.group(2)))))
            blocks = []
    return out


def parse_runs(text):
    """`1-5f 6-20p ` -> [(1, 5, 'f'), (6, 20, 'p')]."""
    return [(int(a), int(b), k)
            for a, b, k in re.findall(r'(\d+)-(\d+)(\S)', text)]


def sgr(name, base):
    order = ('clBlack', 'clRed', 'clGreen', 'clYellow', 'clBlue', 'clMagenta',
             'clCyan', 'clWhite')
    return base + 9 if name == 'clDefault' else base + order.index(name)


def expected_colour(role, wide, ansi, rgb):
    """The bytes `PutRow` must write for a run of this role.

    `crText` goes through `SetColour` whatever the terminal can do, which is
    ADR-0394's decision and not an omission: `clDefault` is a colour only the
    eight-colour form can name, and it is the right answer for text a person
    is reading in their own terminal's colours.
    """
    if wide and role != 'crText':
        fg, bg = rgb[role]
        vals = [int(fg[i:i + 2], 16) for i in (0, 2, 4)]
        vals += [int(bg[i:i + 2], 16) for i in (0, 2, 4)]
        return '%s[38;2;%d;%d;%d;48;2;%d;%d;%dm' % tuple([ESC] + vals)
    fg, bg = ansi[role]
    return '%s[%d;%dm' % (ESC, sgr(fg, 30), sgr(bg, 40))


RUN = re.compile(r'\x1b\[(\d+);(\d+)H(\x1b\[[0-9;]*m)(.*?)\x1b\[0m', re.S)


def parse_frame(text):
    """One frame of emitted bytes -> ([(row, col, colour, cells)], cursor).

    A frame is `HideCursor`, then one `CursorTo` + colour + text + reset per
    run, then a `CursorTo` and `ShowCursor`.  The trailing pair is what says
    where the cursor was left, and is taken from the *end* rather than by
    counting, a frame's run count being what this is here to check.
    """
    runs = [(int(m.group(1)), int(m.group(2)), m.group(3), m.group(4))
            for m in RUN.finditer(text)]
    m = re.search(r'\x1b\[(\d+);(\d+)H\x1b\[\?25h\s*$', text)
    cursor = (int(m.group(1)), int(m.group(2))) if m else None
    return runs, cursor


def drive(binary, name, rows, cols, lines, steps, colorterm):
    """Run the editor under a terminal and answer the frame at each `draw`."""
    work = pathlib.Path(tempfile.mkdtemp(prefix='tui-pty-'))
    if name:
        (work / name).write_text('\n'.join(lines) + ('\n' if lines else ''),
                                 encoding='utf-8')
    env = dict(os.environ)
    env['TERM'] = 'xterm'
    if colorterm:
        env['COLORTERM'] = colorterm
    else:
        env.pop('COLORTERM', None)
    pid, fd = pty.fork()
    if pid == 0:
        # **The size is set in the child, before the program starts.**  Doing
        # it on the master after the fork is a race the editor sometimes wins:
        # it asks `TermSize` once in its first `Draw`, so a frame taken before
        # the ioctl lands is drawn to whatever the pty was opened with.
        os.chdir(work)
        try:
            winsize(0, rows, cols)
        except OSError:
            pass
        argv = [binary, name] if name else [binary]
        os.execve(binary, argv, env)
        os._exit(127)
    buf = ['']

    def settle(seconds=0.35):
        end = time.time() + seconds
        while time.time() < end:
            r, _, _ = select.select([fd], [], [], 0.05)
            if not r:
                continue
            try:
                chunk = os.read(fd, 1 << 16)
            except OSError:
                return False
            if not chunk:
                return False
            buf[0] += chunk.decode('utf-8', 'surrogateescape')
            end = time.time() + 0.2
        return True

    settle(0.9)
    frames = []
    try:
        for word, payload in steps:
            if word == 'draw':
                frames.append(last_frame(buf[0]))
            else:
                os.write(fd, payload)
                settle()
        os.write(fd, b'\x11')          # Ctrl-Q, twice: the document may be dirty
        settle(0.2)
        os.write(fd, b'\x11')
        settle(0.3)
    except OSError:
        pass
    try:
        os.close(fd)
    except OSError:
        pass
    try:
        os.waitpid(pid, 0)
    except ChildProcessError:
        pass
    shutil.rmtree(work, ignore_errors=True)
    return frames


def last_frame(text):
    """The most recent complete frame in what has been emitted so far.

    The shell redraws after every key and a session draws when it says so, so
    what a `draw` directive asks about is the frame standing on the terminal
    at that moment -- which is the last one that both started and finished.
    """
    start = text.rfind(ESC + '[?25l')
    if start < 0:
        return None
    end = text.find(ESC + '[?25h', start)
    if end < 0:
        return None
    return text[start:end + len(ESC + '[?25h')]


def check(name, golden_frames, live_frames, wide, ansi, rgb, letters, bad):
    where = '%s (%s)' % (name, 'truecolor' if wide else 'eight-colour')
    if len(live_frames) != len(golden_frames):
        bad.append('%s: the model drew %d frame(s) and the shell %d'
                   % (where, len(golden_frames), len(live_frames)))
        return
    for n, ((chars, runs, cursor), live) in enumerate(
            zip(golden_frames, live_frames), 1):
        if live is None:
            bad.append('%s frame %d: no frame between a hide and a show'
                       % (where, n))
            continue
        got, at = parse_frame(live)
        # **The run's columns and colour are compared one at a time and its
        # text is compared a row at a time**, because a cell is not a
        # character: a wide one owns two columns and a grapheme cluster is
        # several code points, so the golden's row is a string of *cells* and
        # cannot be sliced by column.  Concatenating a row's runs undoes
        # exactly what `PutRow` did to it, which makes the comparison the
        # right shape rather than a weaker one -- the boundaries are still
        # checked, by the columns beside them.
        want = [(r, lo, expected_colour(letters[letter], wide, ansi, rgb))
                for r, row in enumerate(runs, 1) for lo, _hi, letter in row]
        if len(got) != len(want):
            bad.append('%s frame %d: the model decided %d run(s) and the '
                       'shell wrote %d' % (where, n, len(want), len(got)))
            continue
        for (gr, gc, gk, _gt), (wr, wc, wk) in zip(got, want):
            if (gr, gc) != (wr, wc):
                bad.append('%s frame %d: a run at %d,%d where the model put '
                           'one at %d,%d' % (where, n, gr, gc, wr, wc))
            elif gk != wk:
                bad.append('%s frame %d row %d col %d: %s where the role asks '
                           'for %s' % (where, n, gr, gc,
                                       gk.replace(ESC, '<ESC>'),
                                       wk.replace(ESC, '<ESC>')))
        for r in range(1, len(runs) + 1):
            drew = ''.join(t for (rr, _c, _k, t) in got if rr == r)
            if drew != chars[r - 1]:
                bad.append('%s frame %d row %d: wrote [%s] where the model '
                           'drew [%s]' % (where, n, r, drew, chars[r - 1]))
        if at != cursor:
            bad.append('%s frame %d: the cursor was left at %s and the model '
                       'put it at %s' % (where, n, at, cursor))


def main(argv):
    if not argv:
        print('usage: pty.py <pascalcc> [pascalc]', file=sys.stderr)
        return 2
    env = dict(os.environ)
    if len(argv) > 1:
        env['PASCALC'] = argv[1]

    ansi, rgb = palette.palette(), palette.rgb_palette()
    letters = {v: k for k, v in palette.letters().items()}

    work = pathlib.Path(tempfile.mkdtemp(prefix='tui-pty-build-'))
    editor = work / 'apide'
    build = subprocess.run([sys.executable, str(HERE / 'build.py'), argv[0],
                            'apide.pas', str(editor)], env=env)
    if build.returncode != 0:
        print('tui-terminal: the editor did not build', file=sys.stderr)
        return build.returncode

    bad, driven, total = [], 0, 0
    for script in sorted(SESSIONS.glob('*.keys')):
        golden = script.with_suffix('.screen')
        if not golden.exists():
            continue
        total += 1
        parsed = read_script(script)
        if parsed is None:
            continue
        name, rows, cols, lines, steps = parsed
        frames = frames_of(golden)
        if not frames:
            continue
        driven += 1
        for colorterm in ('truecolor', None):
            live = drive(str(editor), name, rows, cols, lines, steps,
                         colorterm)
            check(script.stem, frames, live, colorterm is not None,
                  ansi, rgb, letters, bad)

    shutil.rmtree(work, ignore_errors=True)

    if driven < FLOOR:
        print('tui-terminal: %d script(s) could be driven from a terminal, fewer '
              'than the floor of %d -- a harness that drives nothing prints a '
              'number and passes' % (driven, FLOOR), file=sys.stderr)
        return 1
    if bad:
        for line in bad:
            print('tui-terminal: ' + line, file=sys.stderr)
        return 1
    print('tui-terminal: %d of %d script(s) driven under a terminal against '
          'both colour tables; every run the shell wrote is one the model '
          'decided, in the colour the role asks for' % (driven, total))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
