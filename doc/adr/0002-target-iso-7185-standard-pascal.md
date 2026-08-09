# 2. Target ISO 7185 Standard Pascal

Date: 2026-08-09

## Status

Accepted

## Context

"Pascal" names a family: Wirth's original, ISO 7185 Standard Pascal, ISO 10206
Extended Pascal, Turbo Pascal 7, Delphi's Object Pascal, and Free Pascal's
several compatibility modes. They differ in ways that reach the whole compiler —
whether `string` exists, whether units exist, whether classes and exceptions
exist — so this is not a decision that can be deferred until the front end
works.

ISO 7185 is small, completely specified in a single readable document, and
finite. Its full feature list is reachable: nested procedures, records, variant
records, sets, files, pointers, `with`, `goto`. Object Pascal, by contrast,
pulls in vtables, RTTI, and exception personality functions before the language
is interesting.

## Decision

Target ISO 7185. Where the standard leaves something implementation-defined,
choose the behaviour that a reader coming from Turbo or Free Pascal expects:
`maxint` is 2147483647, `boolean` writes as `TRUE`/`FALSE`, integers write at
their natural width.

Deviations from the standard are permitted but must each have their own ADR.

## Consequences

The language has an end. There is a point at which the compiler is finished
rather than perpetually catching up with a moving dialect, and conformance is
checkable against a published document rather than against another compiler's
behaviour.

The cost lands on ADR-0004: ISO 7185 lacks a string type, so the self-hosted
source has to work with `packed array [1..n] of char` or the standard has to be
extended. See ADR-0012.

Rejected: Turbo Pascal 7 compatibility, which is a larger surface with no
specification to check against; and an Object Pascal subset, whose codegen cost
arrives long before any of it is useful for the bootstrap.
