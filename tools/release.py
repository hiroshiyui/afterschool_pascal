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

"""**A release archive, and the check that it is one** (ADR-0296).

  release.py --archive <build-dir> <tag> [<arch>] [<out-dir>]
  release.py --check   <archive.tar.gz>
  release.py --notes   <tag>

`--archive` lays a build tree out the way `cmake --install` does, under one
directory named `afterschool-pascal-<tag>-<arch>`, and writes that directory
as `<out-dir>/afterschool-pascal-<tag>-<arch>.tar.gz` with a
`.tar.gz.sha256` beside it in `sha256sum -c` form. The layout is the one
`install-layout` checks (ADR-0244) -- bin/pascalc, bin/pascalcc,
lib/libpasrt.a, lib/afterschool/ -- plus the two licence files and a short
README, because a person who downloaded this has not got the repository's.
`<arch>` defaults to `<uname -m>-<uname -s>` in lower case, which is
`x86_64-linux` here; `<out-dir>` defaults to the working directory.

`--check` is the half that fails. It reads the `.sha256` back and requires
it to match, unpacks the archive into a fresh directory, and then hands the
result to `tests/checks/install_layout.py --prefix`, which is the gate that
already knows what an installed compiler has to be able to do: PATH holding
its bin and nothing else, every variable that could point back at a checkout
unset, a program importing two library modules compiled and run from a third
directory, and one `import <name>;` program per installed module. The logic
is in that script and not copied here, so a file added to the layout is
added in one place. What this adds is the archive's own questions -- the
digest, the one top-level directory, the licences -- and whether `pascalc`
is statically linked, which it reports always and *requires* only when
`RELEASE_REQUIRE_STATIC` is set, because a developer's build tree links
dynamically and the CI job is what configures the static one.

`--notes` prints the CHANGELOG.md section for the tag, for `gh release
create --notes-file`, and refuses a tag that has no section: a release whose
notes are empty is one nobody wrote a changelog entry for, and
`.claude/skills/release-engineering` says one is written before the tag.

**Why a script and not `run:` blocks.** Every line of this runs at a tag and
nowhere else if it lives in the workflow, and twice now something written
there failed for want of anywhere to be exercised first (ADR-0233's
`seed_current.py`, ADR-0282). So this is a script, `tests/checks/
release_archive.py` drives `--archive` and `--check` as a `ctest` case on
every run, and the workflow calls the same text with the tag's name.

**The tag has to be the version.** `pascalc --version` prints what
`CMakeLists.txt` says, `pascalc-product` holds the two together, and this
closes the triangle: an archive named `v3.5.0` holding a compiler that says
3.4.0 is refused rather than uploaded.

Converted from `tools/release.py` under ADR-0366: a harness is Python 3 and
reaches for the standard library rather than a subprocess.
"""

import fnmatch
import gzip
import hashlib
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile

sys.stdout.reconfigure(line_buffering=True)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)


def die(msg):
    sys.stdout.flush()
    sys.stderr.write("release: %s\n" % msg)
    sys.stderr.flush()
    sys.exit(1)




def host_arch():
    u = os.uname()
    return "%s-%s" % (u.machine, u.sysname.lower())


# The digest alone, and the file this writes is in sha256sum's own `-c`
# format. The shell version shelled out to sha256sum or shasum; hashlib is
# the same answer with nothing to be missing from PATH (ADR-0366 rule 2).
def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# `ldd` says "not a dynamic executable" of a static binary and lists the
# libraries of a dynamic one; LC_ALL=C because it says so in the machine's
# language otherwise. Where there is no `ldd` (macOS) the answer is unknown,
# and reported as that rather than as either of the other two.
#
# Captured and not piped: `ldd` exits 1 on a static binary, and under
# pipefail that status is the pipeline's whatever grep found, so the first
# version of this reported the static binary it was written for as dynamic.
def link_kind(path):
    if shutil.which("ldd") is None:
        return "unknown"
    env = dict(os.environ)
    env["LC_ALL"] = "C"
    said = subprocess.run(["ldd", path], stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, env=env).stdout
    said = said.decode("utf-8", "replace")
    if "not a dynamic executable" in said:
        return "static"
    return "dynamic"


