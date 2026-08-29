# 239. The compiler answers a tool's question about a program

Date: 2026-08-29

## Status

Accepted, 2026-08-29.

It supersedes nothing. It is the decision
[ADR-0085](0085-retire-stage-0.md) left implicit when it demoted the tree
dumps from a specification to a debugging aid: nothing then said what a
*machine* should read instead, because until the language server there was no
machine reading.

## Context

LSP's `textDocument/documentSymbol` asks a server for the outline of a
document — the names it declares, what kind each is, where it is and how they
nest. It is the second method an editor wants after diagnostics, and it is the
first that cannot be answered out of the compiler's diagnostics at all.

**The only structured thing this compiler wrote about a program was
`--dump-sema`.** While there were two front ends that dump was a
specification, and `selfhost/difftest.sh` diffed the two over every `.pas` in
the tree. ADR-0085 retired stage 0 and ADR-0232 retired the reference front
end, and what is left is a format that agrees with whoever wrote it. Its
header comment says as much. It is also a *tree*: frames, layouts, type
annotations, the field numbering of every record — a hundred lines for the
twenty a document's outline holds.

So the question is where the outline comes from, and there are two answers.

**The server parses `--dump-sema`.** It is free today and it is the mistake
this project has now named four times in other shapes. A reader of
Pascal-shaped output living outside the compiler drifts from the compiler:
`foreign-reserved` broke on the day of the three-component split because
§6.11.1 puts an exported routine's header in the module-heading *and* leaves
the block repeating the name, so `^function Name(` matched an interface entry
with no body. ADR-0229 and ADR-0230 answered that class of defect by moving
the `kind-exhaustive` gate off a Pascal-parsing regex and onto the compiler's
own `--dump-dispatch`, deleting 85 lines of regex and finding three dispatch
sites the text match had simply missed. A server reading `--dump-sema` would
be the same reader, one layer further out, and reading a format nothing
promises to keep.

**The compiler answers the question it is being asked.** `--dump-dispatch`
(ADR-0229) and `--dump-layout` (ADR-0185) are the precedent and they are
recent: each exists because a reader outside the compiler was answering by
accident what the compiler knew exactly, and each is line-oriented because its
reader is not a person. There was no third, and the reason there was no third
is that the first two have gates for callers and a gate is written by whoever
is holding the compiler. The language server is the first caller that is not.

## Decision

**`pascalc --dump-symbols` writes every name a source declares, one to a
line**, and `lsp/pasls.pas` answers `documentSymbol` out of it and out of
nothing else.

    symbol <depth> <kind> <line> <col> <len> <name>

Six fields, and the four decisions in them are these.

**It stops after the parse.** Not after Sema — and this is the whole of why it
is useful rather than an economy. An outline is what an editor draws *while
the file is wrong*: a half-typed statement, a name not declared yet. Every
question Sema could answer is one that would take the outline away at the
moment a reader most wants it. A parse is also all it needs, since a
declaration's name, kind and position are the parser's own findings. Two
things follow. A source's outline never depends on another file being found,
so **no `--import` is passed** — which matters most for the file whose
components the server could not place, where the diagnostics are useless and
the outline is still exactly right. And the flag is a *stage* flag like
`--dump-ast`, deliberately not a section of `--dump-all`, which runs the whole
pipeline.

**It answers in Pascal's vocabulary.** `procedure`, `record`, `enum`,
`value` — ten words, not LSP's `SymbolKind` numbers. The compiler does not
know what a language server is, and a numbering scheme owned by a third party
changing under a Pascal compiler would be a version of that protocol baked
into it. The server maps the words, in one function.

**It reports the folded spelling, and a position and a length beside it.** The
lexer case-folds an identifier and the string pool holds only that, so
`CaseTest` is reported as `casetest`. Retaining both spellings would be a
change to the pool, which is the one array in this tree whose headroom is
measured (ADR-0126). It is not needed: a caller holding the document slices
`len` bytes at the position and recovers what the programmer typed, which is
what the server does. The name in the dump is the compiler's answer; it is not
a display string.

**The position is the name's, and there is only one of it.** The node's own
line and column are the word-symbol that opened the declaration — `procedure`,
not the identifier after it — and both tree dumps print them that way, so
`nkProcDecl` and `nkModule` gained a `pdNameLine`/`mdNameLine` pair rather
than having their existing one moved. There is no *end*: the parse tree records
where a declaration begins and never where it finishes, so the protocol's
`range` and `selectionRange` are both the extent of the name. That is the
extent this compiler can actually name.

**The order is written order**, which is not the order the declaration parts
hold: §6.2.1 lets them interleave and §6.2.2.9 then makes written order the
only correct one (ADR-0069). The walk is the same selection over four lists
`checkDeclarations` makes, asking the `Earlier` it already exports — and it
holds no list of its own, so it reports a file of any size **without adding a
bound**.

`tools/pascalcc` passes any `--dump-` flag through and does nothing else with
it. That is not tidiness: a user may as well name the driver in
`PASLS_COMPILER` as name `pascalc`, and did — and got `pascalcc: unknown
option '--dump-symbols'` written to a stream nothing was reading, which is an
empty outline and no complaint anywhere.

## Consequences

**The compiler now has a surface a tool asks questions of**, and it is one
question wide. Nothing here decides what the second is; `documentSymbol` is
answered and hover, go-to-definition and workspace symbols are not, and each
will ask whether it belongs behind this flag, behind another, or behind
something that is not a flag at all. What this record settles is only that the
answer comes from the compiler rather than from a second reader of its
debugging output.

**Two bounds were met and one was removed.** `CaptureMax` is 16384 and the
outline of `selfhost/apfront.pas` is 51 192 bytes, so the server's existing
whole-output buffer would have stopped a third of the way through with nothing
said. An outline is a *list of lines*, so it is collected with `CaptureLines`
onto the heap and the bound is gone rather than raised — the per-line bound
that replaces it is `ItemMax`, against six short fields. `SymDepthMax` is the
one bound added, at 64 against a compiler whose own deepest nesting is three,
and it is reported when met (ADR-0110).

**A second `only` import-clause.** §6.11.3's `import PasParse only (...)`,
because `PasParse` and `PasError` both export `ResultText`. `PasDir` was the
first and this makes it a pattern rather than an incident: a library of 25
modules with no namespacing collides, and `only` is what the standard gives.

**What it does not do.** It reports no parameters, no labels, and no import
list; a record's variant fields are reported at the depth of its fixed ones,
because an outline has no name for the nesting an arm would add and the
question *which arm selects this field* is one the source answers and an
outline cannot. A source that does not **parse** gets no outline at all, which
is the ordinary degradation and the one an editor expects.

**Evidence.** `tests/dumps/symbols.pas` and `symbols_module.pas` are the two
golden cases — the first for the four parts interleaved, a variant part, a
schema, an inline denoter, a forward declaration reported once and an external
procedure with nothing under it; the second for a module-heading and block
being one scope at one depth, and for §6.13's module-then-program in one file.
`lsp/sessions/symbols.jsonl` is the protocol half, and what it pins that no
dump case can is that the names come back with the **case the programmer
wrote** and that the outline of a document that no longer compiles is
unchanged. Removing the forward-declaration skip adds one line to a golden;
removing the written-order selection moves twelve. `producttest.sh` asks the
driver the question that failed silently, and fails without the passthrough.
