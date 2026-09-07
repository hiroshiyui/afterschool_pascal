# ADR-0363: A boundary answers; it does not stop

Date: 2026-09-07

## Status

Accepted. Closes the six findings of the `security-audit` run over ADR-0362 on
the day it landed. Adds `PasProcess.Deadline` and `PasFS.TemporaryDirectory`,
`pasx_argv_deadline` and `pasx_temp_dir` to `runtime/pasrt_posix.c`, the mode
letter `e` to every `fopen` in `runtime/pasrt.c`, and a private scratch
directory to `lsp/pasls.pas`. Adds nothing to the language.

## Context

ADR-0362 replaced a shell command with an argument vector and was audited the
same afternoon. Every one of the six findings was reproduced by a probe before
it was written down, and four of the six were **pre-existing** — reached by
the audit because the new routine made them a library's business rather than
one program's.

1. A path holding `chr(0)` — JSON spells it with the `u` escape for code point
   zero — **stopped the language server**: `runtime error: a string crossing
   to a foreign routine contains a NUL character at
   lib/dialect/pasfs.pas:296:23`, and the request after it was never answered.
   ADR-0122's trap is the right answer for a program's own value and the
   wrong one for a value that came from outside.
2. `ExecuteToFile` **followed a symbolic link** at the dump path (`victim`
   overwritten through `link.out`), and `pasls` composed that path as
   `$TMPDIR/pasls-<pid>.uses` — a name anyone sharing the directory can
   compose first and plant a link at. ADR-0242's pid kept two servers apart;
   it kept nobody else out.
3. **No `Execute` had a deadline.** A grandchild holding the pipe stalled
   `ExecuteInto` for its whole life: `sleep 3 &` cost three seconds.
4. **The child inherited every open descriptor** of the parent, seen from
   `ls /proc/self/fd` in a spawned shell.
5. Three `posix_spawn_file_actions_*` **return values were unchecked**: an
   action that could not be recorded was a child running with its streams
   where they were, a dump on the terminal, and a stale file read back as the
   answer, `ok = true`.
6. `fdopen` **failing dropped the output silently**, the status right and the
   text gone.

## Decision

**A library routine that takes a value from outside answers with a code; the
trap is for the program's own mistakes.** Six changes, one rule.

1. **`chr(0)` is `errSyntax` at the routine** — `AddArg`, `ExecuteToFile` —
   and `pasls`'s `PathArg` refuses such a path before any boundary is crossed,
   so the server reports the argument unusable and goes on. The trap stays
   where it is: it is what makes the *next* such routine visible.
2. **`O_NOFOLLOW` on the dump**, one flag, because the name is one the program
   composed and a link planted there is not what it composed. And **a private
   directory for `pasls`**: `PasFS.TemporaryDirectory` over `mkdtemp`, the
   document and everything composed beside it inside, taken away at `exit`.
   `TemporaryPath` could not do this — it makes one *file* exclusively, and the
   `.ll`, `.uses` and `.fmt` composed beside it are names again. **The fallback
   when no directory can be made is a path nothing can create**,
   `/dev/null/doc.pas`: not the old top-level name, which is the hazard back
   under a different condition, and not a name inside a directory that might
   exist after all, which is the same hazard one step in. The server then
   says so per document, exactly as it does for an unwritable `PASLS_SCRATCH`.
3. **`Deadline(v, seconds)`**, a property of the vector so that five runs need
   not each take it. On expiry the child is killed, the pipe's read end is
   closed — which is what stops a grandchild holding the write end from
   holding this side — and the run is `errIO`, a child that did not exit
   normally. Reading is `poll` over a buffer of the runtime's own: a `FILE`
   reads ahead, and a `poll` beneath one would wait for data the `FILE`
   already held.
4. **`FD_CLOEXEC`** where a descriptor is made — pipes and sockets in
   `pasrt_posix.c` — and the mode letter **`e`** on every `fopen` in
   `pasrt.c`. C11 7.21.5.3 lets a libc read that letter and lets it ignore
   it; glibc, macOS and the BSDs read it, and a libc that does not leaves the
   runtime where it was rather than broken. It is the one change here to the
   ISO C unit, and it adds no name to its catalogue.
5. **Every action's return is checked** and a failure is a spawn refused.
6. **There is no `fdopen`** to fail: the buffer of decision 3 replaced it.

## Consequences

**The audit's `sanitizers`/`valgrind-corpus` clean bill stands**: the new C is
reached by `lib_process_execute` cases 17–20 and `lib_fs_tempdir`, both under
those sweeps.

**`lib_fs_tempdir` is its own case for a reason that is a finding about a
gate.** `lib-coverage` runs every case with **no arguments**, and `lib_fs`
takes a program-parameter, so under that sweep it stops at its first
statement and nothing in it has ever been measured — the ten uncovered lines
it reported for `PasFS` were the whole module minus what other cases reach.
That is `doc/sop.md` §7's business and is recorded there.

**The `scratchname` session changed what it asserts** (ADR-0242). It checked
the *file left behind* in TMPDIR and there is none now, so it checks two
things instead: what a spy compiler saw *while the server ran* — one
`pasls-XXXXXX` directory — and that TMPDIR is empty after `exit`. A fourth
session, `notmpdir`, pins the fallback: the `unwritable` conversation word for
word under a TMPDIR no machine has.

**`Deadline` is coarse on purpose.** Seconds, because a run shorter than one
is not what a deadline is for, and a poll every 5 ms for the no-capture case,
because `waitpid` has no timeout.

## Alternatives rejected

- **Normalise `chr(0)` away** (cut the string at it). That is the confusion
  bug the audit checked for first and was glad not to find: a check made on
  the whole value and a call made on its prefix.
- **`closefrom` in the child** for finding 4.
  `posix_spawn_file_actions_addclosefrom_np` is glibc 2.34 and FreeBSD; a
  loop of `addclose` over every descriptor makes the spawn fail on the first
  one that was not open, on a conforming libc. Marking descriptors where they
  are made is portable and is what every other runtime does.
- **A fallback that composes the old name** when no directory can be made.
  It is one branch and it is the whole hazard.

## What this does not do

- **It does not sweep the tree for a second command built out of a value.**
  `doc/sop.md` §7's row from ADR-0362 stands.
- **It does not give `pasls` a startup note** when TMPDIR is unusable. The
  per-document note is what `unwritable` pins and the two roads share it.
- **It does not separate a child's two streams into two values.** ADR-0362's
  last bullet, unchanged.
