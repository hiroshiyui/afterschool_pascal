# 217. A JSON string is bytes, and a JSON document is navigated

Date: 2026-08-27

## Status

Accepted.

## Context

`doc/roadmap.md` named JSON as the one library gap with a **named client**:
every Language Server Protocol message is a JSON object, so the program that
would judge this language needs it on its first day. The row also said it
needed no language feature, and predicted the shape — "a value is a variant
record over the seven JSON kinds, and AP 6.4.15's `utf8` already holds a string
correctly".

The first half was right. The second half is what this record is about, because
both of the guesses in it are wrong for reasons that only appear once the
client is named.

## Decision

### A string value is bytes, and never a text

AP 6.4.15's `utf8` is the right type for text a program means to **read**, and
the wrong one here, for two reasons that point the same way.

**Assignment to a text establishes Normalization Form C** (AP 6.4.15.4). So the
bytes that came in are not the bytes that go out. A language server round-trips
the contents of somebody's source file through this module — `didChange` sends
it, `didSave` sends it back — and silently normalising it would **edit their
document**, in a way no diff would explain and no test of this module would
show.

**And a text stops the program on ill-formed bytes** (AP 6.4.15.5), which is
right for a program's own literals and wrong for a socket. `PasUnicode.ToText`
is the door that reports instead, and a caller who wants text goes through it
and sees both behaviours where it can act on them.

What follows and is stated in the module's heading: **this module does not
check that a string's bytes are well-formed UTF-8.** It checks the JSON grammar
and the `\uXXXX` escapes, and passes every other byte through unread. That is a
narrower claim than "it parses JSON" and it is the honest one.

### A document is a tree of plain pointers with `JsonFree`

`PasList` is the library's owned-pointer container and gets a lifetime it
cannot get wrong: no `New`, no `Free`, disposed when the variable ceases to
exist (ADR-0181, ADR-0182). That was the shape to reach for, and it does not
fit.

**AP 6.4.14.3 gives an owned pointer no copy**, so nothing can hold a second
name for a subtree. `JsonMember(doc, 'params')` *is* such a name, and
navigating is the whole of what a client does with a document — an LSP handler
reaches four levels in before it reads anything. A container that cannot be
navigated is the wrong container, however good its lifetime.

So: `JsonFree`, and a program that forgets it leaks, exactly as with
`PasVector` and `PasMap`. `tests/dialect/lib_json.pas` balances at 0 of 72
allocations and `heap-balance` holds it there.

### A value has no bound and a name does

A string **value** lives in a `JsonChars`, which is `PasContainer`'s `Vec(char)`
— because a `didChange` carries a whole file in one string and a fixed capacity
would make the module useless for the client it was written for. A **member
name** is a `JsonName`, a `string(255)`, because a key is a key; a longer one is
`errFull` and not a silent truncation.

That asymmetry is the decision. It also makes this the **second caller of
`lib/dialect/pascontainer.pas` and the first from inside the library**, which
is how ADR-0216 was found: a module instantiating a generic imported from
another emitted the call and not the body, and the failure was a linker error
naming a counter.

A caller never imports `PasContainer`. Seven routines wrap the buffer, so
`JsonChars` is a type this module hands out and nothing else.

### A number remembers whether it was written as one

`jsNumber` carries `num: real`, and also `whole` and `inum`. **An LSP request
id re-emitted as `3.0` is a different message** — the peer matches responses by
id and JSON does not say `3` and `3.0` are the same token. `whole` is true when
the source had no fraction, no exponent, and a value in `-maxint..maxint`;
`JsonIntegerOr` answers only then, so `1.5` yields the caller's default rather
than `1`.

The mantissa accumulates in `real` and the integer form is taken from it, so a
value above `maxint` is a *number* rather than an overflow — ADR-0014 makes
integer arithmetic trap, and this is input a program did not write.

### What the parser refuses

RFC 8259, and each of these is a case:

- **a leading zero** — `01` being two values rather than one is how a stream
  gets out of step;
- **trailing text after the document** — a second message in the same buffer is
  something the caller has to frame, and answering the first value would hide
  it;
- **a lone surrogate**, high or low — what it would encode is not a character,
  and `PasUnicode` would then reject the result of a *successful* parse;
- **an unescaped control character** below U+0020 — the commonest way a
  hand-written document is wrong;
- **nesting past `JsonDepthMax`** — the parser is recursive descent and a
  hostile document must not exhaust the stack. ADR-0020's answer, at a depth a
  message will never reach.

## Consequences

**A non-whole number renders in Pascal's default real format** —
`3.500000000000E+00`. That is a JSON number by RFC 8259 §6, which admits an
exponent and does not restrict the digits before it, and it is `writestr`'s
own spelling (ADR-0057), so nothing here decides how a real is written. It is
not what came in. A client that needs a number to survive byte-for-byte should
carry it as a string, which is what a protocol wanting that does anyway.

**Duplicate member names are kept and `JsonMember` finds the first.** RFC 8259
§4 permits them and says nothing about which wins; discarding one would be this
module deciding.

**`JsonPut` replaces in place** rather than removing and appending, so a
round-trip through this module does not reorder an object. That is worth a
sentence because nothing requires it — JSON objects are unordered — and a diff
of two messages is unreadable without it.

**Every reader answers for nil.** `JsonKindOf(nil)` is `jsNull` and each
`…Or` reader gives its default, so a client reads an optional field without
asking first. `JsonMember` of an absent name returns nil, which is the same
value, so the two compose.

**Cost.** One module, 1000 lines, no language change, no runtime change, no
clause. The one thing it needed from the compiler was ADR-0216's five lines.

**What was rejected.**

*A `utf8` string value* — see above; it would edit the client's document.

*An owned-pointer tree* — it would make navigation unwritable.

*Validating UTF-8 while parsing* — it belongs to the caller, who may have a
policy (reject, replace, pass through) this module cannot guess, and
`PasUnicode.ToText` is the routine that has it.

*A pretty printer* — `JsonRender` writes no spaces and no newlines, because
what it writes goes to a peer. A caller writing for a person is doing something
this module should not have an opinion about.

*Parsing straight from a `text` file* — the client reads exactly
`Content-Length` bytes and then parses, so the buffer is the natural input and
a file-shaped door would be a second entry point with a different failure mode.
