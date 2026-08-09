# 12. How the self-hosted source handles character strings

Date: 2026-08-09

## Status

Proposed — this decision is open. Recorded now because it is the one place where
ADR-0002 and ADR-0004 genuinely conflict, and because deciding it late means
rewriting the stage-1 source.

## Context

ISO 7185 has no string type. It has string *literals*, and it has
`packed array [1..n] of char`, where the length is part of the type. Two arrays
of different lengths are different types, so a procedure taking a name cannot
also take a longer name, and there is no assignment between them.

A compiler is unusually string-heavy: identifiers, keyword tables, string
literals from the source, diagnostic messages, and — under ADR-0006 — the whole
of the emitted IR as generated text. Written against fixed-length arrays, all of
that carries an explicit length alongside every buffer, and every operation on
it is hand-written.

So the language that the stage-1 source is written in has to answer this, and
today's answer is "painfully".

## Options

**A. Strict ISO, with a length convention.** Declare
`type Str = record len: integer; ch: packed array [1..255] of char end` and write
the handful of operations over it. No language change; conformance untouched.
The stage-1 source pays for it on every line that touches text.

**B. A documented `string` extension.** Add a variable-length string type,
accepted as a deviation with its own ADR, and available only when a flag or a
compiler directive asks for it — so conformance testing can still run against
the standard language.

**C. Extended Pascal (ISO 10206) strings.** Adopt the `string` of the later
standard rather than inventing one. Standardised, but drags in schema types and
a larger specification than the project has committed to.

## Recommendation, not yet a decision

Option A first, revisited once the stage-1 source exists. A record with a length
and a fixed buffer is what a Pascal compiler of the era would have used, it needs
nothing from the compiler that ADR-0004 does not already require, and it keeps
the language conformant while the hard parts — procedures, pointers, files — are
still being built.

If it proves to be the thing slowing the port down, B becomes justified, and by
then the requirement will be known from real code rather than guessed at.

## Consequences of leaving it open

Feature work up to and including text files is unaffected; nothing before that
depends on the answer. What is affected is the shape of the stage-1 source, so
this should be settled before that source is written, not during.
