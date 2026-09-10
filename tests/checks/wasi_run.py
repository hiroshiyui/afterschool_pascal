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

"""Start a `.wasm` under a WASI engine, with the environment it needs.

**A WASI program is given nothing it is not handed** -- no directory and no
environment -- and *how* an engine is told differs per engine. That is why
this exists rather than a runner command in `wasm32.py`: `AFTERSCHOOL_PASCAL_RUNNER`
is a fixed prefix (ADR-0384) and the environment it must pass on is the one
`tests/run_test.py` built for **this case**, which the gate that set the
prefix never saw. A `.epoch` sidecar is the plain example: the case reads
`SOURCE_DATE_EPOCH` and prints 2001, and without it prints today.

Four variables are forwarded and the list is not a guess: it is every name
`runtime/*.c` passes to `getenv`, and `wasm32.py` compares the two in both
directions, so a fifth added to the runtime fails there rather than going
quietly missing on this target.

  APASCAL_WASM_ENGINE   the engine, blanks and all. The default names
                        `wasmedge`, which Debian trixie packages -- the image
                        the wasi sysroot is pinned to, and the answers must be
                        one toolchain's (ADR-0382).

Usage:  wasi_run.py <program.wasm> [args...]
"""

import os
import sys

# Every name `runtime/*.c` reads. `wasm32.py` holds this against the runtime.
FORWARD = ("PASCOV_BRANCHES", "PASCOV_LINES", "PASHEAP_BALANCE",
           "SOURCE_DATE_EPOCH")

# `--dir /:/` because a case is handed two scratch paths as arguments and a
# WASI program reaches no directory it was not granted.
DEFAULT_ENGINE = "wasmedge --dir /:/"


def main(argv):
    if not argv:
        print("usage: wasi_run.py <program.wasm> [args...]", file=sys.stderr)
        return 2
    engine = (os.environ.get("APASCAL_WASM_ENGINE") or DEFAULT_ENGINE).split()
    env = []
    for name in FORWARD:
        if name in os.environ:
            env += ["--env", "%s=%s" % (name, os.environ[name])]
    os.execvp(engine[0], engine + env + list(argv))


sys.exit(main(sys.argv[1:]))
