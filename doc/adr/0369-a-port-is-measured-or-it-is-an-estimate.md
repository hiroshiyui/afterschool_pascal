# ADR-0369: A port is measured, or it is an estimate

## Status

Accepted. Adds `tests/checks/runtime_nonposix.py`, its catalogue
`tests/checks/nonposix_headers.txt` and the `non-posix` CI job; closes
`doc/sop.md` §7's row saying every target the tree compiles the runtime for is
`*-linux-gnu`.

## Context

`doc/roadmap.md` opens with a sentence this project has paid for: **a row
saying a feature is blocked is a row nobody has tried.** Its inventory of what
a daily program could not reach for is empty, and what it keeps in its place is
that lesson — two of its eight rows said why they were blocked and both reasons
were wrong.

On 2026-09-09 the Windows row became the fourth instance. Measured against
Debian's `x86_64-w64-mingw32-gcc`, it was wrong in **both** directions:
`_Complex` and `access` were named as problems and are not, while a socket
layer nobody had costed was not named at all. The row was rewritten as a
report.

**But a report taken by hand once is an estimate again the next morning.**
Nothing in this tree repeats that measurement. `target-sizes` builds
`runtime/*.c` for nine triples and every one of them is `*-linux-gnu`, so the
whole cross-platform apparatus here asks about *word size and alignment* and
never about whether the headers are there at all. A POSIX call added to
`runtime/pasrt.c` tomorrow would pass every gate in this repository.

`runtime-isoc` is the neighbour and it is not this. It bounds each translation
unit by the headers it **may** include — `pasrt.c` to ISO C plus a catalogue of
function names, `pasrt_posix.c` to eleven catalogued headers, `pasrt_task.c` to
`<pthread.h>` alone. Every one of those is a claim about *this source*, checked
by a compiler that has all of them. Whether a platform without them exists, and
what it does with this source, is a different question and no gate asked it.

**And the hand measurement had a defect of its own that a gate can fix.** A
missing header is a *fatal* error: the compile stops. So
`x86_64-w64-mingw32-gcc -c runtime/pasrt_posix.c` reports `netdb.h` and nothing
else, and the roadmap row had to say so — *"the compile stops at the first
missing header, so the rest of its 1 177 lines was never reached"*. A number
that is explicitly a floor is the weakest kind of report.

## Decision

**Compile the runtime for a target that is not POSIX, on every push, and hold
the result in a catalogue that fails in both directions.**

`tests/checks/runtime_nonposix.py` makes two claims against
`tests/checks/nonposix_headers.txt`:

1. **every translation unit's status** — `compiles` or `blocked`;
2. **for each unit, the exact set of its headers the target has not got.**

Four failures, not one: a unit that stops compiling, a unit that starts, a
header that goes missing, and a header that arrives. That is `verify/`'s
`KNOWN_GAP` rule (ADR-0013) applied to a port — progress must be *recorded*, so
closing a blocker is a commit that edits the catalogue.

**Each `#include <...>` is probed on its own**, one one-line translation unit
per header. That is the whole reason this is worth more than re-running the
hand measurement: it turns the floor into a list. `pasrt_posix.c` names
seventeen headers; seven are absent and ten are present, and the compile could
only ever have told us about `netdb.h`.

**It reads no diagnostic text.** A unit's status is an exit status and a
header's presence is an exit status. The compiler is run under `LC_ALL=C` and
the first three lines of a failure are printed for a reader, but no claim rests
on them — ADR-0366 found several gates whose *findings* were partly facts about
whose machine ran them, GNU tools reporting in the operator's locale.

It skips (77) without a cross compiler, and the `non-posix` CI job sets
`NONPOSIX_REQUIRE` so it cannot pass by skipping there (ADR-0330).

## What it found on its first run

The measurement the gate now holds, and it is not what the roadmap row said:

| Unit | For `x86_64-w64-mingw32-gcc` |
| --- | --- |
| `pasrt.c` | blocked, and every header it names is present — `_longjmp`, `fmemopen`, `open_memstream` |
| `pasrt_posix.c` | blocked, **seven headers absent of the seventeen it names** |
| `pasrt_task.c` | blocked, and every header it names is present, `<pthread.h>` included — `timespec_get`/`TIME_UTC`, which mingw makes `#ifdef _UCRT`, so a CRT choice |
| `pasrt_unicode.c` | **compiles**, which is the whole of AP 6.4.15 |

**The seven are the finding, and so are the ten.** Absent: `netdb.h`, `poll.h`,
`spawn.h`, `sys/ioctl.h`, `sys/socket.h`, `sys/wait.h`, `termios.h`. Present:
`dirent.h`, `errno.h`, `fcntl.h`, `signal.h`, `stdio.h`, `stdlib.h`,
`string.h`, `sys/stat.h`, `time.h`, `unistd.h`.

So what a non-POSIX target has not got is **sockets, the terminal and
`posix_spawn`** — and *not* the directory walk, the file information or the
file model. That changes the shape of the Windows question from "port
`pasrt_posix.c`" to "does a first Windows target ship `PasNet` at all", which
is a decision rather than a body of work, and it is a fact now rather than a
reading. `<pthread.h>` being present is the other half of it: AP 6.4.16's
channels and AP 6.9.3.12's tasks are not what blocks a port.

## Consequences

**A port stops being a paragraph.** `doc/roadmap.md`'s Windows row can now cite
a gate, and the number in it moves when the runtime does.

**Progress costs a commit.** Writing the two `FILE*`-over-memory functions
`pasrt.c` needs will make it compile, and the gate will fail until the row says
`compiles`. That is intended and is the same bargain `target32_known.txt` and
`verify/`'s `KNOWN_GAP` strike.

**It does not say the runtime *works* there.** Nothing here links, and nothing
runs a Windows binary — `-fsyntax-only` is the whole of the claim. A unit that
compiles may still be wrong about a width, which is `foreign-width`'s and
`target-layout`'s question and is asked of Linux triples only.

**One bit per unit.** A unit blocked for a *new* reason while still blocked for
an old one is invisible: the status is `blocked` either way, and the names
inside a present header are not catalogued the way `runtime-isoc` catalogues
them. That is a row in `doc/sop.md` §7 rather than a thing this closes.

**One target.** mingw-w64 is the non-POSIX platform available here, and the
catalogue is keyed on nothing else. A second — a bare-metal or a wasi
toolchain — would need the catalogue to grow a column, and the argument for
doing that is a port somebody wants rather than symmetry.

## Alternatives rejected

**Re-run the hand measurement before each release.** That is what
`doc/roadmap.md` already documents, and the reason this record exists is that
it aged in a day. A measurement nobody repeats is a sentence.

**Add mingw-w64 to `target-sizes`' nine triples.** Wrong gate: that one asks
whether `PAS_FILE_SIZE` and `PAS_JUMP_SIZE` are big enough, which requires the
unit to *compile* first — it would report a missing header as a size failure,
which is exactly the confusion ADR-0155's own job comment records for a missing
`libc6-dev-*-cross`.

**Parse the compiler's diagnostics for the missing names.** It would catalogue
`_longjmp` and `fmemopen` as well as the headers, and it would rest every claim
on a wording that changes with the compiler's version and the operator's
locale. `runtime-isoc`'s mechanism — probe, do not parse — is the house style
and is why the header claim is one probe per header.

**Make it a `package`-time or tag-time job.** ADR-0282's finding, twice over: a
piece of automation that runs only at a tag has nowhere to be exercised first,
and both times it was broken when it finally ran.
