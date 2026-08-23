# 172. `binding(f).bound` says whether the file is there

Date: 2026-08-23

## Status

Accepted.

## Context

A standard library was being surveyed for what a daily program needs and
cannot do here, and the largest gap was not in the library: **a conforming
program cannot find out that a file is missing.** §6.10's `bind`, `reset`,
`rewrite` and `extend` create, read and append files perfectly well — the
probe that opened this record wrote, extended and read one back in ten lines —
but a name that does not exist is learned of only at `reset`, as *cannot open
for reading: …*, which stops the program. No conforming module over text
files could report rather than stop, and the dialect's `PasFS.Exists` was the
only way to ask, which put the question on the wrong side of ADR-0120's
layer line.

The standard had already provided for this. ISO/IEC 10206:1991 §6.7.5.6:

> the statement bind(f,b) shall access the variable denoted by f and shall
> **attempt** to bind the accessed variable to an entity that is external to
> the program and that is designated by b. The binding shall be
> implementation-defined.

and NOTE 2: "The function binding (see 6.7.6.8) can be used to obtain an
initial value of type BindingType and **to test the success** of binding a
variable to an external entity." A binding that is not to anything is the
clause's own design; this processor's `bind` simply always reported success,
and so the test NOTE 2 offers always answered true.

## Decision

**A variable is bound to an external entity when that entity exists, asked
whenever `binding` is called.** `bind` records the name and makes no attempt
of its own; `binding(f).bound` answers about *now* — false for a name nothing
is at, true for the same variable once `rewrite` has created the file. Stated
as E.16 in `doc/implementation-defined.md`.

Three choices inside that, each made the least way:

- **Existence, not readability.** `access(name, R_OK)` answers for the wrong
  user under set-uid, and a file that exists but cannot be read is still a
  file the program named — the open is where that is reported. What the rule
  gives a program is exactly the question it could not ask: *is there
  anything there?*
- **Asked at `binding`, not recorded at `bind`.** The first version of this
  record made `bind` decide once — succeeding when the name *or its
  directory* existed, so that `rewrite` of a new name would be bound — and
  writing the first module against it showed the rule answered the wrong
  question: a missing file in an existing directory was "bound", and `reset`
  stopped exactly as before. Asking at `binding` time dissolves the
  dilemma: before `rewrite` the answer is false, after it true, and both are
  the truth. It also costs no storage, where the first version spent the
  last byte of `struct pas_file`'s padding.
- **The name is kept whatever the answer.** An unchecked `reset` stops with
  *cannot open for reading: name* exactly as before. The alternative — a
  binding to nothing leaving a scratch file behind — would make a program
  that forgot to ask read nothing where it named a file, which is the one
  outcome worse than stopping. `bind_missing.pas` ends on that stop. A
  second `bind` is the dynamic-violation §6.7.5.6 names only when the first
  is bound to something, which is the same rule read again.

## Consequences

- **The runtime's departure from ISO C is five names, not four.** ISO C has
  no way to ask whether a path exists without creating it: `fopen` for
  reading says nothing about a file that is there but unreadable, and
  `fopen` for appending creates what it was asked about. So this is
  `access`, catalogued in `tests/checks/nonstandard_c.txt` with that
  argument, and `F_OK` is written as the 0 POSIX fixes it at so that the one
  name is the whole dependency. ADR-0161's count moves; its reasoning does
  not.
- **`runtime-isoc` had a hole, and `access` went through it.** The gate
  compiled `pasrt.c` under `-std=c11 -pedantic-errors` and read what glibc
  then declined to declare. `__STRICT_ANSI__` hides what POSIX *adds* to an
  ISO C header; it does nothing to a header ISO C never had, and glibc's
  `<unistd.h>` declares `access` unconditionally. The catalogue entry was
  therefore rejected as naming a dependency the runtime "no longer uses" —
  the gate's other direction, firing on a false premise. It now compiles a
  **copy with every non-ISO `#include` removed**, which is what a strictly
  ISO C library would present, and both passes read that copy. Removing the
  entry again fails the gate naming `access`.
- **A conforming module can now wrap files and report.** `lib/pasfile.pas`
  is the first use: `bind`, ask, then `reset` — rather than a dialect
  `Exists` on the far side of the layer line.
- **What this does not do.** It does not make `reset` or `rewrite`
  report: §6.10's file procedures have no result and a stop is still what a
  failed open is, so a *write* to a directory that does not exist still
  stops. It does not ask permission questions. It does not change
  `binding` for a program-parameter, `input` or `output` (E.19). And it does
  not follow a symbolic link to decide existence beyond what `access` does.

## Mutation

`pas_bound_exists` answering `bound_name != NULL`: `bind_missing` fails at
its first line, `bound=TRUE` where `FALSE` is expected, and then at its
second `bind` with *the variable is already bound*. Three existing cases —
`required_identifiers`, `trap_bind_twice` and the `scopes.feature` scenario
at §6.7.5.6 — had asked `binding` of a name nothing was at and recorded
`TRUE`; each now creates the file before asking, which is the rule read the
other way and is noted at the line. Striking `access` from
the catalogue: `runtime-isoc` fails naming it.
