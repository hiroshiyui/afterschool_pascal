# 249. A schema's body is read where it was not written

Date: 2026-08-30

## Status

Accepted, 2026-08-30.

It closes the last of the three rows
[ADR-0246](0246-what-a-name-denotes-and-where-it-was-written.md) added to
`doc/sop.md` §7, after
[ADR-0247](0247-a-field-is-not-a-symbol.md) and
[ADR-0248](0248-an-interface-had-a-name-and-no-place.md) closed the other two.
What is left of that record's list is one row it did not open — a *defining*
occurrence answers nothing — and that is a decision about what a `use` line
means rather than a fact nobody recorded.

## Context

§6.4.7 does not translate a schema. It keeps the schema's **syntax** and
resolves that body again, once per distinct tuple, with each discriminant
bound to that tuple's values — which is what lets `array [1..n] of T` reach
the ordinary array code with nothing added to it.

A production therefore happens **where the type is written**, not where the
schema was declared. So while `vec(3)` on line 43 is being produced, the
compiler is reading text from line 35, and `curFile` — the one fact Sema keeps
about which source it is checking, maintained for diagnostics — names the file
line 43 is in.

ADR-0246's dump asks `curFile` to decide whether an occurrence belongs to the
document being compiled. For a production that question has the wrong answer:
`curFile` says "this document", and the line and column being reported are
another file's. For `string(80)` or any schema out of `lib/` those are
genuinely two files, and a caller resolving the position against the document
in front of it would land on whatever happens to sit at that line and column.

So ADR-0246 excluded productions, and paid for it: `cap` in
`array [1..cap] of integer` is resolved **nowhere else**, so nothing was
reported for it at all. A schema's body was the one region of a source the
dump was blind to.

## Decision

**Ask the schema, not the file.** `producingTop` is the stack of schemas being
produced from, innermost first, and a schema is a symbol — which since
ADR-0246 carries `declFile`. So a production reports exactly when
`producingTop^.sym^.declFile` is 0: the body being re-resolved is the
document's own text, and its line and column mean what the caller will assume
they mean.

That is not a fact anyone had to add. ADR-0246 put a file on every symbol for
a different reason — so that a defining-point in an `--import` could be named
— and the schema's own entry in that table is the answer here. The record
could not have made this choice: it is the record that created the field.

**A production's bound discriminant carries the formal's defining-point.**
`Declare` is handed the actual-discriminant-part's line and column, because
that is where its duplicate-declaration message points. Reported unchanged,
`cap` inside the body would send a reader to whichever `vec(3)` happened to be
produced first — a place that says nothing about the name. The formal
discriminant is where it was written and is what answers.

**The negative half is asserted, not assumed.**
`tests/dumps/components/usebase.pas` declares a schema and
`tests/dumps/uses_module.pas` produces it, so a body in another file is
re-resolved on every run of that case and the golden shows no line from it.
A rule that silently reported nothing and a rule that correctly reported
nothing look identical from outside; this is what tells them apart.

## Consequences

**A body is reported once per distinct tuple, and the golden shows two.**
`tests/dumps/uses.pas` demands two productions of one schema — `three: vec(3)`
folds `cap` to a constant, and `widen(var v: vec)` binds it to the
discriminant that reads a descriptor — so `cap` and `integer` on the
declaration line each carry two `use` lines: same position, same
defining-point, a different word for what the name denotes in that production.
Both are true. The intern table (ADR-0039) is what bounds this to distinct
tuples rather than to uses, and a caller taking the narrowest span containing
a position gets a correct answer from either.

Deduplicating was considered and rejected. It needs a set of positions already
reported, which is storage proportional to the file for a dump whose whole
shape is that it holds none — and the two lines are not redundant, they say
what the name denotes in two productions.

**The measurement moved less than it looks.** `--dump-uses` over
`selfhost/apfront.pas` is 34 215 lines against ADR-0246's 25 387, and almost
none of that is this record: that compiler's schemas are the required
`string`, which has no body to resolve. The growth is ADR-0247's fields and
ADR-0248's interfaces. This one adds lines only to a source that declares a
schema *and* produces it.

**A schema imported from another component still answers nothing about its
body**, and always will. That is not a gap left over — it is the rule working:
the dump answers about one document, and that text is not in it.

## Alternatives rejected

**Carrying a file index alongside `curFile`.** A shadow variable saying which
file the text belongs to, maintained wherever `curFile` is. It was rejected in
ADR-0246 for the reason that stands here: `curFile` is already maintained
correctly for diagnostics, and a second variable meaning the same thing is a
second variable free to stop agreeing with it. Asking the schema needs nothing
maintained at all.

**Reporting the body against the schema's file rather than suppressing it.**
The `use` line's first three fields locate an occurrence in *the source being
compiled*; a fourth field saying which file the occurrence is in would make
them locate one anywhere. That is a larger dump for a caller that is holding
one document and asking about a position in it, and every consumer would have
to filter what it cannot use. If a tool ever wants project-wide references it
will want that shape — and it will want it for every occurrence, not for
schema bodies alone.
