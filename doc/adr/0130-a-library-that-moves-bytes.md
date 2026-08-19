# ADR-0130: A library that moves bytes, and the first increment that found nothing

## Status

Accepted. `lib/dialect/pasio.pas`, the sixth module of ADR-0114's library and
the second layer's fifth. No compiler change.

## Context

**Every library increment before this one found a compiler defect**, and each
one was invisible until a library wrote it:

| Increment | What it found |
| --- | --- |
| ADR-0114 | a string argument had to be a variable (fixed, ADR-0115) |
| ADR-0116 | a schema whose component holds a variable-string stopped the compiler |
| ADR-0116 | a `forward` function lost its result-variable-specification, and §6.11.1 makes every exported function a `forward` |
| ADR-0120 | a module imported and not used was activated and never declared |

Four for four, and the reason is the same every time: a library writes shapes
a test program does not, so every oracle here agreed the compiler worked.
That record is why this increment was taken — ADR-0129 shipped a buffer at the
foreign boundary with two cases written by the person who wrote the code, and
the library is the check that is not that.

**And there was a second reason.** `doc/roadmap.md` had said, since ADR-0114,
that a library module ships with each increment; ADR-0129 was the first that
shipped none. `read`, `write`, `recv` and `send` were bindable and nothing
bound them.

## Decision

`PasIO` — descriptor input and output, on ADR-0129's slice.

```pascal
function ReadInto(fd: integer; var buf: array of char) = r: CountResult;
function WriteFrom(fd: integer; protected var buf: array of char) = r: CountResult;
function WriteAll(fd: integer; protected var buf: array of char): ErrorCode;
```

`OpenRead` and `Close` beside them, ADR-0120's result shape for the two things
that answer a value, and `ErrorCode` for the two that do not.

**Three narrownesses, each a number the module cannot check**, and each
recorded in the source rather than discovered:

- **Only `O_RDONLY`.** Creating a file needs `O_WRONLY`, `O_CREAT` and
  `O_TRUNC`, which are header numbers an FFI without a header parser cannot
  see. `O_RDONLY` is 0, the one flag value a header is not needed for — the
  argument `lib/dialect/pasfs.pas` already made for `F_OK` and refused to make
  for `R_OK`, `W_OK` and `X_OK`. So this module reads files and writes only to
  descriptors that were open already.
- **It cannot say why.** A failure is `errIO`, `errno` being
  `*__errno_location()` and a returned pointer being what ADR-0122 does not
  admit. The same wall, now recorded by two modules.
- **It does not share a descriptor with §6.9 and §6.10's own I/O.** Those go
  through the runtime's buffered streams and everything here is unbuffered, so
  writing to `StdOut` from both interleaves by whichever flushed last.
  `tests/dialect/lib_io.pas` puts every descriptor write before Pascal has
  written anything, which is the only ordering that does not depend on how
  `output` is buffered — the caveat demonstrated rather than asserted.

## Consequences

### The finding: nothing

**The compiler had no defect for this to find.** That is the first time in five
library increments, and it is the result worth recording, because the heuristic
that produced the other four is a claim about the compiler and not a ritual.

It was not for want of probing. Beyond the module, a slice reached `write`
from: a global array, a record field, a *schema*-bounded array whose extent is
a discriminant, an enclosing procedure's local read through the static chain, a
`with` statement's binding, a `var` parameter sliced by two expressions, a
slice of a slice inside `WriteAll`, an empty slice, and an `array of int64`.
Every one behaved.

The honest reading is narrow: ADR-0129's feature is built out of ADR-0125's,
which had a corpus, and confining it to an argument is what kept it from
touching anything with a lifetime. It is **not** evidence that the FFI is
sound — the two mutations ADR-0129 recorded as survivors still survive, and
nothing checks a foreign signature.

### What the library did find

Two things, both about the library and caught by mutation rather than by
running it:

- **`AtEnd`'s first conjunct is load-bearing and was untested.** `r.ok and
  (r.count = 0)` over a *failed* result works because `and` short-circuits, so
  `r.count` is never read on a result whose tag says there is none. Dropping
  `r.ok` passed the whole suite until a case asked `AtEnd` of a failure; then
  it traps with *variant: the tag selects another arm*. ADR-0118's rule and
  §6.7.2's short-circuit holding each other up, and neither is visible in the
  successful path.
- **`WriteAll`'s retry branch cannot be reached from a test here.** A short
  write needs a descriptor that takes fewer bytes than it was given: a regular
  file never does and a pipe blocks rather than truncating, so the loop's
  `done := done + r.count` is written against a case this harness cannot
  produce. Its *failing* exit is reachable — writing to a descriptor opened for
  reading — and is covered. The retry is not, and is said here rather than left
  to be found.

### What it does not do

- **No `OpenWrite`, no `Create`, no `Seek`.** All need flag or `whence`
  constants, and the module's policy is PasFS's: a number it cannot check does
  not go in.
- **No `ReadLine`.** Buffering across calls needs state that outlives a call,
  and §6.9's own `read` already has it for the streams a program is given.
- **No sockets.** `socket`, `bind` and `connect` take `struct sockaddr *`, and
  a struct pointer is the part of ADR-0121's type mapping that is still
  entirely absent.
- **A count is components and C's is bytes.** `read` bound to an
  `array of integer` asks for a quarter of what it looks like — probed, and it
  does exactly that. Documented in ADR-0129 and repeated here because a library
  is where someone will meet it.
