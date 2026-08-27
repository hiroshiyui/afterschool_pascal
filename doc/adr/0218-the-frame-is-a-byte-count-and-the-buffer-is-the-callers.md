# 218. The frame is a byte count, and the buffer is the caller's

Date: 2026-08-27

## Status

Accepted.

## Context

`doc/roadmap.md` proposes a language server as **the caller**: the program
large enough to say whether this dialect is pleasant to write in, which no gate
here can measure. That chapter listed what was already in hand and named one
gap — JSON, closed by ADR-0217 — and said, of the transport, that "`PasStream`
frames the messages".

It cannot. This record is the second gap, and the reason it was invisible from
the outside.

**A message is a byte count, not a line.** LSP frames each message as
`Content-Length: N` and a blank line and then exactly N bytes. The header is
line-oriented and the body is not, so a reader that has just consumed a header
line will, on almost every message, be holding the first bytes of the body as
well — one `read(2)` returns whatever the pipe had. **Nothing that reads lines
can hand those back.** `PasStream.ReadLine` answers a line and drops the rest
of what it buffered; `PasIO.ReadInto` reads bytes into the caller's array and
says how many arrived, and something has to sit between that and the frame.

The alternative is a one-byte read per header character — a system call per
byte — which is what a module without a buffer would be forced into.

## Decision

**`PasLsp` is that buffer, and the buffer belongs to a record the caller
declares.**

```pascal
var r: LspReader;
begin
  LspOpen(r, StdIn);
  ...
  e := LspRead(r, body)
```

`PasStream`'s shape and for its reason (ADR-0130): the state belongs to the
descriptor, and a module variable would make two servers in one program share
one buffer. `body` is a `JsonChars`, so a message has no size limit; only how
much arrives at once is bounded.

**It reads the body and does not read the message.** `PasJson.JsonParseChars`
makes a document of what comes back. Framing and content are two failures with
two causes, and a routine answering both would have to say which in a code that
has one field.

**The reader is lenient and the writer is strict.** A bare `<LF>` ends a header
line here, because a hand-written test message is the first thing a server ever
sees; what this module *writes* is always `<CR><LF>`, which is what the
specification says. Postel's rule applied where it is safe — the leniency is in
what is accepted and never in what is produced.

**`errAbsent` is how a session ends.** A read finding nothing at all is the
client closing the pipe, which every session does and no session should log as
an error; a read finding a header line and then nothing is a truncated frame
and is `errSyntax`. `LspRead` tells them apart by whether it saw a line, and
`0218-clean-end-is-a-failure` collapses the two — both still end the loop, so
only a case printing the *cause* can see it.

## Consequences

### The first two usability findings, which are the point of the exercise

**There is no empty substring.** ISO/IEC 10206:1991 §6.5.6: *"It shall be an
error if … the value of the first index-expression is greater than the value of
the second index-expression."* So `s[1..length(s) - 1]` — the ordinary way to
drop a last character — **traps on a string of one**, and the header line that
ends a frame's headers is exactly one character: a bare carriage return. The
program compiled, ran, and stopped at

```
runtime error: substring: [1..0] is not within a string of length 1
```

Checked against the standard's own text before being written down, which is
ADR-0214's lesson applied on the first opportunity to repeat it: the compiler is
right and the clause is explicit. **Whether the dialect should admit
`s[i..i-1]` as the empty string is not decided here** — one site is an
anecdote, and ADR-0116 wants a feature demanded rather than designed. It is in
the roadmap's findings list waiting for a second sighting.

**A program may not mix `writeln` with a descriptor write.** `output` is a
buffered Pascal text file and `PasIO.WriteText` is not, so a program using both
emits them in an order that depends on when the buffer happens to flush —
and neither standard gives a program a `flush`. A program that speaks a
descriptor protocol must therefore say *everything* that way, its own
diagnostics included. `tests/dialect/lib_lsp.pas` does, and says so at the top.
Nothing here is wrong; it is a thing a writer has to know and nothing tells
them.

### The golden has carriage returns in it, and that took a `.gitattributes` line

`core.autocrlf = input` is set in this repository, and its whole job is to stop
a carriage return in a working tree from surviving a commit. That is right for
source and wrong for `lib_lsp.in` and `lib_lsp.out`, where the carriage returns
*are* the subject: the input carries one frame written `<CR><LF>` and one
written with a bare `<LF>`, because the reader is lenient; the golden carries
what the writer produced, which is the only thing that can say the writer is
strict. Both are marked `-text`, beside `selfhost/torture.pas`, which is there
for the same kind of reason.

Git said so in a warning rather than silently — *"CRLF will be replaced by LF
the next time Git touches it"* — and a fresh clone would have failed the case
with a diff no one could see.

### Cost

One module, no language change, no runtime change, no clause. Two mutations:
the carriage return kept in a header, which makes an ordinary frame
`errSyntax`, and the clean end reported as a failure.

### What was rejected

*Framing in `PasStream`* — it would have to grow a byte-count read, and the
buffer it already has is a `FILE *`'s, so the two would fight over who holds
the unconsumed bytes.

*A module-level buffer* — two readers in one program is not exotic; a server
that also speaks to a subprocess has two.

*Requiring `<CR><LF>` on input* — every hand-written message would be rejected
and the first thing a person does with this module is write one.

*Reading the message here* — see above; two failures, two causes, one field.
