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

"""The compiler this repository produces, exercised as a user would reach it.

  producttest.py <path-to-pascalc> <runtime-dir> [files...]

`pascalc` is `selfhost/compiler.pas` translated by the seed and linked by
CMake, and until this existed nothing tested that artefact. `irtest.py` looks
thorough enough to cover it and does not: it builds a stage-1 compiler of its
own in a temporary directory, so the binary in `build/bin` could be missing,
stale or built from the wrong source and every test would stay green. What is
checked here is the *build wiring* -- that the product exists, runs, and
compiles a program correctly -- rather than the compiler, which the 276 cases
and the stage-2/stage-3 fixed point already cover.

It is deliberately small for that reason. Two programs, because one is not
evidence that the wiring works for anything but itself.

Converted from shell under ADR-0366, and the last of the thirty-one. Two
things it does are still shell's own and stay: `tools/pascalcc` is a shell
script by decision, so the checks that read its options parse *its* text, and
the SSE2 check traces it with `bash -x` because what is asserted is the
command line the driver builds. `timeout` is gone -- a subprocess timeout is
`subprocess.run(timeout=)` and needs no coreutils, which is what the shell's
three-way fallback for macOS was working around.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.stdout.reconfigure(line_buffering=True)

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent

TARGET_PAS = """program Target(output);
begin
  writeln('x')
end.
"""

DFLT_PAS = """program dflt(output);
var s: string(5);
begin s := 'hi'; writeln(s) end.
"""

REJECTED_PAS = """program Rejected(output);
begin
  undeclared := 1
