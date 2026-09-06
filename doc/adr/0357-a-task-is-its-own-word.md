# ADR-0357: A task is its own word

Date: 2026-09-07

## Status

Accepted. Answers the question ADR-0349 left open in its Consequences, and
changes one line of one session golden.

## Context

`--dump-symbols` answers an editor's outline in Pascal's words (ADR-0239),
and the walker wrote `function` for an `nkProcDecl` that was one and
`procedure` for every other. A task-declaration (AP 6.7.8) is an
`nkProcDecl` with `pdIsTask` set, so a task was drawn as a procedure in every
outline, by the LSP server and by the MCP `outline` tool. ADR-0349 pinned that
word when it made the outline survive a trait, and said in as many words that
whether it should be `task` was a question it left open.

It is not cosmetic. A task is started by `spawn` and by nothing else —
`CheckStmt` refuses a procedure-statement naming one, with a message saying
so — and a reader who jumps to `procedure Worker` from an outline and writes
`Worker(c)` has been sent to the wrong construct by the tool that named it.
Every other word the dump writes is the construct's own: `record`, `schema`,
`value`, `parameter`.

## Decision

The walker writes `task` for a declaration whose `pdIsTask` is set, before
the `procedure` default. `lsp/pasls.pas` maps the word to `SymbolKind.Function`
and `CompletionItemKind.Function`, the protocol having no kind nearer than a
routine's; the MCP `outline` tool writes the dump's word untranslated, which
is where a reader sees it. `tests/dumps/symbols_task.pas` pins the row, its
extent and its nesting; `lsp/sessions/mcp_dialect.out` moves one line, from
`procedure Worker` to `task Worker`, and `dialect_lsp.out` does not move at
all, the number being the same.

## Consequences

The eleven words are `program`, `module`, `const`, `type`, `record`,
`schema`, `enum`, `field`, `value`, `var`, `parameter`, `procedure`,
`function` and `task` — thirteen spellings for eleven kinds, since a server
maps some together. A client that does not know `task` reports it as a
variable and says so in its log, which is `SymbolKindOf`'s existing
fall-through and the behaviour a client written against ADR-0301's list gets
until it is updated. That is the cost, and the register carries the general
form of it: nothing holds the dump format and its readers together.

## What this does not do

It does not give a task an outline kind of its own in the protocol; there is
none to give. It does not change `--dump-uses`, `--dump-stmts` or
`--dump-words`, none of which names a declaration's kind.
