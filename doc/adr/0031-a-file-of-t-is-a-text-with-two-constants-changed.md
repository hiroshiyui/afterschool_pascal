# 31. A `file of T` is a text file with two constants changed

Date: 2026-08-10

## Status

Accepted.

## Context

ADR-0021 implemented `text` and refused every other file type: a `file of T`
writes the machine representation of its component, which is a decision about
an external format the bootstrap did not need. The bootstrap is closed, and the
bar has changed — ISO 7185 has non-text files, and that is now the reason to
have them.

The question is how much of a second file implementation this needs. A text
file and a `file of T` look different: one has lines, an external
representation of numbers, `readln` and `eoln`; the other has none of those and
writes bytes. But ISO 7185 §6.6.5.2 defines both in terms of the same two
primitives and the same buffer variable, and defines `read` and `write` on a
non-text file as *derived* from them:

    read(f, v)   is   v := f^; get(f)
    write(f, e)  is   f^ := e; put(f)

which is the structure `runtime/pasrt.c` already had, because ADR-0021 kept it
rather than flattening `read` into `getc`.

## Decision

**A `file of T` is the same machine with two constants changed**: a component
is `compsize` bytes rather than one, and there is no line structure. The
lookahead becomes "the buffer variable holds the component the file is
positioned at", which is what the `have` flag already meant. `get`, `put`,
`eof` and the buffer variable are therefore one implementation with a text
branch each, not two implementations. `pas_file_init` gained the component size
and an `istext` flag, and that pair is the whole of what the compiler tells the
runtime about T.

**`text` is not `file of char`.** §6.4.3.5 makes them different types, and only
the first has lines. One flag on the type says which, set on the `text`
singleton and never by `resolveFile`, so `file of char` written out longhand is
a sequence of characters that `readln`, `writeln` and `eoln` are all refused
on. They are otherwise identical, down to the component size.

**`read` and `write` on a non-text file are emitted as the assignments the
standard defines them to be.** That is why `emitAssign` was split: `emitStore`
is now the whole of what assignment does — the conversion, the range check, the
whole-variable copy — and `write(f, e)` calls it with the buffer variable as
the destination. A component of a `file of 1..9` is range-checked on the way in
because it is a store like any other, and a variable read out of a file is
checked on the way out for the same reason. Neither check is new code.

**The buffer variable is allocated by the runtime, not the compiler.** A text
file's `f^` is one character and lives in `struct pas_file`; a `file of T`
needs T's worth of storage, aligned for T, and `malloc` is what guarantees
that. It is freed at the block exit that already closes the file, so the
obligation ADR-0021 created covers it. The alternative — the compiler
alloca'ing the buffer beside the file — was rejected because it would put the
component's size back into the compiler's half of an interface whose whole
point is that the file's storage is opaque.

**The component may be any type that is not, and does not contain, a file.**
§6.4.3.5's restriction, checked recursively through arrays, record fields and
every arm of every variant part. A file has no value to copy — the same fact
that keeps it out of `isStructured()` — so a file inside one could not be read,
written, or positioned.

## Consequences

**`PAS_FILE_SIZE` grew from 64 to 80.** The struct gained the component size,
the text flag, an end-of-file flag and the buffer pointer. Both sides state the
number — `runtime/pasrt.h` for the C++ compiler, a constant for the Pascal one
— and `selfhost/irtest.sh` checks they still agree, which is the mechanism
ADR-0025 put there for exactly this.

**A file variable now owns heap storage.** It is the first thing here whose
block exit has to free something rather than only flush and close. That is the
same obligation, at the same place, so it changes nothing structurally — but it
is now a leak if a block exit is ever skipped, where before it was only an
unflushed buffer. The non-local `goto` that ADR-0029 refused would skip block
exits, and this is a third reason it cannot simply be added.

**There is deliberately no SMT rule.** The catalogue proves lowerings of
arithmetic, conversions and comparisons; a non-text file introduces none. The
one thing that could be got wrong numerically — the range check on a component
entering or leaving a variable — is `checkedForStore`, already proved for every
32-bit input by the subrange rule, and reused here rather than restated. A rule
saying "the bytes written are the bytes read" would restate the lowering, which
is the mistake ADR-0013 warns against. It is covered by the golden tests, by
the cross-check, and by an ASan/UBSan run over `tests/typedfiles.pas` that also
confirms the buffer is freed.

**Twenty-two mutations: twenty-one caught, one equivalent.** The equivalent one
replaces the whole-variable copy in `read` with an aggregate `load`/`store` of
the record type. LLVM accepts that and it behaves identically — but it
contradicts ADR-0017's rule that a structured value has no register form, and
that rule is what lets both backends share one structured-copy path. It stays a
memcpy on the strength of the invariant, not of a test, and this paragraph is
the record that no test defends it.

Two escapes on the first round were real and are fixed: `read(f, a, b)` with
two variables in one statement was in no test, so hoisting the buffer-variable
fetch out of the loop survived, and a `var` parameter of a file type was in no
test either. Both are now in `tests/typedfiles.pas`.

**What ISO 7185 has left is the non-local half of `goto`.**
