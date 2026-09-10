# ADR-0382: The non-POSIX target is WebAssembly

## Status

Accepted. **Its headline finding is corrected by
[ADR-0383](0383-a-word-size-does-not-decide-a-layout.md)**: `pasrt.c` is not
blocked on `_longjmp` — wasi-libc declares it, behind `_XOPEN_SOURCE`, and
this gate was compiling with `-std=c11` where the build uses `-std=gnu11`.
Read the table below with that record beside it. Re-points `runtime-nonposix` and its catalogue from mingw-w64 to
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

**Three flags are part of the command and every one is load-bearing.**
The third was added the day after this record, and its argument is the
other two's — see *What the first CI run found* below.

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

**One of four units compiles, and what blocks the other three is three
different kinds of thing.**

| Unit | wasm32-wasi | mingw-w64, before |
| --- | --- | --- |
| `pasrt_unicode.c` | compiles | compiled |
| `pasrt_task.c` | blocked: no threads | wanted `-D_UCRT` |
| `pasrt.c` | blocked: `_longjmp` | blocked: `_longjmp` |
| `pasrt_posix.c` | blocked: 5 of 17 headers | blocked: 7 of 17 headers |

The `pasrt_task.c` row read `compiles` when this record was written, measured
on one machine. It was wrong, and *What the first CI run found* below is how.

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

**`pasrt_task.c` compiling was not the good news it looked like, and then it
turned out not to be true either.** The caution written here was that this
gate's whole claim is `-fsyntax-only` and wasi-libc ships a `<pthread.h>`
whose declarations are there whether or not a thread can be created — so the
row said only that nothing in *this source* stands in the way of AP 6.4.16's
channels. The caution was right and too gentle: on the sysroot CI installs,
the header does not declare them at all.

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

## What the first CI run found

The push carrying this record turned four jobs red, and the three defects
behind them are worth more than the catalogue was.

**The gate failed where it should have skipped, on every ordinary job.** With
mingw-w64 the toolchain was a driver of its own, so `which` answered the whole
question: a machine without the cross compiler skipped, and a machine with the
driver but no runtime package was half-installed and worth failing on.
`clang --target=wasm32-wasi` is a command whose first word is on *every*
machine that builds this compiler, so `which` says yes everywhere and the
sysroot became the only thing separating a machine that can be asked from one
that cannot — and that state returned 1. The three container jobs and macOS
went red on a gate reporting about a machine. It now skips there, which is
what `NONPOSIX_REQUIRE` in the `non-posix` job exists to make safe (ADR-0330).
**The decision to make the toolchain a command is what carried this in**: the
presence test was written for the other shape and nothing here re-asked it.

**The one failure a reader needed explained was the one the gate would not
explain.** The diagnostic echo fired for a unit the *catalogue* called
blocked, so a unit catalogued `compiles` that had stopped — the exact shape of
`the port went backwards` — printed no reason. CI said `pasrt_task.c` had gone
backwards and nothing else, and the reason had to be reproduced in a container
to be read. Twice now that arm has been written to serve a reader and not done
it; before this it compared a pair against a string and had never printed
anything at all. It now shows every unit that fails.

**And `pasrt_task.c` is blocked on threads, which one machine could not have
told us.** Debian trixie's wasi-libc refuses `pthread_create` with a static
assertion — *"This mode of WASI does not have threads enabled"* — and the
newer one on the machine this was measured on declares it unless
`_WASI_STRICT_PTHREAD` is defined, whereupon it says the same thing in its own
words: *"This function is not available on a single-threaded target"*. One row
cannot be true of both, so the macro joins the command, and both sysroots now
print the same summary line. The substance is the one the caution above
gestured at: wasm32-wasi without the threads proposal cannot create a thread,
and a permissive header plus `-fsyntax-only` would have reported this
language's whole concurrency facility as portable to a platform that cannot
run it.

So what a port pays is a name (`_longjmp`), a set of headers, and a target
capability — three kinds of thing and no single change that closes them.
