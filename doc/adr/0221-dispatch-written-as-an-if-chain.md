# 221. Dispatch written as an if-chain

Date: 2026-08-27

## Status

Accepted.

## Context

ADR-0124 built `kind-exhaustive` for one enumeration and ADR-0145 widened it to
twelve. Both records say **case-statement**, and both mean it: the gate reads
`case … of` and nothing else, which is the same sentence ADR-0194 had to write
about `predicate-kinds` a few months later.

Not every dispatch on a tag is a case-statement. `EmitString` is thirteen arms
of `if e^.kind = nkBinary … else if e^.kind = nkCall …`, and it cannot be a
case-statement, because its arms test a node's kind **and** its type in one
condition:

```pascal
if (e^.kind = nkBinary) and (e^.bnOp = opAdd) and IsText(st) then …
else if (e^.kind = nkCall) and IsTimeBuiltin(e^.clBuiltin) then …
```

A count settles how common that is. **37 if-chains dispatch on a tag**, 24 of
them over `nodeKind`, and until this record not one was read by anything.

**ADR-0220 is what that cost.** `EmitString`'s arm for a literal is keyed on the
node's kind; a constant reaches the code generator as a designator; the value
fell past that arm into one that read four bytes of read-only data as a length.
The guard was one node kind too narrow, in the one chain that dispatches on two
axes at once — and it was invisible at `-O2`, so every golden agreed.

## The failure is the opposite of the case-statement's

This is the part worth stating, because it inverts the argument ADR-0124 rests
on. A Pascal case-statement with no matching label **stops the program**
(ADR-0018), so a constant left off one is a crash — loud, and findable by the
first program that reaches it. An if-chain ends in a trailing `else`, so a
constant left off one is a **wrong answer**, in silence.

So the half that had a gate fails loudly and the half that had none fails
quietly. That ordering is exactly backwards, and it is the whole argument for
this record.

It also means a trailing bare `else` must **not** excuse a chain, where
`otherwise` does excuse a case-statement. §6.9.3.5 makes an `otherwise` total by
construction and the author wrote it as the catch-all for a value-dispatch; a
bare `else` at the end of a tag chain is simply where a kind nobody considered
lands.

## Decision

`kind-exhaustive` reads if-chains as well, and a third catalogue form records
them: `routine:enum:n chains N of M`, counted separately from the
case-statements in the same routine so the two cannot collide.

**A chain is selected by the shape of its conditions and by nothing else**:
`<expr>^.kind = c`, a value asked for its own tag. That is what makes the scope
a fact rather than a judgement. `Check(tkSemicolon)` is a *lookahead predicate*
and not a dispatch, so the parser's long `if Check(…)` ladders are outside this
and stay outside however long they get — which matters, because a first draft
that counted any enumeration constant appearing in a condition pulled in
fifteen token-kind ladders and would have made the catalogue mostly noise.

Three enumerations qualify today, and they qualify by how they are written
rather than by being chosen: `nodeKind`, `symKind`, `typeKind`. `binaryOp` and
`builtinKind` do not, though `EmitString` tests both — they are compared as
`e^.bnOp = opAdd`, an ordinary field and not a tag.

It fails in the same directions the case half does. Measured, not assumed:

| mutation | result |
| --- | --- |
| a node kind added to `nodeKind` | **33 entries fail** — 24 chains and 9 case-statements |
| an arm removed from `EmitString`'s chain | `says … 4 of 63; it names 3 of 63` |
| `EmitString`'s entry struck | `dispatches on 4 of 63 … and argues for none of it` |

## Consequences

**37 catalogue entries, and writing them was the useful part.** Two of the
first drafts were wrong, and a catalogue this project treats as a claim cannot
carry a plausible-sounding reason:

- `OrdinalLo` names two type kinds where `OrdinalHi` names five, and the draft
  said the other three "have a lower bound that is not a number to compute".
  They have a lower bound of **0** — char, boolean and enumerated alike — so one
  `else` is right for the three at once. The asymmetry is the answer, not an
  omission.
- `DynamicExtent` and `CheckSchemaDomain` were called "the three type kinds a
  schema can produce". They are not: an array and a record are the two that can
  *contain* a dynamic part and both recurse, and the third constant is named to
  be **excluded** — a subrange's size is its host's whatever its bounds are.

Both were caught by reading the routine rather than by the gate, which is worth
recording: this gate checks that a claim is *made*, never that it is true. It
is `partial_cases.txt`'s own limit — *"what it does not do is judge whether an
arm is right"* — and it now applies to twice as many entries.

**A first draft ran chains across routine boundaries** and credited
`EmitComplexPow` with naming `nkStr`, which is `EmitString`'s. A chain now ends
at the next `procedure`/`function` header. That artefact is why the detector is
anchored on two independent things — the indentation of `else if`, and the
routine — rather than on indentation alone.

**What it does not reach.** A dispatch written as neither a case-statement nor
an `x^.kind = c` chain: a table, a lookup, a predicate call. `Assignable` is 43
type-predicate calls in thirteen arms and is outside this — `predicate-callers`
(ADR-0146) is the gate that watches that one, from the other direction.

## Alternatives

**Restructure `EmitString` into a `case e^.kind of`.** It would put the chain
under the existing gate with no new machinery. It also needs a shared tail
reached from five arms, which in Pascal is a nested procedure or five copies,
in a 280-line routine in the code generator — a large diff in the riskiest
component to satisfy a checker. The chain is the right shape for what it does;
the gate was the thing that was the wrong shape.

**Count every enumeration constant appearing in a condition.** Tried first, and
it is what produced the token-kind ladders. `Check(tkOf)` is a question about
what comes next, not about what something *is*, and conflating the two makes a
catalogue nobody would trust.

**A threshold — only chains naming four or more constants.** It would have cut
the catalogue from 37 to 6 and it is unprincipled: `HeapHeader`'s two-arm walk
over `nkIndex` and `nkField` needs a third arm exactly as much as
`IsDesignator`'s six do, if a designator node kind is ever added. Two is the
smallest number a reader could have got wrong by leaving a third off, and that
is where the line goes.
