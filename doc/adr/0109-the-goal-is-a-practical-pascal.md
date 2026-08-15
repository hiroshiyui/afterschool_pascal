# ADR-0109: The goal is a practical Pascal

## Status

Accepted. Supersedes the goal statement of
[ADR-0004](0004-feature-priority-follows-the-bootstrap.md), whose feature
priority expired when the bootstrap closed; the conformance work it led to is
untouched and stays.

## Context

The project has reached the end of its stated goals. Self-hosting closed
(ADR-0085), ISO 7185 is complete, ISO/IEC 10206:1991 is complete to its last
clause (ADR-0079), and the conformance sweeps found what they were going to
find. `doc/roadmap.md`'s live section had five entries, of which one was a
language feature and three were about oracles.

A compiler that is finished against its standards is not the same as a compiler
anyone can get work done in. Both standards were written in an era whose
practical concerns were files, arithmetic and structured programming. Neither
has a socket, a code point, a thread, or a way to say what happens when two of
those meet.

## Decision

**The long-term goal is a Pascal — a compiler and a dialect — for daily
practical development work**, with a standard core library and the facilities
modern programs need: networking, internationalisation (l10n/i18n/m17n),
concurrent execution, and memory safety as a first-class property rather than a
convention.

This changes the project's **axis**, and that is the part to understand before
anything else. ADR-0002 made conformance the tie-breaker over convenience and
required a record for every deviation. A dialect deliberately diverges. The two
are not reconciled by weakening the first — they are reconciled by keeping them
apart.

### What follows immediately, by precedent rather than by invention

**The dialect is a third standard, and the two conformance modes are
untouched.** ADR-0033 established that `--std=iso7185` and `--std=extended` are
*not nested*: Extended Pascal reserves word-symbols a valid ISO 7185 program may
use as identifiers, so a source is written in one language or the other and the
standard is a property of the source. A third mode is the same construction
again, and it is why this project can grow a dialect without giving up being a
conforming processor. The corpus already selects by directory, every harness
already derives the flag from the path, and `tests/spec/` already ties scenarios
to clauses of the two standards.

**The standard library is built on what is already here.** §6.11's modules
(ADR-0053) and §6.13's separately translated program-components (ADR-0079) are
implemented, and `--import` reads a component's module-headings from its source.
A library needs no new language mechanism to *exist*; the work is in what it
wraps and what the runtime must grow to support it. This is the single largest
asset the conformance work left behind and it was not built for this purpose.

**`runtime/pasrt.c` is the boundary where the outside world enters.** Pascal has
no foreign-function interface and this record does not add one lightly: the
runtime is already the place holding everything not expressible in the language,
and sockets, clocks and encodings arrive the same way formatted output did.

### What this forces, and is not yet decided

These are named here so they are visible as open decisions rather than
discovered later as assumptions. Each will get its own record.

- **The memory-safety model.** ADR-0019 states plainly that use-after-`dispose`
  is not detected. "Memory safety first" is incompatible with that sentence, and
  the candidates — checked pointers with regions, ownership and borrowing, or a
  tracing collector — differ in what a pointer *means*, not merely in what is
  checked. It is the most expensive decision here to reverse.
- **The text model.** "`char` is a byte, ordinal 0..255, and nothing consults
  the locale" is a documented decision, and UTF-8 currently passes through as
  bytes. Real internationalisation needs either a wider character type or a text
  type distinct from §6.4.3.3's strings, and the choice interacts with every
  string operation the standards define.
- **The memory model.** Pascal has none. Concurrency cannot be specified without
  saying what a data race is and what one execution may observe of another —
  and this must be designed *with* the safety model, not after it, because
  shared mutable state is where the two meet.
- **How far the C++ reference front end follows.** ADR-0108 brought `src/` back
  one commit ago, on the reasoning that the language was finished and slow-
  changing. A dialect growing quickly makes every front-end feature ship twice,
  which is the cost ADR-0085 retired stage 0 to escape. Freezing the mirror at
  the conformance surface — where it goes on guarding what must not regress —
  is the obvious answer and is not yet the decided one.

## Consequences

**The conformance work is not deprecated and must not rot.** `--std=iso7185`
and `--std=extended` remain what they are, the BSI suite goes on running, and a
dialect feature that changes what either mode accepts is a bug. The reason is
not sentiment: those two modes are the only part of this compiler with an
external specification, and they are what every oracle here is calibrated
against. A dialect with no conformant core underneath it has nothing to be
checked against at all.

**The bar for a feature inverts.** During the bootstrap a feature needed a
reason beyond "the standard has it"; after ISO 7185 was completed, "the standard
has it" became sufficient. Neither applies now. A dialect feature needs a
practical task it makes tractable, and the burden is to show the task.

**Self-hosting is now a constraint on ordering, not a goal.** The compiler is
written in its own language, so a dialect feature must be expressible in what
`seed/pascalc.ll` accepts, or the seed is refreshed first (ADR-0085, ADR-0095).
Features the compiler itself will use should land in an order that keeps the
bootstrap closed at every step.

**A third-party differential quietly stops being available.** `doc/roadmap.md`
lists FPC under `-Miso` or p5 as a candidate oracle. That works only for the
ISO 7185 core; nobody else implements this dialect, so as the language diverges
the option narrows to the part that is already most tested. Worth spending
while it is still worth anything.

**`doc/roadmap.md` is restructured around this**, and its "Beyond self-hosting"
section — written when this was speculation — becomes the main line.
