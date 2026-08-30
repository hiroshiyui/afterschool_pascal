# 252. The answer is cached against the document

Date: 2026-08-30

## Status

Accepted, 2026-08-30.

It is the cheaper answer the concurrency row asks for before a construct, and
it is the second time that row has been answered by trying one:
[ADR-0201](0201-a-borrow-cannot-outlive-a-call.md) said *"a socket module
serving more than one client is what would demand it, and `select` is the
cheaper answer to try first"*, and `poll` was enough
([ADR-0205](0205-a-server-that-serves-more-than-one-client.md)).

## Context

`textDocument/definition` and `textDocument/hover` are answered from
`--dump-uses` ([ADR-0246](0246-what-a-name-denotes-and-where-it-was-written.md)),
and each request ran the compiler. That is the right shape and the wrong
frequency: an editor sends a hover on every pause of the pointer, and a reader
asks far more often than they type.

**The numbers had never been taken.** The roadmap's concurrency row says a
program that would demand a concurrency construct is *now named* — this server,
where a `didChange` arrives while a compile is in flight — and that the row is
"one increment away from having a caller instead of a candidate". It said so
without a measurement. Taking one, against `selfhost/apfront.pas` at 22 900
lines and driven by an independent client:

| | before |
| --- | --- |
| `didOpen` to diagnostics | 162 ms |
| one hover | 159 ms |
| five sequential hovers | 795 ms |
| five **pipelined** hovers | 800 ms |
| a `didChange` behind work in flight | 933 ms |

Two things are in that table. Pipelining buys **nothing** — the server is
strictly serial, which is what the row already said. And five hovers on
unchanged text cost five compilations, which the row had not said and which is
the larger number by far.

## Decision

**A document owns the last `--dump-uses` taken of it.** `Document` gains
`uses_`, filled where a definition or a hover first needs it and freed
wherever the text is replaced — `Store`, `Forget`, and the release at exit,
which are the only three places a document's text goes away.

Invalidation is a property of the record and not of a caller: nothing asks
"is this still valid", because the field is nil exactly when it is not.

## Consequences

**Five sequential hovers: 795 ms → 106 ms.** One hover is unchanged at 158 ms,
which is right — the first question after an edit compiles, and the four after
it do not.

**The outline is deliberately not cached.** It comes from `--dump-symbols`,
which stops after the parse and is a different flag; and an outline is asked
once per open where a hover is asked continuously. Caching it would be storage
against a question nobody repeats.

**`heap-balance` caught what the goldens could not.** The cache made the
server keep five heap lists it never gave back — one per document a session
opened and never closed, which is what an editor does when it is killed. Every
session golden was byte-for-byte correct throughout, because what leaked was a
list nobody printed. That is the third defect this chapter has shipped which
only that gate could see (ADR-0183, ADR-0246).

**The existing sessions could not have caught a stale cache**, and finding
that out is worth more than the case that fixes it. `definition.jsonl` already
had a `didChange` followed by requests — but the edit changed a line whose
answers do not move, so a cache that was never invalidated would have matched
the golden exactly. A step was added where `Counter` becomes `char` and the
hover on `Total` must say `var Total: char`; mutating the invalidation away
makes it answer `null`. **A `didChange` in a golden is not a test of
invalidation unless the answer it precedes actually changes.**

**What it does not do is move the concurrency row.** A `didChange` still waits
933 ms behind an outline in flight, because the server still compiles
synchronously. What the measurement says is that the *frequent* cost was never
concurrency — it was recomputation — and the remaining cost is a second
cheaper answer away: the server already has `PasNet.Wait` over `poll`
(ADR-0205), and a `Capture` that polled the child's pipe **and** standard input
could abandon work made stale by a newer message without a task construct at
all. That is what most language servers do, and it is what should be tried
before ADR-0201's construct is built.

## Alternatives rejected

**Caching the compiled IR or the diagnostics instead.** Diagnostics are
published on `didChange`, which is exactly when the cache would be invalid, so
there is nothing to reuse. The dump is the only answer asked repeatedly of one
unchanged text.

**A cache keyed by document version rather than emptied on write.** It is the
same thing with a comparison in front of it, and the comparison is a second
place for the truth to live — the shape ADR-0111 rejected for the string
arena's counter and ADR-0246 rejected for a walk over the tree.

**Building the concurrency construct.** ADR-0116's test is a demand, and the
measurement is what says there is not one yet: the cost a reader actually pays
fell 7.5× without touching the language, and the cost that is left has an
untried cheaper answer in front of it.
