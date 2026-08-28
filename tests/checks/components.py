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

"""Where the compiler's own sources are, and in what order they translate.

The compiler is three ISO/IEC 10206:1991 6.13 program-components (ADR-0233):
`aptypes.pas` imports nothing, `apfront.pas` imports it, and `compiler.pas`
holds the main-program-block and imports both. Half a dozen gates here have to
name that -- some read the text of "the compiler", some run the compiler over
its own source -- and a build order written out six times is a build order that
will disagree with itself the first time a fourth component is added.

`--import` names the *source* of a component already translated: 6.11.1 puts
the whole interface in the module-heading, so there is no other artefact for
one (ADR-0079).
"""

import pathlib

_HERE = pathlib.Path(__file__).resolve()
_LIST = _HERE.parents[2] / "selfhost" / "compiler.components"


def _read():
    """The list, from the sidecar the harnesses already read.

    `selfhost/compiler.components` is an ordinary 6.13 component list -- the
    same file `tests/run_test.sh` and `selfhost/irtest.sh` read for a test case
    -- so the build order is written down once and the compiler's own build is
    not a special case of anything. CMake reads it too."""
    names = [line.split()[0] for line in _LIST.read_text().splitlines()
             if line.strip()]
    return tuple(names) + ("compiler.pas",)


# In dependency order, which is also the order they must be translated in.
COMPONENTS = _read()

# The one that holds the main-program-declaration, and so the one a translation
# of the whole compiler is *of*.
PROGRAM = COMPONENTS[-1]


def sources(root):
    """Every component's path, in dependency order."""
    root = pathlib.Path(root)
    return [root / "selfhost" / name for name in COMPONENTS]


def text(root):
    """The three sources concatenated, for a gate whose question is about the
    compiler rather than about a file. Nothing here is line-addressed across
    the join; a gate that reports a position walks `sources()` itself."""
    return "\n".join(p.read_text() for p in sources(root))


def imports(root, target=None):
    """The `--import` arguments one component's translation needs: every
    component before it in dependency order. Defaults to the program."""
    paths = sources(root)
    names = [p.name for p in paths]
    at = names.index(target or PROGRAM)
    argv = []
    for p in paths[:at]:
        argv += ["--import", str(p)]
    return argv


def translate(root, target=None):
    """The arguments that translate one component: its imports, then the
    component itself. Defaults to the program."""
    paths = sources(root)
    names = [p.name for p in paths]
    at = names.index(target or PROGRAM)
    return imports(root, target) + [str(paths[at])]
