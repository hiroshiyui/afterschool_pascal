# ADR-0405: A question is not an action

## Status

Accepted. Splits the unit [ADR-0186](0186-the-runtime-has-a-posix-half-and-a-catalogue-that-holds-only-functions.md)
created, and is the first piece of ADR-0385's wasm32 work queue to be worked.

## Context

`runtime/pasrt_posix.c` was one translation unit holding everything the
runtime needs POSIX *types* for. `runtime-nonposix` (ADR-0369) reports it
**blocked** for `wasm32-wasi`, wanting five headers wasi has not got —
`<netdb.h>`, `<signal.h>`, `<spawn.h>`, `<sys/wait.h>`, `<termios.h>` — and a
missing header is a fatal error, so none of the unit is built and **every**
`pasx_` routine in it is undefined for that target.

`tests/checks/wasm32_known.txt` then carries sixteen corpus cases under one
heading, and the heading is the finding:

> `runtime/pasrt_posix.c` wants five headers wasi has not got, so none of it
> is built and every `pasx_` routine is undefined.

Sixteen cases blocked, and what the target actually lacks is processes,
sockets, a terminal and name resolution. It has a perfectly good file system.
`PasFs.Info`, `PasDir`'s walk and `PasIo.FdReady` were blocked by nothing but
sharing a file with `posix_spawn`.

ADR-0369 already named the shape: *a system without those headers loses
library routines and not the language*. The unit was the granularity at which
that promise is kept, and it was too coarse.

## Decision

**Two units, and the cut is a rule: a question is not an action.**

`runtime/pasrt_file.c` asks the operating system about a file or a descriptor
that already exists and answers — how big is it, what kind, what is in this
directory, is there anything to read yet. `runtime/pasrt_posix.c` keeps
everything that makes the machine *do* something: start a process, open a
socket, put a terminal into raw mode, make a private directory.

**The rule came first and portability agrees with it, which is the order that
matters.** A unit defined as *what wasi happens to have* is a unit that has to
be re-cut for the next target, and ADR-0369 says so about catalogues. Two
places where the rule and the target disagree were decided by the rule, and
both are worth recording because each looks like an oversight:

- **`pasx_temp_dir` stayed on the action side.** Making a private directory is
  an act, and `mkdtemp` is the POSIX primitive that performs it — and it is
  undeclared for wasi, so this is the rule costing the split a routine it
  might have had. Writing a `mkdtemp` out of `mkdir` was considered and
  refused: ADR-0363 put that routine here for a *security* reason, and
  reimplementing an unpredictable-name loop to win one corpus case is the
  wrong trade.
- **`pasx_term_isatty` stayed with the terminal**, though it compiles for wasi
  and the rest of the terminal does not. *Is this a terminal* is a question,
  but it is a question about a terminal; separating it from `pasx_term_size`
  for one target's convenience would leave `PasTerm` split across two units
  for no reason a reader could reconstruct. It buys nothing either way —
  **`pasx_term_size` does not compile for wasi at all**, and the reason is the
  lesson: wasi-libc *ships* `<sys/ioctl.h>` and has no `struct winsize` and no
  `TIOCGWINSZ`. A header being present is not the target having the thing, and
  that was measured with a probe rather than read off the catalogue.

**One call crosses the cut and goes through a header.** `pasx_exec_getc` waits
on a child's pipe, and waiting on a descriptor is a question about a
descriptor. `runtime/pasrt_file.h` declares `pasx_fd_ready` and both units
include it — not a prototype written beside the caller, because C checks a
call against whatever declaration is in scope and the linker checks only the
name, so a prototype can disagree with its definition and nothing says so.
It is the runtime's first internal header for a `pasx_` routine, every one of
them having been bound from Pascal by name and declared in C nowhere.

**Each unit is bounded separately.** `runtime-isoc` held `pasrt_posix.c` to a
catalogue of headers in both directions; it now does that per unit, and the
catalogue row says which — `header: pasrt_file.c <dirent.h>`. A header both
units include takes **a row each**, because what a unit may depend on is a
claim about that unit: with one shared row, striking the last use in one of
them would be silent.

## What it cost and what it moved

Nothing in the gated half of `runtime-coverage` moved — 301 uncovered of 2240
before and after — which is the arithmetic saying the cut was clean: every
line that moved is in a unit that is reported rather than gated.
`pasrt_file.c` joins that set, and for `pasrt_posix.c`'s own reason:
`pasx_fd_ready` polls with a timeout, so which of its arms runs is a property
of how loaded the machine is (ADR-0354).

`runtime-nonposix` now says **3 of 5 translation units compile** for
`wasm32-wasi`, where it said 2 of 4. Which corpus cases that moves is not
recorded in this commit, and deliberately: no engine runs a `.wasm` on the
machine this was written on, and `wasm32.py` abstains here. **The catalogue
fails in both directions, so CI will report the progress and refuse to let it
go unrecorded** — which is the mechanism `wasm32_known.txt`'s own header
describes finding the `owned.pas` rows with. The rows move in the commit that
reads CI's answer, and not from a guess taken here.

## What this does not do

It does not make wasi grow processes, sockets or a terminal. Those are
ADR-0382's question and the larger half of the port; `pasrt_posix.c` is as
blocked as it was and the catalogue's heading for it is now accurate rather
than over-broad.

It does not touch `pasrt_task.c`, which is blocked on the target having no
threads — a whole facility and not a header, and nothing a cut can reach.

It does not add a preprocessor conditional, and could not: the runtime holds
none and `runtime-isoc` compares that against an empty catalogue in both
directions. **The split is the mechanism this tree has instead**, which is
what ADR-0186 decided and what makes a unit's header list mean something.
