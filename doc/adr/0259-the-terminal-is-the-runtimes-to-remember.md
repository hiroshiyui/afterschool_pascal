# 259. The terminal is the runtime's to remember

Date: 2026-08-30

## Status

Accepted. Adds `pasx_term_*` to `runtime/pasrt_posix.c`,
`lib/dialect/pasterm.pas`, `tests/dialect/lib_term.pas`, and two headers to
`tests/checks/nonstandard_c.txt`. Applies ADR-0185's fifth decision and
ADR-0186's split for the third time.

## Context

`doc/roadmap.md` has carried one row saying *nothing* for as long as it has
existed: no `termios`, no `isatty`, no raw key, no cursor, no window size. It
was the language server's prerequisite once and left with it when the judging
program became a server over stdio, and its shape had already been decided —
"a `pasx_` binding in `runtime/pasrt_posix.c` bounded by its headers,
`<termios.h>` joining ADR-0186's catalogue".

The reason it cannot be a library module alone is the one ADR-0185 wrote down
and ADR-0186 built the machinery for. `struct termios` is a layout that
differs between systems in a way worse than `struct stat` does: `c_cc` is
`NCCS` elements, which is 32 on Linux and 20 on macOS, and the *bit* each of
`ECHO`, `ICANON` and `ISIG` names differs as well as every offset. A module
carrying glibc's would not merely read a wrong number on another system — it
would `tcsetattr` a terminal into a state nobody asked for. `struct winsize`
is the same question a second time.

And neither standard reaches any of it. §6.11.4.2 gives a program `input` and
`output` and §6.4.3.6 makes them file-types; a file-type says nothing about
the device behind it, so whether a keystroke is echoed, whether it is held
until a newline, and how wide the window is have no answer in either standard
at all.

## Decision

### 1. Five `pasx_term_*` routines, and the state lives with them

`pasx_term_isatty`, `pasx_term_size`, `pasx_term_raw`, `pasx_term_restore` and
`pasx_term_raw_active`. Two headers join the catalogue: `<termios.h>` for the
first four, and `<sys/ioctl.h>` for the size.

`<sys/ioctl.h>` is the one entry in that catalogue naming something **no
standard defines**. POSIX has no window size; `TIOCGWINSZ` with `struct
winsize` is BSD-derived and universal, and the only alternative is the
`COLUMNS` environment variable, which is a shell's opinion recorded before the
window was last resized. It is named rather than argued away.

### 2. The saved settings are the runtime's, and there is one set

A caller cannot hold what `tcgetattr` answered — that is the whole reason this
section exists — so `pasx_term_raw` keeps it and `pasx_term_restore` puts it
back. `restore` takes **no descriptor**: the runtime knows which one it saved,
and a caller passing another would be asking to write one terminal's settings
onto a different one.

One slot and not a table. A second `pasx_term_raw` while one is outstanding
would save the *raw* settings as though they were the original, and the
restore after it would leave the user a shell with no echo and no interrupt
character. So it is refused (3, `errFull` above it) with nothing changed,
rather than counted.

### 3. The restore is registered with `atexit`

Raw mode is a property of the **terminal** and not of the process, so a
program that stops without restoring hands its user a shell whose only remedy
is `stty sane` typed blind. The handler is registered the first time raw mode
is entered — `--coverage`'s discipline (ADR-0104), so a program that never
asks pays nothing.

`halt`, a runtime error and an ordinary end of the program-block all reach
`exit` and so all reach it. `_exit`, `abort` and a fatal signal do not, and
nothing portable could make them: a signal handler would have to be
async-signal-safe and would still miss `SIGKILL`.

### 4. Cursor movement and clearing are **strings**, in Pascal

