# ADR-0380: The target is POSIX

## Status

Accepted. Supersedes [ADR-0374](0374-windows-runs-and-is-deferred.md), which
deferred Windows; this drops it. ADR-0369 through ADR-0373 stand as the record
of what was measured and are not superseded — what they *found* is still true
and is why this decision can be taken with its cost known.

## Context

This is a hobby project, and its owner has narrowed its scope: **the target is
POSIX**. x86-64 and aarch64 keep their present standing, macOS is POSIX and is
untouched, and Windows goes.

Windows did not fail. It was measured, in five records over three days, and
the measurements were good: `runtime/pasrt.c` and `runtime/pasrt_unicode.c`
compiled for mingw-w64, `pasrt_task.c` wanted only a modern C runtime,
`llc -mtriple=x86_64-w64-windows-gnu` assembled the module to COFF, and
`tests/hello.pas` **ran under wine and printed its golden**. ADR-0374 deferred
the platform on one remaining defect — the jump record sits at a frame offset
of 136, and Win64's `_setjmp` stores XMM6–15 with an aligned `movdqa`, so the
non-local goto faults.

What follows is not that the defect is unfixable. It is that fixing it means a
frame-layout change compared across every admitted target, and behind it seven
headers of winsock with its own initialisation and error convention, `WSAPoll`
for `poll`, no `posix_spawn`, and CRLF making the corpus goldens
incomparable — **a body of work for a platform nobody here runs**, in a
project whose stated policy is what a program someone would actually write
needs (ADR-0109).

## Decision

**`--target=` admits five triples and every one of them is POSIX**:
`x86_64-pc-linux-gnu`, `aarch64-linux-gnu`, `i386-pc-linux-gnu`,
`arm64-apple-macosx`, `x86_64-apple-macosx`. `x86_64-w64-windows-gnu` and its
three other spellings are removed.

**Three things go with it, and each makes a claim here simpler rather than
weaker.**

- **`CLongSize` has one arm again.** Win64 was the only LLP64 target — eight-byte
  pointers with a four-byte `long` — and the only reason that function could not
  be a question about the pointer. It is asked separately still, because the two
  *did* come apart once and ADR-0328's `clong`/`csize` are what made that one
  line rather than an audit.
- **`_setjmp` has one shape again.** ADR-0371 gave `JumpDispatch` and its
  `declare` an arm apiece keyed on the target, because Win64's `setjmp` macro
  expands to `_setjmp((x), frame)` and unwinds through SEH. Every remaining
  target takes the buffer alone.
- **The runtime holds no preprocessor conditional.** ADR-0373's `_WIN32` arm
  around `PAS_LONGJMP` was the only one in four translation units, and
  `nonstandard_c.txt`'s conditional catalogue is now **empty** — which is a
  claim `runtime-isoc` checks in both directions, not a silence.

## Consequences

**The cost is recorded rather than hidden, and it is one row going backwards.**
`runtime/pasrt.c` now names `_longjmp` unconditionally, so it no longer
compiles for mingw-w64, and `nonposix_headers.txt` says `unit pasrt.c blocked`
where it said `compiles`. That catalogue exists precisely so a port cannot
regress quietly; here the regression is deliberate and the row carries the
argument. `runtime-nonposix` keeps its toolchain and its question — *is this
runtime portable to a target that is not POSIX* — because the question is
about the **runtime**, not about a target this compiler admits.

**Two `doc/sop.md` §7 rows are struck**: the Win64 jump-record alignment, and
`ExtFd`'s meaning on a platform whose socket is not a descriptor. Both move to
`doc/history.md` whole. The alignment finding is the more valuable of the two
and it is *why* it is kept: it was proven in isolation — a `jmp_buf` by hand at
offset 16 works and at 136 faults at the same instruction — and aligning the
frame is not the fix.

**`setjmp-arity` loses its floor and keeps its claim.** It demanded *two
distinct arities* among the compared targets, which was the discriminating
claim while a target had the other one. Its own comment named this: *"If a
target with the other arity was removed, this check goes with it."* It does
not go. What it holds is each target against **its own header**, which is the
half that was always load-bearing — a sixth target whose `setjmp` disagrees
would otherwise be admitted with no diagnostic anywhere, LLVM not comparing a
direct call against its declaration under opaque pointers.

**A gate's own reporting arm was found dead by this change.**
`runtime_nonposix.py` prints the first lines of a blocked unit's diagnostic so
a reader learns *why*; the condition compared a `(status, macro)` pair against
the string `"blocked"` and had therefore never printed anything since the gate
was written. It surfaced because a unit went backwards on purpose and the
reason was not shown. The comment above it said *a reader wants to know why* —
a comment describing a mechanism that was not there.

**What is kept.** ADR-0369 to ADR-0374 stay, and `doc/roadmap.md`'s Windows
row — a measurement somebody took by hand, against a named toolchain, on a
named date — moves to `doc/history.md` whole rather than being deleted. A
contributor who wants Windows starts from a page of measurements and not from
nothing, and `README.md` goes on saying that practical compatibility work is
welcome from anyone who wants to run it there.

## Alternatives rejected

**Keep Windows deferred.** The state ADR-0374 left, and it costs something
every week: four spellings in `TargetIndex`, a datalayout arm, two `_setjmp`
arms, a conditional in the runtime, a dump case, two §7 rows, and a
`CLongSize` that cannot be simplified. Deferred means *nobody is working on it
and everybody maintains it*.

**Keep the target and drop only the runtime's conditional.** That is the state
this change passes through and it is incoherent: the compiler would emit a
module for a platform whose C library the runtime refuses to compile against.
One or the other, and the decision is which project this is.

**Delete the Windows work.** The measurements are the most valuable thing
Windows produced here — the arity difference, the alignment fault proven in
isolation, the header inventory, the emulated-TLS trap, CRLF. Deleting them
would make a future port repeat three days of work to learn the same things.