def version_of(path):
    # `pascalc (Afterschool Pascal) 3.4.0` -- the last word.
    try:
        p = subprocess.run([path, "--version"], stdout=subprocess.PIPE,
                           stderr=subprocess.DEVNULL)
        ok = p.returncode == 0
        line = p.stdout.decode("utf-8", "replace")
    except OSError:
        ok, line = False, ""
    if not ok:
        # The shell called this inside `$( )`, where `die` exits the *subshell*
        # only: a compiler that would not answer printed "--version failed" and
        # then, `set -e` being off, a second refusal naming an empty version.
        # ADR-0366 allows a conversion to fix what it uncovers, and one message
        # naming the real cause is what a release needs to read.
        die("%s --version failed" % path)
    line = line.rstrip("\n")
    return line.rsplit(" ", 1)[-1]


README = """\
Afterschool Pascal %(version)s, for %(arch)s.

    export PATH=$PWD/bin:$PATH
    pascalcc hello.pas -o hello

bin/pascalc writes LLVM IR and stops; bin/pascalcc assembles and links it
with clang, which must be on PATH (clang 15 or later), and links
lib/libpasrt.a beside it. The library under lib/afterschool is source, and
pascalcc puts it on the search path when AFTERSCHOOL_PASCAL_PATH says
nothing. Nothing here needs to be installed anywhere in particular.

The compiler is under the GNU General Public License version 3 or later
(LICENSE); the runtime a compiled program links carries the exception in
COPYING.RUNTIME. Sources: https://github.com/hiroshiyui/afterschool_pascal
"""


def archive(build, tag, arch, out):
    arch = arch or host_arch()
    out = out or "."
    if not os.path.isdir(build):
        die("no build directory '%s'" % build)
    pascalc = build + "/bin/pascalc"
    if not (os.path.isfile(pascalc) and os.access(pascalc, os.X_OK)):
        die("%s/bin/pascalc is missing; build first" % build)
    if not tag.startswith("v"):
        die("a tag starts with 'v', not '%s'" % tag)
    version = version_of(pascalc)
    if tag != "v" + version:
        die("tag %s does not name the compiler's version (%s)" % (tag, version))

    name = "afterschool-pascal-%s-%s" % (tag, arch)
    stage = tempfile.mkdtemp(prefix="release.",
                             dir=os.environ.get("TMPDIR") or "/tmp")
    try:
        log = os.path.join(stage, "install.log")
        with open(log, "wb") as fh:
            rc = subprocess.run(
                ["cmake", "--install", build, "--prefix",
                 os.path.join(stage, name)],
                stdout=fh, stderr=subprocess.STDOUT).returncode
        if rc != 0:
            sys.stdout.flush()
            with open(log, "rb") as fh:
                sys.stderr.buffer.write(fh.read())
            sys.stderr.flush()
            die("cmake --install failed")
        for f in ("LICENSE", "COPYING.RUNTIME"):
            shutil.copy(os.path.join(ROOT, f), os.path.join(stage, name, f))
        with open(os.path.join(stage, name, "README"), "w") as fh:
            fh.write(README % {"version": version, "arch": arch})

        try:
            os.makedirs(out, exist_ok=True)
        except OSError:
            pass
        tarball = out + "/" + name + ".tar.gz"
        # Owner and group are the machine's otherwise, and nothing about a
        # release is a fact about who ran it. `tarfile` says these the same
        # way everywhere, where GNU tar and bsdtar spell them differently.
        try:
            write_tarball(stage, name, tarball)
        except OSError:
            die("tar failed")
        with open(tarball + ".sha256", "w") as fh:
            fh.write("%s  %s\n" % (sha256_of(tarball), name + ".tar.gz"))
        print("release: wrote %s" % tarball)
        print("release: wrote %s.sha256" % tarball)
    finally:
        shutil.rmtree(stage, ignore_errors=True)


