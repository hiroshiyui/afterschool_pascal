# 298. No two library modules export one spelling

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Closes the second of `doc/roadmap.md`'s usability
findings, *"`only` is a collision workaround, not a narrowing tool"*, and
retires the one argument [ADR-0264](0264-tls-is-a-module-and-a-transcription.md)
and [ADR-0265](0265-the-grammar-and-the-transport-are-two-modules.md) each
gave for importing a module `qualified`. Neither record is edited; what they
decided about transports and grammars stands, and what this changes is a
*naming* rule those two had left to convention.

## Context

`lsp/pasls.pas` imports twelve modules and carried two §6.11.3 `only`
clauses, and the comment beside each said why: not to narrow, but because a
name it did not want from one module was a name it did want from another —
`PasDir` exports `Close`, which `PasIO` also exports, and `PasParse` exports
`ResultText`, which another module does too. The roadmap entry recording that
said collisions grow with the product of the export lists, that `only` is
per-import and enumerative, that `qualified` makes every use of a module
wordier and not only the colliding one, and that the fortieth-import program
should be written before anything was designed.

**The first thing this record did was count, and the count changed the
task.** Every export-part under `lib/` and `lib/dialect/` was read and every
folded spelling exported by more than one module listed. The entry named
three. There were **thirty-seven**:

| Kind | Spellings | Modules |
| --- | --- | --- |
| the generic container against the fixed ones it generalised | `VecFree`, `VecPush`, `VecPop`, `VecGet`, `VecSet`, `VecLen`, `VecCap`, `VecClear`, `VecReserve`, `MapFree`, `MapPut`, `MapGet`, `MapHas`, `MapDelete`, `MapCount`, `MapSlots`, `MapLiveAt`, `MapKeyAt`, `MapKey`, `KeyMax`, `CapMax` | `PasContainer` against `PasVector` and `PasMap` |
| one transport vocabulary over five carriers | `Close` (five modules), `ReadLine` and `WriteLine` (four each), `WriteText` (four), `OpenRead`, `Connect`, `Send`, `Receive`, `Exchange` | `PasIO`, `PasNet`, `PasTls`, `PasStream`, `PasFile`, `PasHttp`, `PasHttps` |
| a bound every module names the same way | `LineMax` (`PasJson`, `PasStream`, `PasFile`, `PasStrings`), `ItemMax` (`PasList`, `PasStrVec`), `NameMax` (`PasDir`, `PasJson`) | — |
| accidents | `ResultText` (`PasIO`, `PasParse` — not `PasError`, as the entry said), `List` (`PasDir`'s routine against `PasList`'s *type*), `Upper` and `Lower` (`PasStrings`, `PasUnicode`) | — |

Two of the four kinds were deliberate and recorded. `README.md` says
`PasContainer` is *"what `PasVector`, `PasStrVec` and `PasMap` are, written
once"*, and ADR-0264 and ADR-0265 each call the shared vocabulary *"the
property worth keeping"*: a program moving from a socket to a TLS connection,
or from HTTP to HTTPS, changes the type of a variable and nothing else.

**And each of those two modules imports the one beneath it `qualified`.**
`PasTls` wrote `PasNet.Connect`, `PasNet.Close`; `PasHttps` wrote
`PasHttp.BeginRequest`, `PasHttp.Request` and eight more. The property worth
keeping was being paid for, at the first importer, with exactly the cost the
roadmap entry complained of — and the comment in `PasHttps` already conceded
it: *"a program changes the qualifier on a call and not the name of what it is
doing"*. A qualifier on a call and a prefix on a name are the same edit. The
difference is where it is paid: the prefix once, in the library; the qualifier
at every importer, forever, and only after a collision has been noticed.

The language has no overloading, and ISO/IEC 10206:1991 §6.11.2 puts every
name a program imports into one scope. So two modules exporting one spelling
is not something a program can resolve by meaning; it can only be told to
choose. A library that makes a program choose is a library that scales as the
entry said — with the product of the export lists.