They are ANSI escape sequences — bytes written to a stream — and not system
calls, so C would have bought nothing and would have taken from the caller the
choice of *where* they go. `CursorTo`, `ClearScreen`, `ClearLine`,
`HideCursor` and `ShowCursor` answer a `TermSeq`, and
`write(output, ClearScreen)` and `PasIO.WriteText(StdOut, ClearScreen)` are
both right — which matters, because §6.10's buffered output and a descriptor
write interleave by whichever flushed last (PasIO's own limitation).

It is also what makes them checkable with no terminal, which is most of what
the test case can do.

### 5. `ReadKey` is `PasIO.ReadInto` of one byte, and no new binding

A raw key is not a further system call: it is `read` of a descriptor whose
line discipline is off. `PasTerm` imports `PasIO` rather than binding `read` a
second time — `PasIO` supplies `StdIn`, `StdOut` and the slice that says *one
byte* by its own length (ADR-0129).

## Consequences

- The roadmap's terminal row is answered in the shape it named. A program can
  now ask whether it is on a terminal, how big it is, and read a keystroke.
- **The test asserts the negative path, because ctest has no terminal.**
  `tests/dialect/lib_term.pas` runs with output redirected to a file and input
  from a sidecar, so it pins that `IsTerminal` is false, that `TermSize`
  answers `errAbsent` rather than a plausible number, that `EnterRaw` refuses
  and changes nothing, and that `LeaveRaw` on a terminal nobody entered is
  `errAbsent`. The escape sequences are compared byte for byte, rendered as
  ordinals so the golden holds no control character.
- **What no oracle here sees** (a `doc/sop.md` §7 row): that the flags cleared
  are the right ones, that a read then answers on one keystroke, that the
  settings put back are the settings taken, the `atexit` restore, a real
  window size, and the `errFull` arm — which needs a first `EnterRaw` to
  succeed and so cannot be reached without a terminal. All six were checked by
  hand under a pseudo-terminal while this landed: the size read 24×80, the
  second `EnterRaw` answered `errFull`, `LeaveRaw` answered `errNone` and then
  `errAbsent`, and a program that exited while raw left `stty` reporting
  `echo` and `icanon` back on. **A measurement taken once, by hand, and by
  nothing afterwards** — which is exactly the sentence ADR-0183 wrote about a
  leak, and the honest description of what this row is.
- `runtime/pasrt_posix.c` is now bounded by eight headers rather than six, and
  `runtime-isoc` prints the list.

## What this does not do

- **No terminfo.** A terminal that does not understand the sequences is
  neither detected nor accommodated. Reading a compiled database is a library
  and not a module, and every emulator in use understands them.
- **No colour**, which is the same sequences and can be added when a program
  needs one.
- **No `SIGWINCH`.** A signal has no shape in this language, so a program that
  redraws asks `TermSize` again.
- **No second terminal.** One saved state is one terminal; a program driving
  two is refused rather than served badly.
- **It adds no language feature and no clause.** Everything here is a library
  module over an `external` binding the dialect already admits (ADR-0121,
  ADR-0131), so `doc/afterschool-pascal-spec.md` is unchanged — there is
  nothing the compiler accepts today that it refused yesterday.

## Alternatives rejected

- **Let `lib/dialect/pasterm.pas` declare `struct termios` and call
  `tcgetattr` itself**, now that `foreign-layout` can check such a claim. The
  gate checks it on the machine you build on; a library has to work on
  machines nobody here builds on. That is ADR-0185 §5, and `termios` is its
  worst subject rather than a case for reopening it.
- **`cfmakeraw`.** Not POSIX, and invisible under the `_POSIX_C_SOURCE` this
  file is compiled with. The flags are written out instead, which is also the
  documentation of what raw mode means here.
- **A saved-state table keyed by descriptor.** It makes the second `EnterRaw`
  succeed, which is the case that must not: the failure it hides is a
  terminal left raw, and no program in this tree drives two.
- **Restoring from a `SIGINT`/`SIGTERM` handler as well as at exit.** It would
  need async-signal-safe state and would still miss `SIGKILL`, and installing
  handlers is a decision about the whole runtime rather than about this
  module. Raw mode clears `ISIG` anyway, so the interrupt character does not
  reach the process while it matters most.
- **Cursor and clearing in C.** No system call is involved, and it would fix
  the stream the bytes go to. See decision 4.
