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

"""Does a program built for WebAssembly *behave*? (ADR-0385)

`target-layout` asks whether the compiler lays `wasm32-wasi` out the way LLVM
does, and `runtime-nonposix` asks how far the runtime is from the target. This
asks the question neither can: **take the corpus, build it for wasm32, and run
it under a WebAssembly runtime.** ADR-0325's i386 port is the precedent and
its lesson is the reason: both defects that port found were in neither a
layout rule nor a frame, and it passed every arithmetic check with `select`
segfaulting.

**The runtime here is partial and that is the measurement, not a shortcut.**
`runtime-nonposix` catalogues which translation units compile for this target,
and this gate builds exactly those -- so what a program can reach is what a
port has actually got, and a program wanting more fails at the *link* with the
symbol named. Reading that catalogue rather than holding a second list is the
point: one fact, one place, and a unit that starts or stops compiling moves
both gates together.

`tests/checks/wasm32_known.txt` is what does not pass, in both directions like
every catalogue here (ADR-0013): a case that starts failing is a regression,
and one that stops failing is progress somebody has to record.

Skips 77 without the sysroot, without the wasm linker, or without a runtime to
run the result; `WASM32_REQUIRE` refuses to pass by skipping (ADR-0330).

  APASCAL_WASM_ENGINE   the engine that runs a `.wasm`, blanks and all.
                        The default is `wasmedge --dir /:/`, which Debian
                        trixie packages -- the image the wasi sysroot is
                        pinned to. **A WASI program is given nothing it is not
                        handed**: the mount is why the two scratch paths
                        `tests/run_test.py` passes every case can be opened,
                        and `tests/checks/wasi_run.py` is why the environment
                        arrives. Without that, the case with a `.epoch`
                        sidecar printed *today* instead of 2001 -- a wrong
                        answer rather than a failure to start, which is the
                        kind an engine's flags cause and a reader blames on
                        the compiler.
"""

import concurrent.futures
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.stdout.reconfigure(line_buffering=True)
sys.stderr.reconfigure(line_buffering=True)

ROOT = Path(__file__).resolve().parent.parent.parent
CATALOGUE = ROOT / 'tests' / 'checks' / 'wasm32_known.txt'
NONPOSIX = ROOT / 'tests' / 'checks' / 'nonposix_headers.txt'
TARGET = 'wasm32-wasi'

# The toolchain, and every word of it is `runtime-nonposix`'s (ADR-0382):
# `-mllvm -wasm-enable-sjlj` because the emitted module calls `@_setjmp`,
# `-nostdlibinc -isystem` because `/usr/include` is on clang's search path for
# this target and glibc's headers would otherwise answer for wasi's.
CC = ('clang --target=' + TARGET + ' -mllvm -wasm-enable-sjlj '
      '-nostdlibinc -isystem /usr/include/wasm32-wasi').split()

# **The engine, and it is `wasmedge` because trixie packages it** -- the image
# the wasi sysroot is pinned to, and an answer here is one toolchain's or it is
# two answers about two machines (ADR-0382). `wazero` measured this first and
# gives the same 519 but for two cases, and it is in Debian *testing*: a job
# cannot install it beside the sysroot, so it is not the one to hold the
# catalogue.
#
# It is reached through `wasi_run.py` rather than named directly, because a
# WASI program is handed no environment and *this case's* environment is what
# `run_test.py` built -- which the fixed runner prefix (ADR-0384) never sees.
# The adapter forwards it; the engine is `APASCAL_WASM_ENGINE`'s and the
# summary names it, *which runtime* being exactly the thing a wasm result must
# state.
ADAPTER = Path(__file__).resolve().parent / 'wasi_run.py'
DEFAULT_ENGINE = 'wasmedge --dir /:/'

ROOTS = ['tests', 'tests/extended', 'tests/dialect', 'examples']
FLOOR = 400        # sources swept, or the sweep reached nothing (ADR-0282)
RUN_FLOOR = 100    # ...and programs that actually ran under the runtime


class Skip(Exception):
    pass


