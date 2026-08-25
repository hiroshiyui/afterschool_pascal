# 205. A server serves many clients, and the language needed nothing

Date: 2026-08-25

## Status

Accepted. `PasNet.Wait`, `lib/dialect/pasnet.pas`, and the first of the two
rows ADR-0203 left behind it.

## Context

ADR-0203 landed a socket and said in as many words what it could not do:

> **No datagram socket, no timeout, no half-close, and no way to wait on
> several connections at once.** The last is the one that matters and it is
> ADR-0201's: a program serving two clients at a time needs a construct this
> language has not got, and the cheaper answer — `select` — is what should be
> tried before any of it.

`doc/roadmap.md` carried that as two live rows, and put a second one in front
of it: *of the three affine kinds only `owned ^T` moves*, so a socket cannot
be returned from a function of this language or handed to anything, and a task
could not be **given** a connection. That row said it stood between the
language and a multi-client server.

**It does not, and the way that was established is the point of this record.**
The work began by writing the server rather than by designing the feature —
`doc/sop.md` §4a, *a feature with a surface needs a client, not a case* — and
the client compiled. An array of handles is admitted (AP 6.4.12 NOTE 3), a
`var` parameter binds to one of its elements, so `Accept(srv, clients[k])`
puts a connection in a slot without anything being copied, and `clients[k] :=
nil` releases one (ADR-0202). A schema gives the array whatever length the
program wants, and the discriminant is the count. Nothing had to move, because
nothing was ever assigned: **a handle reaches its home by being the `var`
parameter the producer writes through**, and a server never needs a second
name for one.

So the only thing missing was the answer to *which of these can I read
without blocking*, and a probe pinned that exactly: two clients connect, the
second speaks, the server reads the first — and the program hangs.

## Decision

**One call, and nothing is held between calls.**

```pascal
type SocketList(n: integer) = array [1..n] of Socket;

function Wait(var socks: SocketList; timeoutMs: integer;
              var ready: array of boolean): ErrorCode;
```

`ready[k]` is set for each socket that can be read, or accepted from, without
blocking, and cleared for every other — including the empty slots, which are
never ready. A **listening** socket in the list is ready when a connection is
waiting, so `Accept` and `ReadLine` are answered by the same call: to `poll`
they are one question, and a server is then an ordinary loop.

Four things about the shape, each of which was a decision:

**1. There is no set object, and that is the safety argument rather than a
simplification.** The obvious API is C's — a set built up, waited on, and
asked about — and it would make the set a **second name** for every socket in
it, held across statements, dangling the moment a program wrote `clients[k] :=
nil`. That is ADR-0151's aliasing question arriving through the library door.
Building the list inside one call retires it the way ADR-0187's copy retired
an address: *an ownership question is only a question while something holds
the address*, and between the call's first statement and its last nothing can
close a socket, because every statement in it is this module's.

**2. An empty slot is a hole, not something to compact.** POSIX has `poll`
ignore a negative descriptor and zero its `revents`, so a server that closes a
client leaves a gap and needs no bookkeeping. That is a property of the far
side taken whole, which is [the open questions](../roadmap.md)' advice about
where a dialect feature should look for its authority.

**3. `poll` and not `select`.** The roadmap said "select" and meant the shape.
`select` would have cost `fd_set`, `FD_SETSIZE` and four macros for the same
answer, and `FD_SETSIZE` is a bound this module would then have inherited and
had to explain.

**4. A socket holding a line the runtime has already read is ready, and the
operating system cannot say so.** `ReadLine` buffers (ADR-0203), so a client
that sent two lines in one write leaves the second in `struct pasx_socket` with
the descriptor quiet. A readiness call that asked only `poll` would leave a
server sitting still holding a line it had been handed. So readiness is two
questions — the buffer, in C the compiler can see, and the descriptor — and
this is why `Wait` is a call of this module rather than a binding to `poll`.

**The descriptor becomes a number in exactly one place**, `ExtFd`, which is
not exported. What ADR-0203 refuses is a *program* holding one, AP 6.4.2.6.2
making an integer numeric so that a program could add to it, copy it and close
it twice; inside one call, in an array handed straight back to the runtime, it
is what C would have anyway.

