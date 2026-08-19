# ADR-0132: A returned pointer into the caller's own buffer

## Status

Accepted. `WorkingDirectory`, `LinkTarget` and `PathResult` in
`lib/dialect/pasfs.pas`. **No compiler change and no new mechanism** — which
is the finding rather than a note about the size of the diff.

## Context

`doc/roadmap.md` and README both said the same thing after ADR-0131: what is
left of the foreign-function interface is *every returned pointer that is not
a string*, and that it waits on ADR-0109's memory-safety model because a
pointer outlives the call.

That sentence covers two things that are not alike:

- **A pointer to storage the callee owns** — `getenv`'s, `strerror`'s. Whose it
  is and how long it lives are real questions, and ADR-0123 answered them by
  *copying at the call site* so that no C pointer becomes a Pascal value.
- **A pointer to storage the caller just lent it** — `getcwd`'s, which is the
  buffer that was passed in, or null. There is no ownership question at all:
  the storage is the caller's, it outlives the call by construction, and the
  pointer is a success flag with an address attached.

The second was never blocked. It only looked blocked because both are spelled
`char *`.

## Decision

Bind them, and add nothing.

```pascal
function ExtGetcwd(var b: array of char): OptPathName; external 'getcwd';
function ExtReadlink(path: string; var b: array of char): int64;
  external 'readlink';
```

Three mechanisms already in the tree meet here, and each supplies exactly one
part:

- **ADR-0129's slice** lends the buffer, supplying `getcwd`'s two C arguments
  and `readlink`'s last two from one formal apiece. The size C is given is one
  this compiler computed and checked.
- **ADR-0123's optional string** receives `getcwd`'s result: null is the
  failure and a value is copied at the call site, so what the module holds is
  a string of its own.
- **ADR-0128's `int64`** receives `readlink`'s `ssize_t`.

`PasFS` gains `PathResult` in ADR-0120's shape, `WorkingDirectory`,
`LinkTarget` and `PathOr`.

**One implementation detail is a decision.** The buffer is
`packed array [1..MaxPath] of char` rather than an unpacked one, because
§6.4.3.2 makes a packed char array a **string-type** — so turning what
`readlink` wrote into a `PathName` is one whole-string assignment and one
substring, not 4096 concatenations through ADR-0111's arena. ADR-0125 refuses
`b[1..n]` over such an array, that being §6.5.6's substring, but the *whole*
array still binds to a slice formal, which is the half this needs.

## Consequences

### What it buys

The working directory and a link's target, which `PasFS` could not reach at
all. More usefully it narrows what the roadmap says is left, from "every
returned pointer that is not a string" to **a pointer to storage the callee
owns whose contents are not characters** — a `FILE *`, a `DIR *`, a
`struct sockaddr *`. That is a much smaller and much more precise statement of
where the memory-safety model actually bites.

### What it costs

**`LinkTarget` has to guess at truncation, and reports the safe way.**
`readlink` writes no terminator and answers the number of bytes it placed, so
a result equal to the capacity cannot be told from a target that exactly fits.
It answers `errFull`. Returning a possibly-short path as though it were whole
is the failure that matters, and this is the direction that does not do it.

**That guard is unreachable and so are two others.** `MaxPath` is 4096 because
Linux's `PATH_MAX` is, and the kernel will not create a link whose target
exceeds `PATH_MAX - 1` — so `readlink` cannot fill the buffer, and no test
here enters the arm. It is written against a system whose limit is larger,
which is a number this module can no more read than it can read `O_WRONLY`.

This is now the third such branch in three increments — `WriteAll`'s retry
(ADR-0130), `ErrorNumberText`'s null (ADR-0131), and this one — and the
pattern is worth naming rather than logging a third time: **binding a C
interface produces guards for cases the platform cannot currently produce.**
They are correct to write, because the interface permits the case and a later
platform may produce it, and they are impossible to test from here. A library
of bindings will accumulate them, and the honest treatment is to say which
branch and why, not to delete the guard so the coverage reads better.

### What it does not do

- **No `symlink`, `mkdir`-with-a-mode, or anything that creates.** The test
  binds `symlink` itself, which shows it *could* be offered — it needs no flag
  — but growing the interface is not what a test is for.
- **No opaque handle.** `opendir` answers a `DIR *` that must be given back to
  `closedir`, and that is a pointer the program holds between calls. It is the
  memory-safety question in its smallest form, and this record does not touch
  it. Pascal has a precedent worth using when the time comes: a file variable
  is a handle whose lifetime a block manages, and ADR-0021 and ADR-0032
  already close files at block exit and on a non-local `goto`.
- **Nothing about ownership.** Every pointer here is the caller's own storage
  coming back, which is why there was nothing to decide.

## Alternatives rejected

**Waiting for the memory-safety model**, which is what three documents implied
was necessary. The distinction above is what makes it unnecessary, and it is
the same distinction ADR-0122 drew for the *argument* side — "a pointer
outlives the call, and an argument does not" — applied to a result that is an
argument coming home. Two records in a row have now found that a decision
described as needing the model needed it for only part of its surface.

**Answering `getcwd` as a bare `PathName` with a separate `ok`.** The optional
is the mechanism that already exists for exactly this and refuses to hand the
program anything on the failing path. A second shape would be ADR-0120's
finding — every fallible routine inventing its own way of saying so — repeated
after it had been settled.
