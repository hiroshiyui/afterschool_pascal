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

"""Is ADR-0366's rule still true of this tree? (ADR-0367)

ADR-0366 decided that a harness here is Python 3 and reaches for the standard
library rather than a subprocess, and thirty-one conversions carried it out.
**A rule that nothing enforces is a convention**, and this one had already
been broken once in the other direction: `AFTERSCHOOL_PASCAL_OPT` was named in
a comment by a job that did not set it and read by a harness that did not want
it (ADR-0335), and `require-consistency` is the gate that exists because a
sentence describing a mechanism is not the mechanism.

Three claims, each failing in **both** directions against
`tests/checks/helper_portability.txt`.

**One: no new shell.** Every tracked file that is a shell script -- by its
name or by its `#!` line -- must be catalogued. The list is meant to stay at
one entry, `tools/pascalcc`, which is the product rather than a harness. The
other direction is what makes it a catalogue: a `shell:` row naming a file
that is gone, or one that has stopped being a shell script, is an allowance
that has outlived what it allowed.

**Two: the shell that is left is portable.** macOS ships bash 3.2 and will not
ship another, so what a `shell:` file may not contain is written down --
including `case` inside `$( )`, which is not a name but a parse: bash 3.2
scans a command substitution by counting parentheses, so the `)` closing a
case pattern ends the substitution. That one cost a CI round trip and was
found by reading rather than by the next run.

**Three: a Python helper does not start a general-purpose utility.** The
portability boundary is the set of external programs a helper invokes and not
the language it is written in -- a Python script that runs `sed` is exactly as
unportable as a shell script that runs `sed`, which is what two of the nine
macOS failures were. Invoking the *toolchain* is the job and is not what this
refuses. What it refuses is `diff` where `difflib` does it, `ls` where
`iterdir` does it, `mktemp` where `tempfile` does it.

**It refuses to pass by sweeping nothing.** A run reaching no Python helper,
or no catalogued shell script, is a run that asked nothing and prints the same
line a clean one does.
"""

import ast
import os
import re
import subprocess
import sys
from pathlib import Path

sys.stdout.reconfigure(line_buffering=True)

ROOT = Path(__file__).resolve().parent.parent.parent
CATALOGUE = Path(__file__).resolve().parent / 'helper_portability.txt'

# A shell script by name, or by what its first line says. The second half is
# what catches a script with no extension -- `tools/pascalcc` is one.
SHELL_SUFFIX = '.sh'
SHEBANG = re.compile(rb'^#!.*(?:\bbash\b|\bsh\b|\bzsh\b|\bksh\b)')

# The floors. A sweep that reaches nothing prints what a clean one prints.
PYTHON_FLOOR = 40
SHELL_FLOOR = 1

# General-purpose utilities: a helper that starts one of these is doing in a
# subprocess what the standard library does. Deliberately *not* here: the
# toolchain (clang, llc, llvm-config, cmake, ctest, ar, ld, pdftotext,
# openssl, valgrind, fpc, git, ldd, nm's siblings), this project's own
# programs, and the interpreter.
GENERAL_PURPOSE = {
    'awk', 'basename', 'cat', 'cmp', 'cp', 'cut', 'diff', 'dirname', 'du',
    'echo', 'expr', 'find', 'grep', 'gunzip', 'gzip', 'head', 'ln', 'ls',
    'mkdir', 'mktemp', 'mv', 'nm', 'od', 'printf', 'readlink', 'realpath',
    'rm', 'rmdir', 'sed', 'seq', 'sha256sum', 'shasum', 'sort', 'stat',
    'strings', 'tac', 'tail', 'tar', 'tee', 'test', 'touch', 'tr', 'uniq',
    'wc', 'xargs', 'yes', 'zcat',
}

# What bash 3.2 does not have. The names come from the catalogue; the patterns
# that recognise them are here, because a pattern is not a fact about this
# tree.
BASH4 = {
    'mapfile': re.compile(r'(^|[;&|(\s])mapfile\s'),
    'readarray': re.compile(r'(^|[;&|(\s])readarray\s'),
    'declare -A': re.compile(r'(^|[;&|(\s])declare\s+-[A-Za-z]*A'),
    'local -A': re.compile(r'(^|[;&|(\s])local\s+-[A-Za-z]*A'),
    '${parameter^^}': re.compile(r'\$\{[A-Za-z_][A-Za-z_0-9]*\^\^?'),
    '${parameter,,}': re.compile(r'\$\{[A-Za-z_][A-Za-z_0-9]*,,?'),
    '&>>': re.compile(r'&>>'),
    '|&': re.compile(r'\|&'),
}


def tracked():
    out = subprocess.run(['git', '-C', str(ROOT), 'ls-files'],
                         capture_output=True, text=True)
    if out.returncode != 0:
        print('helper-portability: git ls-files failed', file=sys.stderr)
        sys.exit(1)
    return [ln for ln in out.stdout.split('\n') if ln]


def is_shell(path):
    if path.name.endswith(SHELL_SUFFIX):
        return True
    try:
        with open(path, 'rb') as f:
            return bool(SHEBANG.match(f.readline()))
    except OSError:
        return False


def read_catalogue():
    shell, bash4, allowed = [], [], {}
    for line in CATALOGUE.read_text().split('\n'):
        s = line.strip()
        if not s or s.startswith('#'):
            continue
        if s.startswith('shell:'):
            shell.append(s[len('shell:'):].strip())
        elif s.startswith('bash4:'):
            bash4.append(s[len('bash4:'):].strip())
        else:
            f = s.split()
            if len(f) >= 2:
                allowed.setdefault(f[0], set()).add(f[1])
    return shell, bash4, allowed


