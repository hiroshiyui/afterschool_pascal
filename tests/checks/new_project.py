#!/usr/bin/env python3
# Afterschool Pascal -- a Pascal compiler written in Pascal.
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
#
# Does a generated project build, run and test itself? (ADR-0348)
#
# **No test case can do this**, which is why it is a harness: every case in the
# corpus is one `.pas` file compiled where it sits, and what is asserted here is
# a *directory* the driver wrote, a config file it then read back, and three
# subcommands that only mean anything together. It is the same argument
# `long-path`, `bare-source-name` and `stale-component` are harnesses for.
#
# **The generated program must actually run**, not merely compile. A skeleton
# that a user's first command rejects is worse than no skeleton, and the
# generated `greet.pas` has already been wrong once: it ended `end.` where a
# module's routine ends `end;`, which no amount of reading the generator caught
# and one run did.
#
# ADR-0366's seventh conversion, from `new_project.sh` on 2026-09-08.
# The fourteen `sed` rewrites of the project file are a substitution over
# a string, so the `edit()` helper that existed only because BSD sed's
# `-i` takes a mandatory suffix is gone with them.
#
# Usage:  tests/checks/new_project.py [pascalcc]
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

CONFIG = "afterschool-pascal.toml"


class Fail(Exception):
    pass


