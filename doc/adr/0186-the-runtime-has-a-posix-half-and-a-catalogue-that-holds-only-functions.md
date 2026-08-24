# 186. The runtime has a POSIX half, and a catalogue that holds only functions

Date: 2026-08-24

## Status

Accepted. Adds `runtime/pasrt_posix.c` and the second half of
`tests/checks/nonstandard_c.txt`. Unblocks ADR-0185's fifth decision.

## Context

ADR-0185 decided that a **library module may not declare a foreign struct**:
`struct stat` is not the same struct on two systems, and `lib/` has to work on
machines nobody here can build for. `PasFS.Info` therefore had to ask the
runtime, where the C compiler *of the target* reads the target's own header.

That was written as though it settled the question. It did not, and
`runtime-isoc` said so within minutes of the code being written:

    runtime/pasrt.c:2681: error: variable has incomplete type 'struct stat'

**ADR-0161's catalogue can only ever hold functions, and nobody had noticed.**
The list is proved complete by a specific mechanism: strip every non-ISO
`#include` from a copy, compile what is left, and harvest what the compiler
calls undeclared. That works because an undeclared *function* is a diagnostic
which can then be silenced for the catalogued names while the rest of the file
still compiles — which is what pass 2 checks, and what makes "these five names
and nothing else" a claim rather than a hope.

A *type* has no such behaviour. `struct stat` with `<sys/stat.h>` stripped is
an incomplete type, which is a hard error no flag silences and no catalogue
entry can excuse. So a POSIX dependency needing a type could never live in
`pasrt.c`, however well it was argued for — not because it was rejected, but
because the mechanism that keeps that file honest cannot describe it.

This is a constraint that was always there and had never been met, because
every non-ISO dependency so far — `_setjmp`, `fmemopen`, `open_memstream`,
`access` — happened to be a function.

## Decision

### 1. The runtime is two translation units

- **`runtime/pasrt.c`** — the runtime proper. Strict ISO C11 apart from a
  catalogue of function names, checked exactly as ADR-0161 checks it now.
  **Still five names.** The split cost that claim nothing.
- **`runtime/pasrt_posix.c`** — anything needing a POSIX *type*. Not held to
  ISO C, because what puts a routine there is precisely that it cannot be.

### 2. What bounds the POSIX unit is its **headers**, not its names

A catalogue of names cannot be proved complete for that file — the same
mechanism, the same reason. So the second section of `nonstandard_c.txt` names
the non-ISO headers it may include, and the gate compares them both ways: a
header appearing without an entry, and an entry naming one the file no longer
includes.

Headers are the right granularity anyway. "What does a port to another C
library have to supply" is answered better by *`<sys/stat.h>` and `<unistd.h>`*
than by a list of the members that happen to be read today.

### 3. Everything in it is `pasx_`, and the gate enforces that

`pasx_` is the prefix a Pascal *program* may bind by name (ADR-0131); nothing
the compiler emits calls into it. So a system without these headers loses
library routines and **not the language** — `pascalc` still builds, still
compiles itself, and every conforming program still runs.

That is what makes the split safe rather than merely tidy, and it is checked:
a `pas_` name defined or called in that file fails the gate.

### 4. It stays small, and the rule for what belongs is ADR-0185's

What goes there is what a *library module* cannot ask C for itself — a struct
whose layout differs between systems. Everything a program can declare and have
checked, it should declare: that is what `--dump-layout` and `foreign-layout`
are for, and `tests/checks/foreign_layout_stat.pas` is the worked example.

## Consequences

- `PasFS.Info` lands: one call answering size, modification time and kind,
  since one `stat` answers all three and asking twice would let the file change
  in between. `errAbsent` is distinguished from `errIO` with a second `access`
  rather than by naming `ENOENT`, which would have been another dependency for
  no further information.
- **The headline property survives, restated.** It was "the runtime is the only
  C here and its whole departure from the standard is five names". It is now
  "the runtime proper is those same five names, and a second file is bounded by
  two headers". A worse headline and a better description — a dependency needing
  a type was always a different kind of thing from one needing a symbol, and the
  old sentence could only describe it by not having one.
- Two mutations, two messages: `#include <dirent.h>` in the POSIX unit is named
  as an uncatalogued header, and renaming `pasx_file_info` to `pas_file_info`
  is named as a `pas_` name that must not be there.

## What this does not do

- **It does not move the four existing catalogued names.** `access`, `fmemopen`,
  `open_memstream` and `_setjmp`/`_longjmp` are functions, they are checked by a
  mechanism that works for functions, and moving them would trade a proved claim
  for a weaker one. The split is by *what the dependency needs*, not by how
  POSIX it feels.
- **It does not make the POSIX unit optional to build.** It is compiled into
  `libpasrt.a` unconditionally. Making it conditional needs a decision about
  what a program calling `pasx_file_info` on a system without it should see, and
  nothing has asked for that yet.
- **It does not open the runtime to POSIX generally.** Decision 4 is the rule,
  and `foreign-layout` exists so that the answer to "can a program do this
  itself?" is usually yes.

## Alternatives rejected

- **Teach the catalogue to name a type.** The catalogue's meaning comes from
  pass 2 refusing to compile anything unlisted. An incomplete type cannot be
  conjured, so making it pass means weakening the check that gives the list its
  meaning — the shape `doc/sop.md` §7 calls narrowing a gate to make a build
  green.
- **Drop `modified` and `kind`, keep only a size.** A size is the one of the
  three ISO C can nearly reach, via `fseek` and `ftell` — and only by *opening*
  the file, which fails for a directory and for anything the caller may not
  read. The feature would have been the weakest third of itself.
- **Let `lib/dialect/pasfs.pas` declare `struct stat` after all**, now that
  `foreign-layout` checks such a declaration. The gate checks it on the machine
  you build on; a library must work on machines nobody here builds on. That is
  ADR-0185 §5 and this record does not reopen it.
