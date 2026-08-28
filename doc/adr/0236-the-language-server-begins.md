# 236. The language server begins

Date: 2026-08-29

## Status

Accepted, 2026-08-29.

It supersedes nothing. It is the first increment of the program
[`doc/roadmap.md`](../roadmap.md) has proposed since before v3 as **the
caller** — and it is the first program in this tree written to be *used*
rather than to be tested.

## Context

Every client of this dialect so far has been a library module or a test case.
ADR-0116's discipline says a feature must be demanded by something, and it has
held — `take` (ADR-0182), `h := nil` (ADR-0202) and the element walk
(ADR-0199) were each shaped by the client written beside them. But a module is
small, single-purpose, and written by whoever was already holding the feature,
and none of them can answer the question ADR-0109's goal is actually about:
**is a program of real size pleasant to write in this language?**

Nothing here measures that. The gates say the compiler is correct. The
specification says what the language is. `tests/spec/` says a clause is
honoured. Not one of them can say where the boilerplate collects or what a
writer reaches for and does not find.

The roadmap's answer is a Language Server Protocol server, written in the
dialect, and its argument for the shape is threefold: it needs no prerequisite
(a server over stdio wants no terminal control, which is why the text-mode IDE
that was proposed first is later); it stresses the two live design gaps by
construction rather than by argument; and it has an **external authority**,
which open question §1 says the dialect structurally lacks — the protocol is
third-party and versioned and there are independent clients that disagree with
a server objectively.

Three of its prerequisites had already been written and each corrected the
plan: `PasJson` (ADR-0217), because there was no JSON anywhere; `PasLsp`
(ADR-0218), because `PasStream` reads lines and a message body is a byte count;
`PasLspDiag` (ADR-0219 and after), because `PasParse` parses an integer and
reads no diagnostic. What was missing was the program.

## Decision

`lsp/pasls.pas` is a server that does one thing: it answers
`textDocument/publishDiagnostics` for every document a client opens or changes.
It holds documents by URI, writes the one it was asked about to a scratch file,
invokes `pascalc` on it through `PasProcess.Capture`, reads the diagnostics
back with `PasLspDiag.DiagParse`, and publishes them. It answers `initialize`,
`shutdown` and `exit`, refuses every other *request* with `MethodNotFound`, and
ignores every other notification.

**It lives in `lsp/` and is not a `tests/` case.** A test case is compiled into
a temporary directory and thrown away; a server has to be a binary a user can
point an editor at, which is what makes the external authority above real
rather than theoretical. `lsp/build.sh` produces one, reading
`lsp/pasls.components` — the same sidecar convention `tests/run_test.sh` and
`selfhost/irtest.sh` read, so the build order is written down once. It is a
script and not a CMake target because nothing in this tree installs anything:
`tools/pascalcc` is the precedent and the shape.

**It gets its own harness**, `lsp/run.sh`, for the reason `tests/dumps/` has
one: what is compared is neither a compiled program's output nor a compiler's,
but a *protocol conversation*. A session is `lsp/sessions/name.jsonl`, one
JSON-RPC message per line with `#` comments, and the harness computes the
`Content-Length` frames — so the session stays readable and the byte counts
stay right at the same time. The golden `name.out` holds the exact bytes the
server wrote, carriage returns and counts included, and `name.note` holds what
it said to a person. A session that writes to standard error with no `.note`
beside it **fails**, so a new complaint cannot appear unnoticed.

**Everything a person reads goes to standard error, and the program declares no
program-parameters.** `output` is a buffered Pascal text file whose flushes
interleave unpredictably with a descriptor write — this chapter's own earlier
finding — and 6.9.1 makes `output` a program-parameter, so a program that does
not name it cannot call `writeln` at all. The discipline is enforced by the
compiler rather than by review.

## Consequences

- **It found a bound before it ran.** Ten modules is more than
  `maxImports = 8`, so the program could not be compiled at all;
  [ADR-0235](0235-the-two-command-line-bounds-move-together.md) is that, and it
  is exactly the kind of finding this chapter exists to produce — a limit that
  looked generous next to a test case and was not a limit a *program* could
  live inside.
- **`PasContainer`'s map is unusable for this** and the server searches a
  vector linearly instead. `MapKey` is 63 characters and a document URI is past
  that before the file name starts. Recorded rather than worked around: the
  container was written for a test case's keys.
- **`JsonLine` is 255 characters and a URI is not a line.** The document store's
  key type is `JsonLine` deliberately — `DiagPublish` takes one, so a URI the
  server could hold and that module could not would be a truncation at the
  boundary instead of a refusal at the door. A URI longer than 255 is reported
  and the document ignored.
- **A scratch file cannot be created safely.** There is no `getpid` anywhere in
  this tree, no `mkstemp`, and nothing in `PasFS` that answers a temporary
  name, so the path is one fixed name under `TMPDIR` overridable with
  `PASLS_SCRATCH`, and two servers sharing a `TMPDIR` share the file. Worse,
  `rewrite` on a name that cannot be created is a run-time error and stops the
  program, and neither standard gives a program a way to ask beforehand — so a
  server cannot survive a bad scratch path.
- **`binding(f).bound` is not a readiness test and reads like one.**
  `doc/implementation-defined.md` E.16 binds a variable when the name *exists*,
  so a file about to be created reports false and a file already written
  reports true. The first version of `WriteScratch` checked it and refused to
  write anything at all.
- **The positions are byte offsets and the protocol wants UTF-16 code units.**
  This is the hazard the roadmap named before any of it was written, and it is
  left visibly wrong rather than half-corrected: right for every ASCII line and
  wrong for the rest. AP 6.4.15 refuses an integer index and makes an element a
  grapheme cluster; `PasUnicode` offers a scalar view; the protocol's unit is a
  third one that nothing here answers in.
- **`lsp/` is outside every corpus sweep.** `line-coverage`, `heap-balance`,
  `variant-check` and the rest are globbed over `tests/`, so what checks this
  program is `lsp-server` and nothing else. That is a row in `doc/sop.md` §7.

## What this does not do

- **No document symbols, no hover, no go-to-definition.** Those want the
  compiler to answer questions about a tree rather than about a file, which is
  a compiler interface that does not exist. Diagnostics need only what
  `pascalc` already writes, which is why they are first.
- **No incremental synchronisation.** `textDocumentSync` is Full, because
  incremental changes arrive as ranges in the client's position units and the
  server has no view in those.
- **No concurrency.** A `didChange` arriving while a compile is in flight is
  the sentence the roadmap's concurrency row has been waiting for a program to
  say, and this server does not say it yet: it compiles synchronously and reads
  the next message afterwards. The row keeps its candidate and does not move.
- **It is not installed and it is not a product.** There is no `install`
  target here for anything, and a server that an editor is configured against
  by absolute path into a checkout is what this is, for now.
