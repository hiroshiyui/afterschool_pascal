# 21. Text files keep the buffer variable, and program parameters name them

Date: 2026-08-09

## Status

Accepted

## Context

Item 5 of ADR-0004's dependency list, and the last structural one: without
files the compiler cannot read its own source or write the `.ll` that ADR-0006
makes its backend.

ISO 7185 gives every file variable a *buffer variable* `f^` and defines the
primitives `get` and `put` on it; `read` and `write` are then *derived*
(§6.6.5.2). An implementation may skip that structure and provide only the
derived operations, which is simpler and is what most Pascal compilers do.

The other open question is §6.10, which says a program parameter denotes an
external file but deliberately does not say how the binding happens. Every
implementation answers it differently, and the answer is visible in every
program that reads a named file.

## Decision

**The buffer variable is real, and the derived operations are derived from
it.** `f^`, `get` and `put` exist and `read` is `x := f^; get(f)` — written
that way in `runtime/pasrt.c`, not merely documented as equivalent.

That is not fidelity for its own sake. The buffer variable is exactly one
character of lookahead, and a *lexer* is the program that wants to inspect the
next character without consuming it. The first thing the self-hosted compiler
needs is a lexer, so the primitive that looks redundant is the one its first
component is written against. `tests/files.pas` pins the property that reading
`input^` three times yields the same character three times.

**Program parameters bind to command-line arguments, in the order written.**
`program P(input, output, src, dst)` gives `src` the first argument and `dst`
the second. `input` and `output` are the standard streams and consume no
argument.

**Using a standard file requires listing it**, as §6.10 says: `write` without
`output` in the header is an error, with a diagnostic that says so. Every
program in `tests/` already listed it, so conformance here cost nothing.

**A file variable's storage is opaque to the compiler.** Codegen alloca's
`PAS_FILE_SIZE` bytes in the activation record and only ever passes their
address; `struct pas_file` is private to the runtime. The size is the one fact
both sides need, so it lives in `runtime/pasrt.h`, included by `codegen.cpp`,
rather than being written out twice. A `_Static_assert` in the runtime fails
the build if the struct outgrows it.

**A file is not structured.** `Type::isStructured()` deliberately excludes it —
that predicate is what grants whole-variable assignment — and a new
`isMemory()` covers the cases that only care about travelling by address. So
assignment, comparison, value parameters and function results are all refused
for files, which is §6.8.2.2, §6.7.2.5, §6.6.3.3 and §6.6.2 respectively.

**Only text files.** `file of T` parses, and a component type other than `char`
is rejected with a diagnostic. A typed file writes the machine representation
of its components, which is a decision about an external format this project
has not made and does not need in order to reach stage 1.

**A file is closed when its block exits**, which is ISO's own lifetime rule.
Pascal has no early return, so the single exit point each body already has is
the whole of the epilogue.

## Consequences

The compiler can now read text and write text, which is everything item 5 was
for. What remains before stage 1 is ADR-0012 — how the stage-1 source handles
strings — and that is a decision, not a feature.

Standard input is opened but not *read* until the program first asks. Without
that laziness, any program listing `input` would block on a terminal before its
first statement ran, including every one that never reads.

Binding to the command line is a choice the standard leaves open, and a program
that relies on it is not portable to an implementation that chose differently.
It is recorded here because it is the kind of decision that otherwise becomes
folklore.

`readln` at the very end of a file whose last line has no terminator stops
rather than failing. ISO calls reading past end-of-file an error; a file whose
last line is unterminated is common enough that treating its last line as a
line is worth the deviation, and the error still fires when `readln` is called
with nothing left at all.

### What is verified, and what is not

Two rules were added, and they are about the one place the file code *computes*
something: `pas_read_int` folds digits into a 64-bit accumulator and checks the
running value against `maxint` after each one.

- `read-accumulator-cannot-overflow` justifies the absence of a check on
  `value * 10 + digit` itself — the read counterpart of
  `negation-cannot-overflow`. Its precondition is the loop invariant, which is
  the same statement the emitted check makes, so the two cannot drift.
- `read-traps-exactly-outside-the-integer-type` states both directions, since a
  runtime that rejected every number would satisfy "never reads a wrong value".

The catalogue is now 31 rules, 27 of them for every 32-bit input, and still no
known gaps.

Nothing else here gets a rule, for ADR-0019's reason: `eof`, `eoln`, `get` and
the buffer variable are *state* properties of a stream, not arithmetic
lowerings, and a rule saying "eof is true when the lookahead is EOF" would be
the emitted test written twice. They are covered by golden tests instead — and
by one test that is a real instrument rather than a sample: `files_scratch.pas`
opens three thousand scratch files in sequence, which fails by exhausting the
descriptor table if a block exit stops closing its files. That was confirmed
against a deliberately broken runtime, because a test that cannot fail proves
nothing. LeakSanitizer was tried first and is *not* a valid instrument here:
glibc keeps every open stream reachable from its own list, so a leaked `FILE`
is never reported.

## Notes for the port

`text` is a singleton type, so every `text` variable has the same type, while a
`file of char` written longhand is a different one — name equivalence
(ADR-0017) applied without an exception.

The opaque-blob representation is the part most worth keeping in the rewrite.
It means the Pascal-hosted compiler needs no knowledge of `FILE` or of any
system call: it declares a file variable, and the runtime it links against owns
everything inside.
