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

"""How far is runtime/pasrt.c from ISO C, exactly?

Converted from tests/checks/runtime_isoc.sh under ADR-0366, which makes a
harness Python 3 and keeps it off the general-purpose Unix utilities. Every
message, exit status, count and floor below is what the shell version wrote.

It is the only C in this project and the whole of what a port to another
platform has to satisfy, and doc/roadmap.md's cross-platform chapter used to
answer this by assertion -- "`bind` and the file model are POSIX assumptions
in the runtime". Measured, they are not: the file model is `fopen`, `fseek`
and `tmpfile`, all ISO C, and the runtime's entire departure from the
standard is **three names**, each for a reason ISO C gives no way around.

This turns that measurement into a claim that is checked. Two passes:

  1. compile as strict C11. A C library that honours __STRICT_ANSI__ then
     hides everything POSIX-only, so each such use becomes "call to
     undeclared function". Those names are compared against
     tests/checks/nonstandard_c.txt in **both** directions -- a fourth
     dependency appearing is what this exists to catch, and a listed name
     that stops appearing means the catalogue is describing a runtime that no
     longer exists, which is verify/'s KNOWN_GAP rule.

  2. compile again with only those two diagnostics silenced, and require a
     clean build. That is what says the three names are the whole of it
     rather than the first three of a longer list.

There is a third pass, over the other half of the boundary. The *emitted*
code names symbols too, and doc/roadmap.md claims "the only symbol the
emitted code names outside runtime/pasrt.c and LLVM's intrinsics is
`_setjmp`". That is the same kind of claim and gets the same treatment: every
.pas in the corpus is compiled and every `declare`d name that is neither
`pas_*` nor `llvm.*` has to be in the catalogue. It is where `_setjmp` comes
from -- the runtime never calls it, the generated code does, because the
frame setjmp saves has to be the one longjmp returns into.

**It skips (77) where the C library does not hide POSIX.** macOS exposes
POSIX declarations regardless of __STRICT_ANSI__, and there the first pass
reports nothing -- which is indistinguishable from a runtime that grew clean.
A check that cannot ask its question says so rather than passing.
"""

import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# Python block-buffers a redirected stdout where `echo` does not, so a
# subprocess this script does not capture would otherwise print before the
# lines around it (ADR-0366).
sys.stdout.reconfigure(line_buffering=True)
sys.stderr.reconfigure(line_buffering=True)

here = Path(__file__).resolve().parent
root = here.parent.parent
work = Path(tempfile.mkdtemp())

cc = os.environ.get("APASCAL_CLANG", "clang")
src = root / "runtime" / "pasrt.c"
list_path = here / "nonstandard_c.txt"

std = ["-std=c11", "-pedantic-errors", "-I" + str(root / "runtime")]


def out(*parts):
    """`echo a b` -- the shell joins its arguments with one space."""
    print(" ".join(parts))


def err(*parts):
    print(" ".join(parts), file=sys.stderr)


def head20(path):
    """`head -20 file >&2`, byte for byte and without adding a newline."""
    sys.stderr.flush()
    data = path.read_bytes() if path.exists() else b""
    sys.stderr.buffer.write(b"".join(data.splitlines(keepends=True)[:20]))
    sys.stderr.buffer.flush()


def finish(status):
    shutil.rmtree(work, ignore_errors=True)
    sys.exit(status)


def run_capture(argv, log, stdout=True):
    """Run argv with stderr -- and by default stdout -- into `log`.

    A compiler that is not there is 127 and a line of this script's own, where
    the shell version let bash write its `command not found` **in the
    operator's locale** into the same log (ADR-0366's own reason).
    """
    with open(log, "wb") as fh:
        try:
            return subprocess.call(argv, stdout=fh if stdout else None,
                                   stderr=fh)
        except OSError as e:
            fh.write(("runtime-isoc: cannot run %s: %s\n"
                      % (argv[0], e.strerror)).encode())
            return 127


INCLUDE_RE = re.compile(r"^#include <([a-z0-9_/]+\.h)>", re.M)

# --- pass 0: which headers are not ISO C's? --------------------------------
#
# __STRICT_ANSI__ hides what a POSIX *extension* adds to an ISO C header, and
# that is all it hides. A header ISO C does not have at all -- <unistd.h> --
# is not touched by it: glibc declares `access` there unconditionally, so a
# strict compile of the file as written says nothing about it. The first
# version of this script had exactly that hole, and `access` went through it.
# So the strict compile is of a *copy* with every non-ISO include removed,
# which is what an ISO C library would present, and each name such a header
# declared becomes "undeclared" and is harvested with the rest. The list is
# C11's twenty-nine headers, Annex B.
iso_headers = (
    "assert complex ctype errno fenv float inttypes iso646 limits locale "
    "math setjmp signal stdalign stdarg stdatomic stdbool stddef stdint "
    "stdio stdlib stdnoreturn string tgmath threads time uchar wchar wctype"
).split()

