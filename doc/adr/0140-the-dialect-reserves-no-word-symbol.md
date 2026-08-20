# ADR-0140: The dialect reserves no word-symbol, and what it does instead has a name

Date: 2026-08-20

## Status

Accepted. Answers the first of the seven open questions in `doc/roadmap.md`,
which is the one that document ranks highest and calls a decision.

Adds AP §6.1.2 to `doc/afterschool-pascal-spec.md`.

## Context

Three languages live in this compiler and the word-symbols are what separate
them:

| | word-symbols | how they are reserved |
| --- | --- | --- |
| ISO 7185 | 35 | `kwText[1..isoKwCount]` |
| ISO/IEC 10206:1991 | 48 | the same table to `kwCount`, plus `restricted` (too long for `kwLit`) and `and then` / `or else`, which the lexer joins (ADR-0038) |
| the dialect | **48** | it adds none |

Four dialect features have landed and none of them cost the lexis anything:

| Feature | Spelling | What it cost |
| --- | --- | --- |
| `external` (ADR-0121) | a directive | nothing — the position `forward` occupies |
| `?T` (ADR-0123) | punctuation | nothing — `?` was unused |
| `array of T` (ADR-0125) | two reserved words | nothing — the juxtaposition was illegal |
| `int64` (ADR-0128) | a required identifier | nothing §6.1.3 does not give back |

Verified rather than assumed. This program compiles and prints 13 under
`--std=afterschool`:

```pascal
program Ext(output);
var external, int64: integer;
function optional(slice: integer): integer;
begin optional := slice + external + int64 end;
begin external := 1; int64 := 10; writeln(optional(2)) end.
```

`doc/roadmap.md` §1 observes that this discipline "was never decided: each
feature found a cheap spelling on its own, and the pattern is visible only in
aggregate", and asks whether it is a constraint to design within or a budget to
spend.

**It matters because it is the only thing keeping the containment true.**
ADR-0117 makes the dialect contain Extended Pascal and ADR-0138 now sweeps the
whole conformance corpus to check it. A reserved word breaks that claim *by
construction*: every conforming program using that identifier stops compiling,
and no gate can repair it. It is also precisely how the first two standards came
to be non-nested (ADR-0033), which is the mistake this dialect exists downstream
of.

And the collision is coming. `defer`, error unions, traits and actors — every
remaining borrowing in `doc/roadmap.md` wants a word, and unlike the four above
they want it for **statement syntax**, where the dodges are thinnest.

## Decision

**The dialect shall reserve no word-symbol. Ever, and not as a default.**
`--std=afterschool` reserves exactly the 48 of ISO/IEC 10206:1991 and its
keyword table is the same table.

And the more useful half, because "find a cheap spelling" is not a rule anyone
can apply:

**A dialect feature is spelled in a position where a conforming program cannot
have written it.** That is what the four features have in common, and it is not
what they looked like individually. `external` is not a reserved word — it is
`Check(tkIdent)` and a pool comparison, in the one position where ISO/IEC
10206:1991 admits exactly one other word. `array of T` is two reserved words
whose juxtaposition was a syntax error. `?` was unspellable. `int64` is a
defining-point in a scope §6.1.3 lets any program shadow.

The general name for this is a **contextual keyword**, and the test it has to
pass is one sentence: *in the position where this spelling is read as the new
construct, could a conforming program have written that spelling at all?* If
no, the spelling costs nothing. If yes, it is a reserved word wearing a
disguise and it is refused.

**This extends to statements, which is the case the question was really
about.** A statement-initial identifier in either conforming language is
followed by exactly one of `(`, `:=`, `[`, `.`, `^`, or a statement terminator
(`;`, `end`, `else`, `until` — §6.8.1's empty statement is why the last three
are in the list). Probed, not derived: `v q`, `v v`, `v 1`, `v begin` and
`v if` are each rejected today. So a statement form spelled

    defer <statement>

is decidable with **one token of lookahead** and cannot collide: where the next
token continues a conforming statement, the spelling is an identifier and means
what it has always meant; where it does not, no conforming program was there to
break.

## Consequences

**The budget question is answered by being dissolved.** There is no budget,
because the thing everyone assumed was scarce — spellings — is not what is
scarce. What is scarce is *positions*, and a position is not spent by being
used: `external` occupying the directive slot does not stop `defer` occupying
the statement-initial slot.

**The cost is real and falls in one place.** A program that declares
`var defer: integer` keeps its variable and loses the statement form, for the
rest of that scope. That is the right direction — the dialect feature yields to
the conforming program rather than the other way round — and it is the same
trade §6.1.3 already makes for every required identifier, which is why `int64`
was free.

It also means a dialect feature can be *locally unavailable*, which no feature
of either conformance mode is. A reader must not conclude that `defer` is
always a statement; it is a statement wherever the program has not taken the
name.

**The parser pays, not the lexer.** A contextual keyword is a lookahead in one
production, and there are as many of those as there are features. A reserved
word is one table entry. So this decision makes the *implementation* of each
feature slightly more expensive in exchange for the language property, and the
ratio gets worse as features accumulate. That is the honest cost and it is
accepted: the property is the point of the dialect and the parser is ours.

**`dialect-containment` is the instrument, and it is partial.** ADR-0138's
sweep would report a reserved word wherever a corpus program uses that
identifier as a name, and would say nothing where none does. It is a much
better witness than the 122-line program it replaced and it is not a proof.
What would be a proof is a check that the dialect's keyword table equals
Extended Pascal's — one assertion, and the decision above is what makes it
meaningful. `doc/sop.md` §7 carries this until it is written.

## What this does not do

**It does not claim every future feature has a position.** It claims the four
that landed did, that statements do, and that the test is answerable in advance
rather than after a spelling has been chosen. A feature with no position is a
feature that has found the real limit, and the right response then is to say so
in a record — not to quietly reserve a word and let ADR-0138's gate discover it.

**It does not revisit `?T`'s punctuation** or suggest punctuation is preferred.
Punctuation is a small supply and reads poorly for statements; it was right for
an optional because `?T` is a *type*, where a word would have been worse.

**It does not decide anything about `defer`.** `defer` is used above because it
is the nearest concrete case in the borrowings table and because a statement
form is the hard case for this rule. Whether the dialect gets one is its own
question, with its own record.

**It does not change the two conformance modes**, which reserve what their
standards say and nothing else.
