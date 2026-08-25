# 191. A text is a type beside the string, and shares only its representation

Date: 2026-08-25

## Status

Accepted. AP 6.4.15, and the second of ADR-0189's four increments. 6.4.15.7 —
concatenation — remains stated ahead of the processor (AP 5.6); everything else
in that clause is now what `--std=afterschool` does.

## Context

ADR-0189 decided the text model and ADR-0190 built its runtime half. This is
the increment that gives the language a type: the denoter, assignment,
comparison, `length`, the capacity, and `write`.

One question had to be answered before any of that, and it is the whole of why
this record exists. A text value and a variable-string value have **the same
representation** — a length and that many bytes — and almost none of the same
rules. Sharing the representation is most of what makes the feature cheap;
sharing the rules would have been a defect in every direction at once.

## Decision

**A new type kind, `tyText`, and a separate predicate for the shared
representation.**

`IsVarString` goes on asking whether §6.4.3.3.3's rules apply. `IsStringRep`
asks the other question — "is this value a length and that many bytes?" — and
is what the six sites that are about *storage* now ask: `IsMemory`, the
dynamic size, `EmitString`, the store, and the three parameter paths. Every
frame slot, copy, parameter form and layout rule the string had, the text has,
and none of them was written twice.

That split is ADR-0181's, applied before it could cost anything. `IsOwned` and
`IsAffine` were one name until an ownership question and a representation
question were asked through it and one of them got the wrong answer. Here the
two start apart.

**The alternative was a flag on `tyString`**, which is what ADR-0181 chose for
`owned` and what would have been wrong here. The test is whether every rule
about the old kind is a rule about the new one. For an owned pointer it is —
the domain, `nil`, the dereference are all a pointer's. For a text it is not:
indexing, substrings, `index`, `substr`, `length` in characters and 6.8.3.5's
padded comparison are each about a *char*, and a text has none. A flag would
have granted all six by default and required six refusals to be remembered,
which is ADR-0146's "a permission granted in a shared predicate leaks to every
caller" set up deliberately.

The polarity is the point: with a new kind, everything is refused until a rule
admits it. The first probe after adding the kind — an assignment, a comparison,
an index, a substring, a concatenation, a `read`, a `write` — was refused in
every position but two, and each rule below was then added on purpose.

### What adding a kind granted anyway, and what it cost

**Comparison was accepted, and emitted invalid IR.** `IsMemory` was
`IsStructured or IsOwned or IsVarString`, so a text was not memory, so the
relational operators took it for a simple type and emitted
`icmp eq { i32, [64 x i8] } %a, %b`. clang refuses that — *"error about a file
nobody wrote"*, ADR-0139's defect reproduced exactly by adding a type. The fix
is the `IsStringRep` split at that one site; the lesson is that a new kind is
not refused everywhere by construction, only where a predicate happens to be
asked.

`kind-exhaustive` caught nothing here and could not have: `IsMemory` is a
boolean expression and not a case-statement. It did its own job — six
case-statements over `typeKind` needed the arm and it named each — and the
gap between those two facts is the register entry below.

### The rules, and the two the implementation changed

**Assignment is admitted and can fail.** A text takes its value from any
string-type or char and gives it back to a variable-string; the bytes are
validated and normalised where they enter, and ill-formed input is an **error**
that stops the program.

AP 6.4.15.5 said the opposite when ADR-0189 wrote it: a string was refused, and
every conversion was to go through a function answering a fallible-type,
because "invalid input from the outside world is not an error in the program".
That sentence is true and does not reach the conclusion. §6.4.6 admits
assignments that can fail everywhere — every store into a subrange is one, and
ISO 7185 has made an out-of-range store an error since 1982 (ADR-0018). A
text's invariant is a constraint on a value of exactly that kind.

**What made it visible was writing the tests.** Under the clause as written, a
text could be filled from a character-string and from another text and from
nothing else, so every test was a test about literals — and a type whose only
source is a literal is a type nobody reaches for. Annex E.11 records it. This
is the first divergence in that annex found by *implementing* a clause rather
than by an audit or a probe, and it is an argument for the order ADR-0189
staged: the specification was written first and was wrong in a way only the
client could show.

**Comparison is text-to-text and text-to-character-string, and a string is
refused.** Not for symmetry with the assignment rule but for the opposite
reason: an assignment normalises, so what a text holds afterwards is right,
while a comparison against unnormalised bytes would produce a *wrong answer*
rather than an error. The runtime normalises a character-string operand into
the arena before comparing; a string operand has no such excuse and Sema names
it.

