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

"""Compile one .pas file, run it, and compare against the expected output.

  run_test.py <path-to-pascalcc> <path-to-test.pas>

Two forms of expectation:

  name.out   expected stdout; the program must compile and exit 0.
  name.warn  expected compiler warnings, for a program that compiles.
             A case without one must produce none (ADR-0272).
  name.err   expected stderr, for a program that is *supposed* to fail --
             either it does not compile, or it stops on a runtime error.
             A non-zero exit is then required, and name.out (if present) is
             compared against whatever was written before the failure.

Two more inputs, for the text-file tests:

  name.in    fed to the program's standard input. Without it stdin is
             /dev/null, so a program that reads sees end-of-file at once
             rather than waiting for a terminal that is not there.
  name.epoch one integer: seconds since 1970-01-01 UTC, exported as
             SOURCE_DATE_EPOCH so the program's idea of "now" is fixed.
             ISO/IEC 10206:1991 6.7.5.8 makes the current date and time
             implementation-defined, and this implementation defines them
             from that variable when it is set -- which is what lets a golden
             file name a date at all.
  name.opt   one word: the optimisation flag to compile this case with, where
             the default -O2 would hide what it is testing. Storage is the
             only thing that has needed it -- an alloca inside a loop is
             invisible at -O2, LLVM being free to hoist one whose address
             does not escape, so a leak of it can only be seen at -O0.
  arguments  two writable scratch paths are always passed, so a program
             whose header names external files has somewhere to put them.
             A program that names none simply ignores them.

The source path is rewritten to <source> in stderr so diagnostics can be
compared without depending on where the checkout lives.

Converted from shell under ADR-0366. This is the harness roughly 850 ctest
cases run through, so the differential was the whole corpus, every case
compared byte for byte, and then the failure arms staged one at a time.
"""

import difflib
import os
import resource
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.stdout.reconfigure(line_buffering=True)


