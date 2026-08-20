# ADR-0136: A constant cannot have the wide type, and saying so is a diagnostic rather than a crash

Date: 2026-08-20

## Status

Accepted. Settles a question ADR-0128 left ambiguous and ADR-0135 found by
probing it. Fixes a compiler crash.

## Context

ADR-0135 wrote the dialect's specification from the records and then compiled a
program for each requirement. One of them stopped the compiler:

```pascal
const c = 5000000000;
```

    runtime error: case: no label matches the selector

That is `EvalConst`'s closing arm, which enumerates every node kind that cannot
fold and answers `false` for each. `nkInt64` was absent from the list and there
is no `else`, so a wide literal reaching the folder found no label — and a
case-statement with no matching label **stops the program** (§6.9.3.5's error,
ADR-0018). Not a wrong answer: a stopped compiler, writing nothing a golden
could hold.

Six constructs reach it: a constant-definition, an operand of a
constant-expression, a subrange bound, an array's index-type, a set's
base-type, and a case-constant. All six are dialect-only, both conformance
modes rejecting such a literal in the lexis.

### Why nothing here could see it

`tests/dialect/int64_types.pas` exists precisely to hold the refusals, and it
writes `int64` and `maxint64` in every one of those positions. Both of those
**fold**: `maxint64` is a constant-identifier, and the symbol it folds to has
type `int64`, so each position went on to report its own ordinal message. The
file therefore tested the *type* in every constant position and the *literal*
in none.

`kind-exhaustive` (ADR-0124) is the gate for exactly this failure, and it
watches `typeKind`. This is a `nodeKind`, and `doc/sop.md` §7 has carried the
row saying the other enumerations are swept by hand since ADR-0124 landed. The
row was right, and this is what it was describing.

### The question the crash exposed

ADR-0128's *What this does not do* says: "No 64-bit arithmetic is folded.
`const c = 5000000000` names the digits and nothing more". Read one way that
sentence admits the constant and denies only arithmetic on it. Read the other
it means the digits are all there is and no constant is formed. **The compiler
did neither; it fell over**, so the sentence had never been tested and could
not be settled by asking what shipped.

This is a language question and not a repair, which is why it is a record.

## Decision

**No expression of type `int64` is a constant.** A constant-definition whose
value has that type is refused, and so is every other position requiring
§6.3's constant or §6.8.2's constant-expression.

`nkInt64` joins the arm that answers "this does not fold", which is the whole
of the crash fix.

### 1. The refusal, not the admission

The reason is the one ADR-0128 built the type on and it is not a preference:
**this compiler holds no value of `int64`.** Its own integers are 32 bits,
because it is written in the language it translates, so a wide value is carried
as the *text that was written*, all the way into the emitted code (ADR-0025's
answer for a real literal, one clause later). A symbol has nowhere to keep
text, and a constant is a symbol.

Admitting the constant would therefore mean either giving the symbol a text
field and a second folding path that computes nothing, or giving the compiler a
64-bit integer — which is a change to what the compiler is written in and
reaches the seed. Neither is a convenience.

**The admission stays available.** Nothing here forecloses it: a later record
wanting `const c = 5000000000` widens what is accepted and breaks no program,
because every program this decision refuses is one that does not compile today.
That asymmetry is why refusing first is the reversible choice.

### 2. One new message, and only where the old one would have lied

Five of the six positions want an **ordinal**, and `int64` is not one
(AP §6.4.2.6.2). Their existing messages are already correct and already
explain — *the bounds of a subrange must be ordinal*, *a case label must be an
ordinal constant* — and **not one word was written for this type**, which is
the same property ADR-0128 claimed for its thirteen refusals and is claimed
again here.

A constant-definition is the exception and needed a message of its own. It
requires no ordinal — a constant may be real — so the generic
*'c' is not a compile-time constant* would have been a **plain untruth about a
literal**: `5000000000` is a compile-time constant in any language able to hold
it. What it cannot be is a constant of *this* compiler. So:

    the value of constant 'c' has type int64, and a constant cannot:
    assign it to a variable of that type instead

The remedy is named because there is one, and it is the thing the program
almost certainly wanted.

`constReported` — the flag ADR-0134 added so that a precise reason suppresses a
vague follow-up — needed nothing: the choice is made where the generic message
is written, so a caller that had already said why still says only that.

## Consequences

- **Six programs that stopped the compiler now report an error**, and five of
  them report a message that already existed. `tests/dialect/int64_const.pas`
  is the case and carries all six.
- **`tests/dialect/int64_types.pas` keeps its subject and gains a neighbour.**
  It holds the type in every position; the new file holds the literal. The
  distinction is written into both, because it is the reason one of them
  existed for four increments without reaching this.
- **AP §6.4.2.6.5 states the requirement** and AP Annex E.5 keeps the account of
  how it was found. The specification is the normative statement (ADR-0135), so
  the language question is settled there and this record says why.
- **`doc/sop.md` §7 loses the row ADR-0135 added** for the crash, and keeps the
  one about `case` over a node kind — which is the general form and is still
  unchecked.
- **`src/` needs nothing.** `int64` is a dialect type and the reference front
  end does not have it (ADR-0128), so there is no second implementation of this
  to keep in step and difftest compares nothing new.
- **`verify/` gets no rule.** The folder gained a *refusal*, not a computation:
  a node kind that reached no arm now answers `false`. No value is computed and
  no emitted code changed, so a rule would have nothing to state. The commit
  carries `Model-unchanged:` — the edit is inside the constant-folder region
  `model_drift.py` watches, and the region is watched because the folder is a
  second implementation of §6.7.2.2's `mod` and `div` and of Annex D's overflow
  conditions, none of which this touches.

## What this does not do

- **It does not admit a constant of `int64`**, and says above why that stays
  available.
- **It does not extend `kind-exhaustive` to node kinds.** That is the general
  fix and it is cheap; it is not done here because this change is a language
  decision with a crash attached, and bundling a gate would make the record
  about two things. `doc/sop.md` §7's row stands.
- **It does not revisit ADR-0128's thirteen refusals.** They were correct and
  remain untouched; what was missing was the literal reaching them.

## Alternatives rejected

**Admit the constant, carrying the text on the symbol.** The reading of
ADR-0128's sentence that would have made it true. Rejected as the *first* move
rather than on its merits: it is a feature — a constant-access of it must emit
the text, a comparison must not fold, `write` of it must work — and a feature
argued for by a crash is a feature argued for badly. If a program wants it, it
can be added without breaking anything.

**Add an `else` to the folder's case-statement.** Two lines and it would have
stopped the crash everywhere at once, including for node kinds nobody has
thought about. Rejected because it is the opposite of what ADR-0124 decided:
the enumerated arm is what makes the *next* missing kind a build-time or
test-time question rather than a silent `false`. An `else` would have converted
this crash into a wrong answer, which is worse and much harder to find.

**Say nothing new and let the generic message stand.** One line smaller, and it
tells a program that a literal is not a compile-time constant. Diagnostics are
part of the public interface here (`release-engineering`), and one that is
false about the program in front of it is a defect of its own.