## Decision

**No two modules under `lib/` export one spelling**, folded as §6.1.3 folds
identifiers. It is a rule about the library and not about the language: the
standard's `only`, `qualified` and `=>` are all still there for a program
importing a module *outside* `lib/`, and nothing in the compiler changes.

**The less general side of every collision was renamed**, and where that side
was a module with several verbs, the whole module took the prefix so that its
verbs read alike:

- `PasDir`: `Open`, `Next`, `Close`, `List`, `NameMax` → `OpenDir`,
  `NextEntry`, `CloseDir`, `ListDir`, `EntryNameMax`. `PasIO.Close` keeps the
  general name: a socket is a descriptor and a directory is not.
- `PasNet`: nine routines take `Net` — `NetConnect`, `NetListen`, `NetAccept`,
  `NetService`, `NetWriteText`, `NetWriteLine`, `NetReadLine`, `NetClose`,
  `NetWait`. `PasTls`: six take `Tls`, so `NetConnect` and `TlsConnect` stand
  side by side, which is what ADR-0264's property becomes. `PasStream`: eight
  take `Stream`. `PasHttps`: `HttpsSend`, `HttpsReceive`, `HttpsExchange`,
  `PasHttp` keeping the plain spellings as the grammar the two transports
  share. `PasFile` keeps `ReadLine` and `WriteLine`, the by-path convenience
  being the oldest holder of them and colliding with nothing once the
  transports are prefixed.
- `PasVector`: `IVecNew` and the rest, `IVecPtr`, `IVecCapMax` — the `I`
  standing beside `PasStrVec`'s `S`, which already existed for this reason.
  `PasMap`: `SMapPut` and the rest, `SMapKey`, `SMapKeyMax`, `SMapCapMax`.
  `PasContainer`, the generic, keeps `Vec`, `Map`, `CapMax` and `KeyMax`.
- The bounds take the type they bound: `FileLineMax`, `StreamLineMax`,
  `JsonLineMax`, `JsonNameMax`, `ListItemMax`; `PasStrings.LineMax` and
  `PasStrVec.ItemMax` keep theirs.
- `ResultText` becomes `IntResultText` and `CountResultText`, on
  `PasError.ErrorText`'s pattern — the text of a result type `X` is `XText` —
  and `lib/dialect/README.md`'s convention says so. `PasStrings.Upper` and
  `Lower` become `UpperAscii` and `LowerAscii`; `PasUnicode`'s are the full
  mappings and keep the words.

Sixty-nine spellings moved. Every `only` and every `qualified` an importer in
this tree had written for a collision is gone: both of `lsp/pasls.pas`'s,
`PasTls`'s and `PasHttps`'s, and the one `tests/checks/tls/tls_https.pas`
carried. The cases that exercise the feature itself —
`tests/extended/module_qualified.pas`, `module_importlist.pas` and their
siblings — are untouched, because they import modules of their own.

**The rule is held by a gate, `export-unique`**, and not by a convention. It
reads every source under `lib/` and `lib/dialect/` with `pascalc
--dump-tokens` and walks each export-part in the lexer's own tokens — `export`
name `=` `(` … `)` `;`, with §6.11.2's `identifier => identifier` taking the
right-hand spelling and `identifier .. identifier` counted as its two ends. A
regex over the text was the shape `diagnostic-coverage` broke on (ADR-0273):
an export-list spans lines, and the ones here carry comments. It fails on
three things — a folded spelling in two modules, a source under `lib/` with
no export-part, and a sweep that read fewer than 20 modules or 200 exports —
and prints what it swept: **486 exports across 31 modules** as this is
written.

## Evidence

The regex scan that measured the problem and the gate's token walk agree on
486 and 31, which is the one cross-check available for a reader of
export-parts that nothing else here reads.

**Two mutations, because the gate's argument has two halves.**

The first gives `PasDir` its `Close` back — the export-list item and the two
declarations — which is a module that compiles, so the mutant is a working
library with the defect in it. The gate names the pair and the module of
each:

```
export-unique: 1 spelling(s) are exported by more than one module
    close: lib/dialect/pasdir.pas (pasdir), lib/dialect/pasio.pas (pasio)
```

**And so does the rest of the suite, which is the finding this record did
not expect.** `lsp-server`, `warning-free`, `heap-balance` and
`selfhost-codegen` all fail with it, because `lsp/pasls.pas` now imports
`PasDir` and `PasIO` *plain* and is therefore exactly the program the
collision breaks; before this record it carried the `only` and would have
compiled through the mutation unchanged. So the rename did not only remove a
workaround, it turned the one client that had met the collision into an
oracle for it — at the client, and only for the pairs that client imports.

The second is the half only the gate can see: `PasStrings` gets `Upper` back,
against `PasUnicode`'s. Nothing in this tree imports the two together, so
**806 cases stay green and `export-unique` alone fails** — which is the
roadmap entry's own point, met as a measurement. A collision between two
modules no program has yet imported together is invisible to every oracle
that compiles a program, and the fortieth-import program is the one that
would have found it.

`install-layout` compiles one `import <name>;` program per installed module
and `warning-free` compiles every module and the server, so a renamed export
that any client in this tree still spelt the old way would have failed there;
both pass, as do the 806 `ctest` cases and every `lsp/run.sh` session.

## What is not done

**`PasVector` and `PasMap` are not retired.** `README.md` keeps them on the
argument that *"a program that avoids the dialect layer must still have a
vector and a map"*, and since ADR-0232 there is no such program: there is one
language. That is an argument for deleting two modules and it is not this
record's to make; the rename costs them a prefix and takes nothing else.

**Nothing compares a library export against the required identifiers.**
`PasHttp` exports `Send` and `Receive`, which are also the dialect's channel
operations (ADR-0268), shadowable by §6.1.3 as every required identifier is.
The gate reads modules against modules and would not see that; a program
importing `PasHttp` and using a channel is the case that would.

**The spelling of a prefix is not checked**, only that no two modules share
a name. `NetConnect` beside `TlsConnect` is a choice this record made; a
module exporting `ConnectNet` tomorrow would pass.

**No `except` clause, and no use of `=>`.** A language-level *import
everything but these* was the alternative that reads most naturally against
the roadmap entry, and §6.11.3's `=>` renaming at the import already exists
for the same purpose; both were declined for one reason. Each is a tool for
the *importer* to resolve a collision the *library* created, so each leaves
the collision in place and asks every program to meet it — which is what the
entry measured as the wrong scaling. A rule on the library removes the
collision for every program at once, needs no syntax, and can be gated. It is
also the cheaper: `except` is a parser and Sema change with a spec clause and
a `tests/spec/` scenario, and this is a rename and a Python script.

## Consequences

**A record that counts three of thirty-seven is a report of the afternoon it
was typed.** The roadmap's own lesson — a row there should be a report and
not an estimate — met a third time in one chapter, and each time the
measurement took minutes. The entry was right about the scaling and wrong
about the size, and the size is what changed the answer: at three
collisions a comment beside an import is proportionate, and at thirty-seven
a rule is.

**A deliberate collision is a collision.** ADR-0264 and ADR-0265 recorded a
property worth keeping and the mechanism that kept it was the cost being
argued against. The pattern to carry is that *the first importer of a module
is the measurement of its interface*, and both of those modules had one, and
it wrote `qualified` on the first line.

**A new library module has a rule to meet before it has a client**, which is
new. Until now a module's export-list was judged by whether it compiled; now
every spelling in it is checked against thirty others, at `ctest` and not at
the moment a program happens to import both. A module that wants a general
verb takes a prefix, and the prefixes are in the table above.

**The property ADR-0264 named survives, spelt differently.** A program moving
from a socket to a TLS connection changes the type of one variable and the
prefix on its calls, and imports both modules plain. What it no longer does
is write a qualifier that the next program has to write again.