def gnu_date(p):
    ns = os.stat(p).st_mtime_ns
    t = time.localtime(ns // 10**9)
    return '%s.%09d %s' % (time.strftime('%Y-%m-%d %H:%M:%S', t),
                           ns % 10**9, time.strftime('%z', t))


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

    `str.splitlines` also breaks at a bare carriage return, and a golden here
    holds LSP framing -- `Content-Length: 53\r\n\r\n` -- so splitting that
    way made two files with the same bytes look different. It cost one case
    out of 597 on the first sweep, which is what a full-corpus differential is
    for."""
    out = text.split('\n')
    tail = out.pop()
    lines = [ln + '\n' for ln in out]
    if tail:
        lines.append(tail)
    return lines


def diff_u(expected, actual_text, actual_name, actual_date):
    """`diff -u expected <actual>`, written where the shell wrote it.

    The shell compared against a process substitution in three places, so the
    `+++` line says `/dev/fd/63`; where it compared against a real file the
    name is that file's. Both are reproduced, because a golden's failure
    output has been read by people in exactly this form.
    """
    a = split_lines(read_exact(expected))
    b = split_lines(actual_text)
    lines = list(difflib.unified_diff(a, b, str(expected), actual_name,
                                      gnu_date(expected), actual_date))
    if not lines:
        return False
    sys.stdout.writelines(lines)
    return True


def limits():
    """The compiled program runs with a deliberately small descriptor table.
    Closing a file at block exit is ISO's rule and this compiler's obligation
    -- a test that opens thousands of scratch files in sequence
    (files_scratch.pas, goto_files.pas) can only fail if the table can
    actually run out, and on a machine whose default limit is half a million
    it never would.

    The stack is bounded for the same reason and it is the same argument: a
    test that leaks stack per iteration can only fail where the stack can
    actually run out, and 8 MB is the ordinary Linux default -- so this
    changes nothing for every other case and makes for_nested_stack.pas mean
    something wherever it runs, including a container that inherited no limit
    at all."""
    for what, value in ((resource.RLIMIT_NOFILE, 256),
                        (resource.RLIMIT_STACK, 8192 * 1024)):
        soft, hard = resource.getrlimit(what)
        want = value if hard == resource.RLIM_INFINITY else min(value, hard)
        resource.setrlimit(what, (want, want))


def main(argv):
    pascalc, source_file = argv[0], argv[1]
    src = Path(source_file)
    stem = source_file[:-len('.pas')] if source_file.endswith('.pas') \
        else source_file
    d = os.path.dirname(source_file)
    name = os.path.basename(stem)

    expected_out = stem + '.out'
    expected_err = stem + '.err'
    # A case that compiles *and* has something to say about it (ADR-0272).
    # Neither sidecar above can hold a warning: .out compares what the program
    # printed and .err requires a non-zero exit, so a remark made by a
    # successful compilation was pinnable by nothing at all -- which is how the
    # first warning in this compiler arrived with no case able to assert it.
    #
    # The rule is two-directional and the second half is the load-bearing one:
    # a case *without* this sidecar must produce no warning. Otherwise a
    # warning added later would appear on dozens of cases and every one of them
    # would stay green, which is the shape ADR-0067 keeps finding.
    expected_warn = stem + '.warn'
    stdin_file = stem + '.in'
    if not os.path.isfile(stdin_file):
        stdin_file = '/dev/null'

    env = dict(os.environ)
    # Unset when there is no .epoch file, so every other case runs against the
    # real clock -- and does so whatever the developer happens to have
    # exported, since a fixed instant inherited from the environment would
    # otherwise silently replace the clock in the one case that is testing the
    # clock.
    if os.path.isfile(stem + '.epoch'):
        env['SOURCE_DATE_EPOCH'] = Path(stem + '.epoch').read_text().rstrip(
            '\n')
    else:
        env.pop('SOURCE_DATE_EPOCH', None)

    if not os.path.isfile(expected_out) and not os.path.isfile(expected_err):
        print('missing expected-output file: %s or %s'
              % (expected_out, expected_err), file=sys.stderr)
        return 1

    work = Path(tempfile.mkdtemp())
    try:
        return case(pascalc, source_file, d, name, stem, expected_out,
                    expected_err, expected_warn, stdin_file, env, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def case(pascalc, source_file, d, name, stem, expected_out, expected_err,
         expected_warn, stdin_file, env, work):
    def normalise(text):
        # The source path is rewritten so a golden does not depend on where
        # the checkout lives. A diagnostic may also name one of 6.13's *other*
        # program-components -- an --import reports a heading's errors against
        # the file that wrote it -- so the case's own directory is rewritten
        # too, which leaves such a path as <dir>/components/name.pas and
        # portable with it.
        return text.replace(source_file, '<source>').replace(d + '/', '<dir>/')

    # ADR-0183's heap balance belongs to the *program under test*, and this
    # script runs a Pascal compiler to produce it -- `pascalc` is itself a
    # Pascal program on the same runtime, so an inherited PASHEAP_BALANCE
    # would have it count its own allocations into the same file. It did, on
    # the first run of that gate: every case reported hundreds of outstanding
    # variables, which were the compiler's. So the variable is taken out of
    # the environment here and put back only around the program.
    heap_balance = env.pop('PASHEAP_BALANCE', '')
    os.environ.pop('PASHEAP_BALANCE', None)

    def run_program(merge):
        run_env = dict(env)
        if heap_balance:
            run_env['PASHEAP_BALANCE'] = heap_balance
        with open(stdin_file, 'rb') as fin:
            r = subprocess.run(
                [str(work / name), str(work / 'file1'), str(work / 'file2')],
                stdin=fin, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT if merge else subprocess.PIPE,
                env=run_env, preexec_fn=limits)
        out = r.stdout.decode('utf-8', 'surrogateescape')
        err = ('' if merge
               else r.stderr.decode('utf-8', 'surrogateescape'))
        return r.returncode, out, err

    # ISO/IEC 10206:1991 6.13's other program-components, when the case has
    # any: name.components lists them, one path per line, relative to the
    # .pas's own directory. Each is translated on its own first -- which is
    # the whole point of the clause, and the reason they are named here rather
    # than concatenated into the source. They live in a subdirectory so the
    # CMake glob, which is not recursive, does not register a component with
    # no program declaration as a case that fails to run.
    imports = []
    objects = []
    components_file = stem + '.components'
    if os.path.isfile(components_file):
        n = 0
        for line in Path(components_file).read_text().split('\n'):
            if not line:
                continue
            # One path per line. A second field used to name a standard,
            # because ADR-0137's case had components under two of them;
            # ADR-0232 removed the modes and there is one language, so
            # anything after the path is ignored.
            rel = line.split()[0] if line.split() else ''
            comp = os.path.join(d, rel)
            n += 1
            obj = str(work / ('c%d.o' % n))
            r = subprocess.run([pascalc] + imports + ['-c', comp, '-o', obj],
                               stderr=subprocess.PIPE, env=env)
            if r.returncode != 0:
                print('--- %s: component %s did not translate ---'
                      % (name, rel), file=sys.stderr)
                sys.stderr.write(r.stderr.decode('utf-8', 'surrogateescape'))
                return 1
            imports += ['--import', comp]
            objects.append(obj)

    # ADR-0244's search path, when the case has one: name.importpath lists
    # directories, one per line, relative to the .pas's own directory. It is
    # the other half of name.components and the two are deliberately different
    # questions -- .components names the files and this names the *places*, so
    # a case with one is asserting that the compiler found what it was not
    # told.
    #
    # The harness hands the flag to pascalcc, which hands it to pascalc and
    # then translates and links whatever the compiler reports having resolved.
    # Nothing here reads a heading; the compiler is asked.
    paths = []
    importpath_file = stem + '.importpath'
    if os.path.isfile(importpath_file):
        for line in Path(importpath_file).read_text().split('\n'):
            if line:
                paths += ['--import-path', os.path.join(d, line)]

    # ...and the same path as an *environment*: name.importenv holds one line,
    # the value of AFTERSCHOOL_PASCAL_PATH, with <dir> standing for the case's
    # own directory. It is a second sidecar rather than a second line of the
    # first because they are different claims -- a flag is what one command
    # line says and a variable is what a machine was configured with, and only
    # the second can hold an empty entry, a trailing separator or a directory
    # nobody can name on a command line without quoting it.
    importenv_file = stem + '.importenv'
    if os.path.isfile(importenv_file):
        first = Path(importenv_file).read_text().split('\n')[0]
        env['AFTERSCHOOL_PASCAL_PATH'] = first.replace('<dir>', d)

    # Which optimisation level to compile at, most specific first:
    #
    #   name.opt                  this case pins one, because the default
    #                             hides what it is testing
    #   AFTERSCHOOL_PASCAL_OPT    the whole run wants one -- which is how the
    #                             corpus is swept at -O0 without 497 sidecars
    #   neither                   pascalcc's own default, -O2
    #
    # The sidecar wins so that a case pinning -O0 still means -O0 during an
    # -O2 sweep, and vice versa: a case that pins a level does so because the
    # other one cannot see the defect, and a sweep must not quietly undo that.
    optflag = []
    opt_file = stem + '.opt'
    if os.path.isfile(opt_file):
        optflag = [''.join(Path(opt_file).read_text().split())]
    elif env.get('AFTERSCHOOL_PASCAL_OPT'):
        optflag = [env['AFTERSCHOOL_PASCAL_OPT']]

    r = subprocess.run([pascalc] + optflag + [source_file] + imports + paths
                       + objects + ['-o', str(work / name)],
                       stderr=subprocess.PIPE, env=env)
    compile_status = r.returncode
    compile_err = r.stderr.decode('utf-8', 'surrogateescape')

    if not os.path.isfile(expected_err):
        # --- ordinary test: must compile, run, and exit 0 ---
        if compile_status != 0:
            print('--- %s: compilation failed ---' % name, file=sys.stderr)
            sys.stderr.write(compile_err)
            return 1
        status, actual, _ = run_program(merge=True)
        if status != 0:
            print('--- %s: program exited with status %d ---' % (name, status),
                  file=sys.stderr)
            sys.stderr.write(actual)
            return 1
        got = work / 'actual'
        got.write_bytes(actual.encode('utf-8', 'surrogateescape'))
        if diff_u(expected_out, actual, str(got), gnu_date(got)):
            print('--- %s: output differs (expected vs actual above) ---'
                  % name, file=sys.stderr)
            return 1
        # What the compiler said about a program it accepted. Matched on the
        # severity word rather than on the whole of compile.err, because that
        # file also carries whatever clang and the linker wrote and those are
        # not this compiler's diagnostics.
        actual_warn = '\n'.join(
            ln for ln in normalise(compile_err).split('\n')
            if ': warning: ' in ln)
        if os.path.isfile(expected_warn):
            # `printf '%s\n'` of an empty capture is one empty line, which is
            # what the shell compared against and what a `.warn`-less case
            # would have had to match.
            if diff_u(expected_warn, actual_warn + '\n', '/dev/fd/63',
                      fd_date()):
                print('--- %s: compiler warnings differ ---' % name,
                      file=sys.stderr)
                return 1
        elif actual_warn:
            print('--- %s: the compiler warned and no %s.warn says so ---'
                  % (name, name), file=sys.stderr)
            sys.stderr.write(actual_warn + '\n')
            return 1
        print('%s: ok' % name)
        return 0

    # --- expected-failure test ---
    if compile_status != 0:
        # Failed to compile: the diagnostics are the thing under test.
        if diff_u(expected_err, normalise(compile_err), '/dev/fd/63',
                  fd_date()):
            print('--- %s: compiler diagnostics differ ---' % name,
                  file=sys.stderr)
            return 1
        print('%s: ok (rejected at compile time)' % name)
        return 0

    status, actual, actual_err = run_program(merge=False)
    if status == 0:
        print('--- %s: expected a failure, but the program succeeded ---'
              % name, file=sys.stderr)
        return 1
    if diff_u(expected_err, normalise(actual_err), '/dev/fd/63', fd_date()):
        print('--- %s: runtime error message differs ---' % name,
              file=sys.stderr)
        return 1
    if os.path.isfile(expected_out):
        got = work / 'actual'
        got.write_bytes(actual.encode('utf-8', 'surrogateescape'))
        if diff_u(expected_out, actual, str(got), gnu_date(got)):
            print('--- %s: output before the failure differs ---' % name,
                  file=sys.stderr)
            return 1
    print('%s: ok (failed as expected)' % name)
    return 0


def fd_date():
    """The mtime `diff` reads off a process substitution: the pipe is made
    now, so this is now."""
    ns = time.time_ns()
    t = time.localtime(ns // 10**9)
    return '%s.%09d %s' % (time.strftime('%Y-%m-%d %H:%M:%S', t),
                           ns % 10**9, time.strftime('%z', t))


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
