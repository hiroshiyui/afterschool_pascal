# 276. A clamp nobody honoured, and a bound nobody measured

Date: 2026-08-31

## Status

Accepted, 2026-08-31.

## Context

`doc/roadmap.md` asked for `--dump-uses --at line:col`, on the ground that

> A hover costs 1 599 325 bytes and 38 519 lines of dump to answer one
> question, which the server then scans linearly.

The first step was to measure it, and the measurement went somewhere else. A
driver that opens `selfhost/apfront.pas` in the language server and hovers
produced

    runtime error: array index out of bounds (1..1000000)

Bisected by size, the server **stopped on any document of 1 000 000 bytes or
more**, and the mechanism is three lines of `lib/dialect/pascontainer.pas`:

- `CapMax = 1000000`, whose comment states the policy: "A request above it is
  clamped rather than trapped, because a library that halts is a library that
  cannot be tested."
- `Claimed` honours that, returning `CapMax` for any larger request.
- `VecPush` did not. `if v^.n = v^.cap then VecReserve(Ptr, v, v^.cap * 2)`
  and then `v^.n := v^.n + 1; v^.a[v^.n] := x` — so at the ceiling the reserve
  gave back a vector of the same capacity and the element was written one past
  the array.

`JsonChars` is `^Vec(char)`, and its own comment said a document larger than
`LineMax` "goes through `JsonChars`, which has **no bound**". It has one, and
past it the program stopped.

`PasStrVec` is the other growable vector here, written for the same job by the
same hand, and it has had the guard from the beginning:

    if v^.n < v^.cap then begin v^.n := v^.n + 1; v^.a[v^.n] := s end

So the policy was stated in one module, implemented in the other, and the two
were never compared.

There was a second defect underneath. `VecReserve` asked `want > v^.cap`,
which is true of *every* request once the capacity is clamped — so a vector at
the ceiling reallocated and copied a million elements on every push. With the
out-of-bounds write fixed, a 2 MB document simply never finished arriving.

And a third thing, which is not a defect but a bound nobody had measured
against anything. `selfhost/apfront.pas` is 992 056 bytes and **1 017 200 as a
JSON string** — so even with both defects fixed, the language server could not
open the largest source in the tree it was written for.

## Decision

**`VecPush` writes nothing it has no room for.** A full vector keeps what it
has, and `VecFull` — exported — is how a caller asks. `PasStrVec`'s shape,
adopted.

**`VecReserve` asks `Claimed(want) > v^.cap`**, which is the question it meant:
would the vector actually be bigger?

**`PasJson` exports `JsonCharsFull`**, and the comment that claimed no bound
says what the bound is. A caller "never names `Vec` and never imports
PasContainer", so the eighth routine belongs there.

**`LspRead` and `JsonlRead` return `errFull`** for a body that did not fit,
which is this library's answer everywhere else a bound is met. The framed
transport compares the length it stored against the `Content-Length` it was
promised; the line transport asks the buffer, having no count. **Every
promised byte is still consumed**, so the stream is left where the next header
begins.

**The server skips that frame and carries on.** One message lost, with
`a message was larger than this server can hold, and was skipped` on standard
error, rather than a session ended — which the reader's other errors still do,
because they leave the stream nowhere in particular.

**`CapMax` becomes 16 000 000**, and it is now stated in *elements* with the
measurement beside it: 15.7 times the largest message this tree can produce,
and 16 MB for the `Vec(char)` that is `JsonChars`. The old number was round
and nothing had ever been compared against it.

## Consequences

**The server opens the compiler's own largest source.** An 8 MB message is
skipped in 52 ms with the session intact; 992 056 bytes is an ordinary
document. Before this it was a crash, and for the eight thousand bytes between
992 056 and a megabyte it had been a crash *waiting for the file to grow*.

**A clamp is now askable.** `VecFull` and `JsonCharsFull` exist because a
clamp nothing can ask about is a silent truncation, and this library's rule
where `NameMax` is declared is "`errFull` rather than a silent truncation past
this". The clamp was there; the question was not.

**`tests/dialect/container_ceiling.pas` is the case**, and it checks four
things because four were wrong: that filling past the ceiling does not stop
the program, that the kept prefix is what was written — a tail lost and not a
corruption — that `VecFull` says so, and that a push at the ceiling is cheap.

The fourth is the one a golden cannot see, and it is why the case pushes
200 000 elements past the ceiling rather than a handful. Restoring the
unguarded `VecPush` traps on the first push past the ceiling and the case
fails at once. Restoring `VecReserve`'s `want > v^.cap` produces **byte-identical
output**, only slower — 10 s against 40 ms at a thousand extra pushes, which
is a mutation a golden passes. At 200 000 the two are four orders of magnitude
apart: constant-time per push with the fix, linear without it, so the run goes
from 40 ms to over half an hour and the corpus's 300-second backstop reports a
failed case. A duration is a fact about the machine that took it (ADR-0270),
which is why the gap is *arranged* rather than measured.

**Raising `CapMax` changes what a runaway costs.** It bounds elements, not
bytes, so a `Vec` of large records now stops sixteen times later than it did.
Nothing here pushes records in those numbers, and `VecFull` is what a caller
that might should ask.

**The roadmap's `--at` item is closed by the same measurement, and not by
code.** `--dump-uses` over `apfront.pas` is 170 ms piped and 170 ms discarded
— writing and transferring 1.6 MB is *within noise* — because the 170 ms is
Sema, and the flag stops there rather than running the code generator, which
is why it is half of a 345 ms compile. So `--at` would save no compiler time
at all. What it would save is the server's parse of 38 569 lines into
259-byte slots and the ~10 MB that holds, and what it would **cost** is
ADR-0252's cache: the dump is kept per document precisely so that the second
question is free, and a query narrowed to one position cannot be cached. The
item's premise — "nobody chose that" — is wrong; it was chosen, and measured
at five hovers on `apfront.pas` going from 795 ms to 159. The roadmap now
carries the numbers instead of the proposal.

## Alternatives rejected

**Trapping in `Claimed`.** The policy where `CapMax` is declared is explicitly
against it, and the reason given is good: a library that halts cannot be
tested. The defect was never the clamp.

**`VecPush` returning a boolean.** It would make every caller say whether it
cared, which is the honest signature — and it changes 40-odd call sites in
five modules to answer a question all but two of them cannot reach. `VecFull`
puts the question where the callers that can reach it are.

**Leaving `CapMax` at a million and letting the server refuse a large
document.** That is a working editor for every file except the ones this
project's own compiler is written in. The number was never a measurement, so
there was nothing to defend.

**Building `--dump-uses --at` anyway.** It is a real narrowing of a real dump,
and the measurement says it buys nothing a cache does not already buy and
gives up the cache to get it. If the dump's *memory* becomes the complaint,
the answer is a tighter representation of the cache — the longest `use` line
in this tree is 62 characters and each is held in 259 bytes — and not a
per-position query.