def write_tarball(stage, name, tarball):
    def sortkey(info):
        return info.name

    def scrub(info):
        info.uid = 0
        info.gid = 0
        info.uname = ""
        info.gname = ""
        return info

    members = []
    root = os.path.join(stage, name)
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for n in sorted(filenames) + sorted(dirnames):
            members.append(os.path.join(dirpath, n))
    members = [root] + sorted(members)
    with open(tarball, "wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as gz:
            with tarfile.open(fileobj=gz, mode="w", format=tarfile.GNU_FORMAT) as tf:
                for path in members:
                    arcname = os.path.relpath(path, stage)
                    tf.add(path, arcname=arcname, recursive=False,
                           filter=scrub)


def check(tarball):
    if not os.path.isfile(tarball):
        die("no archive '%s'" % tarball)
    base = os.path.basename(tarball)
    name = base[:-len(".tar.gz")] if base.endswith(".tar.gz") else base
    if name == base:
        die("'%s' is not a .tar.gz" % base)
    if not fnmatch.fnmatchcase(name, "afterschool-pascal-v*-*"):
        die("'%s' is not named afterschool-pascal-<tag>-<arch>.tar.gz" % base)

    # The digest first: it is what a downloader checks, and an archive whose
    # sidecar names another file or another hash is wrong before it is opened.
    sidecar = tarball + ".sha256"
    if not os.path.isfile(sidecar):
        die("no %s.sha256 beside the archive" % base)
    with open(sidecar, "r") as fh:
        text = fh.read()
    # `cut -d' ' -f1` over the whole file, then `$( )` strips the newlines.
    want = "\n".join(l.split(" ")[0] for l in text.split("\n"))
    want = want.rstrip("\n")
    got = sha256_of(tarball)
    if want != got:
        die("%s.sha256 says %s; the archive is %s" % (base, want, got))
    if not any(l.endswith(" " + base) for l in text.split("\n")):
        die("%s.sha256 names a file other than %s" % (base, base))

    work = tempfile.mkdtemp(prefix="release-check.",
                            dir=os.environ.get("TMPDIR") or "/tmp")
    try:
        try:
            with tarfile.open(tarball, "r:gz") as tf:
                tf.extractall(work, filter="tar")
        except Exception:
            die("could not unpack %s" % base)

        # One directory, named as the archive is. A tarball that unpacks into
        # the working directory, or into a directory named for another
        # release, is the kind of mistake a user meets first and a build log
        # never does.
        entries = len(os.listdir(work))
        if not (entries == 1 and os.path.isdir(os.path.join(work, name))):
            die("%s does not unpack into exactly one directory named %s"
                % (base, name))
        prefix = os.path.join(work, name)

        for f in ("LICENSE", "COPYING.RUNTIME", "README"):
            if not os.path.isfile(os.path.join(prefix, f)):
                die("%s does not carry %s" % (base, f))

        # The layout, and everything an installed compiler has to be able to
        # do, asked by the gate that already asks it (ADR-0244). Its own
        # message names the file or the step that failed.
        sys.stdout.flush()
        rc = subprocess.run([os.path.join(ROOT, "tests", "checks",
                                          "install_layout.py"),
                             "--prefix", prefix]).returncode
        if rc != 0:
            sys.exit(1)

        kind = link_kind(os.path.join(prefix, "bin", "pascalc"))
        if kind == "static":
            print("release: bin/pascalc is statically linked")
        elif kind == "dynamic":
            print("release: bin/pascalc is dynamically linked")
        else:
            print("release: no ldd here, so how bin/pascalc is linked is unknown")
        if os.environ.get("RELEASE_REQUIRE_STATIC") and kind != "static":
            die("RELEASE_REQUIRE_STATIC is set and bin/pascalc is %s" % kind)
        print("release: %s checks out" % base)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def notes(tag):
    if not tag.startswith("v"):
        die("a tag starts with 'v', not '%s'" % tag)
    version = tag[1:]
    changelog = os.path.join(ROOT, "CHANGELOG.md")
    # From the line after `## [X.Y.Z]` to the line before the next `## `.
    head = "## [" + version + "]"
    found = False
    body = []
    try:
        with open(changelog, "r") as fh:
            text = fh.read()
    except OSError:
        text = ""
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    for line in lines:
        if line.startswith("## ["):
            if found:
                break
            if line.startswith(head):
                found = True
                continue
        if found:
            body.append(line)
    out = "\n".join(body).rstrip("\n")
    if not "".join(out.split()):
        die("CHANGELOG.md has no section for %s; write one before tagging"
            % version)
    print(out)


def main(argv):
    mode = argv[1] if len(argv) > 1 else ""
    if mode == "--archive":
        if len(argv) - 1 < 3:
            die("usage: release.py --archive <build-dir> <tag> [<arch>] "
                "[<out-dir>]")
        archive(argv[2], argv[3],
                argv[4] if len(argv) > 4 else "",
                argv[5] if len(argv) > 5 else ".")
    elif mode == "--check":
        if len(argv) - 1 != 2:
            die("usage: release.py --check <archive.tar.gz>")
        check(argv[2])
    elif mode == "--notes":
        if len(argv) - 1 != 2:
            die("usage: release.py --notes <tag>")
        notes(argv[2])
    else:
        die("usage: release.py --archive <build-dir> <tag> [<arch>] "
            "[<out-dir>] | --check <archive> | --notes <tag>")


if __name__ == "__main__":
    main(sys.argv)
