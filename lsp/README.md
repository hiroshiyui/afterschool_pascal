# `pasls` — a language server for Afterschool Pascal, in Afterschool Pascal

This is the program `doc/roadmap.md` calls **the caller**: the thing large
enough to say whether this dialect is pleasant to write in, which no gate in
this repository can measure. It is not part of the compiler and it is not a
feature — it invokes `pascalc` as a separate process, exactly as an editor
would, and everything it uses is in `lib/`.

It does one thing today: it publishes the compiler's diagnostics for every
document a client opens or changes. ADR-0236 records why that is the first
thing and what it deliberately leaves out.

## Building it

```sh
PASCALC=build/bin/pascalc AFTERSCHOOL_PASCAL_RUNTIME=build/lib \
  lsp/build.sh tools/pascalcc /somewhere/pasls
```

`pasls.components` lists ISO/IEC 10206:1991 §6.13's other program-components,
one path per line in dependency order — the same sidecar convention
`tests/run_test.sh` and `selfhost/irtest.sh` read. There is no CMake target,
because nothing in this tree installs anything; `tools/pascalcc` is the
precedent.

## Running it

The server speaks the protocol over standard input and output and says nothing
else on either. Two variables configure it, both with defaults so an editor
that sets no environment still works:

| | |
| --- | --- |
| `PASLS_COMPILER` | what to invoke to compile a document. Default `pascalc`, so it must be on `PATH`; `tools/pascalcc` works too, and passes a `--dump-` flag through untouched — which it did not until the outline below asked it to |
| `PASLS_SCRATCH` | the file the current document is written to before it is compiled. Default `$TMPDIR/pasls-<pid>.pas`, and `/tmp` where `TMPDIR` is unset |

It finds a file's **imports** by reading `.components`, which is this tree's
build description — the same sidecar `tests/run_test.sh`, `selfhost/irtest.sh`,
CMake and `build.sh` read, a path per line in dependency order. The rule is one
sentence: *take the entries before this file*. A sidecar beside the file and
named after it answers first; otherwise the workspace the client named at
`initialize` is searched for one that names the file. Without this the compiler
is handed a module alone and reports every name it imports as undeclared —
21 171 diagnostics for `selfhost/apfront.pas` — so a project that does not use
the convention gets no imports and that noise back. Resolving an interface name
to a file, which would need no sidecar at all, is a compiler feature this
project does not have.

The scratch file exists because a compiler reads a file and an editor holds a
buffer that has never been saved — which is the whole reason a language server
exists. **Its name carries the server's own process id**
([ADR-0242](../doc/adr/0242-a-name-no-other-live-process-will-choose.md)), so
two servers on one machine do not share it; run as many as you like. It is not
`mkstemp` — §6.7.5.6 binds a file by *name*, so an exclusive creation could not
survive being opened a second time to be written — and what the name carries is
a number no other **live** process has. `PASLS_SCRATCH` still overrides the
whole path, and two servers told the same one share it again.

The file is left behind when the server ends. That is deliberate: it is the
exact source `pascalc` was handed, which is what you want when the server and
the editor disagree about a document, and it is one file per process under
`TMPDIR`.

**A path it cannot write is reported and survived**, which it was not until
AP 6.4.3.4.7 ([ADR-0240](../doc/adr/0240-a-program-may-ask-before-it-writes.md)):
`rewrite` at a name that cannot be created stops the program, and neither
standard gave a program a way to ask first. The server asks
`binding(f).writable`, says once per document what is wrong and where to fix
it, and keeps the session. `sessions/unwritable.jsonl` is that session, and its
`.scratch` sidecar is the path.

It negotiates the **position encoding** at `initialize`. LSP counts a
`Position.character` in UTF-16 code units by default; this compiler counts
bytes. If your client offers `utf-8` in `general.positionEncodings` the server
takes it and hands the compiler's own columns straight through; otherwise it
converts, and either way it says which in `positionEncoding` so nothing is
guessing. A file holding nothing above U+007F is identical under both.

It answers `textDocument/documentSymbol` out of `pascalc --dump-symbols` and
out of nothing else ([ADR-0239](../doc/adr/0239-the-compiler-answers-a-tools-question.md)).
That flag stops after the *parse*, which is why an outline is still drawn for a
file full of errors and why no `--import` is passed for one — a name is a name
whether or not the module it came from was found. The compiler answers in
Pascal's words (`procedure`, `record`, `value`) and this server maps them to
LSP's `SymbolKind` numbers, so the protocol's table lives here and not in a
Pascal compiler.