end.
"""


class Run:
    """The tallies, and the two ways a check reports."""

    def __init__(self):
        self.checked = 0
        self.failed = 0

    def fail(self, msg):
        print(msg, file=sys.stderr)
        self.failed += 1


def sh(argv, timeout=None, **kw):
    kw.setdefault('capture_output', True)
    kw.setdefault('text', True)
    try:
        return subprocess.run(argv, timeout=timeout, **kw)
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(argv, 124, '', '')


def main(argv):
    if len(argv) < 2 or not argv[0] or not argv[1]:
        print('usage: producttest.py <pascalc> <runtime-dir> [files...]',
              file=sys.stderr)
        return 2
    pascalc, runtime = argv[0], argv[1]
    files = argv[2:]

    if not os.access(pascalc, os.X_OK):
        print('producttest: %s is not executable -- was it built?' % pascalc,
              file=sys.stderr)
        return 1

    work = Path(tempfile.mkdtemp())
    try:
        return check(pascalc, runtime, files, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def check(pascalc, runtime, files, work):
    r = Run()
    driver = str(ROOT / 'tools' / 'pascalcc')

    # A caller may name others. The default pair is a small program and a
    # larger one; there is one language, so neither stands for a mode.
    if not files:
        files = [str(ROOT / 'tests' / 'hello.pas'),
                 str(ROOT / 'tests' / 'extended' / 'otherwise.pas')]

    for f in files:
        name = Path(f).stem
        expected = Path(f[:-len('.pas')] + '.out')
        if not expected.is_file():
            r.fail('producttest: %s has no .out to compare against' % name)
            continue

        # A command line, since ADR-0081: the compiler reads its own arguments
        # through the binding of its program-parameters, so -o is a flag like
        # any other compiler's rather than the file it used to be.
        p = sh([pascalc, f, '-o', str(work / 'ir.ll')], timeout=120)
        if p.returncode != 0:
            print('--- %s: pascalc did not translate it ---' % name,
                  file=sys.stderr)
            sys.stderr.write(p.stderr)
            r.failed += 1
            continue
        # A compiler that exits 0 and writes nothing would otherwise be
        # reported as a link failure, which names the wrong component.
        if not (work / 'ir.ll').stat().st_size:
            r.fail('--- %s: pascalc exited 0 and wrote no IR ---' % name)
            continue

        # Linking is the one part of a driver's job that does not port:
        # neither standard has process control, so the Pascal compiler stops
        # at the IR and something outside it assembles and links. Here that is
        # this script.
        p = sh(['clang', '-Wno-override-module', str(work / 'ir.ll'),
                os.path.join(runtime, 'libpasrt.a'), '-lm',
                '-o', str(work / 'prog')])
        if p.returncode != 0:
            print('--- %s: what pascalc wrote did not link ---' % name,
                  file=sys.stderr)
            sys.stderr.write(p.stderr)
            r.failed += 1
            continue

        stdin_path = Path(f[:-len('.pas')] + '.in')
        if not stdin_path.is_file():
            stdin_path = Path('/dev/null')
        with open(stdin_path, 'rb') as fin:
            p = subprocess.run([str(work / 'prog')], stdin=fin,
                               stdout=subprocess.PIPE,
                               stderr=subprocess.DEVNULL)
        r.checked += 1
        got = p.stdout.decode('utf-8', 'surrogateescape')
        want = expected.read_text(errors='surrogateescape')
        if got != want:
            print('--- %s: pascalc built a program with the wrong output ---'
                  % name, file=sys.stderr)
            sys.stderr.write(unified(expected, got, work))
            r.failed += 1

    version_check(r, pascalc)
    compiler_help(r, pascalc)
    help_text = driver_help(r, driver)
    subcommands(r, driver, help_text)

    (work / 'target.pas').write_text(TARGET_PAS)
    target_flag(r, pascalc, work)
    dump_through(r, pascalc, driver, work)
    no_standard(r, pascalc, driver, runtime, work)
    import_diagnostics(r, pascalc, work)
    default_target(r, pascalc, work)
    exit_status(r, pascalc, work)
    target_env(r, pascalc, driver, runtime, work)
    sse2(r, pascalc, driver, runtime, work)
    command_line(r, pascalc, work)

    if r.failed:
        print('producttest: %d of %d failed' % (r.failed, r.checked + r.failed),
              file=sys.stderr)
        return 1
    print('producttest: %d checks passed against the built pascalc' % r.checked)
    return 0


def unified(expected, got, work):
    """`diff -u <golden> <what the program wrote>`, as the shell printed it."""
    import difflib
    import time
    out = work / 'out.txt'
    out.write_text(got, errors='surrogateescape')

    def when(p):
        ns = p.stat().st_mtime_ns
        t = time.localtime(ns // 10**9)
        return '%s.%09d %s' % (time.strftime('%Y-%m-%d %H:%M:%S', t),
                               ns % 10**9, time.strftime('%z', t))
    a = expected.read_text(errors='surrogateescape').split('\n')
    b = got.split('\n')
    for xs in (a, b):
        if xs and xs[-1] == '':
            xs.pop()
    return ''.join(difflib.unified_diff([x + '\n' for x in a],
                                        [x + '\n' for x in b],
                                        str(expected), str(out),
                                        when(expected), when(out)))


def version_check(r, pascalc):
    """The version it reports is the one the project carries.

    Pascal has no preprocessor, so CMake cannot substitute the number into
    compiler.pas: it is written there as a constant and checked here, which is
    the arrangement `fileSize` and PAS_FILE_SIZE already have for the same
    reason -- two files that cannot include one another, and a disagreement
    that is checked rather than trusted. A compiler that misreports its own
    version makes every bug report worse than no version at all.
    """
    want = ''
    m = re.search(r'^project\(afterschool_pascal VERSION ([0-9.]*)',
                  (ROOT / 'CMakeLists.txt').read_text(), re.M)
    if m:
        want = m.group(1)
    said = sh([pascalc, '--version']).stdout
    have = ''
    for ln in said.split('\n'):
        if ln.startswith('pascalc (Afterschool Pascal) '):
            have = ln[len('pascalc (Afterschool Pascal) '):]
    r.checked += 1
    if not want:
        r.fail('--- version: CMakeLists.txt names no project VERSION ---')
    elif want != have:
        r.fail("--- version: the project is %s but pascalc says '%s' ---"
               % (want, have))


def compiler_help(r, pascalc):
    """...and that -h documents every flag it accepts.

    Derived from ParseArgs rather than compared against a golden, because the
    thing worth knowing is not what the help text says -- it is whether the
    help text and the argument parser still describe the same compiler. A
    golden would agree with whichever of the two was edited last.

    Until this was written the release checklist said "confirm the -h output
    matches the flags that actually exist" and a person did it by eye, once a
    release. tests/checks/coverage.py is what surfaced it: `Usage` was entered
    by no case in the corpus, so nothing ran -h at all.
    """
    help_text = sh([pascalc, '-h']).stdout
    r.checked += 1
    if not help_text:
        r.fail('--- help: pascalc -h wrote nothing ---')
        return
    src = (ROOT / 'selfhost' / 'compiler.pas').read_text()
    # Two spellings, because a flag that takes a *joined* value cannot be
    # compared with EQ against the whole argument: `--target=aarch64-linux-gnu`
    # is matched by its prefix, `EQ(substr(a, 1, 9), '--target=')`. Deriving
    # only the first form left --target= undiscoverable here, so the check that
    # exists to notice an undocumented flag could not have noticed that one
    # (ADR-0156).
    flags = set(re.findall(r"EQ\(a, '(-[^']*)'\)", src))
    flags |= set(re.findall(r"EQ\(substr\(a, 1, [0-9]*\), '(-[^']*)'\)", src))
    undocumented = ''
    for flag in sorted(flags):
        probe = '--target=' if flag.startswith('--target=') else flag
        if probe not in help_text:
            undocumented += ' ' + flag
    if undocumented:
        r.fail('--- help: pascalc accepts flags -h does not mention:%s ---'
               % undocumented)


def driver_help(r, driver):
    """...and the same question of the driver.

    `tools/pascalcc` is the half of the compiler that links, so it is where
    -c, -O0..-O3 and <file>.o are documented and nowhere else -- `pascalc -h`
    is the compiler's own help and knows nothing about them. Its --help
    printed the licence header and stopped one line before the first option,
    because it was a line range (`sed -n '2,20p'`) into a file whose lines had
    moved. Every option was invisible and nothing here asked, while the check
    directly above had been asking the same question of the compiler for a
    release.

    Same derivation as above and for the same reason: the flags come from the
    case arms that parse them, so this compares the help text against the
    argument parser rather than against a golden that would agree with
    whichever was edited last.

    One arm is written as a family rather than as itself, in the help text and
    in the parser both, so it is matched by the prefix they share:
    `-O0|-O1|-O2|-O3` against `-O`, which the text spells `-O0 .. -O3`. The
    catch-all arms (`-*`, `*.o`, `*`) name no option and are dropped -- which
    is also what drops `--std=*`, the arm ADR-0232 left behind to accept and
    ignore the flag, and `--dump-*`, which is a family and not a catch-all: it
    names a real group of options, the help text spells it `--dump-<what>`,
    and what this check cannot do is compare a pattern against a placeholder.
    The section below is what asks whether it works instead (ADR-0239).
    """
    help_text = sh([driver, '--help']).stdout
    r.checked += 1
    if not help_text:
        r.fail('--- help: pascalcc --help wrote nothing ---')
        return help_text
    undocumented = ''
    for flag in driver_options(driver):
        # A substring test is not enough here and the check above gets away
        # with it only because its flags are long: `-c` occurs inside
        # `--coverage`, so deleting the line that documents `-c` left this
        # passing. The flag has to stand as a token -- at the start of a line
        # or after a space or comma, and ended the same way -- which is how
        # the text actually writes it (`--emit-llvm,-S`, `-h, --help`).
        if re.fullmatch(r'-O[0-9]', flag):
            # Written as the range `-O0 .. -O3` rather than one line per level.
            if '-O' not in help_text:
                undocumented += ' ' + flag
        elif not re.search(r'(^|[ \t\n,])%s([ \t\n,]|$)' % re.escape(flag),
                           help_text, re.M):
            undocumented += ' ' + flag
    if undocumented:
        r.fail('--- help: pascalcc accepts options --help does not '
               'mention:%s ---' % undocumented)
    return help_text


def driver_options(driver):
    text = (ROOT / 'tools' / 'pascalcc').read_text()
    body = section(text, r'^while \[\[ \$# -gt 0 \]\]', r'^done$')
    out = set()
    for ln in body:
        m = re.match(r'^ *(-[^)]*)\)', ln)
        if m:
            for part in m.group(1).split('|'):
                part = part.strip()
                if part and '*' not in part:
                    out.add(part)
    return sorted(out)


def section(text, start, end):
    """`sed -n '/start/,/end/p'`."""
    out = []
    on = False
    for ln in text.split('\n'):
        if not on and re.search(start, ln):
            on = True
        if on:
            out.append(ln)
            if re.search(end, ln) and len(out) > 1:
                break
    return out


def subcommands(r, driver, help_text):
    """...and that every project subcommand is documented too (ADR-0348).

    The check above derives its flags from the *argument loop*, and the
    subcommands are not in it: they are a `case` on `${1:-}` before it,
    because a subcommand is recognised by position rather than by shape. So a
    new one would have been undocumented and unasked -- which is the defect
    the check above exists for, one dispatch over.

    Derived the same way, from the dispatch's own arms rather than from a list
    here, so adding a fifth subcommand moves this check without it being
    edited.
    """
    r.checked += 1
    text = (ROOT / 'tools' / 'pascalcc').read_text()
    body = section(text, r'^case \$\{1:-\} in$', r'^esac$')
    cmds = set()
    for ln in body:
        m = re.match(r'^  ([a-z|-]*)\)', ln)
        if m:
            for part in m.group(1).split('|'):
                part = part.strip()
                if part:
                    cmds.add(part)
    undocumented = ''
    for cmd in sorted(cmds):
        if not re.search(r'(^|[ \t\n,])%s([ \t\n,]|$)' % re.escape(cmd),
                         help_text or '', re.M):
            undocumented += ' ' + cmd
    if undocumented:
        r.fail('--- help: pascalcc accepts subcommands --help does not '
               'mention:%s ---' % undocumented)


def target_flag(r, pascalc, work):
    """...and that --target= picks the machine the module says it is for.

    ADR-0156. `clang` overrides both header lines with its own target's, so
    what these check is the module as a *document*: what `llc` with no
    -mtriple reads, and what a person reads. Two directions, because the flag
    is as much about what it refuses -- a target whose layout has not been
    compared against LlSize and LlAlign is answered wrongly rather than
    refused if this arm goes.
    """
    r.checked += 1
    p = sh([pascalc, '--target=aarch64-linux-gnu', str(work / 'target.pas'),
            '-o', str(work / 'target.ll')])
    ok = p.returncode == 0
    if ok:
        ir = (work / 'target.ll').read_text()
        ok = ('target triple = "aarch64-unknown-linux-gnu"' in ir
              and 'i8:8:32-i16:16:32' in ir)
    if not ok:
        r.fail('--- target: --target=aarch64-linux-gnu did not emit that '
               'target ---')


def dump_through(r, pascalc, driver, work):
    """...and that the driver hands a dump through untouched.

    ADR-0239. A --dump flag asks the *compiler* a question and the answer is
    its standard output, so `tools/pascalcc` has nothing to add: no
    assembling, no linking, and no folding the answer into stderr the way it
    folds a diagnostic. Until the language server asked for one the driver had
    never been handed a dump at all, and it answered `pascalcc: unknown option
    '--dump-symbols'` -- on stderr, to a caller reading stdout, which is an
    empty outline and no complaint anywhere.

    It is checked here rather than by the dump corpus because `tests/dumps` is
    handed `pascalc` and this is a claim about the *driver*: which is what
    this harness is for, the build wiring rather than the compiler.
    """
    r.checked += 1
    env = dict(os.environ)
    env['PASCALC'] = pascalc
    p = sh([driver, '--dump-symbols', str(work / 'target.pas'),
            '-o', str(work / 'target.ll')], env=env)
    got = p.stdout.rstrip('\n')
    if got != 'symbol 0 program 1 9 6 4 4 target':
        print('--- dump: pascalcc --dump-symbols did not pass the dump '
              'through ---', file=sys.stderr)
        print('wrote: %s' % got, file=sys.stderr)
        sys.stderr.write(p.stderr)
        r.failed += 1


def no_standard(r, pascalc, driver, runtime, work):
    """...and that there is no standard to select.

    ADR-0232 removed `--std` and with it the two conformance modes, so there
    is one language and the compiler has no mode to be put into. Three claims,
    and each fails in a different direction.

    First, that the flag is gone from the compiler rather than quietly
    accepted: a `--std=iso7185` that was ignored would compile an ISO 7185
    program under the dialect and say nothing, which is the outcome a caller
    has no way to notice. The line above it -- ADR-0165's default -- is what
    this replaces, and it was pinned here because two harnesses had been
    riding on the default silently.
    """
    (work / 'dflt.pas').write_text(DFLT_PAS)
    r.checked += 1
    p = sh([pascalc, '--std=extended', str(work / 'dflt.pas'), '-o',
            '/dev/null'])
    said = p.stdout + p.stderr
    if p.returncode == 0:
        r.fail('--- std: pascalc still accepts --std= ---')
    elif 'unknown option' not in said:
        print('--- std: --std= was refused without naming why ---',
              file=sys.stderr)
        sys.stderr.write(said)
        r.failed += 1

    # Second, that an unflagged source is the whole language. `string(n)` is
    # the cheapest construct ISO 7185 does not have, and it is what the check
    # this replaces used to prove the default was Extended Pascal; it now
    # proves there is nothing left to select.
    r.checked += 1
    if sh([pascalc, str(work / 'dflt.pas'), '-o',
           str(work / 'dflt.ll')]).returncode != 0:
        r.fail('--- std: the compiler no longer accepts string(n) '
               'unflagged ---')

    # Third, that the *driver* still swallows the flag. `pascalcc --std=` is
    # accepted and ignored on purpose (ADR-0232), so a caller's build script
    # survives the release that removed it -- and a driver that passed it
    # through to a compiler which no longer knows it would break exactly the
    # scripts that arm was written for.
    r.checked += 1
    env = dict(os.environ)
    env['PASCALC'] = pascalc
    env['AFTERSCHOOL_PASCAL_RUNTIME'] = runtime
    p = sh([driver, '-S', '--std=iso7185', str(work / 'dflt.pas'),
            '-o', str(work / 'dflt.ll')], env=env)
    if p.returncode != 0:
        print('--- std: pascalcc no longer accepts and ignores --std= ---',
              file=sys.stderr)
        sys.stderr.write(p.stdout + p.stderr)
        r.failed += 1


def import_diagnostics(r, pascalc, work):
    """ADR-0210: a diagnostic about an imported component names *that
    component*.

    Nothing under tests/ can assert this, and for a sharp reason:
    run_test.py translates every .components entry separately and first, and
    gives up if one fails -- so no case can reach a component that does not
    translate on its own being handed to --import anyway. A person reaches it
    by typing it. tests/checks/importdiag/ has the two sources.
    """
    diag = ROOT / 'tests' / 'checks' / 'importdiag'

    # The component's error carries the component's name. It used to carry the
    # client's, with the component's line number -- client.pas is three lines
    # long and the error was reported at line 12 of it.
    r.checked += 1
    p = sh([pascalc, '--import', str(diag / 'badmod.pas'),
            str(diag / 'client.pas'), '-o', '/dev/null'])
    said = p.stdout + p.stderr
    if p.returncode == 0:
        r.fail('--- importdiag: a component with a type error was '
               'accepted ---')
    elif 'badmod.pas:15:' not in said:
        print("--- importdiag: an imported component's error did not name "
              'it ---', file=sys.stderr)
        sys.stderr.write(said)
        r.failed += 1

    # And the other direction, which is what stops "name the component for
    # everything" from passing: the client's own error still names the client.
    r.checked += 1
    p = sh([pascalc, '--import', str(diag / 'badmod.pas'),
            str(diag / 'badclient.pas'), '-o', '/dev/null'])
    said = p.stdout + p.stderr
    if p.returncode == 0:
        r.fail('--- importdiag: a client with a type error was accepted ---')
    elif 'badclient.pas:3:' not in said:
        print("--- importdiag: the client's own error did not name the "
              'client ---', file=sys.stderr)
        sys.stderr.write(said)
        r.failed += 1


def default_target(r, pascalc, work):
    """The default has to stay the default: this repository is built and
    tested on x86-64 and the seed was generated for it."""
    r.checked += 1
    p = sh([pascalc, str(work / 'target.pas'), '-o', str(work / 'host.ll')])
    ok = (p.returncode == 0
          and 'target triple = "x86_64-pc-linux-gnu"'
          in (work / 'host.ll').read_text())
    if not ok:
        r.fail('--- target: the default is no longer x86_64-pc-linux-gnu ---')

    r.checked += 1
    p = sh([pascalc, '--target=riscv64-linux-gnu', str(work / 'target.pas'),
            '-o', '/dev/null'])
    said = p.stdout + p.stderr
    if p.returncode == 0:
        r.fail('--- target: an unverified target was accepted ---')
    elif 'unknown target' not in said or 'x86_64-pc-linux-gnu' not in said:
        print('--- target: the refusal does not name what is admitted ---',
              file=sys.stderr)
        sys.stderr.write(said)
        r.failed += 1


def exit_status(r, pascalc, work):
    """...and that it says so when it does not translate something.

    A compiler that cannot report failure is not usable from a build rule:
    `pascalc bad.pas && clang bad.ll ...` would run the linker on a file that
    was never written. ISO/IEC 10206:1991 6.7.5.7's `halt` takes no parameters
    and neither standard models an exit status, so this is the one language
    extension this processor adds for its own sake (ADR-0084) -- and *nothing
    else checks it*. Removing `halt(1)` from compiler.pas passed all 279
    cases, the golden files comparing what a program wrote and never how it
    stopped.
    """
    (work / 'rejected.pas').write_text(REJECTED_PAS)
    (work / 'ir.ll').write_bytes(b'')
    p = sh([pascalc, str(work / 'rejected.pas'), '-o', str(work / 'ir.ll')])
    said = p.stdout + p.stderr
    r.checked += 1
    if p.returncode == 0:
        r.fail('--- rejected: pascalc exited 0 for a program it refused ---')
    elif (work / 'ir.ll').stat().st_size:
        r.fail('--- rejected: pascalc wrote IR for a program it refused ---')
    elif 'undeclared identifier' not in said:
        print('--- rejected: pascalc gave no diagnostic naming the fault ---',
              file=sys.stderr)
        sys.stderr.write(said)
        r.failed += 1

    # The other half of the same contract: a successful run must exit 0, or a
    # build rule would stop on every program it compiled.
    p = sh([pascalc, str(ROOT / 'tests' / 'hello.pas'),
            '-o', str(work / 'ir.ll')])
    r.checked += 1
    if p.returncode != 0:
        r.fail('--- accepted: pascalc exited %d for a program it '
               'translated ---' % p.returncode)


def target_env(r, pascalc, driver, runtime, work):
    """AFTERSCHOOL_PASCAL_TARGET, and that an explicit flag beats it.

    ADR-0159 added the variable so a whole run -- the arm64 CI job, above all
    -- can be pointed at one target without a flag on every invocation.
    Nothing here exercised it: the only thing that set it was that job, so a
    typo in tools/pascalcc would have passed every local gate and failed
    remotely, on another architecture, in a job about something else. The
    precedence rule was asserted by nothing at all.

    Both halves, because a check that only pins the variable passes just as
    well with the explicit flag ignored.
    """
    def target_check(want, value, *extra):
        r.checked += 1
        env = dict(os.environ)
        env['AFTERSCHOOL_PASCAL_TARGET'] = value
        env['PASCALC'] = pascalc
        env['AFTERSCHOOL_PASCAL_RUNTIME'] = runtime
        p = sh([driver, '-S'] + list(extra) + [str(work / 'target.pas'),
                                               '-o', str(work / 't.ll')],
               env=env)
        if p.returncode != 0:
            r.fail('--- target: pascalcc failed with '
                   'AFTERSCHOOL_PASCAL_TARGET=%s ---' % value)
            return
        ir = (work / 't.ll').read_text()
        if 'target triple = "%s"' % want not in ir:
            print('--- target: AFTERSCHOOL_PASCAL_TARGET=%s %s did not emit '
                  '%s ---' % (value, ' '.join(extra), want), file=sys.stderr)
            for ln in ir.split('\n'):
                if 'target triple' in ln:
                    print(ln, file=sys.stderr)
                    break
            r.failed += 1

    target_check('aarch64-unknown-linux-gnu', 'aarch64-linux-gnu')
    target_check('x86_64-pc-linux-gnu', 'aarch64-linux-gnu',
                 '--target=x86_64-pc-linux-gnu')


def sse2(r, pascalc, driver, runtime, work):
    """An i386 this compiler emits for has SSE2 (ADR-0346).

    The one property here that cannot be read off the IR. A `double` is a
    double in it whatever the processor, so what the rule decides is which x86
    *clang* generates for -- and clang's own default for this triple is
    `i686`, whose eighty-bit x87 registers make 6.7.6.3's `round` contradict
    its clause and D.32's `sqr` error go undetected. So the command line the
    driver builds is what is asserted, traced out of `bash -x`.

    The trace is read whether or not clang then succeeds: a machine with no
    32-bit toolchain cannot finish this compilation and can still be asked
    what the driver would have run.

    Both directions, and the second is the one that matters -- a rule written
    without its condition would narrow *every* target to a 2003 processor and
    no other check here would notice.

    `bash -x` stays: `tools/pascalcc` is a shell script by decision, and what
    is asserted is the command line it builds.
    """
    def cpu_check(value, want):
        r.checked += 1
        env = dict(os.environ)
        env['AFTERSCHOOL_PASCAL_TARGET'] = value
        env['PASCALC'] = pascalc
        env['AFTERSCHOOL_PASCAL_RUNTIME'] = runtime
        p = sh(['bash', '-x', driver, '-c', str(work / 'target.pas'),
                '-o', str(work / 't.o')], env=env)
        trace = p.stdout + p.stderr
        if '-march=pentium4' in trace:
            if want != 'yes':
                r.fail('--- target: %s was narrowed to a pentium4 ---' % value)
        else:
            if want != 'no':
                r.fail('--- target: %s was not given a processor with '
                       'SSE2 ---' % value)

    cpu_check('i386-pc-linux-gnu', 'yes')
    cpu_check('aarch64-linux-gnu', 'no')
    cpu_check('x86_64-pc-linux-gnu', 'no')


def command_line(r, pascalc, work):
    """A misused command line is reported, and reported as a failure.

    The command line is part of the interface (CHANGELOG says so in as many
    words), and none of it was tested. It could not be: these messages carry
    the `pascalc: ` prefix, which tests/checks/diagnostic_coverage.py filters
    out as driver output rather than a diagnostic about a program -- so the
    one gate that counts messages is blind to them by construction, and
    tests/checks/line_coverage.py is what found the branches unrun (ADR-0104).

    Each case asserts the message *and* a non-zero exit, for the reason the
    rejected-program check above gives: a driver that misreports a bad flag as
    success is worse than one that says nothing.
    """
    def cli_check(want, *args):
        r.checked += 1
        p = sh([pascalc] + list(args))
        said = p.stdout + p.stderr
        if p.returncode == 0:
            r.fail("--- cli: '%s' exited 0 ---" % ' '.join(args))
        elif want not in said:
            print("--- cli: '%s' did not report '%s' ---"
                  % (' '.join(args), want), file=sys.stderr)
            sys.stderr.write(said)
            r.failed += 1

    hello = str(ROOT / 'tests' / 'hello.pas')
    cli_check('unknown option', '--no-such-flag', hello)
    cli_check('-o needs a file name', hello, '-o')
    cli_check('--import needs a file name', hello, '--import')
    cli_check('more than one input file', hello,
              str(ROOT / 'tests' / 'arith.pas'))
    # A command line one word longer than the program-parameter list. Nothing
    # can count the arguments -- an unbound program-parameter is the only
    # end-of-list there is -- so this is reported by one *extra* parameter
    # being bound, and without it the surplus was silently dropped: twelve was
    # exactly what tests/dialect/lib_os.pas needs, so ADR-0156's --target=
    # made a correct command line report "-o needs a file name" about the
    # argument that fell off the end. The complaint has to name the length,
    # not the last flag standing.
    cli_check('more than 72 arguments', *(['--dump-limits'] * 70
                                          + [hello, '-o', str(work / 'ir.ll')]))

    # ...and the length below that is accepted, which is the half a
    # bound-raising change gets wrong: a check that only pins the refusal
    # passes just as well with the bound left where it was.
    r.checked += 1
    p = sh([pascalc] + ['--dump-limits'] * 69
           + [hello, '-o', str(work / 'long.ll')])
    if p.returncode != 0 or not (work / 'long.ll').stat().st_size:
        print('--- cli: 24 arguments were refused or wrote no IR ---',
              file=sys.stderr)
        sys.stderr.write(p.stdout + p.stderr)
        r.failed += 1
    # With no source at all pascalc writes the usage rather than a message,
    # which is the one case here that is not a complaint -- and worth pinning,
    # because "prints help" and "silently succeeds" are indistinguishable
    # without the exit status this function also checks.
    cli_check('usage: pascalc', '-o', str(work / 'ir.ll'))


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