def case_in_substitution(text):
    """`case` inside `$( )`, which bash 3.2 mis-parses.

    It scans a command substitution by counting parentheses, so the `)` that
    closes a case pattern ends the substitution instead -- and the error is
    reported far from the line that caused it. Found by reading the script
    rather than by the run after the one that failed.
    """
    hits = []
    depth = 0
    line = 1
    opened = 0
    i = 0
    while i < len(text):
        c = text[i]
        if c == '\n':
            line += 1
        elif text.startswith('$(', i) and not text.startswith('$((', i):
            if depth == 0:
                opened = line
            depth += 1
            i += 2
            continue
        elif c == ')' and depth:
            depth -= 1
        elif depth and text.startswith('case', i) and \
                (i == 0 or not text[i - 1].isalnum()) and \
                i + 4 < len(text) and text[i + 4] in ' \t':
            hits.append(opened)
        i += 1
    return hits


def commands_started(path):
    """Every string that stands where a program name stands.

    The first element of a list literal, and the string form of a shell
    command -- which catches a call through a local wrapper as well as
    `subprocess.run` itself, because what is looked at is the argv and not who
    passes it on.
    """
    try:
        tree = ast.parse(path.read_text(errors='surrogateescape'))
    except SyntaxError:
        return []
    out = []
    for n in ast.walk(tree):
        # The argv shape: `[prog, arg, ...]`.
        if isinstance(n, ast.List) and n.elts:
            e = n.elts[0]
            if isinstance(e, ast.Constant) and isinstance(e.value, str):
                out.append((e.value, getattr(e, 'lineno', 0)))
        # ...and a wrapper that takes the program and its arguments as
        # positionals: `run("nm", str(exe))`. Without this the check reads
        # only the helpers that spell the list out, and `coverage.py` -- the
        # one place `nm` is still started -- was invisible to it.
        elif isinstance(n, ast.Call) and len(n.args) >= 2:
            e = n.args[0]
            if isinstance(e, ast.Constant) and isinstance(e.value, str):
                out.append((e.value, getattr(e, 'lineno', 0)))
    return out


def main():
    shell_rows, bash4_rows, allowed = read_catalogue()
    failed = 0

    unknown = [c for c in bash4_rows
               if c not in BASH4 and c != 'case-inside-command-substitution']
    if unknown:
        print('helper-portability: the catalogue names constructs this check '
              'cannot recognise:%s' % ''.join(' ' + c for c in unknown),
              file=sys.stderr)
        failed += 1

    files = tracked()

    # --- one: no new shell ------------------------------------------------
    found = [f for f in files if is_shell(ROOT / f)]
    for f in sorted(set(found) - set(shell_rows)):
        print('helper-portability: %s is a shell script and is not in the '
              'catalogue -- ADR-0366 makes a helper here Python 3' % f,
              file=sys.stderr)
        failed += 1
    for f in sorted(set(shell_rows) - set(found)):
        why = ('is not tracked' if not (ROOT / f).exists()
               else 'is no longer a shell script')
        print('helper-portability: the catalogue allows %s and it %s -- an '
              'allowance that outlived what it allowed' % (f, why),
              file=sys.stderr)
        failed += 1

    swept_shell = 0
    # --- two: the shell that is left is portable --------------------------
    for f in sorted(set(shell_rows) & set(found)):
        swept_shell += 1
        text = (ROOT / f).read_text(errors='surrogateescape')
        lines = text.split('\n')
        for name in bash4_rows:
            pat = BASH4.get(name)
            if pat is None:
                continue
            for n, line in enumerate(lines, 1):
                if line.lstrip().startswith('#'):
                    continue
                if pat.search(line):
                    print('helper-portability: %s:%d uses %s, which bash 3.2 '
                          'does not have' % (f, n, name), file=sys.stderr)
                    failed += 1
        if 'case-inside-command-substitution' in bash4_rows:
            for n in case_in_substitution(text):
                print('helper-portability: %s:%d opens a command substitution '
                      'holding a `case` -- bash 3.2 counts parentheses and the '
                      "pattern's `)` ends it" % (f, n), file=sys.stderr)
                failed += 1

    # --- three: no general-purpose utility from Python --------------------
    swept_python = 0
    seen = {}
    for f in files:
        if not f.endswith('.py'):
            continue
        swept_python += 1
        for prog, line in commands_started(ROOT / f):
            base = os.path.basename(prog)
            if base not in GENERAL_PURPOSE:
                continue
            seen.setdefault(base, set()).add(f)
            if f not in allowed.get(base, ()):
                print("helper-portability: %s:%d starts `%s` -- a helper "
                      'reaches for the standard library rather than a '
                      'general-purpose utility (ADR-0366)' % (f, line, base),
                      file=sys.stderr)
                failed += 1
    for prog, where in sorted(allowed.items()):
        for f in sorted(where - seen.get(prog, set())):
            print('helper-portability: the catalogue allows `%s` in %s and it '
                  'is not there any more' % (prog, f), file=sys.stderr)
            failed += 1

    # --- the floors -------------------------------------------------------
    if swept_python < PYTHON_FLOOR:
        print('helper-portability: only %d Python helpers were read, below '
              'the floor of %d -- a sweep that reaches nothing prints what a '
              'clean one prints' % (swept_python, PYTHON_FLOOR),
              file=sys.stderr)
        failed += 1
    if swept_shell < SHELL_FLOOR:
        print('helper-portability: only %d shell script(s) were read, below '
              'the floor of %d' % (swept_shell, SHELL_FLOOR), file=sys.stderr)
        failed += 1

    if failed:
        return 1
    print('helper-portability: %d Python helpers start no general-purpose '
          'utility the catalogue does not allow, and %d shell script(s) hold '
          'none of the %d constructs bash 3.2 lacks'
          % (swept_python, swept_shell, len(bash4_rows)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