src_text = src.read_text()
stripped = work / "pasrt.c"
stripped_text = src_text
for h in [m[: -len(".h")] for m in INCLUDE_RE.findall(src_text)]:
    if h not in iso_headers:
        stripped_text = re.sub(
            r"(?m)^#include <" + re.escape(h) + r"\.h>",
            "/* <%s.h> is not ISO C: removed by runtime_isoc.py */" % h,
            stripped_text,
        )
stripped.write_text(stripped_text)

# --- pass 1: what does strict ISO C not declare? ---------------------------
p1_log = work / "p1.txt"
p1 = run_capture([cc] + std + ["-c", str(stripped), "-o", str(work / "a.o")],
                 p1_log)
found = sorted(set(re.findall(
    r"call to undeclared function '([A-Za-z_][A-Za-z0-9_]*)'",
    p1_log.read_text(errors="replace"))))

# Nothing undeclared has two very different causes, and telling them apart is
# the whole of this branch. A *clean* compile means the C library declared
# everything -- macOS exposes POSIX regardless of __STRICT_ANSI__ -- and the
# question cannot be asked here. A compile that *failed* and still named
# nothing means it stopped before reaching the calls, which a bad #include does,
# and reporting that as "this C library declares POSIX" is a lie that exits 77.
#
# The first version of this script had exactly that bug: replacing <errno.h>
# with a header that does not exist made it print the skip message and pass.
if not found:
    if p1 == 0:
        out("runtime-isoc: this C library declares POSIX even under",
            "__STRICT_ANSI__, so the question cannot be asked here --",
            "glibc is what it was measured on")
        finish(77)
    err("runtime-isoc: runtime/pasrt.c does not compile as strict ISO C, and",
        "the failure is not a POSIX call:")
    head20(p1_log)
    finish(1)

# --- pass 3: and what does the *generated* code name? ----------------------
#
# The runtime is one half of the boundary; the emitted module is the other, and
# it declares what it calls. Everything this compiler emits is either its own
# `pas_` runtime or an LLVM intrinsic -- except `_setjmp`, which the generated
# code has to call itself.
pascalc = os.environ.get("PASCALC", str(root / "build" / "bin" / "pascalc"))
if os.access(pascalc, os.X_OK):   # `[[ -x $pascalc ]]`
    # tests/ and tests/extended/ and not tests/dialect/: ADR-0121's `external`
    # lets a program name any C function it likes, so a declare there is the
    # *program's* business and not the compiler's. What is being asked is what
    # this compiler emits on its own account, and no source in these two
    # directories writes an `external` heading -- which used to be guaranteed
    # by the conformance modes and is now a property of the corpus, checked
    # here rather than assumed.
    ell = work / "e.ll"
    declare_re = re.compile(r"^declare [^@]*@([A-Za-z_][A-Za-z0-9_.]*)", re.M)
    external_re = re.compile(r"\bexternal\b")
    names = set()
    for d in ("tests", "tests/extended"):
        for f in sorted((root / d).glob("*.pas")):
            if not f.is_file():
                continue
            if external_re.search(f.read_text(errors="replace")):
                continue
            subprocess.call([pascalc, str(f), "-o", str(ell)],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL)
            # `[[ -s ... ]]`: a file that exists and is not empty. The shell
            # never removes it between iterations either, and `sort -u` is
            # what makes that harmless.
            if ell.exists() and ell.stat().st_size > 0:
                names.update(declare_re.findall(ell.read_text(errors="replace")))
    emitted = sorted(n for n in names
                     if not (n.startswith("pas_") or n.startswith("llvm.")))
    found = sorted(set(found) | set(emitted))
else:
    # No degraded mode. Half the harvest against a whole catalogue accuses it of
    # naming `_setjmp`, which the runtime indeed does not use -- the *generated
    # code* does -- so running on without the emitted half turns a missing build
    # into a false finding against the file that is right. Skips as
    # buffer-headroom does for the same reason.
    out("runtime-isoc: no compiler at %s -- half of this check reads what"
        % pascalc,
        "the emitted module declares, and half a harvest against a whole",
        "catalogue is a false accusation rather than a partial answer. Build",
        "first, or set PASCALC.")
    finish(77)

