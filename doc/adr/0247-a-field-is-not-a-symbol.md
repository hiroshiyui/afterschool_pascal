# 247. A field is not a symbol, and has a defining-point anyway

Date: 2026-08-30

## Status

Accepted, 2026-08-30.

It closes the first of the three rows
[ADR-0246](0246-what-a-name-denotes-and-where-it-was-written.md) added to
`doc/sop.md` §7 — *a field selection is answered by no dump, where a
discriminant is*. The other two, an interface's own name and a name inside a
schema's body, stand.

## Context

ADR-0246 answers `textDocument/definition` and `textDocument/hover` by having
Sema report every applied occurrence and the defining-point it resolved to.
Every occurrence it reports resolves to a `symbol`, because that is what
resolution produces: `Lookup` walks the scope chain and hands back a symbol,
and the symbol carries a position now.

A **field-identifier** is not one, and it is the only applied occurrence in
this language that is not.

§6.4.3.3 makes a record type a *region* and puts a defining-point for every
field-identifier in it — the clause is explicit, and ADR-0098 and ADR-0112 are
both about consequences of that region. So a field is exactly as much an
applied occurrence as a variable is. But nothing about a field is ever looked
up in a *scope*: `r.x` is resolved by asking the record's **type** for a field
of that spelling, through `FindField`, and the answer is a `fieldPtr`.

So the dump answered nothing for `r.x`, while `v.cap` — a schema's
discriminant, which looks identical in the source — was answered, a
discriminant being a symbol. The asymmetry was visible in
`tests/dumps/uses.dump` and explained nowhere in it.

It is worth saying what a field selection *is* in an editor, because it is not
a corner: a program that uses records at all writes more field selections than
it writes anything else. Answering nothing for them is answering nothing for
most of a file.

## Decision

**A `fieldRec` carries its own defining-point**, and it turned out to be
mostly there already: `line` and `col` were recorded when ADR-0045 needed them
for a diagnostic. What was missing is which *file* — a record declared in an
imported module has fields whose positions belong to that module's source —
so the record gains `declFile`, set the way a symbol's is and asked for only
when `--dump-uses` is on.

It is spelled `declFile` and not `file` because §6.1.2 reserves that word.
The compiler refused the field the first time it was compiled, which is
`reserved-words`' argument surviving the gate that used to make it: there is
one language now, and every word-symbol is reserved in it.

**A second reporter, not a second line shape.** `NoteUseField` writes the same
`use` line `NoteUse` writes, with `field` for the kind — which is
`--dump-symbols`' own word for one — and the field's type. The seven numbers
in front are written by one routine both call, because two things reporting
one line format is exactly the shape that drifts. They are two routines rather
than one because a field has no `symKind` to write and no symbol to read it
from.

**§6.8.3.10's bare field answers the field**, not the `with`. A
field-identifier written inside a with-statement has a defining-point *in the
with-statement* by that clause, and the symbol Sema binds it to is a hidden
frame variable holding an address. Neither is what a reader pointing at the
name wants: the with-statement is where the **record** was named, and the name
under the cursor was declared in the record. So the bare form and the
selection it abbreviates give the same answer, and
`lsp/sessions/definition_field.jsonl` pins that they agree — the same field
asked both ways, inside the statement and after it.

## Consequences

**A variant part costs nothing extra.** A field in an arm is added by the same
`AddField` and carries the same position; §6.4.3.3's arm path is about where
the field *lives*, not about where it was written. `tests/dumps/uses.pas` has
a variant record so that this is asserted rather than assumed.

**The required record-type has no defining-point, and says so.** §6.4.3.4's
`TimeStamp` is built by the compiler and its fields answer line 0, which is
the same zero a required identifier's symbol carries and means the same thing:
there is nowhere to go.

**Two of ADR-0246's three §7 rows remain**, and neither is like this one. An
interface has no position recorded anywhere, so closing it means adding a
fact; a name in a schema's body is resolved only where the type is *produced*,
which is a different file, so closing it means carrying a file index that is
not in hand at the production. This one needed one integer, because §6.4.3.3's
defining-point was already being recorded for a diagnostic.

## Alternatives rejected

**Making a field a symbol.** It would have made one reporter serve everything
and it is the wrong direction: §6.2.2 puts a symbol in a scope and a field is
deliberately not in one — ADR-0098 and ADR-0112 are two records about how
carefully a record's region is kept *out* of the scope chain, and `LookupUser`
answering nil for a required identifier is the convention that would have to
survive a third kind of entry. The dump wanted a position, not a scope.

**Reporting the `with` binding instead of the field.** It is what the code
already had — the binding is what `vrSym` is set to — and it answers a
question nobody asked: the binding is a frame slot with no source position at
all, so the honest version of it is `null`. Sending a reader to the
`with here do` line was considered and rejected for the same reason: that is
where the record was named, and a reader pointing at `x` is asking about `x`.
