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

"""**Is this compiler installable anywhere?** (ADR-0244)

  install_layout.py <build-directory>
  install_layout.py --prefix <installed-prefix>

The second form skips the `cmake --install` and asks every other question of
a prefix something else laid out -- a release archive, unpacked
(`tools/release.py --check`, ADR-0296). One script for both, so a file added
to the layout is added to one list.

Every other harness here drives the compiler out of the build tree, with
PASCALC and AFTERSCHOOL_PASCAL_RUNTIME saying where that tree is -- which is
exactly the configuration an installed copy does not have. So the claim
"put it anywhere and point PATH at it" was made by no oracle at all, and it
is a claim with four parts, each of which fails on its own:

  * `cmake --install` puts the compiler, the driver, the runtime and the
    library where the layout says.
  * `pascalcc` finds `pascalc` *beside itself* rather than in a build tree
    whose path is compiled into nothing.
  * it finds `libpasrt.a` the same way, or the link fails.
  * it adds the installed library to the search path when the environment
    says nothing, so `import PasError` resolves with no configuration.

The program below is compiled in a directory that is neither the checkout nor
the install, with the environment emptied of every AFTERSCHOOL_ and PASCALC
variable and PATH holding the install's bin and the system's. If it prints
what it should, all four hold at once.

Converted from shell under ADR-0366; the shell version's output is what this
was required to reproduce byte for byte, on this tree and on every arm.
"""

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# The layout, named here rather than only in CMakeLists.txt: a file that stops
# being installed is a claim that stopped being true, and the message should
# say which file rather than that a program did not run.
LAYOUT = ['bin/pascalc', 'bin/pascalcc', 'bin/apconfig', 'lib/libpasrt.a',
          'lib/afterschool/pastext.pas',
          'lib/afterschool/dialect/paserror.pas']

GREET = """program greet(output);
import PasError;
       PasFS;
begin
  writeln('installed: ', ErrorText(errNone));
  writeln('here: ', Exists('greet.pas'))
end.
"""

WANT = 'installed: no error\nhere: TRUE'

# Nothing of this checkout in the environment, and PATH is how the compiler is
# found -- which is the sentence being tested. Emptying the environment
# outright would lose HOME and the locale as well, and clang wants a usable
# environment, so the four variables that could point back at the build tree
# are unset by name.
POINTERS = ['PASCALC', 'AFTERSCHOOL_PASCAL_RUNTIME', 'AFTERSCHOOL_PASCAL_PATH',
            'AFTERSCHOOL_PASCAL_TARGET', 'AFTERSCHOOL_PASCAL_OPT']


def clean_env(prefix):
    env = dict(os.environ)
    for v in POINTERS:
        env.pop(v, None)
    env['PATH'] = '%s/bin:%s' % (prefix, os.environ.get('PATH', ''))
    return env


def main(argv):
    work = Path(tempfile.mkdtemp())
    try:
        return run(argv, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def run(argv, work):
    if argv[:1] == ['--prefix']:
        prefix = Path(argv[1]) if len(argv) > 1 else Path('')
        if not prefix.is_dir():
            print("install-layout: no prefix '%s'" % prefix, file=sys.stderr)
            return 1
        how = 'the prefix at %s' % prefix
    else:
        build = Path(argv[0]) if argv else Path('build')
        if not build.is_dir():
            print("install-layout: no build directory '%s'" % build,
                  file=sys.stderr)
            return 1
        prefix = work / 'prefix'
        r = subprocess.run(['cmake', '--install', str(build),
                            '--prefix', str(prefix)],
                           capture_output=True, text=True)
        if r.returncode != 0:
            print('--- cmake --install failed ---', file=sys.stderr)
            sys.stderr.write(r.stdout + r.stderr)
            return 1
        how = 'installed to a prefix'

    for f in LAYOUT:
        if not (prefix / f).exists():
            print('--- install-layout: %s was not installed ---' % f,
                  file=sys.stderr)
            return 1

    elsewhere = work / 'elsewhere'
    elsewhere.mkdir(parents=True, exist_ok=True)
    (elsewhere / 'greet.pas').write_text(GREET)

    env = clean_env(prefix)
    r = subprocess.run(['pascalcc', 'greet.pas', '-o', 'greet'],
                       cwd=elsewhere, env=env, capture_output=True, text=True)
    if r.returncode != 0:
        print('--- install-layout: the installed compiler could not build '
              'it ---', file=sys.stderr)
        sys.stderr.write(r.stdout + r.stderr)
        return 1

    got = subprocess.run(['./greet'], cwd=elsewhere, capture_output=True,
                         text=True).stdout.rstrip('\n')
    if got != WANT:
        print('--- install-layout: the program printed something else ---',
              file=sys.stderr)
        print('expected:', file=sys.stderr)
        print(WANT, file=sys.stderr)
        print('actual:', file=sys.stderr)
        print(got, file=sys.stderr)
        return 1

    # **Every installed module reachable by its own name.** The search is
    # `<directory>/<interface name>.pas` and nothing opens a file to find out
    # what it declares (ADR-0244), so the convention that a library module's
    # file is named after the interface it exports is load-bearing and was
    # checked by nothing: a module renamed, or one exporting an interface
    # under another name, would simply stop being resolvable and every
    # existing case would still pass.
    #
    # One program per module, importing it and nothing else. It has to
    # *compile* and not merely resolve, because resolving finds a file with
    # the right name and only Sema knows whether that file declares the
    # interface.
    modules = 0
    for d in ('lib/afterschool', 'lib/afterschool/dialect'):
        for f in sorted((prefix / d).glob('*.pas')):
            name = f.stem
            (elsewhere / 'probe.pas').write_text(
                'program probe(output);\nimport %s;\nbegin end.\n' % name)
            r = subprocess.run(['pascalcc', '-S', 'probe.pas',
                                '-o', '/dev/null'],
                               cwd=elsewhere, env=env, capture_output=True,
                               text=True)
            if r.returncode != 0:
                print("--- install-layout: '%s' is not reachable as import "
                      '%s ---' % (name, name), file=sys.stderr)
                sys.stderr.write(r.stdout + r.stderr)
                return 1
            modules += 1
    if modules < 20:
        print('--- install-layout: only %d library modules were installed ---'
              % modules, file=sys.stderr)
        return 1

    print('install-layout: %s, found on PATH, %d library modules reachable '
          'by name' % (how, modules))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