# The identifier half of the catalogue. `header:` lines belong to the POSIX
# unit's section (ADR-0186) and are read by pass 3, not here -- without this
# they arrive as identifiers pasrt.c does not use, and the both-directions
# check reports the new section as a stale entry.
list_text = list_path.read_text()
listed = sorted({
    line.replace(" ", "").replace("\t", "")
    for line in list_text.splitlines()
    if not re.match(r"^\s*(#|$)", line) and not line.startswith("header:")
})

missing = [n for n in listed if n not in set(found)]
extra = [n for n in found if n not in set(listed)]

status = 0
if extra:
    err("runtime-isoc: runtime/pasrt.c uses an identifier ISO C does not",
        "declare and this catalogue does not name:")
    for n in extra:
        err("          " + n)
    err("        Every one of these is something a port to another C library")
    err("        has to supply. Add it to tests/checks/nonstandard_c.txt with")
    err("        the argument for why ISO C could not do it, or use ISO C.")
    status = 1
# A catalogued name the strict compile did not report has two causes, and only
# one of them is this gate's finding. Either pasrt.c no longer uses it -- the
# stale catalogue -- or it uses it and *this* C library declared it anyway, so
# no diagnostic could name it. macOS declares `_longjmp`, `fmemopen` and
# `open_memstream` regardless of __STRICT_ANSI__, which is the same reason the
# all-or-nothing skip above exists, met one name at a time instead of all of
# them. The source is what tells the two apart, and it is the same source
# everywhere: a name pasrt.c still writes is not a name it no longer uses.
declared = ""
still = []
for n in missing:
    # `grep -qw -- "$n" "$src"`: the name as a whole word.
    if re.search(r"(?<![A-Za-z0-9_])" + re.escape(n) + r"(?![A-Za-z0-9_])",
                 src_text):
        declared = declared + " " + n
    else:
        still.append(n)
if declared:
    out("runtime-isoc: this C library declares these even under",
        "__STRICT_ANSI__, so the strict compile could not name them, and",
        "runtime/pasrt.c still uses each --" + declared)
missing = still
if missing:
    err("runtime-isoc: the catalogue names an identifier runtime/pasrt.c no",
        "longer uses:")
    for n in missing:
        err("          " + n)
    err("        Good news, and it still fails: a catalogue describing a")
    err("        runtime that no longer exists is what verify/'s KNOWN_GAP")
    err("        rule is about. Strike the entry in the change that removed")
    err("        the dependency.")
    status = 1
if status != 0:
    finish(1)

# --- pass 2: and nothing else is non-standard ------------------------------
#
# `-Werror` here as in every other pass, and it was the one pass without it.
# What that cost: four `-Wcomment` warnings entered this file with ADR-0293 and
# shipped unnoticed until a release rehearsal read the build log by hand -- a
# comment naming `seed/*.ll` inside a `/* */` block. Nothing else could have
# seen them. `warning-free` (ADR-0286) asks what the *Pascal* compiler has to
# say about this tree's Pascal, and the four other compiles in this file each
# had `-Werror` already, so the gate closest to the C was the only one that
# would print a warning and pass.
#
# The two `-Wno-` flags below are what stripping the includes makes necessary
# and are unrelated: without the declarations, every call is implicit.
p2_log = work / "p2.txt"
if run_capture([cc] + std + [
        "-Wall", "-Wextra", "-Werror",
        "-Wno-implicit-function-declaration", "-Wno-int-conversion",
        "-c", str(stripped), "-o", str(work / "b.o")], p2_log) != 0:
    err("runtime-isoc: with those names excused, runtime/pasrt.c is still not",
        "strict ISO C:")
    head20(p2_log)
    finish(1)

# --- pass 3: and the POSIX unit is bounded by its headers -------------------
#
# ADR-0186 split the runtime because the catalogue above can only ever hold
# *functions*: it is proved complete by stripping includes and requiring what
# is left to compile, and an incomplete `struct stat` is an error no flag
# silences. runtime/pasrt_posix.c is therefore not held to ISO C at all. What
# is bounded for it is the set of non-ISO headers it may include -- the
# granularity a port actually cares about, and one that can be checked without
# conjuring a type.
#
# Both directions, like everything else here: a header appearing without an
# entry, and an entry naming a header the file no longer includes.
posix_src = root / "runtime" / "pasrt_posix.c"
if not posix_src.is_file():
    err("runtime-isoc: no runtime/pasrt_posix.c -- ADR-0186 says the runtime",
        "has two translation units, and this one is where anything needing a",
        "POSIX type lives. If it went away, strike its section from",
        "%s." % list_path)
    finish(1)

