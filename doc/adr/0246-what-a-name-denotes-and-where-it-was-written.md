# 246. What a name denotes, and where it was written

Date: 2026-08-30

## Status

Accepted, 2026-08-30.

It answers the sentence
[ADR-0239](0239-the-compiler-answers-a-tools-question.md) closed with, and
`doc/roadmap.md` repeats: *"the next method is the one that will decide
whether that surface generalises. Hover and go-to-definition want a type and a
defining point, which are Sema's and not the parser's — so neither can inherit
the sentence above, and each will have to say what it does about a file that
does not check. Nothing here settles it, and the record deliberately does
not."*

It settles it, and the surface generalises: the same shape as
`--dump-symbols` — the compiler answering in Pascal's words, a caller mapping
them onto a protocol — carries a second question, and the second question
turned out to be **two** questions with one answer.

## Context

`textDocument/definition` and `textDocument/hover` are one question asked
twice. Given a position in a document: what does the name there denote, and
where was it written? An editor draws the first as a tooltip and the second as
a jump, and a reader wants them in the same moment.

Neither can be answered the way an outline is. `--dump-symbols` stops after
the **parse** on purpose (ADR-0239) — an outline is what an editor draws while
the file is wrong, and a parse knows every declaration a source makes. But it
knows only that a declaration exists. *Which* declaration a given occurrence
denotes is §6.2.2's scope rules: the region chain, §6.2.2.9's ordering,
§6.4.3.3's record region, the interface an import brought, the `with`
statement's field-identifiers. That is Sema's, entirely.

So the question was not whether to ask the compiler — ADR-0239 settled that,
and the argument stands unchanged: a tool re-deciding scope from an outline is
a second reader of Pascal outside the compiler, which is the shape
`foreign-reserved` broke on and the shape ADR-0229 and ADR-0230 moved
`kind-exhaustive` off. The question was what to ask it *for*, and there were
three things nobody had had to decide.

**The compiler did not know where a symbol was declared.** `Declare` takes a
line and a column — for its own *"is already declared in this block"* message
— and threw them away. Every applied occurrence in this compiler resolves to a
`symbol`, and a `symbol` could not say where it came from. Nothing had ever
wanted it: a diagnostic reports where the *mistake* is.

**A dump proportional to a file is a different animal.** `--dump-symbols` is
one line per declaration and `selfhost/apfront.pas` gives 1 642 of them. One
line per *applied occurrence* of the same file is 25 387 lines and a megabyte
— which is a size worth measuring rather than assuming, and it was measured
before the shape was chosen (below).

**And the file-that-does-not-check question, which is the real one.** Every
other dump here is guarded by `errorSeen`, and the reason is sound: a dump
shows one stage's *result*, and a stage that failed has none.

## Decision

**`--dump-uses`**, which writes one line per applied occurrence and the
defining-point it resolved to, preceded by the table of files those
defining-points may be in:

```
file <index> <path>
use <line> <col> <len> <declfile> <declline> <declcol> <decllen> <kind> <type>
```

**Sema records a use where it resolves one.** It is not a walk over the
finished tree. The stage that resolved a name already knows it resolved one,
and a second walker would be a second opinion free to drift — and free to miss
a node kind in silence, which is the failure `kind-exhaustive` exists to make
loud. It is ADR-0111's argument about the string arena's counter (*the emitter
already knows what it emitted, and a predicate would be a second opinion*) and
ADR-0230's about the dispatch dump, met a third time. `LookupName` is the
funnel for eight of the sites and carries a line and a column already; five
more are named individually, each because the symbol on the node is not the
one the occurrence denotes.

**It answers in Pascal's words.** Twelve of them, one per `symKind`, with
§6.7.3.1's three parameter kinds spelled as that clause spells them —
`value-parameter`, `variable-parameter`, `procedural-parameter` — so each is
one field of one line. The type is `WriteTypeName`'s own spelling and comes
last, being the only field that may contain a space. No name is written at
all: the pool holds the folded spelling, and the caller holding the document
slices out what was typed, which is ADR-0239's decision unchanged.

**It reports what Sema resolved whether or not Sema was happy.** This is the
one dump not guarded by `errorSeen`, and the reason is that it is not a
result — it is one line per name, and Sema *accumulates* its diagnostics
rather than stopping at the first, so a source with three mistakes has
resolved everything else correctly. The party asking is an editor, and an
editor asks where a name is declared exactly while the file is being edited
into shape. A go-to-definition that went blank on the first typo would be a
go-to-definition nobody could use. `--dump-symbols` answers the same objection
by stopping before Sema and this one cannot, a defining-point being Sema's to
know; so it answers it by carrying on.

**A `symbol` now records its defining-point** — `declLine`, `declCol`,
`declFile` — set in `Declare` from the two numbers it was already handed. Zero
means there is nowhere to go, and that zero is an answer rather than a missing
one: a required identifier is declared in a region enclosing the program
(§6.2.2.10), and a result variable and a `with` binding are frame slots no
programmer wrote.

**The file table is the compiler's, not the caller's.** A defining-point in an
`--import` is reported with the path this compiler opened, which is a path the
caller can open too. That is what makes go-to-definition cross a file at all,
and crossing a file is what the method is worth having for: the name a reader
does not already know is exactly the one declared somewhere else.

