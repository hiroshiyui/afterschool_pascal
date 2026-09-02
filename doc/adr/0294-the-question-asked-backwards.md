# 294. The question asked backwards

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Closes the `references` and `rename` rows of
`doc/roadmap.md`'s Tooling table, and found one defect in the compiler on the
way, in the dump [ADR-0246](0246-what-a-name-denotes-and-where-it-was-written.md)
wrote and every session since had read.

## Context

`textDocument/definition` asks *where was this name declared*. An editor has
two more questions built on the same fact and the server answered neither:
`textDocument/references` — where else is the declared thing named — and
`textDocument/rename`, which is that list with an edit per entry. The roadmap
called the first *the row that is nearly free* and it was right about the
reason: every `use` row the document already caches (ADR-0252) carries the
defining-point the occurrence resolved to, so the rows sharing the
defining-point of the name under the cursor are the occurrences of one thing.
No compiler change was needed for the question itself.

Four things needed deciding, and one turned out to be a defect.

**What the answer is the answer *for*.** A `--dump-uses` reports the
occurrences in the document the compiler was handed and the defining-points
they resolved to, which may lie in a component the compilation read. It
reports **no** occurrence inside a component — `NotingHere` asks whether the
text being checked is the document's, for the reason ADR-0246 gives: a
position in another file would be resolved against the wrong text. So a
rename of a name declared in `middle.pas` and used in `client.pas`, asked
from `client.pas`, had one row to work from and four occurrences it could
not see — the export list, the heading, the block completing it and the
result assignment — and a rename that edited the one and not the four is a
program that no longer compiles.

**A field has no row of its own.** ADR-0250 reports a block's declarations by
walking the scope, and §6.4.3.3's record region is not one; a schema's
discriminant is the same shape. A rename of a field that edited every use and
not the declaration is the same broken program from the other side.

**The new name.** Which spellings are word-symbols is the lexer's knowledge
(§6.1.2), and a table of forty-five words copied into the server is the shape
`foreign-reserved` broke on and `kind-exhaustive` was moved off twice.

**And the qualified name**, which is where the defect was. ADR-0246 reports
`M.x` as two nested spans measured from where `M` begins — the interface for
its own length, the whole for `M.x`'s — so that a position inside `M` finds
the interface and one inside `x` finds the wider span. In an *expression* the
node is an `nkField` and an `nkField` stands at its point: `CheckExpr` passed
the node's own position, so both spans began at the `.`. Hovering `Middle`
in `Middle.Doubled` answered nothing, hovering `.Doubl` answered
`interface Middle`, and no session had ever stood on a qualified name in an
expression. `definition_across` asks about `import Base;`, which is a
different node and was right.

## Decision

**Answered in the server, from the cached dump, per translation.** The rows
of the document give its own occurrences. Where the defining-point is in a
component, every entry of the document's file table is compiled again with
`--dump-uses`, with the table entries *before* it as its imports — the table
is in the order the `--import`s were given and a `.components` is in
dependency order, so the prefix is what the document's own translation read
and not a second lookup free to differ — and its rows are matched against
the same defining-point, by path. A name the document declares cannot be
named by anything it imports, so nothing is recompiled for one. The unit is
the translation; a second open document importing the same module is another
translation and is not asked.

**The declaration is added by position** when no row already stands at the
defining-point, which covers a field, a discriminant, and a declaration in a
component the client never opened with one rule. `includeDeclaration: false`
drops the row standing at its own defining-point, which ADR-0250 made the
declaration; the block completing a heading (§6.11.1) is an applied
occurrence and stays.

**A report may be partial and an edit may not.** `references` answers what
was found. `rename` refuses — LSP 3.17's `RequestFailed`, with a message the
editor shows, rather than `null`, which is legal and says nothing — for a
required identifier, whose defining-point is nowhere (§6.2.2.10) and whose
key `(0, 0, 0)` every other required identifier shares; for a component whose
dump could not be taken; for a qualified name written `M . x`, whose wider
span stops short (ADR-0246) and cannot be placed; and for a new name that is
not exactly one identifier. `references` reports the unplaceable span whole,
a worse answer and not a wrong one.

**The new name is judged by the compiler.** It is written alone to a file
beside the scratch one and `--dump-tokens` must answer one `ident` and then
`eof`, with a folded spelling as long as what was given — which is what
refuses `two words`, `9x`, `begin` and the empty string without this program
knowing what any of them is.

**`documentChanges`, not `changes`.** `changes` is an object keyed by URI and
`JsonName` is 255 characters; a URI this server holds is as long as a path
since ADR-0291, and `definition_deep`'s is 309. A `TextDocumentEdit` carries
its URI as a value and `JsonNewText` takes one at any length. The version is
`null`, which the field admits and which is the truth.

