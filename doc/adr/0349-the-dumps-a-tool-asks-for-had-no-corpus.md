# ADR-0349: The dumps a tool asks for had no corpus

Date: 2026-09-06

## Status

Accepted. Fixes `DumpSymBlock`, adds the `tool-dumps` gate,
`tests/dumps/symbols_traits`, and two server sessions over a dialect fixture.
ADR-0239 and ADR-0241 are not superseded — this is the corpus they were
missing.

## Context

The MCP server failed to connect at the start of a session, so a day's work was
done without it. Asked afterwards what it is *for*, the honest way to answer was
to drive it — and its `outline` tool answered `lib/dialect/passortx.pas` with
one line: `module PasSortX  52:8`, which reads exactly like a file that declares
one thing.

It was a crash. `--dump-symbols` traps on **any source containing a `trait`**:
ADR-0338 put two node kinds into a block's declaration list, and `DumpSymBlock`
read them through the procedure arm, which §6.5.3.3 makes an error and
ADR-0118's guard reported. The compiler died after printing its first line, and
the tool returned what it had.

**Every one of 888 cases was green.** `tests/dumps/` has one case per flag over
one small source apiece — `symbols.pas` and `symbols_module.pas` both predate
the object model — and the coverage sweep passes `--dump-all`, which is tokens,
AST and Sema and not this. `lsp/sessions/` names `pasjson.pas`,
`symbols_module.pas` and `hello.pas`, so the server was never asked about a
trait, a task, a channel, an owned pointer, an optional or a slice either. The
construct had shipped that morning.

**The shape is ADR-0103's, one layer out.** That record found thirty-one walker
procedures entered by nothing and built `tests/dumps/` to enter them. What it
did not do — could not, the corpus being one source per flag — is keep entering
them *as the language grows*. A dump walker is the one part of this compiler
whose input is every construct and whose output nobody reads on an ordinary
run.

## Decision

**`tool-dumps` sweeps every tracked `.pas` through every dump a tool asks
for** — `--dump-symbols`, `--dump-uses`, `--dump-words` and `--dump-imports` —
and requires the compiler to survive. 881 sources, 3524 invocations, eleven
seconds.

It is a **crash sweep and not a golden**: what a dump *says* is
`tests/dumps/`'s business, and asking that here would be a second copy of those
goldens with the same drift. What it asks is ADR-0269's question — *did the
compiler survive every invocation?* — of the dumps rather than of the corpus.
`--dump-imports` is in the list because `tools/pascalcc` reads it to learn what
to translate, so a crash there is a build that stops rather than an editor that
goes quiet.

**`tests/dumps/symbols_traits` pins the answer as well as the survival**, and
it is what the branch ratchet demanded: the guard added to fix this had a
direction no case took, which is the same gap reported a second way. A
trait-declaration and an implementation-declaration are **not** outline
entries — a trait's routine names have no defining-point in the block
containing it (AP 6.7.9.2), and an implementation's are reached only through
the trait — so what a reader can jump to is the type, and the case says so.

**`lsp/sessions/workspace/dialect.pas` is the fixture the server was
missing**, carrying a trait, two implementations, a task, a channel, a
select-statement, an owned pointer, an optional, a schema, a slice parameter
and a trait-bounded generic. `mcp_dialect` asks both MCP tools about it and
`dialect_lsp` asks `documentSymbol` about a compact version inline. **A feature
added to the language belongs in that fixture**, and those two goldens are what
say whether the server still knows about it.

## Consequences

**The mutation is loud in the right place.** With the fix reverted,
`tool-dumps` reports 13 of 3524 invocations stopping the compiler, and
`dialect_lsp`'s outline collapses from the full tree to a single entry — the
program name alone. The second is the user-visible symptom, and a golden is
what turns it from *the file looks empty* into a diff.

**The first run of the sweep found the harness rather than the compiler.**
`git ls-files` quotes a path holding non-ASCII bytes, and
`lsp/sessions/workspace/` has a directory named in Japanese (ADR-0291), so
eight invocations "crashed" on a file whose name reached the compiler with
literal quotes in it. `-z` is not a nicety here.

**It says nothing about what a dump *means*.** A task is reported as
`procedure` by `--dump-symbols` and therefore drawn as one in an editor's
outline. That is now pinned by a golden rather than unexamined, and whether it
should say `task` is a question this record leaves open.

## What this does not do

**It does not sweep `--dump-ast`, `--dump-sema` or `--dump-tokens`.** The
coverage corpus already passes `--dump-all` over every source, which is those
three, and it has since ADR-0103.

**It does not check that the two tools' output is *useful*.** `outline`
returning a correct tree that omits something a person wanted is invisible to
both a crash sweep and a golden, and there is no oracle for it — the same
absence `format-check` names about layout.

**It does not connect the MCP server.** Why it failed to start that morning is
unexplained; the launcher builds it on demand in under two seconds, and it
started and answered every time it was asked afterwards.

## Alternatives rejected

**Add a golden for every dump over every source.** 3524 goldens, all of them
agreeing with whatever wrote them, and a change to any walker's format would
rewrite the lot — which is the shape a green suite hides in. The crash sweep
asks the question that has an answer independent of the compiler.

**Put the trait guard in `Offer` rather than at the call.** It would fix this
walker and leave the next one that iterates `blProcs` to find the same thing
out. The list holds declarations of several kinds now, and every walker over it
is entitled to say which it handles.

**Have `outline` report a trait's routines.** They are reachable through the
trait and not by name in the block, so an outline entry would be a name a
reader cannot jump to — an editor drawing something `textDocument/definition`
then declines to find.
