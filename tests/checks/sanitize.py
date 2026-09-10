#!/usr/bin/env python3
"""Run the corpus under AddressSanitizer, UndefinedBehaviorSanitizer and
LeakSanitizer (ADR-0261).

**This is the only oracle here that reads the runtime's own memory
behaviour.** Every other gate compares what a program printed, or counts
something the compiler reported about itself: `heap-balance` (ADR-0183) tallies
`pas_new` against `pas_dispose` and is the closest, and it counts *calls*
rather than watching storage -- so a write one byte past an allocation, a read
of a freed block, or a signed overflow in the runtime's own C is invisible to
it and to everything else in this tree. `runtime/pasrt.c` is the only C here
and it does the allocation, the handles, the setjmp buffers and the string
arena; nothing was watching any of it.

It is not a fuzzer and does not pretend to be. What it does is run the corpus
that already exists under three checkers, which is the cheap half of the gap
`doc/sop.md` 7 records -- the expensive half is generating inputs nobody
wrote, and that is a separate job.

**A leak is not automatically a failure**, for the reason ADR-0183 gives: no
standard obliges a program to dispose what it created. `heap_balance.txt`
already records, case by case, which programs legitimately end with something
outstanding -- so that file is the suppression list, and using it rather than
a second list of this script's own is the point. A case leaking that the
catalogue says balances is a failure; a case leaking that the catalogue
already accounts for is not. The two therefore cannot drift apart without one
of them failing.

Skips are counted and printed rather than hidden. A program whose heading
declares file parameters needs names on its command line, which `run_test.py`
supplies from its sidecars and this does not -- those are reported as skipped,
which is honest and is this harness's own limit.

  usage: sanitize.py <pascalcc> [<pascalc>]

Converted from shell under ADR-0366. Two of the shell version's awkwardnesses
were written for bash 3.2 and are simply gone: the newline-delimited string
standing in for `declare -A`, and the hoisted `asan_options` that existed so
`uname` was not forked five hundred times. What each was working around is
kept in a comment, because the reason is still worth knowing.
"""

import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.stdout.reconfigure(line_buffering=True)

ROOT = Path(__file__).resolve().parent.parent.parent

ADDRESS_PROBE = """program SanProbe(output);
type Ptr = ^integer;
var p, q: Ptr;
begin
  new(p); q := p; dispose(p); q^ := 5; writeln(q^)
end.
"""

THREAD_PROBE = """program SanProbe(output);
var n: integer; a, b: task;
procedure Bump;
var k: integer;
begin
  for k := 1 to 100000 do n := n + 1
end;
task Worker;
begin
  Bump
end;
begin
  spawn a := Worker; spawn b := Worker; wait(a); wait(b); writeln(n)
end.
"""

CONCURRENT = re.compile(r'(^|[^A-Za-z_])(spawn|channel|task)([^A-Za-z_]|$)',
                        re.M)

# 6.1.8's two comment forms and 6.1.7's character-string, blanked before the
# word above is looked for.  A comment is not what a program *writes*, and
# this selector read one as if it were: a note in `tests/dialect/lib_term.pas`
# saying "each channel is a separate parameter" -- about a colour -- enrolled a
# single-threaded program in the ThreadSanitizer sweep and moved a number
# `quoted-numbers` watches.  ADR-0229's argument at its own scale: reading
# Pascal-shaped text with a regex answers about the text.  This does not make
# it a lexer, and does not need to be one -- what it must not do is see a word
# in a place a program cannot have written it.
#
# 6.1.8 lets `{` be closed by `*)` and `(*` by `}`, so the closers are a pair
# and not the mate of the opener; a doubled apostrophe inside a string is
# consumed by the same alternation that started it.
NOTCODE = re.compile(r"\{[^}*]*(?:\*(?!\))[^}*]*)*[}]|\{.*?\*\)|"
                     r"\(\*.*?(?:\*\)|\})|"
                     r"'(?:[^']|'')*'", re.S)


