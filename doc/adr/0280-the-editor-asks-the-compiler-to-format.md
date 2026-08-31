# 280. The editor asks the compiler to format

Date: 2026-08-31

## Status

Accepted, 2026-08-31.

## Context

ADR-0279 built `pascalc --format` and closed by naming what it had not done:
the language server's `textDocument/formatting`, which `doc/roadmap.md` lists
as the first of the three things a formatter would pay for. The compiler half
is what a server would call, and it existed; nothing called it.

## Decision

`textDocument/formatting` is answered by running `pascalc --format` over the
scratch file the server already writes for every other question, and returning
**one edit over the whole document**.

One edit and not a diff. LSP admits a list and a client applies them all, but
computing a minimal set means comparing two texts — a second algorithm to get
wrong, for a gain the client's own undo already provides — and the formatter's
output is a whole file by construction, there being nothing in it that says
which part of the input any part of it came from.

**The command redirects standard output to a file of its own**, which no other
command this server runs does. Every other one folds standard error into
standard output, because this compiler writes its diagnostics to `output` and
`tools/pascalcc` moves them to standard error, and folding the two is what
makes either work. Here the compiler's standard output is the *program*: a
diagnostic mixed into it would be written straight into the user's buffer.

**A non-zero exit means no edits at all.** The source did not lex, or holds
more comments than the formatter can keep in order; either way it says so on
its own stream and leaving the buffer alone is what an editor expects of a
formatter that could not read the file.

The range ends at line 0 of the line *after* the document. That position is at
or past the end however the last line ends, and every client clamps it;
computing the exact end would mean measuring the last line in the negotiated
encoding, and `LineOf` bounds a line at `DiagLine`'s capacity, which the corpus
exceeds by an order of magnitude.

## Consequences

**`tools/pascalcc` had to learn the flag, and the way that was found is the
point.** The script passes `--dump-*` through to `pascalc` and links nothing,
for the reason its own comment gives: a user may just as well name `pascalcc`
in `PASLS_COMPILER` as name `pascalc`, and one did, and got an empty outline
back with `pascalcc: unknown option` in a stream nothing was reading. `--format`
arrived the same way and was caught by the same thing — the session suite drives
the server through `pascalcc`, and the first run of `lsp/sessions/formatting`
answered with no edits and the same unread complaint. It is now in that list,
which the usage text and the comment both name.

`lsp/sessions/formatting.jsonl` pins three things a `tests/dumps/` case cannot:
that the reply is a single `TextEdit` and not a diff, that its range ends one
line past the document, and that a source the lexer rejects is answered with an
empty array rather than with an error or with silence.

**Fifteen goldens changed for one field.** `documentFormattingProvider` joins
the capabilities every session's `initialize` reply carries, so every golden's
first frame and its `Content-Length` moved. That is the cost of a capability
being a fact about the server rather than about a request, and it is worth
knowing before adding the next one.

What is still not built is `textDocument/rangeFormatting`, which needs a
formatter that can be asked about part of a file — the token-stream printer
would have to be told where to start its indent from, and that is a question
about the enclosing structure that only a parse can answer. And the `style:`
gate for the Pascal of the kind `git clang-format` gives the C, which is a
policy this tree has not chosen (`doc/sop.md` §7).
