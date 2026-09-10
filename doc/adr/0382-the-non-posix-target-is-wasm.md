# ADR-0382: The non-POSIX target is WebAssembly

## Status

Accepted. Re-points `runtime-nonposix` and its catalogue from mingw-w64 to
`wasm32-wasi`, and generalises the gate's toolchain from a program to a
command. Follows [ADR-0369](0369-a-port-is-measured-or-it-is-an-estimate.md),
which anticipated exactly this, and
[ADR-0380](0380-the-target-is-posix.md), which made it necessary.

## Context

ADR-0369 built a gate that asks whether the runtime is still portable to a
target that is **not POSIX**, and measured it against the only such toolchain
Debian packages. Its own *Alternatives* section named what would come next:

> **One target.** mingw-w64 is the non-POSIX platform available here, and the
> catalogue is keyed on nothing else. A second — a bare-metal or a **wasi**
> toolchain — would need the catalogue to grow a column, and the argument for
> doing that is a port somebody wants rather than symmetry.

There is now a port somebody wants. WebAssembly is where this project is
going, ADR-0380 dropped Windows, and the question the gate asks was never
about Windows: it is whether `runtime/*.c` still depends only on what each
unit is *allowed* to depend on, and it needs some non-POSIX toolchain to ask
with.

## Decision

**`wasm32-wasi` is the column**, and the catalogue is rewritten from what it
answers. The mingw-w64 measurements are not lost — they are in
`doc/history.md` with the rest of the Windows work.

**The toolchain is a command and not a program.** A non-POSIX cross compiler
arrives in two shapes: a driver of its own, which is what mingw-w64 is, and a
`--target=` handed to the clang that is already installed, which is how wasi
and every other LLVM target is reached. `APASCAL_NONPOSIX_CC` is split on
blanks; `which` asks about the first word. One line, and it is what let this
change be made at all.

**Two flags are part of the command and both are load-bearing.**

- `-mllvm -wasm-enable-sjlj`, because without it wasi-libc's `<setjmp.h>`
  refuses outright — *"Setjmp/longjmp support requires Exception handling
  support"* — and `pasrt.c` would be catalogued blocked by a header that a
  build flag satisfies, **with the real blocker hidden behind it**. That is
  `doc/sop.md` §7's own row about the status being one bit, met before it
  could do any damage.
- `-nostdlibinc -isystem /usr/include/wasm32-wasi`, because `/usr/include` is
  on clang's search path for this target: a header wasi-libc has not got and
  glibc has would be **found, and reported present**. That is ADR-0345's
  lesson — a gate answering about the wrong machine — in a second place.

## Consequences

**Two of four units compile, and the two that do are the interesting half.**

| Unit | wasm32-wasi | mingw-w64, before |
| --- | --- | --- |
| `pasrt_unicode.c` | compiles | compiled |
| `pasrt_task.c` | **compiles** | wanted `-D_UCRT` |
| `pasrt.c` | blocked: `_longjmp` | blocked: `_longjmp` |
| `pasrt_posix.c` | blocked: 5 of 17 headers | blocked: 7 of 17 headers |

**The finding is `_longjmp`, and it is the second target in a row to lack
it.** mingw-w64 declares `longjmp` and no `_longjmp`; wasi-libc does the same.
ADR-0373 bought that row with the runtime's only preprocessor conditional and
ADR-0380 bought the conditional back by dropping the platform that needed it —
so the honest statement is that **the non-local goto is what stands between
this runtime and a non-POSIX target**, now measured twice. A wasm port pays
for it either with the conditional again or with the tidier shape ADR-0373
named: the jump emitted by the compiler, where `_setjmp` already is, which
waits on a reseed because the committed seed declares and calls
`@pas_jump_go`.

**`pasrt_task.c` compiling is not the good news it looks like.** This gate's
whole claim is `-fsyntax-only`, and wasi-libc ships a `<pthread.h>` whose
declarations are there whether or not a thread can be created. What the row
says is that nothing in *this source* stands in the way of AP 6.4.16's
channels; a port learns the rest by linking. The catalogue says so where a
reader will meet it.

**The port's shape is different from Windows'.** `<poll.h>`, `<sys/socket.h>`
and `<sys/ioctl.h>` are all present — wasi has a socket API of its own — while
`<spawn.h>` and `<sys/wait.h>` are absent because there are no processes at
all, and `<signal.h>` and `<termios.h>` because there is no terminal and no
signal. So `PasProcess.Execute` has nothing to be implemented over, and
`PasNet` would need whatever wasi calls name resolution. Which of those a
first port ships is the open question, and one that ships neither is much
smaller than *port `pasrt_posix.c`*.

**Two warnings the exit status does not carry**, both recorded in the
catalogue: `tmpfile` is *deprecated on WASI* at three sites — §6.7.5.5's
auxiliary file and the two scratch files — so that unit would compile and fail
at run time; and the SjLj flag above is what makes `<setjmp.h>` usable at all.

**And the gate's diagnostic echo learned to skip the warnings.** It shows the
first three lines of a blocked unit's output; under this toolchain the first
three are `tmpfile` deprecations, and a reader shown those learns nothing. It
now starts at the first line saying `error`. Display only — the claim still
rests on the exit status alone.

## Alternatives rejected

**Keep mingw-w64 and add wasi as a second column.** The catalogue would then
hold two answers per unit and every row would need a target beside it, for a
platform this project has dropped. ADR-0369 costed that as *the argument for
doing it is a port somebody wants*, and nobody wants Windows here now.

**Point it at wasi without the isolation flags.** Simpler, and it answers
about glibc for any header wasi lacks and the host has. Every answer was taken
both ways and none differed today — glibc's copies fail on their own `bits/`
internals — but *it happens not to bite* is not a claim, and the diagnostic is
honest with them: `'netdb.h' file not found` rather than a failure inside
`/usr/include/netdb.h`.

**Leave the SjLj flag off and catalogue what that reports.** It would be a
true row and a shallower one, and the gate's own §7 row says why that is bad:
one bit per unit means a second blocker hides behind the first. Here the
hidden one is the finding.