posix_text = posix_src.read_text()
posix_used = sorted({"<%s>" % h for h in INCLUDE_RE.findall(posix_text)
                     if h[: -len(".h")] not in iso_headers})
posix_named = sorted(set(re.findall(r"(?m)^header: (<[a-z0-9_/]+\.h>)",
                                    list_text)))

extra = [h for h in posix_used if h not in set(posix_named)]
gone = [h for h in posix_named if h not in set(posix_used)]
if extra:
    err("runtime-isoc: runtime/pasrt_posix.c includes a non-ISO header this",
        "catalogue does not name:")
    for h in extra:
        err("          " + h)
    err("        That file's headers *are* its porting surface (ADR-0186).",
        "Add it to %s with the argument for why ISO C could not do it."
        % list_path)
    finish(1)
if gone:
    err("runtime-isoc: the catalogue names a header runtime/pasrt_posix.c no",
        "longer includes:")
    for h in gone:
        err("          " + h)
    err("        Good news, and it still fails, for verify/'s KNOWN_GAP",
        "reason. Strike the entry in the change that removed it.")
    finish(1)

# It still has to be *clean* C -- POSIX rather than ISO, which is what the
# feature macro selects, and nothing warned about at all.
#
# `_DARWIN_C_SOURCE` beside it on Darwin, and the reason is a fact about that
# C library's headers rather than about this runtime. `mkdtemp` and
# `O_NOFOLLOW` are both POSIX.1-2008, and Darwin still gates them as the BSD
# extensions they were before 2008 -- so asking for exactly the standard the
# names belong to is what hides them. Defining it asks Darwin for its full
# set, which makes this pass weaker *there* and not anywhere else: the strict
# question is answered on a C library whose gating follows the standard it
# names, and this pass still refuses a warning and a non-POSIX call on both.
posix_std = ["-std=c11", "-D_POSIX_C_SOURCE=200809L"]
if platform.system() == "Darwin":
    posix_std.append("-D_DARWIN_C_SOURCE")
p3_log = work / "p3.txt"
if run_capture([cc] + posix_std + [
        "-pedantic-errors", "-Wall", "-Wextra", "-Werror",
        "-I" + str(root / "runtime"),
        "-c", str(posix_src), "-o", str(work / "posix.o")], p3_log) != 0:
    err("runtime-isoc: runtime/pasrt_posix.c is not clean POSIX C11:")
    head20(p3_log)
    finish(1)

# And nothing the *compiler* emits may call into it: everything there is
# `pasx_`, which is what makes the whole file optional for a port (ADR-0131).
bad = set()
for line in posix_text.splitlines():
    m = re.match(r"[a-z].*(?<![A-Za-z0-9_])(pas_[A-Za-z0-9_]*)\s*\(", line)
    if m:
        for n in re.findall(r"pas_[A-Za-z0-9_]*", m.group(0)):
            if not n.startswith("pasx_"):
                bad.add(n)
bad = sorted(bad)
if bad:
    err("runtime-isoc: runtime/pasrt_posix.c defines or calls a pas_ name:")
    for n in bad:
        err("          " + n)
    err("        Everything in that file has to be pasx_, or a system",
        "without these headers loses the language and not just a library",
        "routine (ADR-0186).")
    finish(1)

# --- pass 4: and the Unicode unit is held to more than pasrt.c is -----------
#
# runtime/pasrt_unicode.c is AP 6.4.15's tables and the arithmetic over them,
# and it needs *nothing* outside ISO C -- no allocation, no locale, no POSIX,
# not even the five names pass 2 excuses pasrt.c. So it is compiled with no
# catalogue at all, which is a stronger claim than either file above carries
# and one that is free to make while it stays true.
#
# It is checked here rather than left to the build because the build compiles
# it with the project's warnings and not with -pedantic-errors, and because a
# third translation unit invisible to this gate is exactly the gap ADR-0186
# closed for the second.
uni_src = root / "runtime" / "pasrt_unicode.c"
if not uni_src.is_file():
    err("runtime-isoc: no runtime/pasrt_unicode.c -- if the text primitives",
        "went away, strike this pass. If they moved, this pass follows them.")
    finish(1)

p4_log = work / "p4.txt"
if run_capture([cc, "-std=c11", "-pedantic-errors", "-Wall", "-Wextra",
                "-Werror", "-I" + str(root / "runtime"),
                "-c", str(uni_src), "-o", str(work / "uni.o")], p4_log) != 0:
    err("runtime-isoc: runtime/pasrt_unicode.c is not strict ISO C11:")
    head20(p4_log)
    err("        It is held to ISO C with no catalogued name at all",
        "(ADR-0189). If it now needs one, that is a decision and not a",
        "compile flag.")
    finish(1)

