# 238. The server reads the build description

Date: 2026-08-29

## Status

Accepted, 2026-08-29.

It supersedes nothing. It answers the eleventh finding of
[`doc/roadmap.md`](../roadmap.md)'s language-server chapter, and it does *not*
close the gap `README.md` names — resolution of an interface name to a file —
which stays open and is now the sharper question for having been worked around.

## Context

The compiler is handed one file. A program is several (§6.13), and the
components arrive as `--import` words the caller computes. Every harness here
computes them the same way: from a `.components` sidecar, a path per line
relative to the sidecar's own directory, in dependency order.

The server computed none. So `pascalc` was handed a module alone, and

    lib/dialect/pasjson.pas:64:8: error: no interface named 'paserror' has been
                                        exported

was followed by **47 more** — two real and 46 cascade from names that arrived
with the interfaces. `selfhost/apfront.pas` produced **21 171**, which is not a
partial answer but noise the length of the file. Every module in `lib/`, every
source in `selfhost/`, and every case with a sidecar behaved the same way. **The server worked on
`hello.pas` and on nothing in the repository it was written in**, which is not
a partial implementation of a language server so much as a demonstration that
the first increment had only ever been pointed at documents it wrote itself.

Two ways to answer it, and they are not close.

**Resolve the interface name to a file.** A module says `import PasError;` in
its own source, so the information is there; what is missing is a search path
and a rule taking `PasError` to `paserror.pas`. That is the gap `README.md`
states in as many words — *"There is no install location and no resolution by
name"* — and it belongs to the **compiler**: resolution has to be transitive
and in dependency order, which means reading module headings recursively, and
the compiler is the thing that reads module headings. Putting it in the server
would put a second reader of Pascal in this tree, which is the mistake this
chapter has already named three times in a different form.

**Read the build description.** `.components` is one, and it is already read by
`tests/run_test.sh`, `selfhost/irtest.sh`, CMake, `lsp/build.sh` and four
gates. It is what `compile_commands.json` is to clangd and `go.mod` is to
gopls, and reading the project's build description is what every language
server actually does — none of them makes the compiler resolve names.

## Decision

The server reads `.components`, and **one rule covers every shape: take the
entries before this file.**

- A sidecar **beside** the file and named after it answers first — it is the
  one whose author meant this file. `lsp/pasls.components` does not name
  `pasls.pas`, so the answer is all ten entries.
- `selfhost/compiler.components` sits beside `compiler.pas` **and names it**,
  and the answer is the two entries before it. Handing a component its own
  interface is what `run_test.sh` is careful not to do, and the one rule gets
  this right without a second case.
- Otherwise the workspace is walked for a sidecar naming the file, files before
  directories and both sorted, to a depth of eight, skipping hidden
  directories and anything beginning with `build` — a build tree holds a second
  copy of every sidecar and would answer with paths into itself.

The workspace comes from `initialize`: `workspaceFolders` where the client
sends them, `rootUri` where it sends the older field, and neither where it
opened a single file — in which case only a sidecar beside the document is
read. A `file:///…` URI becomes a path with percent-escapes undone, because a
project under a directory with a space in its name is otherwise a path that is
not there.

`Resolve` collapses `.` and `..` before anything is compared. The sidecars are
written `../../lib/dialect/paserror.pas`, and two spellings of one file are two
strings.

## Consequences

- **The server works on this repository.** `lib/dialect/pasjson.pas`,
  `selfhost/apfront.pas` and `selfhost/compiler.pas` each report **zero**
  diagnostics where they reported **48**, **21 171** and **8 394** — the last
  two being what an editor showed for the compiler's own front end and driver,
  which is the number worth quoting rather than the first: it is not a partial
  answer, it is noise the length of the file. `lsp/sessions/imports`
  pins the three shapes over a three-file workspace beside it, and pins that a
  *real* error in a resolved module still arrives at the right position —
  an empty array is also what a server that failed to run the compiler
  produces, so the pair is what says the imports were resolved and the
  compilation happened.
- **`README.md`'s gap is not closed and is now sharper.** A file that no
  sidecar names gets no imports, which is right for an unsaved buffer and wrong
  for a module in a project that does not use this convention. Resolution by
  name would answer both, and it is the compiler's to do.
- **A file named by several sidecars gets whichever the sorted walk reaches
  first.** They differ: `tests/dialect/lib_json.components` gives `pasjson.pas`
  a prefix of two, `lsp/pasls.components` a prefix of seven. Both compile, a
  superset of the imports being harmless, so the rule is *deterministic* rather
  than *minimal* — and nothing checks that the one chosen is the one a reader
  would have chosen.
- **`import PasDir only (List)` is the first import-clause in this tree outside
  a test.** §6.11.3's clause is there for a collision and this is one: `PasDir`
  exports `Close` and `NameMax`, and so do `PasIO` and `PasJson`. Naming the
  one routine wanted is cheaper than qualifying every use of the other two.
- **A session that names files on disk cannot pin its byte counts**, because
  the URI it echoes holds an absolute path whose length is the checkout's. Such
  a session carries a `.workspace` marker; the harness substitutes `%ROOT%`
  into its input and, before the diff, writes the root back and blanks the
  `Content-Length`s. What it pins is the behaviour — the four sessions that
  name no file pin the framing, and they are the majority.
- **The walk is per compilation and not cached.** 42 sidecars and 63
  directories in this tree, read on every `didChange` a beside-sidecar does not
  answer. It is milliseconds today and it is the wrong shape for a workspace of
  ten thousand files; caching it needs an invalidation rule, which needs
  `workspace/didChangeWatchedFiles`, which is a feature nobody has asked for.

## Alternatives considered

- **Resolution by name, in the server.** Rejected: it puts a second reader of
  Pascal's import-part here, and the roadmap's own lesson is that the compiler
  should answer questions about a program.
- **Resolution by name, in the compiler** — a `--import-path` flag resolving
  transitively. This is the right feature and it is deferred, not refused: it
  wants a search-path policy, a diagnostic for a name that resolves to nothing,
  and a decision about whether the compiler may open files it was not given.
  What asked for it was a server that needed *this* tree's components, and this
  tree writes them down.
- **A project file of the server's own.** Rejected outright: a second place for
  the truth to live, when four harnesses and CMake already read the first.
