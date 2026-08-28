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
| `PASLS_COMPILER` | what to invoke to compile a document. Default `pascalc`, so it must be on `PATH`; `tools/pascalcc` works too |
| `PASLS_SCRATCH` | the file the current document is written to before it is compiled. Default `$TMPDIR/pasls-scratch.pas`, and `/tmp` where `TMPDIR` is unset |

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
exists. There is no `getpid` in this tree and no `mkstemp`, so the name is
fixed and two servers sharing a `TMPDIR` would share it. Point
`PASLS_SCRATCH` somewhere of your own if you run more than one.

It negotiates the **position encoding** at `initialize`. LSP counts a
`Position.character` in UTF-16 code units by default; this compiler counts
bytes. If your client offers `utf-8` in `general.positionEncodings` the server
takes it and hands the compiler's own columns straight through; otherwise it
converts, and either way it says which in `positionEncoding` so nothing is
guessing. A file holding nothing above U+007F is identical under both.

Anything the server has to say to a person goes to **standard error**. It has
to: standard output is the protocol, and a Pascal `writeln` is buffered where a
descriptor write is not, so a program that used both would interleave them
unpredictably. The program declares no program-parameters, which makes a stray
`writeln` a compile-time error rather than a corrupted frame.

## The sessions

`run.sh` builds the server and replays every recorded conversation against it.
It is one `ctest` case, `lsp-server`.

```sh
lsp/run.sh tools/pascalcc build/bin/pascalc
```

A session is three files:

| | |
| --- | --- |
| `sessions/name.jsonl` | one JSON-RPC message per line. A blank line or one beginning with `#` is a comment — the harness computes the `Content-Length` frames, so the session stays readable and the byte counts stay right |
| `sessions/name.out` | the **exact bytes** the server wrote to standard output, carriage returns and byte counts included. A change to what `JsonRender` or `LspWrite` produces fails here even when the JSON still parses |
| `sessions/name.note` | what it wrote to standard error. Absent means none, and a session that writes something with no `.note` beside it **fails** — so a new complaint cannot appear unnoticed |
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