def main():
    root = Path(__file__).resolve().parent.parent.parent
    driver = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "tools/pascalcc"

    with tempfile.TemporaryDirectory() as work:
        w = Path(work)
        demo = w / "demo"

        def run(*args, cwd=None):
            """The driver, with its output swallowed as `>/dev/null` did."""
            r = subprocess.run([str(driver), *args], cwd=str(cwd or w),
                               capture_output=True, text=True, errors="replace")
            return r.returncode == 0, (r.stdout + r.stderr).rstrip("\n")

        def edit(pattern, replacement, path):
            """One substitution over one file, anchored as the sed was."""
            path.write_text(re.sub(pattern, replacement.replace("\\", "\\\\"),
                                   path.read_text(), count=1, flags=re.M))

        def fail(what):
            raise Fail(what)

        try:
            # --- 1. the skeleton is written, and it is the layout decided ---
            if not run("new-project", "demo")[0]:
                fail("new-project failed")
            for f in (CONFIG, "src/demo.pas", "src/greet.pas", "test/demo.out",
                      ".gitignore", "README.md"):
                if not (demo / f).is_file():
                    fail(f"demo/{f} was not written")
            if not (demo / "build").is_dir():
                fail("demo/build was not made")

            cfg = demo / CONFIG

            # --- 2. it builds, runs and passes its own test ----------------
            #
            # `run` before `build`, deliberately: a user's first command is the
            # one that has to work, and it must not depend on having built.
            ok, out = run("run", cwd=demo)
            if not ok:
                fail("'run' failed on a fresh skeleton")
            if out != "Hello, world!":
                fail(f"'run' printed '{out}'")
            if not run("build", cwd=demo)[0]:
                fail("'build' failed")
            if not os.access(demo / "build/demo", os.X_OK):
                fail("'build' wrote no executable")
            if not run("test", cwd=demo)[0]:
                fail("'test' failed on a fresh skeleton")

            # --- 3. the config is found from a subdirectory ----------------
            if not run("test", cwd=demo / "src")[0]:
                fail("'test' failed from src/")

            # --- 4. and the test subcommand can *fail* ---------------------
            (demo / "test/demo.out").write_text("something else\n")
            if run("test", cwd=demo)[0]:
                fail("'test' passed a wrong golden")
            (demo / "test/demo.out").write_text("Hello, world!\n")

            # --- 5. the reader refuses what it does not understand ---------
            kept = cfg.read_text()
            for bad in ('outupt = "x"', "[deps]", "opt = 2", 'stray = "x"'):
                extra = '[deps]\nk = "v"\n' if bad == "[deps]" else bad + "\n"
                cfg.write_text(kept + extra)
                if run("build", cwd=demo)[0]:
                    fail(f"the reader accepted: {bad}")
            cfg.write_text(kept)

            # --- 6. a link flag in the config reaches the link -------------
            edit(r"^# ldflags.*", 'ldflags = ["-lm"]', cfg)
            if not run("build", cwd=demo)[0]:
                fail('ldflags = ["-lm"] did not link')
            edit(r"^ldflags.*", 'ldflags = ["-lnosuchlibraryanywhere"]', cfg)
            if run("build", cwd=demo)[0]:
                fail("a bogus ldflag still linked")
            edit(r"^ldflags.*", "# ldflags = []", cfg)

            # --- 6b. and so do the other two keys that reach a tool --------
            edit(r"^# cflags.*", 'cflags = ["-nosuchclangflaganywhere"]', cfg)
            if run("build", cwd=demo)[0]:
                fail("a bogus cflag still compiled")
            edit(r"^cflags.*", "# cflags = []", cfg)

            edit(r"^# target.*", 'target = "nosucharch-unknown-none"', cfg)
            if run("build", cwd=demo)[0]:
                fail("a bogus target still built")
            edit(r"^target.*", '# target = ""', cfg)

            if not run("build", cwd=demo)[0]:
                fail("the project stopped building after 6b")

            # --- 7. the reader is TOML, and not a subset of it (ADR-0361) --
            edit(r"^# ldflags.*",
                 'ldflags = ["-Wl,-rpath,/nosuchdir", "-lm"]', cfg)
            if not run("build", cwd=demo)[0]:
                fail("a comma inside a quoted ldflag did not link")
            edit(r"^ldflags.*",
                 'ldflags = ["-Wl,-rpath,/nosuchdir", '
                 '"-Wl,--no-such-linker-option,x"]', cfg)
            if run("build", cwd=demo)[0]:
                fail("the second element of an ldflags list never reached the "
                     "link")
            edit(r"^ldflags.*", "# ldflags = []", cfg)

            edit(r"^output .*", 'output      = "build/demo#1"', cfg)
            if not run("build", cwd=demo)[0]:
                fail("a # inside a quoted output path did not build")
            if not os.access(demo / "build/demo#1", os.X_OK):
                fail("the # in build/demo#1 was cut off the path")
            edit(r"^output .*", 'output      = "build/demo"', cfg)

            edit(r"^opt .*", "opt         = 2", cfg)
            if run("build", cwd=demo)[0]:
                fail("build.opt = 2 was accepted")
            edit(r"^opt .*", 'opt         = "-O2"', cfg)

            # And a refusal names a column as well as a line, which is the
            # whole of what a real parser has over a line-at-a-time one.
            kept = cfg.read_text()
            cfg.write_text("[build]\nopt = \n")
            msg = run("build", cwd=demo)[1]
            if f"{CONFIG}:2:7:" not in msg:
                fail("a syntax error did not name its line and column: " + msg)
            cfg.write_text(kept)
            if not run("build", cwd=demo)[0]:
                fail("the project stopped building after 7")

            # --- 8. a subcommand is a position, not a word -----------------
            #
            # ADR-0140's rule for a command line: `build.pas` is a source file
            # and must go on compiling, or the feature has taken a name away
            # from every user.
            (w / "build.pas").write_text((demo / "src/demo.pas").read_text())
            (w / "greet.pas").write_text((demo / "src/greet.pas").read_text())
            if not run("build.pas", "-o", "built")[0]:
                fail("a file named build.pas stopped compiling")
            r = subprocess.run(["./built"], cwd=str(w), capture_output=True,
                               text=True, errors="replace")
            if r.stdout.rstrip("\n") != "Hello, world!":
                fail("build.pas ran wrongly")
        except Fail as e:
            print(f"new-project: {e}", file=sys.stderr)
            return 1

    print("new-project: a generated project builds, runs and tests itself, "
          "and the reader reads TOML rather than a subset of it")
    return 0


if __name__ == "__main__":
    sys.exit(main())
