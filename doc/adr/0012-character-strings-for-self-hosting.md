# 12. How the self-hosted source handles character strings

Date: 2026-08-09 (proposed), 2026-08-09 (decided)

## Status

Accepted — option A. Recorded as Proposed while items 1–5 were built, and
settled once text files made it possible to measure the requirement instead of
guessing at it.

## Context

ISO 7185 has no string type. It has string *literals*, and it has
`packed array [1..n] of char`, where the length is part of the type. Two arrays
of different lengths are different types, so a procedure taking a name cannot
also take a longer name, and there is no assignment between them.

A compiler is unusually string-heavy: identifiers, keyword tables, string
literals from the source, diagnostic messages, and — under ADR-0006 — the whole
of the emitted IR as generated text.

So the language that the stage-1 source is written in has to answer this. The
question this record was opened to defer is *how much* that hurts.

## Options

**A. Strict ISO, with a length convention.** Declare
`type str = record len: integer; ch: packed array [1..n] of char end` and write
the handful of operations over it. No language change; conformance untouched.

**B. A documented `string` extension.** Add a variable-length string type,
accepted as a deviation with its own ADR, and available only when a flag or a
compiler directive asks for it — so conformance testing can still run against
the standard language.

**C. Extended Pascal (ISO 10206) strings.** Adopt the `string` of the later
standard rather than inventing one. Standardised, but drags in schema types and
a larger specification than the project has committed to.

## Decision

**Option A.** The stage-1 source uses a length-plus-buffer record and the
half-dozen operations over it. No extension is added, and ADR-0002 stands
untouched.

## What settled it

The original text of this record recommended A while warning that "the stage-1
source pays for it on every line that touches text". **That warning was wrong**,
and measuring the existing compiler is what showed it. The finding that decides
this is simple:

> A compiler does not *manipulate* text. It reads text in and writes text out.

Four measurements, over the C++ compiler this one will be a port of:

- **Concatenation is almost entirely output.** 164 uses of `+` on strings, of
  which the overwhelming majority build a diagnostic message or an LLVM label.
  Both are *written*, so in Pascal each becomes a sequence of `write` calls and
  needs no string to exist. `tests/bootstrap_strings.pas` emits
  `@name = global i32 0, align 4` with no string type involved at all.
- **Exactly one function returns a built-up string:** `Type::name()`. Its
  natural Pascal form is `procedure WriteTypeName(var f: text; t: typePtr)`,
  writing directly — which is what a backend that emits text wants anyway.
- **Diagnostics are never sorted or revisited** — `diag.cpp` has no `sort` — so
  messages can be written the moment they are produced. Nothing needs to hold a
  message.
- **What genuinely has to be *stored* is bounded and small:** identifiers and
  the string literals of the program being compiled, both of bounded length,
  plus about **sixty** literals in fixed tables — 35 reserved words, 17
  required functions, 8 predefined names.

So the entire cost of option A is those sixty table entries, which must be
padded to a common width because a literal cannot be passed to a procedure
unless its type matches:

```pascal
IsKeyword := StrSameAsLit(s, 'begin       ') or
             StrSameAsLit(s, 'end         ') or ...
```

That is the whole of the tax: sixty padded literals in a compiler of several
thousand lines, concentrated in tables that are written once and never touched
again. It is not a cost per line of text-handling code, and treating it as one
would have bought an extension to solve a problem that is not there.

`tests/bootstrap_strings.pas` is the evidence rather than an illustration of
it: it implements the record, the lexer's accumulate-a-word loop, keyword
recognition against padded literals, a symbol table that interns by comparison,
and IR emission with interpolated names — and it compiles and runs against the
compiler as it stands. If the discipline did not work, that test would fail.

## Consequences

Conformance is untouched: the stage-1 source is a Standard Pascal program, so
stage 1 can be compiled by any ISO 7185 compiler and not only by this one. That
is worth more than it looks — it is the escape hatch if stage 0 turns out to
have a bug that stage 1 depends on.

The lexer's inner loop gets the shape it wants for free. A word is accumulated
one character at a time from the buffer variable (ADR-0021), so no string needs
to exist before it is built, and the awkward direction — literal *into* a
variable — barely arises.

Sizes have to be chosen and they become limits: a maximum identifier length and
a maximum stored-literal length. ISO explicitly permits an implementation to
impose them, and they should be stated in the same place as the nesting limit
of ADR-0020 rather than discovered.

Comparison is O(n) with no hashing, and the symbol table in the experiment is a
linear scan. That is a performance question, not a language one; a hash over
the buffer is ordinary Pascal when it is needed.

**What would reopen this.** If the stage-1 source turns out to want strings in
a shape option A cannot express — string-returning functions in the interior of
the compiler rather than at its output edge — B becomes justified, and by then
it would be justified by real code. Nothing measured here points that way: the
one string-returning function is at the output edge, where writing replaces
returning.

This record now describes a decision rather than a recommendation, so the last
open question before stage-1 Pascal is closed.