# The same both-directions question pass 2 asks of pasrt.c, asked of a file
# whose answer must be zero: any non-ISO include here would be a dependency the
# catalogue does not know about, and __STRICT_ANSI__ would hide it exactly as
# <unistd.h> hid `access` (ADR-0186).
uni_text = uni_src.read_text()
uni_extra = sorted({"<%s>" % h for h in INCLUDE_RE.findall(uni_text)
                    if h[: -len(".h")] not in iso_headers})
if uni_extra:
    err("runtime-isoc: runtime/pasrt_unicode.c includes a non-ISO header:")
    for hh in uni_extra:
        err("          " + hh)
    err("        That file is the one part of the runtime a port gets for",
        "free. Keep it that way, or say in ADR why not.")
    finish(1)

# --- pass 5: and the concurrency unit is bounded by one header --------------
#
# runtime/pasrt_task.c is AP 6.4.16's channel and AP 6.9.3.12's task set
# (ADR-0268). It is the fourth translation unit and the second bounded by its
# **headers** rather than by a list of names -- one header beyond ISO C:
#
#     <pthread.h>
#
# A system without it loses the concurrency construct and not the language,
# which is pasrt_posix.c's own bargain (ADR-0186). Unlike that file it holds
# `pas_` names, because what it implements is what the *compiler emits* rather
# than what a program may bind -- so the `pasx_` rule is the wrong question
# here and the header list is the right one.
task_src = root / "runtime" / "pasrt_task.c"
if not task_src.is_file():
    err("runtime-isoc: no runtime/pasrt_task.c -- if the concurrency runtime",
        "moved, this check moved with it (ADR-0268)")
    finish(1)
# The base name, and `iso_headers` in the spelling the rest of this script
# uses: it is lower-case and holds names *without* the `.h`, which is what
# passes 3 and 4 compare against. The shell version once read `$ISO_HEADERS` --
# a variable assigned nowhere -- and compared it against names *with* the
# suffix, so under `set -u` the reference killed the subshell, `task_extra`
# came back empty whatever the file included, and the summary below went on
# calling this unit "bounded by <pthread.h> alone" as a fact. Adding
# <sys/mman.h> to runtime/pasrt_task.c left the gate green and silent.
task_allowed = ["pthread"]
task_text = task_src.read_text()
task_includes = sorted(set(re.findall(
    r"(?m)^[ \t]*#[ \t]*include[ \t]*<([^>]+)>", task_text)))
task_extra = ["<%s>" % hh for hh in task_includes
              if (hh[: -len(".h")] if hh.endswith(".h") else hh)
              not in iso_headers + task_allowed]
if task_extra:
    err("runtime-isoc: runtime/pasrt_task.c includes a header outside ISO C",
        "and its one catalogued one:")
    for hh in task_extra:
        err("          " + hh)
    err("        <pthread.h> is the whole of what a port has to have for the",
        "concurrency construct. Adding a second is a decision for an ADR.")
    finish(1)
# `cc`, which is APASCAL_CLANG or `clang`. The shell version spelled this one
# compile literally and the conversion kept it, the conversion being a
# conversion; that left four of the five strict compiles answering about the
# compiler the operator chose and the fifth answering about whatever `clang`
# is on PATH. With APASCAL_CLANG pointing at a wrapper the wrapper was
# invoked four times and never once for pasrt_task.c, so on a machine where
# the two differ this pass reported a compiler nobody asked for -- a green
# bar meaning `<pthread.h> alone` had been checked by the wrong reader.
task_err = work / "task.err"
sys.stdout.flush()
if run_capture([cc, "-std=c11", "-Wall", "-Wextra", "-Werror",
                "-c", str(task_src), "-I" + str(root / "runtime"),
                "-o", str(work / "task.o")], task_err, stdout=False) != 0:
    err("runtime-isoc: runtime/pasrt_task.c is not clean POSIX C11 under",
        "%s:" % cc)
    head20(task_err)
    finish(1)

# `wc -l` over `echo "$var"`: an empty variable is still one line.
n = len(found) or 1
h = len(posix_named) or 1
out("runtime-isoc: runtime/pasrt.c is strict ISO C11 apart from %d catalogued"
    % n,
    "names (%s), runtime/pasrt_posix.c is bounded by" % (" ".join(found) + " "),
    "%d catalogued headers (%s)," % (h, " ".join(posix_named) + " "),
    "runtime/pasrt_unicode.c needs no catalogue at all,",
    "runtime/pasrt_task.c is bounded by <pthread.h> alone, and the",
    "emitted module names nothing but its own")
finish(0)