Both operands being in Normalization Form C, comparing their bytes **is**
canonical equivalence. That is the whole return on ADR-0189's choice to
normalise where a value is constructed, and it is why `=` needs no table.

**`length` counts elements and `capacity` counts bytes**, so the two are in
different units for one value and `length(t) <= t.capacity` is true and not
tight. `length` is the one required string function a text gets: `index`,
`substr` and `trim` are each about a position or a run of characters.

**A field-width pads to a count of elements**, which needs the runtime because
the pair carries bytes. It is still not what a terminal does, and AP 6.4.15.10
NOTE says so.

## Consequences

**The compiler grew a kind and the corpus grew four cases.**
`tests/dialect/text.pas` is the readable statement of the model: a decomposed
literal of seven source bytes and a composed one of six are one value of five
elements; three Hangul jamo compose to one syllable of three bytes; a family
emoji joined by zero-width joiners is one element of eighteen bytes; a flag is
one element of eight. Those numbers are the model working, and none of them is
a number this repository chose.

**`utf8` takes a spelling, and `inherits_extended.pas` hands it back.** A
required identifier lives in a scope enclosing the program (§6.2.2.10) and
§6.1.3 makes it shadowable, which is ADR-0140's second shape. The witness
declares `utf8` as an *integer variable* — the sharper case than `int64`'s,
because the parser must go on reading it as an ordinary identifier rather than
looking for a discriminant after it.

**Annex B gains the second row whose two columns differ.** ISO 7185 has no
discriminated schema at all, so it stops at the syntax; Extended Pascal parses
`utf8(16)` and finds no schema of that name. `substring` was the first such
row and this is the second, so a row whose columns agree is the common case
and not the rule.

**The line-coverage ratchet moved by one**, to 462. The statement is the
exhaustiveness arm of `EmitTextCompare`'s operator case — `opAdd … opPow` in a
case over a relational node — which no program reaches. Its twin
`EmitStringCompare2` has exactly the same arm uncovered, at `1/25`, which is
the argument: the new number is the old one plus a copy of something already
argued for.

**Four runtime entry points**, all `pas_` and so refused as foreign names:
`pas_text_store`, `pas_text_length`, `pas_text_cmp`, `pas_write_text`. Each is
thin over ADR-0190's `pasrt_unicode.c`. `pas_text_store` is the **only** door
into a text value, which is what lets every reader past it assume 6.4.15.2.

## What this does not do

**No concatenation.** AP 6.4.15.7 stays ahead of the processor and `t + u` is
refused by the ordinary arithmetic diagnostic. It is increment 3's, with the
iteration of 6.4.15.9, and the two belong together: `+` must renormalise at
the join, and the canonical-text-type that a concatenation yields is the same
device iteration's element type wants.

**No iteration.** `for g in t` is not accepted. 6.4.15.9's refusal half — no
index, no substring — is implemented and cited; its iteration half is not.

**No conversion that reports instead of stopping.** A program that expects
ill-formed input still has nowhere to put it: the assignment stops the
program. The fallible conversion AP 6.4.15.5 NOTE 5 still points at is
increment 4's, in `PasUnicode`.

**A text is not a foreign type.** It does not cross an `external` boundary in
either direction; AP 6.7.7's list is unchanged. Nothing needed it yet, and what
crosses is a question about C's ABI rather than about this type.

**It does not touch `string(n)` or `char`.** Both mean exactly what they meant,
in all three modes. This record adds a type; it withdraws nothing.

## Alternatives rejected

**A flag on `tyString`.** Above: it grants six rules by default that a text
must not have, which is ADR-0146's failure mode arranged on purpose.

**Making a text `IsStringType`,** so that the existing string paths would take
it. Cheaper still, and wrong in the same direction one level up: `IsStringType`
is what 6.8.3.5's padded comparison, `substr`, `index` and the substring
notation all ask.

**Normalising a literal at translation time.** AP 6.4.15.5 required it and it
is not implementable here: `selfhost/compiler.pas` is an Extended Pascal source
(ADR-0082), `external` is refused there, so the compiler cannot reach the
Unicode tables at all. The four ways out were registered in ADR-0190 and the
first was taken — validate where the value is assigned, at run time, through
the emitted call that was going to happen anyway. Annex E.12 records that the
clause over-specified *when*, and that when a required conversion happens is
not a property a program can observe.

**Refusing an assignment from a `string`.** The clause as written, argued
above and recorded in Annex E.11.