## Consequences

**No language change, no clause, and no seed question.** The fifth estimate in
a row that this page was wrong about in the useful direction, and the second
where the answer was that the feature already existed in pieces. AP gets
nothing: `Wait` is a library routine over AP 6.4.12, AP 6.4.8's schemata and
ADR-0125's slices, and a specification clause for it would be a clause about a
module.

**ADR-0201's construct is not nearer, and its trigger is gone.** ADR-0201
named "a socket module serving more than one client" as what would demand
share-nothing concurrency. That module now exists and demands nothing: the
cheaper answer was tried first and was enough, which is what ADR-0201 said to
do. What a *thread* would still buy is a slow client not slowing the others,
which is a different sentence from the one the roadmap has been carrying.

**The handle-move row loses its stated client and keeps its argument.** It was
entered because a task cannot be given a socket. No task exists, and a server
does not need one, so the row goes back to what AP 6.4.14 NOTE 5 already said
— it waits for a client — rather than standing in front of anything.

**`<poll.h>` joins `tests/checks/nonstandard_c.txt`**, the sixth header and
the third for sockets. It is a *type* dependency for ADR-0186's reason: ISO C
cannot ask whether a descriptor is readable, and `struct pollfd` is a struct a
program would otherwise have to declare.

**The dialect corpus gets a `TIMEOUT`.** A readiness defect makes a server
*block*, and three of the four mutations below fail by printing something
while one hangs. `tests/dialect/` is the only corpus here that can open a
socket, so a hang there had nothing bounding it but ctest's default; 300
seconds is a backstop against a case that runs in a fifth of a second.

**What is still not pinned**, and it is worth naming because a whole gate
family here exists for this shape: nothing checks that a *listening* socket in
the list is what makes `ready[1]` true rather than some other property of slot
1 — the case has one listener and it is in slot 1 every time. A second
listening socket would be the client that settled it, and no program here has
one.

## What was measured

Four mutations of `runtime/pasrt_posix.c`, each restored and **rebuilt**
before the next:

| mutation | outcome |
| --- | --- |
| the buffered half never fires | fails, 7 s |
| `poll` reports nothing ready | fails, 2 s |
| an empty slot is reported ready | **hangs**, killed at 100 s |
| the timeout is ignored (`poll(…, 0)`) | fails, 1 s |

The fourth is why the case opens with an idle wait against §6.7.6.9's clock:
every other assertion in it is satisfied by a `Wait` that never waits, both
ends being in one program so that whatever was written has already arrived. A
server whose readiness call did not wait would burn a processor and print the
right answers.

**And the harness caught one of its own.** The first run of that idle wait
answered *it did wait: FALSE*, which was read as a defect in `Wait` and was
the restore from the previous mutation: the file was copied back and its mtime
touched, and nothing rebuilt the library. One golden had already been taken
against the mutant. `doc/sop.md` §7's mutation row says a restore must not
preserve mtime; it now says the restore must also rebuild, which is the same
mistake one step further along.

## Alternatives rejected

**A `SocketSet` handle**, C's shape transliterated: `Clear`, `Watch`, `Wait`,
`Ready`. It reads well and every parameter is a lend AP 6.4.12.4 admits. It
puts a second name for a live socket in the runtime across statements, which
is decision 1 above, and it would have been the first place in this library
where closing a variable could leave something else dangling.

**A global watch list in the runtime**, which avoids the type and has the same
aliasing property plus one more: ADR-0201's construct is share-nothing, and a
global would be the first thing such a construct had to unpick.

**Waiting on one socket at a time with a zero timeout**, polled round-robin.
No new array shapes, and it busy-loops — the defect mutation 4 exists to catch,
written in deliberately.

**Passing the sockets to the runtime as a slice.** `array of Socket` is
refused, correctly: ADR-0150's `ContainsFile` reaches a handle, and a slice is
storage a callee may write. The refusal was the first thing the probe found
and it is why the parameter is a schema.
