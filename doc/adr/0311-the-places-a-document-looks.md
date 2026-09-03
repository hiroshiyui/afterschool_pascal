# 311. The places a document looks

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Extends
[ADR-0242](0242-a-document-is-not-a-file-the-compiler-can-open.md)'s sidecar
reading to ADR-0244's other sidecar. Found by asking the language server about
`examples/word_freq.pas` — a program landed the day before, in a directory
added the day before, to be *read*.

## Context

`lsp/pasls.pas` compiles a document by handing the compiler the components
that document depends on, and it learns them from a `.components` sidecar:
one path a line, in dependency order, which is this tree's build description
and what `tests/run_test.sh`, `selfhost/irtest.sh`, CMake, `lsp/build.sh` and
four gates already read. The comment above `ReadSidecar` says why that is the
right shape — a server reading the project's build description is what every
language server does, and the alternative, resolving `import PasError;` to a
file by name, *wants the compiler to answer rather than a second reader of
Pascal living here*.

**ADR-0244 had already made the compiler answer**, and the corpus had already
taken it up. A `name.importpath` sidecar names *directories*, one a line, and
the compiler searches them by interface name; `run_test.sh` reads it and says
in as many words that it and `.components` are deliberately different
questions — one names the files and this one names the places, so a case with
one *is asserting that the compiler found what it was not told about*.

The server read the first and not the second. The tree has 64 `.components`
sidecars and 8 `.importpath` ones, and **seven of the eight are the
`examples/` programs** (ADR-0295). So opening `examples/word_freq.pas` in an
editor produced **21 diagnostics, every one false**: `no interface named
'pascontainer' has been exported`, and then one for each name it exports.

That is the exact failure the server's own comment says it exists to prevent —
*a server that did nothing about it would be usable on a single-file program
and on nothing in the repository it was written in*. The convention simply
arrived after the server did, and nothing could see it: `lsp/run.sh` replays
sessions, and every session named its components because that was the only
thing the server read.

## Decision

**`ReadImportPaths` reads a `name.importpath` sidecar and passes
`--import-path` for each directory it names**, resolved against the sidecar's
own directory, exactly as `run_test.sh` resolves it.

- **It combines with `.components` rather than replacing it.** They are
  different claims and a document may make both: these are the components I
  follow, *and* here is where to look for the rest. `ImportsFor` appends the
  second to whatever the first answered.

- **Only the sidecar beside the document and named after it is read. There is
  no walk.** `.components` can be searched for through the workspace because
  it *names its target*, so a sidecar found anywhere can say whether it is
  about this file. A list of directories names nobody, and a walk would hand
  one document another document's search path — a wrong answer rather than a
  missing one, which is the trade this tree refuses everywhere else
  (ADR-0292's file table, ADR-0291's cut URI).

- **`name.importenv` is not read**, and that is deliberate: see below.

## Evidence

`lsp/sessions/import_path.jsonl`, with a fixture that **cannot** be compiled
by naming files — `importclient/asks.pas` imports a module in a *sibling*
directory, and the only thing that places it is the `../importpath` line in
the sidecar beside it. The golden was written as a prediction and matched on
the first run once its framing carried `\r\n`; the content was right first
time.

The claim is an empty `diagnostics` array, which is the whole of it: the
server either found the module or it did not.

The mutation (`tests/mutation/mutants/0311-the-places-sidecar-unread.mut`)
guards the call away and kills `import_path` alone — every other session names
its components and none of them can see this.

## What is not done

**`name.importenv` is unread.** It holds one line, the value of
`AFTERSCHOOL_PASCAL_PATH`, and `run_test.sh`'s comment says why it is a second
sidecar rather than a second line of the first: *a flag is what one command
line says and a variable is what a machine was configured with*. One file in
the tree has one (`tests/extended/import_by_env.importenv`), and it exists to
test the compiler's reading of the variable rather than to describe a project.
A server that set that variable would be configuring the machine on the
document's behalf, which is a larger claim than passing a flag. ADR-0116's
bar: no caller has wanted it.

**Nothing resolves an import with no sidecar at all.** A user's own program
still needs one of the two files beside it, and `README.md`'s promise that a
program and its modules in one directory find each other holds for the
*compiler* (ADR-0308) and not yet for the server — which could read the
document's own directory as a search path and does not, because a server
guessing at a search path is how one document gets another's.

## Consequences

**A convention added to the corpus is a convention the tools have to be told
about.** `.importpath` landed with ADR-0244 and grew a second user with
ADR-0295, and both times the question was whether the *compiler* honoured it.
The server is the third reader of this tree's sidecars and nothing enumerates
them; `doc/sop.md` §7 gains that row.

**The server was not the only reader that had not been told.**
`tests/checks/warning_free.py` compiles every source under `selfhost/`, `lib/`
and `lsp/` with a *fixed* list of import paths, which is where this tree's
library lives and cannot be where a fixture's neighbour is — so the fixture
written as evidence for this record failed that gate, and the gate was the
third reader of the sidecar to be told about it. That is the register row
above, demonstrated by the change that wrote it.

**The finding came from using the thing.** No gate could produce it: every LSP
session named its components, and every `examples/` case is compiled by
`run_test.sh`, which reads both sidecars and always did. What found it was
opening one of the twelve programs the way a reader would. That is
ADR-0308's *a document can be an oracle* one step further on — here the
oracle was the corpus, read through the tool it was written to be read with.