def code(text):
    """`text` with its comments and string literals blanked, newlines kept.

    Blanked rather than removed so that nothing here has to care about the
    line numbering, and so a comment cannot join two identifiers into one.
    """
    return NOTCODE.sub(lambda m: re.sub(r'[^\n]', ' ', m.group(0)), text)


def program_text(d, name, src):
    """The code of a whole program: the main source and its components.

    A question about what a *program* contains has to read every 6.13
    program-component of it, or it is a question about one file. The sidecar
    is read the way the linking code below reads it, one path per line
    relative to the case's own directory.
    """
    text = code(src.read_text(errors='surrogateescape'))
    comps = d / (name + '.components')
    if comps.is_file():
        for line in comps.read_text().split('\n'):
            rel = line.split()[0] if line.split() else ''
            if not rel:
                continue
            part = d / rel
            if part.is_file():
                text += '\n' + code(part.read_text(errors='surrogateescape'))
    return text
VG_FINDING = re.compile(r'^==[0-9]+== (Invalid|Use of uninitialised|'
                        r'Conditional jump|Mismatched|'
                        r'Source and destination)', re.M)
TSAN_FINDING = re.compile(r'^(WARNING|SUMMARY): ThreadSanitizer: ', re.M)
ASAN_FINDING = re.compile(r'^==[0-9]+==ERROR: |:[0-9]+:[0-9]+: runtime error: ',
                          re.M)
LSAN_ERROR = re.compile(r'^==[0-9]+==ERROR: LeakSanitizer', re.M)
ASAN_ERROR = re.compile(r'^==[0-9]+==ERROR: AddressSanitizer', re.M)
UBSAN_ERROR = re.compile(r':[0-9]+:[0-9]+: runtime error: ', re.M)


def head(text, n, stream=sys.stderr):
    """`head -n` over a captured stream.

    The trailing fragment after a final newline is not a line: printing it
    added a blank line the shell never wrote, which is what the probe-refusal
    arm caught."""
    lines = text.split('\n')
    if lines and lines[-1] == '':
        lines.pop()
    for ln in lines[:n]:
        stream.write(ln + '\n')


def grep(pattern, text, limit=None):
    """`grep -m<limit> -E <pattern>` over a captured stream."""
    out = [ln for ln in text.split('\n') if re.search(pattern, ln)]
    return out[:limit] if limit else out


