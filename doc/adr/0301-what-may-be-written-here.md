# 301. What may be written here

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Closes the `completion` row of `doc/roadmap.md`'s
Tooling table, which was the last of it.

## Context

`doc/roadmap.md` called this *the one an editor user misses within a minute,
and the one with a design in it*, and named the difficulty exactly: **the
outline gives the names in scope after a parse, but what may follow a token is
the parser's knowledge and `--dump-symbols` stops before Sema.**

That sentence contains two different questions and only one of them is worth
answering here.

**What may follow a token** is syntactic completion — after `while` a
condition, after `.` a field. The second of those is the one a person notices,
and it is not the parser's at all: which fields `p.` admits is a question
about the *type* of `p`, which is Sema's. Answering it means waiting for Sema,
and Sema is exactly what an outline stops before, for ADR-0239's reason — a
completion is asked while the file is half-written, which is when Sema has the
least to say.

**What names are in scope here** is the other question, and `--dump-symbols`
nearly answers it. Nearly, because the dump reports what a source *declares*
and a completion needs what is *visible*, and the gap between those is two
rules the dump does not apply and cannot: §6.2.2's nesting, and §6.2.2.9's
order.

Checking what the dump actually reported found a third thing: it reported no
**formal parameter** at all. Its own sentence is *every name a source
declares*, and §6.2.2.10 gives a parameter a defining-point in the routine's
block, so this was simply missing — invisible because an outline is not where
anybody looks for a parameter, and unmissable in a completion list inside a
routine's body.

## Decision

**The list is the names in scope at the position, plus the compiler's own
vocabulary, and nothing else.** No member completion and no syntactic
completion. A list that is short is better than one that is wrong, and a list
that offers a name §6.2.2.9 refuses is wrong in the way that costs most: the
reader accepts it and the file stops compiling.

**Two rules filter the dump, and they are the whole of the design.**

*The block that declares a name has to contain the position.* The rows nest by
depth and a declaration with a block carries its extent (ADR-0253), so the
nearest enclosing **container** — a program, a module, a procedure or a
function — is the row above at the first depth that has one, and the position
must lie inside it. Checking the nearest is enough because containers nest: a
position inside a nested procedure is inside every block around it. A row at
depth 0 is the program or the module and is in scope throughout its own text.

*And its defining-point has to precede the position* (§6.2.2.9). This is not a
nicety. `procedure A; begin writeln(later) end; var later: integer;` is
**refused** by this compiler — probed before the rule was written — so
offering `later` inside `A` offers a name that does not compile where it was
offered.

A **field** is dropped: §6.4.3.3 makes a record a region and a field is
reachable through a selection or a with-statement, both of which need the type
at the position. That is the same refusal as member completion, from the other
side.

**`--dump-symbols` reports formal parameters**, one word for all four forms:
`parameter`. Which of them a name is — value, variable, procedural,
functional — is a fact about the *signature* and this row has nowhere to put
it. The **server** drops them from both outlines, LSP's and MCP's: an outline
is drawn to navigate by, `selfhost/apfront.pas` would gain some hundreds of
rows nobody jumps to, and where the rows are dropped is the client's question
and not the compiler's.

**`--dump-words` is new, and it exists so that no table is copied.** It writes
every word-symbol §6.1.2 reserves and every required identifier §6.2.2.10 puts
in a region enclosing the program, one to a line:

    word <spelling>
    required <kind> <spelling>

It copies nothing: the words come from the lexer's own `kwText`, so a
forty-sixth appears here on the day it is reserved; the required identifiers
come from walking the outermost scope at the one moment it holds them and
nothing the source declared, which is immediately after `InstallPredefined`;
and the twelve required procedures, which are names and not symbols (ADR-0097),
come from `RequiredProcName`, which `IsRequiredName` now reads too — one list,
two readers. ADR-0294 refused a word-symbol table in the server as *correct
today and silently wrong on the day a forty-sixth is reserved*, and this is
that refusal met a second time with the compiler answering instead.

It is asked **once per session**, of a two-line program the server writes
itself, and held. The vocabulary is a property of the compiler and not of any
document; a compiler cannot change under a running server without the server
being restarted. It is answered inside `RunSema` and stops there, which is why
it wants a source that parses and why the server does not ask it of the
document.

## Evidence

`lsp/sessions/completion.jsonl` is one document written so that both rules
refuse something: `later` is declared after `Inner` and must not be offered
inside it, and `Inner`'s parameters and local must not be offered in the
program's own statement part. Both answers were predicted and matched.

`tests/dumps/words.pas` is the vocabulary's golden — 118 rows as this is
written, and the case is the only reader of that dump. `tests/dumps/symbols.dump`
gains three `parameter` rows, and no session golden moved, which is the
evidence for the server-side drop.

Four mutations, each killing what it should: the order test dropped
(`lsp-server`, `later` appears inside `Inner`); the container test dropped
(`lsp-server`, `Inner`'s names appear in the program's body); the parameter
walk removed (`dump-symbols`); and `restricted` unwritten (`dump-words`, and
nothing else in the tree reads the vocabulary).

## What is not done

- **No member completion, and no plan for one.** It needs the type at the
  position, which is `--dump-uses`' territory: a `use` row carries a type
  name, not a field list, so the compiler would have to answer a new question.
  The refusal is a decision and not a deferral — until something asks, the
  list is what it says it is.
- **A file that does not parse offers only the vocabulary.**
  `--dump-symbols` is guarded by `errorSeen`, so a half-typed statement takes
  the names away and leaves the word-symbols. Holding the last successful
  parse per document would answer it, at the cost of filtering by extents that
  the current text has already moved.
- **§6.2.2.8's pointer domain is over-refused.** A type-name may be written in
  `^T` before `T` is defined, and the order rule here does not know it. The
  list is shorter than the language allows in exactly that one position.
- **A `with`-statement adds no fields**, being the field question again.
- **Nothing sorts or scores the list.** `isIncomplete` is false and the client
  filters, which is what clients do.

## Consequences

- **`--dump-symbols` reported no parameter for eleven records and nobody
  noticed.** Its header comment said *every name a source declares* the whole
  time. The lesson is ADR-0239's own, met from the other end: a dump is
  checked by its callers, and a caller that does not want a fact cannot report
  that the fact is missing.
- **A third dump now answers a question about the compiler rather than about a
  program**, after `--dump-predicates` (ADR-0194) and `--dump-limits`
  (ADR-0148). The shape is the same each time: the tool asks the compiler what
  it knows instead of holding a copy.
- **The server takes one extra compilation per session**, of a two-line
  program. It is the first thing here compiled for a reason having nothing to
  do with the document, and the alternative — asking the document and
  accepting no answer when it does not parse — would make the vocabulary
  arrive at a time nobody could predict.
- **The roadmap's Tooling section is empty.** What is left of the language
  server's own list is in `doc/history.md`.
