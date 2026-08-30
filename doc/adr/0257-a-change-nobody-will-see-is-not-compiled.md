# 257. A change nobody will see the answer to is not compiled

Date: 2026-08-30

## Status

Accepted, 2026-08-30.

It is the fourth answer to `doc/roadmap.md`'s concurrency row — after `select`
for the sockets ([ADR-0205](0205-a-server-waits-on-many-sockets.md)) and the
document cache ([ADR-0252](0252-the-answer-is-cached-against-the-document.md))
— and it closes the 933 ms that row named as what was left.

## Context

The concurrency row has proposed a construct three times and been answered by
something cheaper twice. ADR-0201 decided what a construct must be —
share-nothing, a task owning what it is given — and declined to build it;
ADR-0205 met the trigger it named with `poll`; ADR-0252 measured the row for
the first time and found the expensive-looking sentence was not where the time
went.

What ADR-0252 left was one number. Against `selfhost/apfront.pas` at 22 900
lines, a `didChange` arriving behind work in flight waited **933 ms**. The
sketch in front of it was a `Capture` that polls the child's pipe and abandons
work a newer message has made stale — single-threaded, which is what most
language servers do. That sketch was costed and found to run into ADR-0174's
own decision: `PasProcess.Pipe` is `handle external 'pclose'`, opaque by
design, so no program can get a descriptor out of one to poll.

## Decision

**The server drains the messages that have already arrived, and keeps only the
last `didChange` per document.** Nothing waits, no construct is added, and the
compiler is not touched.

A keystroke is a `didChange` carrying the whole document (this server is
full-sync), so when two of them for one file are already queued, compiling the
first is work whose answer is stale before it could be published. The drain
reads what is *there* — never waits for more, which would be a policy about a
client's typing speed rather than a fact about the queue — and stops at the
first message that is not a change of the same file. That one is held and
dispatched next, so ordering is exactly what the client sent.

Three pieces, and two of them are general:

- `pasx_fd_ready(fd, timeout_ms)` in `runtime/pasrt_posix.c`. `poll` on one
  descriptor. `pasx_socket_poll` answers the same question for a list and its
  contract is a pair of slices whose lengths must agree, which is right for a
  server holding many sockets and an awkward way to ask about standard input.
  No new header — `<poll.h>` has been in ADR-0186's catalogue since ADR-0205.
- `PasIO.FdReady`, over it.
- `PasLsp.LspPending`, which is `pasx_socket_pending`'s two-halves shape for
  the reason ADR-0205 gives: bytes already taken off the descriptor are bytes
  the descriptor no longer has, so `poll` alone would say "nothing there" about
  a frame sitting in the reader's own buffer.

**Standard input was never the obstacle.** It was worth checking before
anything was built, and the answer was that `pasls` reads descriptor 0 through
`PasIO.ReadInto` and declares no program-parameters at all — so the pipe was
the hard half and stdin the easy one, which is the reverse of what a reading of
ADR-0174 suggests.

## Consequences

**Measured: four queued edits of a 22 900-line source, 780 ms → 340 ms**, and
five `publishDiagnostics` become two. The reader's own wait falls further than
that, because the change they are waiting for is now compiled *first* rather
than fourth.

**And the cancellation that is still not built now has a number against it,
which is the result worth keeping.** What is left after this is a compile
already in flight, which the drain cannot abandon — one compilation, about
170 ms, once at the end of a burst. The roadmap named three routes to it and
called one of them small: a `pasx_` routine polling the pipe on the far side,
where the runtime holds the `FILE *` and can `fileno` it.

That route requires the stream to be unbuffered, and this is where the estimate
breaks. `poll` sees the *descriptor*; a `FILE *`'s buffer is libc's and ISO C
and POSIX give no way to ask how much it holds, so a bare `poll(fileno(f))` is
wrong exactly as often as the socket case would have been without
`pasx_socket_pending` — which is ADR-0205's decision 4 met a third time, with
no `pasx_` counter available because libc owns the buffer. `setvbuf(f, NULL,
_IONBF, 0)` makes `poll` the whole truth and makes every `getc` a `read(2)`.

Measured on the dump a hover actually reads — `--dump-uses` over
`selfhost/apfront.pas`, 1 555 350 bytes:

| reading that dump through a pipe | time |
| --- | --- |
| buffered, as `Collect` does today | 5 ms |
| unbuffered, as the polled route needs | 621 ms |

So the cheapest form of the remaining work would cost **124 times** what it
could save, on the operation a reader performs most. The correct form is the
other one — moving the buffer into C as `struct pasx_socket` does, about
80 lines and a change to `Pipe`'s closer — and it is not built, because
ADR-0116's test is a demand and what is left to demand it is 170 ms once per
burst.

**The row is teaching a rule and this is its fourth confirmation**: *measure
the cost before naming the mechanism.* Three times running the expensive-
looking sentence was not where the time went, and this time the cheap-looking
route was the expensive one.

**A collision worth recording.** `PasIO`'s new export was called `Ready` for an
hour, and `PasLsp` then refused to compile: §6.11.3 binds an imported
constituent into the importing block's scope unqualified, and that module has a
private `Ready` of its own. `only` would have hidden it. Renaming the export to
`FdReady` is the fix, and it is the same finding the language server's
usability pass made from the other side — a generic name costs the most in a
library export, because every importer pays for it.

**What the harness cannot see.** Its standard input is a regular file, and
POSIX makes `poll` report a regular file ready always, including at end of
input. So every session here exercises the drain on every adjacent pair of
messages, where a real editor over a pipe exercises it only when messages
genuinely queued. That makes the goldens *stronger* than the real case rather
than weaker, and it is why `LspPending` is documented as a permission to try a
read and never a promise that one will yield a frame.

**`diagnostics.jsonl` was reordered rather than regenerated.** It had two
adjacent `didChange` messages and its job is to pin what a diagnostic looks
like after each edit; with the drain, the first of them stopped publishing. The
request that was already in that session now sits between the two edits, so
every publish it asserted is still asserted and no coverage was traded for the
new behaviour. `coalesce.jsonl` and `coalesce_distinct.jsonl` are where the
drain itself is pinned, and each kills a different mutation — dropping the
drain, and coalescing across documents.
