# 203. A socket is a handle, and both ends are strings

Date: 2026-08-25

## Status

Accepted. `lib/dialect/pasnet.pas`, the thirteenth dialect module, and the
last row of `doc/roadmap.md`'s *what a daily program wants*.

## Context

Networking is the first of ADR-0109's four goals and the only one with no
module. The roadmap has carried the row since ADR-0184 unblocked it:

> **unblocked**: `sockaddr` is a caller-owned struct and crosses as a `var`
> parameter. What is left is a module and a decision about what a portable
> `sockaddr` declaration looks like, `struct stat` having shown that a
> hand-written field list is one platform's layout — not a language gap.

That framing is right about the language and wrong about the destination.
ADR-0185's fifth decision is categorical: a **library** may not declare a
foreign struct at all, because it has to work where nobody here can build it
and `foreign-layout` can only check a program. So the question is not what a
portable `sockaddr` declaration looks like — there is not one — but what the
module asks for instead.

## Decision

**A socket is a handle, and the runtime owns the object.**

A descriptor is an `int`, and AP 6.4.2.6.2 makes an integer numeric on
purpose, so a program holding one could add to it, copy it and close it
twice — the door ADR-0151 records as open and unclosable for `int64`. So
`pasx_socket_*` keeps the descriptor in a structure of its own and Pascal
holds `Socket = handle external 'pasx_socket_close'`: no copy, no comparison
but with `nil`, closed when the variable holding it dies, and closed early by
`s := nil` (ADR-0202, landed the same day and used here immediately).

**Both ends of every call are strings, and that is what shrinks the port.**
A host and a *service* — a name like `http` or a number written out — go to
`getaddrinfo`, which decides what they mean. So nothing in the module or the
runtime names an address family, a port number, an address or a byte order:
no `sockaddr`, no `htons`, no `sin_port`, no choice between IPv4 and IPv6. The
loop takes the first address that works, so a caller gets IPv6 where it exists
and IPv4 where it does not, without a line about either.

Two consequences fall out that were not the reason:

- **`<netinet/in.h>` and `<arpa/inet.h>` are not needed.** `runtime-isoc`
  bounds `pasrt_posix.c` by its headers (ADR-0186), and this adds **two**:
  `<sys/socket.h>` and `<netdb.h>`.
- **An ephemeral port is expressible.** Ask to listen on service `'0'`, then
  ask `Service`, which answers the numeric string `Connect` takes back. A
  program can talk to itself without a number type ever being involved, which
  is the whole of what the test needs.

**Reading is by line, and the buffer is in the runtime.** A socket delivers
whatever arrived; a Pascal program wants a line. `PasStream` gets that from
`FILE *` and a socket cannot: a stream opened for update over a descriptor
that cannot seek may not switch between reading and writing without a
file-positioning call. So the buffering is forty lines of C rather than a trap
for whoever writes the first program that reads and writes on one connection.

**SIGPIPE is ignored, once, where a socket is first made.** Writing to a
connection the far end has closed raises it, and its default disposition ends
the process with no diagnostic — which is not an outcome a routine answering
an `ErrorCode` can report. `signal` is ISO C; `MSG_NOSIGNAL` and
`SO_NOSIGPIPE` are one system's each.

## Consequences

**`lib/dialect/` is thirteen modules**, ten of them bindings. `PasNet` takes
the `ErrorCode` shape throughout, which is `lib/dialect/README.md`'s commonest
of four, and it distinguishes two failures where a caller acts on the
difference: `errAbsent` for a host or service that resolves to nothing, and
`errIO` for a machine that would not talk.

**`tests/dialect/lib_net.pas` talks to itself, and it has to.** A test needing
a second machine, or a server left running, would be a test of the
environment. The listening socket and the connection to it live in one
activation, which works because `listen` completes the handshake in the
backlog before anything calls `accept` — so one thread of control can be both
ends. That is also the module's honest limit, stated in its own header.

**Three mutations kill it**, and the sharpest is the signal: dropping
`signal(SIGPIPE, SIG_IGN)` ends the program with **exit 141** where the golden
has an `ErrorCode`, which is precisely the outcome the line exists to prevent.
Confusing `errAbsent` with `errIO` fails the last two lines, and answering a
line that does not fit rather than `errFull` fails the short-string block.

**No port number is in the golden.** The program asks for `'0'` and prints
that a port was given, never which; a golden naming one would fail on a
machine where something else held it.

**`doc/sop.md` §7 gains a row.** This is the first case here that needs a
working loopback interface, and it fails rather than skips without one — where
`unicode-conformance` and `target-sizes` skip when what they need is absent.
It is not given a skip: a case that quietly does nothing is what that whole
section exists to make visible, and a machine that cannot connect to itself is
a machine where this module does not work.

## What this does not do

**No datagram socket, no timeout, no half-close, and no way to wait on several
connections at once.** The last is the one that matters and it is
ADR-0201's: a program serving two clients at a time needs a construct this
language has not got, and the cheaper answer — `select` — is what should be
tried before any of it. Everything here is written for one connection at a
time, and a server that accepts, serves and closes in a loop is what it is
for.

**No TLS, and no name for one.** That is a library over a library and would
need a second dependency this repository has no way to bound.

**It does not close ADR-0151's `int64` door.** A program may still declare
`function connect(...): int64; external` and hold a descriptor as a number.
What this offers is somewhere better to go.

## Alternatives rejected

**Declaring `struct sockaddr` in the module and crossing it as a `var`
parameter**, which AP 6.7.7.6.2 admits and which the roadmap's row assumed.
ADR-0185's fifth decision forbids it for a library, and sockets are the
strongest case for that decision rather than an exception to it:
`struct sockaddr` is not one struct but a family, a program never declares the
one it is actually using, and `sockaddr_in6` differs from `sockaddr_in` in
size as well as in layout.

**Handing the descriptor to Pascal as an `integer`.** Simplest, and it makes
every property the handle-type exists for absent at once — ADR-0151 wrote out
what that costs for `int64` and there is no reason to repeat it deliberately.

**Reusing `PasStream` by `fdopen`ing the descriptor.** It would have cost no
buffering code, and it puts a read-write trap under the first program that
uses one connection both ways. A socket is not a file and the module says so.

**A `select`-based readiness call in this increment.** It is what turns this
into a server that serves more than one client, and it is a different shape —
a set of sockets, a timeout, and a question about which are ready. It waits
for a program that wants it, which is ADR-0116's rule and the one ADR-0201
just applied to concurrency itself.