Two things it does that are worth knowing. The names come back with the case
the **programmer** wrote: the compiler's string pool holds only the folded
spelling, so what the dump reports is a position and a length, and the server
slices the written spelling out of the document it is holding. And `range` and
`selectionRange` are both the extent of the **name** rather than of the whole
declaration — the parse tree records where a declaration begins and never where
it ends, so anything wider would be invented. Go-to-symbol, the outline and
breadcrumbs are unaffected; "expand selection to the enclosing declaration" is
the one thing that degrades.

It answers `textDocument/definition` and `textDocument/hover` out of
`pascalc --dump-uses` ([ADR-0246](../doc/adr/0246-what-a-name-denotes-and-where-it-was-written.md)),
which are one question asked twice: what does the name under this position
denote, and where was it written? Unlike the outline these need **Sema** —
which declaration a name denotes is §6.2.2's scope rules and a parse cannot
say — so the compiler is run further and the document's imports are passed. A
definition that crosses a file is what the method is worth having for, and the
dump's own `file` lines are how the server names a path it was never told
about.

`--dump-uses` reports what Sema resolved **whether or not Sema was happy**,
and that is the decision behind these two: Sema accumulates its diagnostics
rather than stopping at the first, so a file with a mistake in it still
answers about every name the mistake is not about — which is the state a file
being edited is in most of the time. The outline reaches the same place by
stopping *before* Sema; a defining-point cannot, so it carries on instead.

A **field** is answered too, and it took a record of its own
([ADR-0247](../doc/adr/0247-a-field-is-not-a-symbol.md)): it is the one
applied occurrence in this language that resolves to no symbol, §6.4.3.3
making a record a *region* with a defining-point in it while a selection is
resolved by asking the record's type. §6.8.3.10's bare form inside a `with`
answers the field as well — not the with-statement, which is where the
*record* was named.

An **interface** name is answered as well
([ADR-0248](../doc/adr/0248-an-interface-had-a-name-and-no-place.md)) — and
the occurrence worth having is not §6.11.3's rare `M.x` but `import Middle;`,
which is where a module says where it gets things from. It leads to the
`export` clause that declared it, in whichever file that is.

A name inside a **schema's own body** is answered
([ADR-0249](../doc/adr/0249-a-schemas-body-is-read-where-it-was-not-written.md)),
which took working out: §6.4.7 resolves such a body only while a type is being
produced from it, and that happens where the type is *written*, so the
compiler is reading one file's text while it believes it is checking another.
A schema declared in another component still answers nothing about its body —
that text is not in this document.

A **declaration** answers as an occurrence of itself
([ADR-0250](../doc/adr/0250-a-declaration-is-an-occurrence-of-itself.md)), so
a hover over `var Total: Counter` gives the type — the most ordinary question
a reader has. Go-to-definition there is a no-op jump, except in the one place
Pascal has a declaration/definition split: §6.6.1's `forward` and §6.11.1's
module-heading declare a routine whose body arrives later, and the name
written at the implementation leads back to the interface that promised it.

An **interface's own export-part** answers too
([ADR-0251](../doc/adr/0251-an-interface-declares-itself.md)) — §6.11.1
registers an interface in a table beside the scope rather than in it, so it
needed a reporter of its own rather than falling out of the walk.

**It is checked against a client this project did not write.** Every session
in `sessions/` is a golden written here, so Microsoft's `vscode-jsonrpc` — the
reference implementation of the wire protocol that VS Code itself uses — was
driven against the server as an independent client: a real capabilities
object, `initialized`, diagnostics, `definition`, `hover`, `documentSymbol`
with hierarchy, `$/cancelRequest`, pipelined requests, out-of-range positions,
an unimplemented method. Zero connection errors and zero unhandled
notifications. The sharpest result is the position encoding: on a line where
an astral pair and an accented letter precede an identifier, the byte column
is 20 and the UTF-16 column is 17, and the server answered each under the
encoding that was negotiated.

**A document owns the last `--dump-uses` taken of it**
([ADR-0252](../doc/adr/0252-the-answer-is-cached-against-the-document.md)), so
a hover a reader repeats costs one compilation and not five: on
`selfhost/apfront.pas` — 22 900 lines — five sequential hovers went from 795 ms
to 106. The cache is emptied wherever the text is replaced, which is the three
places a document's text goes away and nowhere else. The outline is
deliberately not cached: it is asked once per open where a hover is asked
continuously.

