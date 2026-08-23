# 174. A handle is a file variable for a foreign address

Date: 2026-08-23

## Status

Accepted. AP 6.4.12, and amendments to 6.7.7.3 and 6.7.7.8.

## Context

AP §6.7.7.9 c) forbids an external result that is "an address of storage the
callee owns whose contents are not characters", and the roadmap carried that
as the item standing between the library and a directory listing, a pipe to
a child process, a socket. ADR-0151 then found two things about it. The
prohibition was never enforced — `int64` carries a `DIR *` today, it copies,
arithmetic on it is legal, and closing it twice aborts the process
(`tests/dialect/foreign_int64_handle.pas`, Annex C.7). And the property such
an address needs, a *lifetime*, was already answered in this language by the
file variable: released when the variable holding it dies, not copyable out
of it, across every exit the language has — block epilogue, non-local `goto`,
`halt`, `dispose`.

So the design question was never "what is ownership". It was how to spell a
type that has a file variable's semantics for an address a foreign routine
answered, and what a second kind of owned variable costs the machinery built
for the first.

## Decision

**A handle-type is an owned variable whose value is a foreign address and
whose type names the routine that releases it.**

```pascal
type Dir = handle external 'closedir';
function ExtOpendir(path: string): Dir; external 'opendir';
```

- **The spelling reserves nothing** (ADR-0140). `handle` and `external` are
  identifiers; what no conforming program can write is a type-identifier
  followed by an identifier and a character-string where a type-denoter
  ends, so the dialect reads that juxtaposition and the conformance modes go
  on saying *expected ';' after a type definition* — Annex B's row, with
  `src/` needing nothing. `tests/dialect/inherits_extended.pas` declares a
  type `handle` and a variable `external` and keeps both.

- **It is owned the way a file is, through the same predicate.** `IsOwned`
  is a file or a handle, `ContainsFile` walks it, and so every refusal a
  file has — assignment, the relational operators, a value parameter of a
  Pascal routine, a function result, and anything containing one — reaches
  a handle with no new arm. `predicate-callers` sweeps the 21 positions for a
  third spelling and all refuse. `HoldsFile`'s walk sets the slot up in the
  prologue and tears it down in the epilogue exactly as it does a
  `struct pas_file`.

- **Three things a handle has that a file does not**, each written out as
  an exception beside the rule it excepts. `h := <external function
  designator of the same type>` is the one assignment, and the variable
  releases what it held first (`pas_handle_set`); a handle-valued call may
  stand nowhere else, which CheckCall enforces through a flag the assignment
  arm sets for that one node. `h = nil` and `h <> nil` ask whether it is
  empty, the optional's rule for the optional's reason. And a handle may be a
  **value parameter of an external** — lent: the word crosses, the variable
  keeps ownership, and an empty one is an error at the lend (Annex A.7),
  because a C routine given NULL for a stream does not report.

- **The slot rides the file model's runtime.** `struct pas_handle` is the
  value, the closer, and two links — 32 bytes, `PAS_HANDLE_SIZE` beside
  `PAS_FILE_SIZE` and checked by `irtest.sh` the same way. The live handles
  are a list beside the open files, marked in `struct pas_jump` beside the
  file mark, so `pas_jump_go` and `pas_halt` release what they abandon with
  the walk they already do. The closer is called through the pointer the
  slot holds; the emitter declares it `i32 (ptr)` — `fclose`, `closedir`
  and `pclose`'s shape — unless an `external` heading already declared the
  name, in which case that declaration stands (ADR-0147's one-declaration
  rule, kept).

- **No second name for one value, by construction.** A handle cannot be
  copied at all, so it cannot be stored where two variables reach it. That
  is the lifetime half of the memory-safety model and nothing of the
  aliasing half (ADR-0151): this record moves the fork no closer to being
  decided, deliberately.

## Consequences

- **What it unlocks.** `popen`/`pclose` (a command's output, and a
  directory listing through the shell), `fopen` with a mode (the file
  creation `PasIO` could not do without header numbers), `opendir`/`closedir`.
  Each is a library module away; none needed more language.
- **What it does not do.** It does not follow a handle into a struct the
  far side lays out — `readdir`'s `struct dirent` is still the layout item.
  It does not let a handle be returned by a Pascal function or stored by
  copy, and a `var` parameter of an external cannot be one: a routine given
  the variable could replace what the program owns without releasing it.
  It does not check that the closer the type names is the right one for the
  routine that answered the value, nor its signature — `doc/sop.md` §7's row
  about an external's name against its routine covers the closer too. A
  handle in a variant part is refused through the file's rule.
- **`foreign_int64_handle.pas` stands**, and Annex C.7 now says what it is
  the register of: the cost of the `int64` door for a program that uses it
  instead of this type.
- **Two enumerations grew** — `nkHandle`, `tyHandle` — and `kind-exhaustive`
  named every partial case that had to decide. `target-layout` compares the
  slot's offsets in a record beside a set, on both admitted targets.

## Mutation

`pas_handle_set` not releasing the old value: `handle` fails at *first,
after reassignment*, the file empty. The `goto` walk skipped: `handle`
fails at *after goto*. The call-context rule dropped: `handle_errors` loses
two diagnostics. Each is a different line of the design, and each case
reads the file back rather than trusting the closer ran.