GETENV = __import__('re').compile(r'getenv\("([A-Z_][A-Z0-9_]*)"\)')


def read_forwarded():
    """The names `wasi_run.py` passes on, read from its own source rather
    than imported: it `execvp`s at import time, which is right for a runner
    and wrong for a module."""
    text = ADAPTER.read_text()
    body = text.split('FORWARD = (', 1)[1].split(')', 1)[0]
    return {w.strip().strip('",\'') for w in body.split() if w.strip(' ,')}


# The fields of a datalayout this compiler **models** -- `target_layout.py`'s
# allowlist, repeated rather than imported for the reason every check here is
# standalone. That gate carries the argument: an x86 host states segment
# address spaces for every target and an arm64 one states none, and clang 19
# writes no `Fn32` where clang 21 does, and none of it decides a size or an
# alignment.
MODELLED = re.compile(r"^(?:[eE]|p:|[ivfa]\d*:)")


def modelled(line):
    body = line.split('"')[1] if '"' in line else line
    return frozenset(f for f in body.split('-') if MODELLED.match(f))


def clang_datalayout():
    """What *this* clang says the target's layout is."""
    r = subprocess.run(CC + ['-x', 'c', os.devnull, '-S', '-emit-llvm',
                             '-o', '-'], capture_output=True, text=True)
    for line in r.stdout.splitlines():
        if line.startswith('target datalayout'):
            return line.strip()
    raise Skip('%s states no datalayout for %s' % (CC[0], TARGET))


def emitted_datalayout(pascalcc):
    """...and what this compiler writes for it, asked of the compiler rather
    than transcribed, a transcription being a claim that agrees with itself."""
    with tempfile.TemporaryDirectory() as d:
        src = Path(d) / 'd.pas'
        src.write_text('program d(output);\nbegin writeln(1) end.\n')
        out = Path(d) / 'd.ll'
        pascalc = os.environ.get('PASCALC',
                                 str(ROOT / 'build' / 'bin' / 'pascalc'))
        r = subprocess.run([pascalc, '--target=' + TARGET, str(src),
                            '-o', str(out)], capture_output=True, text=True)
        if r.returncode != 0 or not out.exists():
            raise Skip('this compiler could not emit for %s: %s'
                       % (TARGET, (r.stdout + r.stderr).strip()[:200]))
        for line in out.read_text().splitlines():
            if line.startswith('target datalayout'):
                return line.strip()
        raise Skip('this compiler stated no datalayout for ' + TARGET)


def units_that_compile():
    """Which translation units `runtime-nonposix` says compile for this
    target. A `crt` row counts: that unit compiles once a macro selects the
    target's modern C runtime, and no such row exists for wasi today."""
    out = []
    for line in NONPOSIX.read_text().split('\n'):
        f = line.strip().split()
        if len(f) >= 3 and f[0] == 'unit' and f[2] in ('compiles', 'crt'):
            out.append(f[1])
    return out


def main(argv):
    write = '--write' in argv
    rest = [a for a in argv if a != '--write']
    pascalcc = rest[0] if rest else str(ROOT / 'tools' / 'pascalcc')
    require = os.environ.get('WASM32_REQUIRE', '')
    work = Path(tempfile.mkdtemp())
    try:
        return sweep(pascalcc, work, write)
    except Skip as s:
        if require:
            print('wasm32: %s -- and WASM32_REQUIRE is set' % s,
                  file=sys.stderr)
            return 1
        print('wasm32: skipped -- %s' % s)
        return 77
    finally:
        shutil.rmtree(work, ignore_errors=True)