`lsp/mcp.sh` is the **MCP launcher**, named by `.mcp.json` at the top of the
checkout so that an agent working on this repository has `outline` and
`diagnostics` as tools. It finds a compiler in the build tree or on `PATH`,
builds the server when the binary is missing or older than its sources, and
execs it with `--mcp`. `build.sh` stays what it is — a server wants a binary a
user can point an editor at — and this is the stable *command* an agent needs
beside it.

Anything the server has to say to a person goes to **standard error**. It has
to: standard output is the protocol, and a Pascal `writeln` is buffered where a
descriptor write is not, so a program that used both would interleave them
unpredictably. The program declares no program-parameters, which makes a stray
`writeln` a compile-time error rather than a corrupted frame.

## The other protocol

`pasls --mcp` speaks the [Model Context Protocol](https://modelcontextprotocol.io)
over stdio instead ([ADR-0241](../doc/adr/0241-a-second-transport-over-one-program.md)),
and it is the same program: one import resolver, one compiler invocation, one
set of answers about a Pascal source. What changes is the framing — one JSON
message to a line rather than `Content-Length` — the method names, and who is
asking. LSP serves a person in an editor; MCP serves an **agent working on a
checkout**, which is why the two tools are the ones a shell cannot do:

| tool | what it answers |
| --- | --- |
| `outline` | every name a source declares, with kind, position and nesting, indented. Answers for a file that does not compile, because `--dump-symbols` stops after the parse |
| `diagnostics` | what the compiler says about a source, one diagnostic to a line, with imports resolved from `.components` |

Both take a `path` to a `.pas` file, absolute or relative to the directory the
server was started in — MCP has no `rootUri` to be told, so that directory is
also where a `.components` is looked for. A path that is not there is
`isError: true` inside a result; an unknown tool or a missing argument is a
JSON-RPC error, which is the distinction the specification draws and the one
most easily got backwards.

```sh
lsp/build.sh tools/pascalcc pasls
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"outline","arguments":{"path":"tests/hello.pas"}}}' \
  | PASLS_COMPILER=build/bin/pascalc ./pasls --mcp
```

## The sessions

`run.sh` builds the server and replays every recorded conversation against it.
It is one `ctest` case, `lsp-server`.

```sh
lsp/run.sh tools/pascalcc build/bin/pascalc
```

A session is up to six files, of which the first two are required:

| | |
| --- | --- |
| `sessions/name.jsonl` | one JSON-RPC message per line. A blank line or one beginning with `#` is a comment — the harness computes the `Content-Length` frames, so the session stays readable and the byte counts stay right |
| `sessions/name.out` | the **exact bytes** the server wrote to standard output, carriage returns and byte counts included. A change to what `JsonRender` or `LspWrite` produces fails here even when the JSON still parses |
| `sessions/name.note` | what it wrote to standard error. Absent means none, and a session that writes something with no `.note` beside it **fails** — so a new complaint cannot appear unnoticed |
| `sessions/name.mcp` | a marker: this session is MCP rather than LSP. The server is started with `--mcp` and each line of the `.jsonl` **is** a frame, since that transport delimits by newlines and has no header to compute |
| `sessions/name.scratch` | the scratch path for this session, one line, in place of the work directory's. It exists for a session that is about a path the server **cannot** write, and so must name one no work directory would be |
| `sessions/name.tmpdir` | a marker: this session is about the path the server picks when it is told none. `PASLS_SCRATCH` is left unset, `TMPDIR` is a directory of the session's own, and the files left in it must be named for the server's process id. Every other session is handed a path, so this is the only one that can see the default |
| `sessions/name.workspace` | a marker: this session opens files on disk. `%ROOT%` in the `.jsonl` becomes this checkout's path, and before the diff the harness writes the root back and blanks the `Content-Length`s — an absolute path is as long as somebody's home directory, so neither it nor the count over it can be written down once. Such a session pins the *behaviour*; the sessions that name no file pin the framing |

To add one, write the `.jsonl`, run `run.sh`, and read what it says before
saving the output as the golden. A golden agrees with whatever wrote it, which
is the standing rule everywhere in this tree: regenerating one is a decision to
argue for in the commit message, not a step.

## What it is for

The product of writing this is **the list of what it demands** — the roadmap's
"first findings" section, which is where each one is recorded and where you can
see which have been acted on. Writing the first increment produced five, one of
which (`maxImports = 8`, so a ten-module program could not be compiled at all)
had to be fixed before the program could exist.
