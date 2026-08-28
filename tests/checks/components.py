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


def translate(root, target=None):
    """The arguments that translate one component: every component before it
    as an `--import`, then the component itself. Defaults to the program."""
    paths = sources(root)
    names = [p.name for p in paths]
    at = names.index(target or PROGRAM)
    argv = []
    for p in paths[:at]:
        argv += ["--import", str(p)]
    return argv + [str(paths[at])]