def sweep(pascalcc, work, write):
    if shutil.which(CC[0]) is None:
        raise Skip('no %s' % CC[0])
    if shutil.which('llvm-ar') is None:
        raise Skip('no llvm-ar, which is what archives a wasm object')

    engine = (os.environ.get('APASCAL_WASM_ENGINE') or DEFAULT_ENGINE).split()
    if shutil.which(engine[0]) is None:
        raise Skip('no %s to run a .wasm with (Debian trixie packages '
                   'wasmedge); APASCAL_WASM_ENGINE names another' % engine[0])
    runner = [sys.executable, str(ADAPTER)]

    # **The environment a wasm program is given is exactly what the runtime
    # reads**, in both directions. The adapter forwards four names and the
    # runtime calls `getenv` on four; a fifth added to either side without the
    # other is a variable that silently stops arriving on this target, which
    # is a *wrong answer* and not a failure -- the `.epoch` case printed
    # today's date rather than 2001 when this went unnoticed once already.
    forwarded = read_forwarded()
    wanted = set()
    for c in sorted((ROOT / 'runtime').glob('*.c')):
        wanted |= set(GETENV.findall(c.read_text()))
    if forwarded != wanted:
        print('wasm32: %s forwards {%s} and runtime/*.c reads {%s} -- a WASI '
              'program is handed no environment it is not given, so the two '
              'have to be the same set'
              % (ADAPTER.name, ', '.join(sorted(forwarded)),
                 ', '.join(sorted(wanted))), file=sys.stderr)
        return 1

    # **Is this clang talking about the same target the module states?**
    # `target-layout` abstains where the two disagree about a field this
    # compiler models, and so must this, for a reason that is this gate's own:
    # clang *overrides* the module's datalayout with its own for the
    # `--target=` it is given (ADR-0156), so on a toolchain naming no
    # `i128:128` for wasm32 an i256 aligns to 8 where this compiler computed
    # 16 -- and a set inside a record is laid out two ways. That is ADR-0028's
    # defect, and CI found it the way only a gate that *runs* things could:
    # Debian trixie's clang 19 names no `i128:128`, and
    # `tests/sets_records.pas` -- the case ADR-0028 exists for -- was the one
    # case in 598 that failed there.
    #
    # So: skip, with both lines printed. What this compiler supports for this
    # target is the layout it states, and an older LLVM is a toolchain this
    # measurement cannot be taken on.
    mine = emitted_datalayout(pascalcc)
    theirs = clang_datalayout()
    if modelled(mine) != modelled(theirs):
        raise Skip('this clang lays %s out differently from the module this '
                   'compiler emits, so a program built here is assembled '
                   'against a layout the compiler did not compute '
                   '(ADR-0156). wasm32 needs an LLVM that names i128 for the '
                   'target: trixie\'s clang 19 does not, testing\'s clang 21 '
                   'does.\n           clang: %s\n          module: %s'
                   % (TARGET, theirs, mine))

    # Can this machine compile *anything* for the target? Asked with C and
    # before any of this compiler's work, so an absent sysroot is reported as
    # what it is rather than as a Pascal failure -- `target32`'s rule.
    (work / 'probe.c').write_text('int main(void){return 0;}\n')
    if subprocess.run(CC + ['-o', str(work / 'probe.wasm'),
                            str(work / 'probe.c')],
                      capture_output=True).returncode != 0:
        raise Skip('%s cannot link a C program for %s (the wasi sysroot is a '
                   'separate package)' % (CC[0], TARGET))
    if subprocess.run(runner + [str(work / 'probe.wasm')],
                      capture_output=True).returncode != 0:
        raise Skip('%s cannot run a .wasm this machine just built'
                   % ' '.join(runner))

    # The runtime, for the target, and only the units that compile for it.
    rt = work / 'rt'
    rt.mkdir(parents=True, exist_ok=True)
    units = units_that_compile()
    if not units:
        print('wasm32: %s names no translation unit that compiles for this '
              'target, so there is no runtime to link against and nothing '
              'here to measure' % NONPOSIX.name, file=sys.stderr)
        return 1
    objects = []
    for name in units:
        obj = rt / (Path(name).stem + '.o')
        r = subprocess.run(CC + ['-std=gnu11', '-O2', '-I',
                                 str(ROOT / 'runtime'), '-c',
                                 str(ROOT / 'runtime' / name),
                                 '-o', str(obj)],
                           capture_output=True, text=True)
        if r.returncode != 0:
            print('wasm32: runtime/%s is catalogued as compiling for %s and '
                  'does not:' % (name, TARGET), file=sys.stderr)
            sys.stderr.writelines(ln + '\n'
                                  for ln in r.stderr.splitlines()[:20])
            return 1
        objects.append(str(obj))
    if subprocess.run(['llvm-ar', 'rcs', str(rt / 'libpasrt.a')] + objects,
                      capture_output=True).returncode != 0:
        print('wasm32: llvm-ar would not archive the runtime objects',
              file=sys.stderr)
        return 1

    env = dict(os.environ)
    env['AFTERSCHOOL_PASCAL_RUNTIME'] = str(rt)
    env['AFTERSCHOOL_PASCAL_TARGET'] = TARGET
    env['AFTERSCHOOL_PASCAL_RUNNER'] = ' '.join(runner)
    env['APASCAL_WASM_ENGINE'] = ' '.join(engine)
    env.setdefault('PASCALC', str(ROOT / 'build' / 'bin' / 'pascalc'))

    known = set()
    for line in CATALOGUE.read_text().split('\n'):
        s = line.strip()
        if s and not s.startswith('#'):
            known.add(s.split()[0])

    sources = [src for d in ROOTS for src in sorted((ROOT / d).glob('*.pas'))]

    def one(src):
        r = subprocess.run([str(ROOT / 'tests' / 'run_test.py'),
                            pascalcc, str(src)],
                           env=env, capture_output=True)
        return str(src.relative_to(ROOT)), r.returncode == 0

    # Oversubscribed on purpose, as the other sweeps here are: every case
    # works in a directory it made (ADR-0281), and most of the wall clock is
    # a compiler and a linker rather than this process.
    results = {}
    with concurrent.futures.ThreadPoolExecutor(
            max_workers=(os.cpu_count() or 4)) as pool:
        for rel, ok in pool.map(one, sources):
            results[rel] = ok

    total = len(results)
    ran = sum(1 for ok in results.values() if ok)
    failing = sorted(rel for rel, ok in results.items() if not ok)

    if write:
        # **Printed and not written.** The catalogue is grouped by cause with
        # a paragraph over each group saying what a port would do about it,
        # and a mode that rewrote the file would throw all of that away to
        # save a copy and paste. What a row *means* is the whole value of the
        # file; the list of paths is the cheap half.
        print('wasm32: %d case(s) do not pass -- the rows, for %s:'
              % (len(failing), CATALOGUE.name))
        for n in failing:
            print(n)
        return 0

    if total < FLOOR:
        print('wasm32: only %d sources swept, below the floor of %d -- a sweep '
              'that reaches nothing must fail rather than report a clean run'
              % (total, FLOOR), file=sys.stderr)
        return 1
    if ran < RUN_FLOOR:
        print('wasm32: only %d program(s) ran under %s, below the floor of %d '
              '-- a gate whose every case fails the same way is measuring the '
              'toolchain and not the corpus'
              % (ran, engine[0], RUN_FLOOR), file=sys.stderr)
        return 1

    status = 0
    unexpected = [r for r in failing if r not in known]
    fixed = sorted(known - set(failing))
    if unexpected:
        print('wasm32: %d case(s) do not pass for %s and are not in the '
              'catalogue:' % (len(unexpected), TARGET), file=sys.stderr)
        for n in unexpected:
            print('  ' + n, file=sys.stderr)
        status = 1
    if fixed:
        print('wasm32: %d catalogued case(s) now pass -- that is progress and '
              'it has to be recorded: take the row out and say why:'
              % len(fixed), file=sys.stderr)
        for n in fixed:
            print('  ' + n, file=sys.stderr)
        status = 1
    if status == 0:
        print('wasm32: %d of %d corpus program(s) compile for %s, link '
              'against the %d runtime unit(s) that build for it, and answer '
              'their golden under `%s`; the other %d are catalogued'
              % (ran, total, TARGET, len(units), ' '.join(engine),
                 total - ran))
    return status


sys.exit(main(sys.argv[1:]))