**Two spans for §6.11.3's qualified name.** `M.x` is two applied occurrences
and the tree keeps one position for them, so the interface is reported for its
own length and the whole of `M.x` for the length the three parts have written
adjacently. A caller resolves a position by the **narrowest** span containing
it, so a point inside `M` finds the interface and a point inside `x` finds
only the wider one. Written with spaces around the point the wider span stops
short and the tail answers nothing — a worse answer and not a wrong one.

**A schema production is not reported, and the reason is the file.** §6.4.7
produces a type by re-resolving the schema's *body*, once per tuple, where the
type is **written** — so `curFile` is the writer's while the body's line and
column belong to wherever the schema was declared, which for `string(80)` or
anything out of `lib/` is another file entirely. The test that keeps this dump
to one document asks which file Sema is checking, and Sema is checking this
one; it cannot see that. AP 6.7.3.10's generic instantiation is the same shape
and *is* reported, because it puts `curFile` to the generic's own file and the
test then answers. What this costs is a use inside a schema's own body, which
is resolved nowhere else.

**`lsp/pasls.pas` answers both methods**, from one compilation and one dump,
with the imports the diagnostics path already resolves (ADR-0238) — a name
from another program-component resolves to nothing without them.

## Consequences

**The surface generalises, and it did not have to.** ADR-0239 left open
whether a second question could be asked the same way, and the answer is that
the second question was two questions: a defining-point and a type travel on
one line because Sema knows both at the same moment. Hover cost one field and
one reply shape over go-to-definition.

**Two facts were added to the compiler and one to the AST.** The symbol's
defining-point is three integers set at one site. The AST's `nkField` gained
`fdLine`/`fdCol`, because the node's own position is the `.` — the parser
builds it before reading the name — and whitespace is legal on either side of
a point, so the two cannot be derived from each other. That is `doc/sop.md`
§7's *"the parse tree has no extent"* finding met from the other end: a
declaration's end is still not recorded and a field-identifier's start now is.

**A field selection is still not an answer.** `r.x` reports nothing: a field
is a `fieldPtr` and not a `symbol`, so there is no defining-point of the shape
this dump carries. A schema's discriminant *is* reported, being a symbol, and
that asymmetry is visible in the golden. Closing it means giving a field a
position and a route from an occurrence to it, which nothing has asked for
twice.

**An interface has no defining-point.** `ifaceRec` holds a name, an owner and
its constituents, and never where the `export` clause was written — so a
qualified name's first half hovers and does not jump. It would take two
integers and a file index on that record, and there is one caller.

**The cost was measured before the shape was chosen.** `--dump-uses` over
`selfhost/apfront.pas` — the largest source in the tree — is 25 387 lines,
1 000 919 bytes, in 0.18 s; a whole compilation of the same file is 0.37 s. So
the dump is affordable per request and the server neither caches it nor holds
it: `CaptureLines` collects the lines, one position selects one of them, and
the rest are freed. A document a person is editing is two orders of magnitude
smaller than that worst case.

**`heap-balance` found the defect this increment shipped with.** Both methods
began by making a JSON `null` and replacing it where there was an answer,
which abandoned one node per successful request — thirteen over two sessions.
Every golden was green: the replies were correct, and what leaked was a value
nobody printed. It is ADR-0183's whole argument arriving on the first program
to exercise it after the catalogue was written, and it is the second defect in
this chapter that no output could have shown.

**`diagnostic-coverage` had to learn about dumps.** It reads every write
literal of twenty characters or more and requires a golden to name it, which
was exact while every long literal was a diagnostic; `procedural-parameter` is
twenty characters and is a dump word. Its golden set now includes `.dump`
files beside `.err` ones — the same evidence, from a corpus that did not exist
when the gate was written — and it cuts both ways, `tests/dumps/uses_broken.dump`
holding the diagnostics of a compilation that failed.

**The dumps harness gained two sidecars.** `name.components` passes
`--import`, because this dump has a cross-file answer and nothing in that
corpus had needed one; `name.status` says which exit status a case expects,
because the case that pins the decision above is a program the compiler
rejects and every other case there is required to exit 0.

## Alternatives rejected

**A query flag — `--at line:col`, the compiler answering about one position.**
It is what the protocol asks and it makes the output small. It was rejected
because it makes the compiler a server: every other dump here reports what the
compiler *found*, and none takes a question. The measurement above is what
made the choice affordable rather than merely principled — had the whole list
cost seconds, this would have been the answer.

**A walk over the finished tree.** It is the obvious shape and it is the one
this repository has moved away from twice. A walker over a variant record must
name every node kind that can hold a name, and a kind left out is silent —
`kind-exhaustive` catches that for a `case` statement and cannot catch it for
a hand-written recursive walk. Recording where the resolution happens has no
such failure: a construct Sema resolves is a construct this dump reports, by
construction.

**Extending `--dump-symbols` instead.** An outline and a use-list are the same
shape of line and answer opposite questions, and the outline's whole value is
that it stops before Sema. Merging them would have made the outline wait for
the checker, which is the one thing ADR-0239 was careful not to do.

**Deriving the constituent's position in a qualified name arithmetically and
reporting one span.** `col + qLen + 1` is right whenever nobody writes
`M . x`, and wrong in a way a caller could not detect. Two overlapping spans
and a narrowest-wins rule cost one comparison and are never wrong about which
identifier a position is inside.
