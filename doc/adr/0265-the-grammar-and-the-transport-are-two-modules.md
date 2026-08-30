# ADR-0265: HTTP's grammar and its transport are two modules

Date: 2026-08-30

## Status

Accepted. Completes ADR-0264, which landed TLS and closed saying `PasHttp`
still spoke plain HTTP only and naming this as the way to fix it.

## Context

`lib/dialect/pashttp.pas` was written against `PasNet.Socket`. `Send` called
`WriteText(s, …)` once; `Receive`, `ReadCounted` and `ReadChunked` called
`ReadLine(s, …)` at eight sites between them. Everything else in that module —
RFC 9112's start-line, its field lines, §6.3's six ways of knowing where a body
ends, §7.1's chunks, and every refusal in them — touches nothing at all.

ADR-0264 made a TLS connection available with the same line-oriented shape. So
HTTPS was 900 lines of parser away from working, and the question was where to
put the choice of transport.

### Importing `PasTls` into `PasHttp` was the obvious answer and is wrong

A module's activation is commenced before the program-block whether the program
reaches into it or not (ISO/IEC 10206:1991 §6.2.3.6), and an activation
procedure is an ordinary linked symbol. So a `PasHttp` that imported `PasTls`
would make **every program using plain HTTP link OpenSSL** — a cryptography
library, its two shared objects and its trust store, for a program fetching a
status page over a private network.

That is not a packaging inconvenience. `lib/dialect/README.md` records eleven
modules that reach outside the program and eleven that do not, and the line is
kept because a dependency a program did not ask for is one it cannot decline.

### A transport parameter was the other answer and this language refuses it

A procedural parameter (§6.7.3.4) cannot carry a handle, so `ReadLine` could not
be passed in. A variant record over the two transports needs both types
declared, which is the import above. There is no interface type in this dialect
and ADR-0201 declined to add one.

## Decision

**The grammar is exported, and each transport is a caller of it.**

`PasHttp` gains six routines and two types, and its own `Send` and `Receive` are
rewritten as the first caller:

    function  BeginRequest(protected var q: Request;
                           var w: RequestCursor): ErrorCode;
    procedure NextPiece(protected var q: Request; var w: RequestCursor;
                        var piece: string);

    procedure BeginResponse(var r: Response; method: MethodName);
    function  WantsLine(protected var r: Response): boolean;
    function  FeedLine(var r: Response; line: HttpPiece): ErrorCode;
    function  FeedEnd(var r: Response): ErrorCode;

A transport is then twelve lines each way, and `lib/dialect/pashttps.pas` is
those twenty-four lines over `PasTls`.

### The two sides are not symmetric, and the reason is which record is moving

The **response** side keeps its state in the `Response`, because that record is
being built: a phase, whether the method was HEAD, and the two counters chunked
framing needs. The **request** side takes a `RequestCursor` of its own, because
`Send` takes the request `protected` and state inside it would take that away.

`FeedEnd` is a routine rather than a flag on `FeedLine` because the far end
closing means three different things and only the reader knows which: before a
status-line it is `errAbsent`, there being no response rather than a bad one;
inside the header section or a chunked body it is `errSyntax`, a message that
stopped in the middle of itself; and in an uncounted body it is RFC 9112 §6.3's
rule 6 working exactly as intended, `errNone` with `byClose` set. Those three
answers were spread across `Receive`, `ReadCounted` and `ReadChunked` before,
which is why the split found them rather than inventing them.

`NextPiece` **spans** a piece across calls, so a caller's buffer bounds nothing.
That is what lets `PieceMax` be a fact about a request rather than a demand on a
transport, and it is the one behaviour the socket transport cannot exercise —
its buffer is larger than any piece.

### The duplication is refused with a reason

`PasHttps.Send` and `PasHttps.Receive` are the same loops `PasHttp.Send` and
`PasHttp.Receive` are. ADR-0116's rule is that one site is an anecdote and two
are a demand, and this is a case where the demand is declined: what the two
share is a **loop shape**, and factoring it out needs the transport abstraction
this language does not have and this record exists to avoid. What is not
duplicated is the part worth not duplicating — there is one parser, one set of
framing rules, and one place every refusal is written.

Twenty-four lines against nine hundred is the trade, and it is stated in the
module rather than left for a reader to notice.

### A collision the second module found

`PasTls` exported `HostMax`, `ServiceMax`, `LineMax`, `ReasonMax`,
`ProtocolMax`, `TrustMax` and `BufMax`. `PasHttp` exports a `ReasonMax` of its
own — RFC 9112 §4's reason-phrase against OpenSSL's diagnostic — so the first
program importing both would not compile, and `PasNet` collides with three
more. They are renamed `TlsHostMax` and the rest, which is `PasLsp`'s existing
convention (`LspBufMax`, `LspHeadMax`) and matches `PasTls`'s own types, every
one of which was `Tls`-prefixed already. Free to do: the module is unreleased.

The routine names are **not** disambiguated and must not be. `PasTls.ReadLine`
and `PasNet.ReadLine` are the same question of two transports, and a program
moving between them changing a variable's type and nothing else is the property
that makes the pair worth having. A program wanting both imports one
`qualified`, which is §6.11.2's own answer.

## Consequences

`tests/dialect/lib_http_grammar.pas` is the case the split exists for, and it
opens nothing: a request is rendered into a `string(7)` and printed, and a
response is fed a line at a time from an array in the program. It is also the
only case that reaches the grammar on a machine without OpenSSL.

The seven-character buffer is the mutation-relevant part. Making `NextPiece`
stop clipping to the room left leaves **`lib_http` green and fails
`lib_http_grammar`**: every piece fits in the socket transport's 4 096-byte
buffer, so the spanning is invisible there. Mis-numbering the trailing pieces —
dropping the skip past a `Connection` this module supplied — fails the new case
too.

`tests/checks/tls/tls_https.pas` is the other half, and the only place a second
transport is driven at all: a grammar that had quietly kept a socket in it would
pass everything else in this tree. It runs inside `tests/checks/tls.sh` and so
skips with that check, which is why the network-free case above is the one that
carries the grammar.

The TLS servers there moved from `s_server -www` to `-WWW` over a file the
harness writes. The status page `-www` generates lists the ciphers the library
was built with, is longer than `PasHttp`'s `MaxBodyLines`, and is OpenSSL's
text — all three are reasons a golden must not meet it.

`lib_http.pas` is unchanged and passes unchanged, over a `Receive` that is now a
six-line loop around a state machine. That is the evidence the refactor
preserved behaviour: that case covers a 200 framed by length, a POST answered
404, chunked framing with an extension and multi-line chunk data, a 302, a HEAD,
a body framed by the close, and five malformed responses.

### What it does not do

`PasHttps` opens nothing. `PasTls.Connect` is the caller's, as `PasNet.Connect`
is for the plain form, because a client handed an open connection can be pointed
at a proxy or a test server and this module has no business deciding.

There is still no way to write one routine that serves both transports. A
program that wants to be transport-agnostic writes the twelve-line loop itself
against whichever it holds, and that is the honest state of the language: it is
ADR-0201's absent interface type seen from a third direction, after ADR-0146's
shared predicate and ADR-0125's slice.