def main(argv):
    if not argv:
        print('usage: sanitize.py <pascalcc> [<pascalc>]', file=sys.stderr)
        return 1
    pascalcc = argv[0]
    pascalc = argv[1] if len(argv) > 1 else os.environ.get('PASCALC',
                                                           'pascalc')

    # `SANITIZE_REQUIRE` turns every skip below into a failure, which is what a
    # CI job that installed the checker wants (ADR-0330). The `sanitizers` job
    # named this variable in a comment for as long as it existed and **nothing
    # read it**: the job refused a skip by grepping its own log instead, so the
    # mechanism worked and the sentence describing it was false.
    # `require-consistency` is the gate that now refuses that pair.
    sanreq = os.environ.get('SANITIZE_REQUIRE', '')

    def sanskip(why):
        if sanreq:
            print('sanitize: %s -- and SANITIZE_REQUIRE is set' % why,
                  file=sys.stderr)
            return 1
        print('sanitize: %s' % why, file=sys.stderr)
        return 77

    for tool in ('clang', 'ar'):
        if shutil.which(tool) is None:
            return sanskip('no %s' % tool)

    mode = os.environ.get('SANITIZE_MODE', 'address')
    if mode == 'address':
        san = '-fsanitize=address,undefined -fno-omit-frame-pointer'
    elif mode == 'thread':
        san = '-fsanitize=thread -fno-omit-frame-pointer'
    elif mode == 'coverage':
        san = '-fprofile-instr-generate -fcoverage-mapping'
    elif mode == 'valgrind':
        # The fourth mode, and the only one that instruments *nothing*
        # (ADR-0353). Valgrind reads the binary rather than the build, which is
        # precisely why it is here: ADR-0342 established that
        # `-fsanitize=address` reaches the compilation of the `.ll` and changes
        # nothing about a compiled program's own loads and stores, because
        # clang's pass instruments only functions carrying `sanitize_address`
        # and this compiler emits none. So the corpus was checked by four
        # sanitizers that could see the runtime's C and none of the Pascal.
        # Valgrind needs no attribute, no flag and no cooperation from the
        # emitter.
        san = ''
        # Skips like every other tool this tree can do without, and refuses to
        # (ADR-0330) when the variable says the job installed it. Valgrind is
        # not a documented dependency: `doc/sop.md` and the developer guide
        # list what a build needs, and this is a second opinion a developer may
        # not have.
        if shutil.which('valgrind') is None:
            if os.environ.get('VALGRIND_REQUIRE'):
                print('sanitize: valgrind is not installed, and '
                      'VALGRIND_REQUIRE is set', file=sys.stderr)
                return 1
            print('sanitize: valgrind is not installed -- skipping')
            print('  (Debian/Ubuntu: apt-get install valgrind)')
            return 77
    else:
        print("sanitize: unknown SANITIZE_MODE '%s'" % mode, file=sys.stderr)
        return 1

    work = Path(tempfile.mkdtemp())
    try:
        return sweep(pascalcc, pascalc, mode, san, work, sanskip)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def sweep(pascalcc, pascalc, mode, san, work, sanskip):
    sanflags = san.split()

    # Where the second runtime goes. `$work/lib` unless the caller named a
    # directory, and the caller that does is `runtime_coverage.py`: llvm-cov
    # reads the coverage mapping out of the **objects**, which have to outlive
    # this script, and `$work` is removed on the way out. One build and one
    # path either way -- a second build of the runtime here would be a second
    # set of function hashes for llvm-profdata to disagree with.
    rtdir = Path(os.environ.get('SANITIZE_RT_DIR', str(work / 'lib')))

    # Is the checker itself here? Debian's `clang` package has carried
    # compiler-rt separately before, and a missing one shows up as every link
    # failing for a reason this harness reports once and counts 500 times --
    # which it learned to do the hard way. Asked with C, before anything else,
    # so the answer is "the checker is absent" and not "the corpus does not
    # build".
    (work / 'probe.c').write_text('int main(void){return 0;}\n')
    r = subprocess.run(['clang'] + sanflags + ['-o', str(work / 'probe'),
                                               str(work / 'probe.c')],
                       capture_output=True, text=True)
    if r.returncode != 0:
        head(r.stdout + r.stderr, 3)
        return sanskip('clang here cannot link %s' % san)

    rtdir.mkdir(parents=True, exist_ok=True)
    units = ['pasrt', 'pasrt_posix', 'pasrt_unicode', 'pasrt_task']
    for u in units:
        r = subprocess.run(['clang'] + sanflags
                           + ['-O1', '-I', str(ROOT / 'runtime'),
                              '-c', str(ROOT / 'runtime' / (u + '.c')),
                              '-o', str(rtdir / (u + '.o'))],
                           capture_output=True, text=True)
        if r.returncode != 0:
            print('sanitize: the runtime does not build under %s' % san,
                  file=sys.stderr)
            head(r.stderr, 20)
            return 1
    if subprocess.run(['ar', 'rcs', str(rtdir / 'libpasrt.a')]
                      + [str(rtdir / (u + '.o')) for u in units]).returncode:
        return 1

    # **Does the sanitizer see compiled Pascal?** Asked of a Pascal program,
    # after the C probe above asked whether the checker links at all -- because
    # for the whole of this gate's life the answer was no and nothing here
    # could tell (ADR-0342): clang's passes instrument only a function carrying
    # `sanitize_address` or `sanitize_thread`, and the emitter wrote neither,
    # so a use-after-free written in Pascal printed 5 under a fully ASan-linked
    # binary and every one of the 377 programs below was "clean" of a class the
    # tool had not been asked about. ADR-0358 put the attributes on every
    # function this compiler emits, and this is the step that refuses to sweep
    # without them: a probe the sanitizer *must* report, compiled the way every
    # case below is, through the same pascalcc, the same compiler and the same
    # runtime. It is the floor's argument one step earlier -- a run that
    # reaches nothing prints the same tally as a clean one, and so does a run
    # whose instrument is switched off. Valgrind needs no attribute (ADR-0353)
    # and coverage asks a different question, so the two modes that instrument
    # are the two that are asked.
    want = ''
    if mode == 'address':
        (work / 'probe.pas').write_text(ADDRESS_PROBE)
        want = 'ERROR: AddressSanitizer: heap-use-after-free'
    elif mode == 'thread':
        (work / 'probe.pas').write_text(THREAD_PROBE)
        want = 'WARNING: ThreadSanitizer: data race'
    if want:
        env = dict(os.environ)
        env['AFTERSCHOOL_PASCAL_CFLAGS'] = san
        env['AFTERSCHOOL_PASCAL_RUNTIME'] = str(rtdir)
        env['PASCALC'] = pascalc
        r = subprocess.run([pascalcc, str(work / 'probe.pas'),
                            '-o', str(work / 'probe')],
                           capture_output=True, text=True, env=env)
        if r.returncode != 0:
            print('sanitize[%s]: the Pascal probe does not build' % mode,
                  file=sys.stderr)
            head(r.stdout + r.stderr, 5)
            return 1
        p = subprocess.run([str(work / 'probe')], capture_output=True,
                           text=True)
        said = p.stdout + p.stderr
        if want not in said:
            print("sanitize[%s]: the sanitizer does not see compiled Pascal --"
                  " the probe ran without '%s', so the emitted functions carry"
                  " no sanitize_* attribute (ADR-0342, ADR-0358) and every"
                  " 'clean' below would be a program the tool was never asked"
                  " about" % (mode, want), file=sys.stderr)
            head(said, 3)
            return 1

    # Every case the catalogue says ends with something outstanding. Read once.
    #
    # A set, where the shell carried a newline-delimited string: `declare -A`
    # is bash 4 and macOS ships bash 3.2, where that declaration fails and
    # every later subscript is evaluated as *arithmetic* -- a name that is not
    # a number is 0, so every lookup would answer with whatever the last case
    # wrote at index 0, and the suppression list would silently apply to
    # everything. The workaround is gone; the reason it existed is not.
    outstanding = set()
    for line in (ROOT / 'tests' / 'checks' / 'heap_balance.txt').read_text(
    ).split('\n'):
        if not line or line.startswith('#'):
            continue
        f = line.split()
        if len(f) >= 2 and f[1].lstrip('-').isdigit() and int(f[1]) > 0:
            outstanding.add(f[0])
        elif len(f) == 1:
            pass

    findings = ROOT / 'tests' / 'checks' / 'sanitizer_findings.txt'
    known_text = findings.read_text() if findings.exists() else ''

    def is_known(name):
        return bool(re.search(r'^%s( |$)' % name, known_text, re.M))

    # **Three reasons to skip, and they are not the same news.** For as long as
    # this gate existed the tally said `233 skipped` and a reader could not
    # tell a case with no `.out` -- which is nothing to run and is honest --
    # from one that *failed to link*, which is coverage silently lost. 47 of
    # that 233 were the second kind. They are counted apart now so the number
    # that matters is on its own: `unbuilt` should be 0, and a run where it is
    # not has stopped watching something it used to watch.
    clean = failed = known = 0
    reported = False
    noout = needsargs = unbuilt = notconc = 0

    # LeakSanitizer is Linux's: on macOS/arm64 an ASan program started with
    # `detect_leaks=1` refuses to run at all ("detect_leaks is not supported on
    # this platform"), which would flag every case as a finding. On Linux the
    # option is the default and this changes nothing. The shell hoisted this
    # out of the loop because the sweep runs many hundred times and `uname` is
    # a fork; here it is simply a constant.
    asan_options = 'detect_leaks=1' if platform.system() == 'Linux' else ''

    sources = []
    for d in ('tests', 'tests/extended', 'tests/dialect', 'examples'):
        sources += sorted((ROOT / d).glob('*.pas'))

    for src in sources:
        name = src.stem
        d = src.parent
        # In thread mode, the programs with two threads of control in them.
        # Selected by what the source *writes* rather than from a list, so a
        # concurrent program added tomorrow is swept without this file being
        # edited -- the arrangement `target-layout` has for a target. A
        # single-threaded program under ThreadSanitizer is minutes of runtime
        # and no question asked.
        #
        # **The program is the main source and its components** (6.13), and
        # through `code`, and the two halves of that are one defect found from
        # opposite sides. A comment is not something a program writes and this
        # read one as if it were; blanking comments then dropped
        # `task_in_module.pas`, whose `task` is declared in the module it
        # imports and whose *comment* had been selecting it all along. Each
        # error was hiding the other, so fixing either alone is wrong -- one
        # sweeps three programs that have no thread in them, the other stops
        # sweeping one that has.
        if mode == 'thread' and not CONCURRENT.search(program_text(d, name, src)):
            notconc += 1
            continue
        # A case with no `.out` is one that is meant to fail, and what it
        # prints is a diagnostic rather than a run.
        if not (d / (name + '.out')).is_file():
            noout += 1
            continue

        # **A component named with --import needs an object, and this did not
        # supply one.** `pascalcc` translates and links whatever
        # `--dump-imports` reports *except* what the caller already named --
        # "its object is the caller's to supply, and tests/run_test.py supplies
        # one" -- and this harness named them and supplied nothing, so every
        # case with a `.components` sidecar failed at the link and was counted
        # as a **skip**. 47 of them, silently: the whole of `lib/` and
        # `lib/dialect/` reached the only memory-safety oracle here through no
        # case at all. So the components are compiled here the way run_test.py
        # compiles them -- each translated with the ones before it, in the
        # dependency order 6.13 gives -- and the objects go to the link.
        argv = []
        objs = []
        compfail = False
        paths = []
        ip = d / (name + '.importpath')
        if ip.is_file():
            for line in ip.read_text().split('\n'):
                if line:
                    paths += ['--import-path', str(d / line)]
        env = dict(os.environ)
        ie = d / (name + '.importenv')
        if ie.is_file():
            env['AFTERSCHOOL_PASCAL_PATH'] = ie.read_text().split(
                '\n')[0].replace('<dir>', str(d))
        env['AFTERSCHOOL_PASCAL_CFLAGS'] = san
        env['AFTERSCHOOL_PASCAL_RUNTIME'] = str(rtdir)
        env['PASCALC'] = pascalc
        build_txt = ''
        comps = d / (name + '.components')
        if comps.is_file():
            cn = 0
            for line in comps.read_text().split('\n'):
                rel = line.split()[0] if line.split() else ''
                if not rel:
                    continue
                cn += 1
                r = subprocess.run([pascalcc] + argv + paths
                                   + ['-c', str(d / rel),
                                      '-o', str(work / ('c%d.o' % cn))],
                                   capture_output=True, text=True, env=env)
                if r.returncode != 0:
                    build_txt = r.stdout + r.stderr
                    compfail = True
                    break
                argv += ['--import', str(d / rel)]
                objs.append(str(work / ('c%d.o' % cn)))

        # The level the *corpus* is compiled at, most specific first, which is
        # `run_test.py`'s own order one harness over:
        #
        #   name.opt                  this case pins one
        #   AFTERSCHOOL_PASCAL_OPT    the whole run wants one (ADR-0335)
        #   neither                   -O1, which is what a sanitizer build
        #                             wants: -O0 buries a report in noise and
        #                             -O2 optimises away the undefined
        #                             behaviour UBSan is looking for. It is the
        #                             level this gate has always answered at
        #                             and the default does not move.
        #
        # It read the variable **not at all** until ADR-0335, so
        # `AFTERSCHOOL_PASCAL_OPT=-O0 ctest` reported the whole suite green at
        # -O0 with two of its cases quietly at -O1 -- and CI's `unoptimised`
        # job made that claim on every push. The `-O1` two hundred lines up is
        # a different number and stays pinned: it is the level the runtime's
        # own C is built at, which is the sanitizer's business and not the
        # corpus's.
        opt = os.environ.get('AFTERSCHOOL_PASCAL_OPT') or '-O1'
        of = d / (name + '.opt')
        if of.is_file():
            opt = of.read_text().rstrip('\n')

        if not compfail:
            r = subprocess.run([pascalcc, opt] + argv + paths + [str(src)]
                               + objs + ['-o', str(work / 'prog')],
                               capture_output=True, text=True, env=env)
            if r.returncode != 0:
                build_txt = r.stdout + r.stderr
                compfail = True
        if compfail:
            # **Say why, once.** A program that will not build is counted as a
            # skip, and the tally at the end refuses a run that reached nothing
            # -- which is the guard working. But "0 clean, 516 skipped" does
            # not say *what* went wrong, and the first time that happened the
            # cause took a container to find: debian:trixie's `clang` package
            # does not carry compiler-rt, so every `-fsanitize=address` link
            # failed with a missing `libclang_rt.asan.a` and this harness
            # reported none of it.
            #
            # One program's output is enough -- when they all fail they fail
            # for one reason -- and printing every one would bury the tally
            # under 516 copies.
            if not reported:
                reported = True
                print('sanitize: %s did not build under %s, and here is why:'
                      % (name, san), file=sys.stderr)
                head(build_txt, 10)
                print('sanitize: (further build failures are counted, not '
                      'printed)', file=sys.stderr)
            unbuilt += 1
            continue

        stdin_path = d / (name + '.in')
        if not stdin_path.is_file():
            stdin_path = Path('/dev/null')
        # `halt_on_error=0` so a program with two findings reports both, and
        # `exitcode=0` so the detection below is by what was *written* -- which
        # is what the address mode already does, ASan's own exit status never
        # being consulted here.
        # Valgrind is a *wrapper* where the other three modes are a build, so
        # the only thing that changes here is what runs the program.
        # `--error-exitcode` is deliberately not used: this harness decides by
        # what was **written**, as the address mode's comment above says, and a
        # corpus case that traps on purpose already exits non-zero.
        vg = (['valgrind', '-q', '--error-exitcode=0',
               '--errors-for-leak-kinds=none'] if mode == 'valgrind' else [])
        renv = dict(os.environ)
        renv['ASAN_OPTIONS'] = asan_options
        renv['TSAN_OPTIONS'] = 'halt_on_error=0 exitcode=0'
        with open(stdin_path, 'rb') as fin:
            p = subprocess.run(vg + ['./prog'], cwd=work, stdin=fin,
                               capture_output=True, env=renv)
        err = p.stderr.decode('utf-8', 'surrogateescape')

        # A program that wanted file names on its command line, which this
        # harness does not supply. Its own `.out` is what run_test.py compares;
        # here it is a skip and is counted as one.
        if 'needs a file name as argument' in err:
            needsargs += 1
            continue

        # **The two `runtime error:` messages are not the same message**, and
        # telling them apart is the whole of what makes this gate readable.
        # This compiler traps on purpose -- an array subscript out of bounds,
        # an integer overflow, a case with no matching label -- and
        # `runtime/pasrt.c` writes `runtime error: ...` at the start of a line
        # for it (ADR-0014, ADR-0017). UBSan writes
        # `<file>:<line>:<col>: runtime error: ...`, with a position in front.
        # Matching the bare text called every `trap_*` case in the corpus a
        # sanitizer finding, which is thirteen programs doing exactly what they
        # were written to do.
        # ThreadSanitizer announces itself differently from the other three: a
        # data race is `WARNING: ThreadSanitizer: data race`, with no
        # `==pid==ERROR:` in front of it, so the pattern the address mode
        # matches finds nothing and every racy program reports clean. That is
        # the shape of failure this whole register exists to refuse, so the two
        # patterns are named separately rather than a wider one being written
        # that happens to catch both.
        if mode == 'thread':
            if TSAN_FINDING.search(err):
                if is_known(name):
                    known += 1
                    continue
                print('--- %s ---' % name, file=sys.stderr)
                for ln in grep('ThreadSanitizer: ', err, 6):
                    print(ln, file=sys.stderr)
                failed += 1
                continue
            clean += 1
            continue
        # Valgrind's findings are `==pid== Invalid write of size 4` and the
        # like, which match none of the three signatures above -- so without
        # this arm the mode would run the whole corpus under Valgrind and
        # report every case clean (ADR-0353). A gate that cannot see its own
        # tool's output is the shape `format-check` shipped with (ADR-0282).
        if mode == 'valgrind' and VG_FINDING.search(err):
            if is_known(name):
                known += 1
                continue
            print('--- %s ---' % name, file=sys.stderr)
            for ln in grep(r'^==[0-9]+== ', err, 6):
                print(ln, file=sys.stderr)
            failed += 1
            continue
        if mode == 'valgrind':
            clean += 1
            continue
        if ASAN_FINDING.search(err):
            # LeakSanitizer alone, on a case the catalogue already accounts
            # for, is the catalogue being right rather than a defect.
            #
            # Asked of the ERROR *line*, not of the whole output:
            # LeakSanitizer prints its own summary as
            # `SUMMARY: AddressSanitizer: ... leaked`, so a test for the
            # absence of the string `AddressSanitizer` anywhere suppressed
            # nothing and reported every catalogued leak.
            if (LSAN_ERROR.search(err) and not ASAN_ERROR.search(err)
                    and not UBSAN_ERROR.search(err) and name in outstanding):
                clean += 1
                continue
            # A finding this tree already knows about and has argued for.
            if is_known(name):
                known += 1
                continue
            print('--- %s ---' % name, file=sys.stderr)
            for ln in grep(r'^==[0-9]*==ERROR: |runtime error: |SUMMARY:',
                           err, 4):
                print(ln, file=sys.stderr)
            failed += 1
            continue
        clean += 1

    print('sanitize[%s]: %d clean, %d catalogued, %d flagged, %d skipped '
          '(%d with no .out, %d wanting file names, %d unbuilt, %d '
          'single-threaded)'
          % (mode, clean, known, failed,
             noout + needsargs + unbuilt + notconc,
             noout, needsargs, unbuilt, notconc))
    if unbuilt > 0:
        print('sanitize: %d case(s) with a golden did not build, and a case '
              'that cannot be linked is coverage lost rather than a case with '
              'nothing to run -- see the first one printed above' % unbuilt,
              file=sys.stderr)
    # The floor, and it is a different number for each mode because each
    # sweeps a different corpus: everything with a golden, against the eleven
    # programs in this tree that have two threads of control. Both exist for
    # one reason -- a run that reaches nothing prints the same tally as a clean
    # one.
    floor = 8 if mode == 'thread' else 100
    if clean + known < floor:
        print('sanitize[%s]: only %d programs ran, below the floor of %d -- a '
              'run that reaches nothing passes for the same reason a clean one'
              ' does' % (mode, clean + known, floor), file=sys.stderr)
        return 1
    return 0 if failed == 0 else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