**`textDocument/prepareRename` is answered**, being the same lookup: the
range of the identifier and its spelling as written. A qualified name's range
is the constituent alone, the last `declLen` characters of the span when the
point stands immediately before them.

**The compiler passes the qualifier's position.** Two call sites in
`apfront.pas` — the expression and the procedural actual — now hand
`LookupName` the base `nkVar`'s line and column rather than the `nkField`'s,
which is where ADR-0246's own comment said the spans were measured from.
`tests/dumps/uses_module.dump` moves by six rows, each by the length of the
qualifier, and that move is the evidence: the old golden recorded `shared` at
the column of its point.

## Evidence

Five sessions, each golden written as a prediction from the protocol and
matched byte for byte on the first run — except `rename_across`, whose
difference was the defect above and not the prediction. `references` and
`rename` on one document, with a variable, a field asked through `p.x` and
through §6.8.3.10's bare form, a procedure, a required identifier and a
position on no name; `references_across` and `rename_across` over the
three-file workspace, following `Answer` and `Doubled` into the components
they were declared in, renaming an interface through its qualifier, and
refusing the spaced form; `rename_refused` for every refusal.

Five mutations of the server, each killing the sessions it should and no
other: dropping the declaration filter (`references`, `references_across`);
comparing the defining-point on its line alone, so `x, y: integer` is one
name (`references`, `rename`); never adding the declaration by position
(`references`, `rename`); ignoring the qualified tail (`rename_across`); and
not following the components (`references_across`, `rename_across`). A sixth
is the compiler's: reverting the two call sites fails `rename_across` and
`dump-uses_module` and nothing else, which is the measure of how invisible
the defect was.

## What it cannot see

- **A second open document that imports the same module.** The answer is per
  translation; the protocol names the method for the workspace it does not
  cover. Closing it means compiling every document that names the module,
  which is a project model this server does not have.
- **A component edited but not saved.** The compiler reads a component from
  disk, so the positions and the edits are the disk's; a client applying them
  to a dirty buffer of that file applies them to text the server never saw.
  `definition` has had the same edge since ADR-0246 and it is recorded here
  because a wrong edit costs more than a wrong jump.
- **A name written in a comment or a string**, which is not an occurrence
  and is not renamed. That is the right answer and it is worth saying.
- **A collision.** Renaming `a` to `b` where `b` is already in scope is
  accepted; the compiler's own diagnostics say so on the next `didChange`.

## Consequences

- **The compiler's `--dump-uses` was wrong about every qualified expression
  and nothing here could see it.** Three dump cases, five definition sessions
  and an independent client had all read the columns and none had stood on
  `M.x` in an expression. The session that found it was written for a
  different feature, which is ADR-0250's lesson met a third time: the golden
  moved, and the moved value — `.Doubl` as a placeholder — was visibly
  wrong.
- **A rename of a library name costs one compilation per component.**
  `lsp/pasls.pas` imports ten modules; renaming an exported name from it
  compiles each once, about a second in all. A rename is rare and a person
  waits for it; `references` pays the same and is not rare, and the answer
  is not cached because it is a question about a name and not about a
  document. If it becomes the complaint, the cache is a second vector per
  component beside the document's, invalidated with it.
- **`RefMax` is 8192 and it is a measurement**: the most-used name in the
  compiler's sources has 2037 occurrences in `compiler.pas`. Past it the
  list is cut, `references` says so on standard error, and `rename` refuses
  rather than renaming half.
- **The spaced qualified name is now a refusal rather than a silence.**
  ADR-0246 said the tail *answers nothing* and called that a worse answer;
  a rename that answered nothing would edit nothing and say nothing, so it
  says why instead. Reporting the constituent's own position from the
  compiler would close it, and nothing has asked twice.

## Alternatives rejected

**Reporting every file's occurrences from one compilation, with a file index
per row.** It is the natural extension of the dump and it makes the server's
loop over components disappear. Rejected because it changes the row's shape
under every reader — the server's, three dump goldens' and the coverage
sweep's — for an answer the server can assemble from the dumps it already
knows how to take, and because the rule for this increment was to prefer the
server-side answer where the dump does not genuinely lack the fact. The
qualifier's position *was* genuinely lacking, and that change was made.

**`changes` when every URI fits and `documentChanges` otherwise.** Two shapes
is a second thing to keep true, and every client this server has been driven
against reads `documentChanges`.

**A word-symbol table in the server.** Forty-five strings, correct today and
silently wrong on the day a forty-sixth is reserved, which ADR-0140 says
should not happen and this server should not be the place that notices.

**Refusing a rename over a document that does not check.** Probed and
rejected: a `use` row is written where a name resolves, and `counter` beside
an undeclared name on the same line is still reported, so a diagnostic
elsewhere in the file hides no occurrence of a name that resolved. A rename
in a file with an error in it is what a reader in the middle of an edit
wants, and ADR-0246 already argued the same for `definition`.
