# 38. A word-symbol may be two words

Date: 2026-08-11

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.8.3.3 adds two Boolean operators to the four ISO 7185
has. `A and then B` evaluates `B` if and only if `A` is true; `A or else B`
evaluates `B` if and only if `A` is false. §6.8.3.1 puts the first among the
multiplying-operators, beside `and`, and the second among the
adding-operators, beside `or`, and says of all the others:

> Except for the `and then` and `or else` operators, the order of evaluation of
> the operands of a dyadic operator shall be implementation-dependent.

This compiler has short-circuited `and` and `or` since ADR-0010. So the
*lowering* of the new operators already exists, and this feature is, as the
roadmap predicted, a small one. It was written down as `and_then`/`or_else`
there, and in README, and in ADR-0033's list of words Extended Pascal reserves.
That spelling is wrong. §6.1.2 lists the word-symbols, and among them are

```
word-symbol = `and' | `and then' | `array' | ... | `or' | `or else' | ...
```

Each of these operators is **one word-symbol written as two words**, with a
separator between them. There is no underscore anywhere in the standard.

## Decision

**The two-word word-symbols are built by joining two tokens, not by looking a
spelling up.** `and`, `or`, `then` and `else` are already reserved words of ISO
7185; the lexer scans them as it always did, and when the token it has just
produced is `then` and the one before it is `and`, it rewrites the pair as one
`and then`. Nothing is added to either keyword table.

**They are joined across any separator.** §6.1.10 says "no separators shall
occur within tokens", which cannot be read literally against a token whose own
reference representation contains a space; the strict reading would also forbid
a line break in the middle of an operator, which no processor does and no
reader would expect. The join therefore happens at the token level, where
comments and line breaks have already been consumed. This is a *leniency* — a
program the strict reading rejects, this compiler accepts — and it is safe
rather than merely convenient: `and` followed by `then` has no other meaning in
either language, because `then` cannot begin a factor and `else` cannot begin a
term. There is no valid program whose meaning it can change.

**The joined token is placed where its first word is**, which is where the
operator starts and where a diagnostic about it should point.

**They are joined under both standards and refused under ISO 7185**, the same
answer ADR-0036 gave for `16#ff` and ADR-0037 for `**`, and for the same
reason: the sequence is not a sentence of ISO 7185 either, so joining it costs
that language nothing and buys one honest diagnostic instead of a complaint
about `then` appearing where a factor was wanted.

**`AndThen` and `OrElse` are their own `BinOp`s, even though they lower
identically to `And` and `Or`.** The standard *permits* an implementation to
short-circuit `and`; it *requires* one to short-circuit `and then`. A tree that
spelled both as `And` would have discarded the one fact that says which of
those two things a given expression is — and with it the freedom ADR-0010 chose
not to exercise. The lowering is shared; the node is not.

## Consequences

**This feature reserves nothing.** It is the first Extended Pascal feature with
no lexical cost to the other language: ADR-0033's rule is that a word-symbol is
reserved when the feature needing it lands, and this one needs none. The list
in ADR-0033 that named `and_then` as a word Extended Pascal reserves was wrong
on both counts — the spelling, and the reserving. That record is immutable and
stays as it is; this is the correction.

**The difference between `and` and `and then` is visible in exactly two places
in this compiler**: the AST dump, which spells them `and` and `andthen`, and a
diagnostic, which names the operator the program wrote. No program's *output*
can distinguish them, because ADR-0010 already gave `and` the behaviour
`and then` demands. `tests/extended/shortcircuit_errors.pas` is therefore not a
minor companion to the main test — it is the only golden file that can see the
two nodes are different, and a mutation collapsing `AndThen` into `And` is
caught there and nowhere else.

**No verification rule.** The catalogue is about arithmetic, conversions,
comparisons and indexing; `and`/`or` have never had a rule, because the
short-circuit lowering is a control-flow shape rather than a computation, and a
rule stating "the right operand is evaluated when the left is true" would be
the emitted branch written twice. That is the test ADR-0013 sets and this
fails, the same way the nil check does.

**Thirteen mutations, thirteen caught**, and where each was caught is worth
recording, because two of the oracles carried more than their share:

- The golden pair caught the precedence of both operators, the collapse of
  either into its plain form, the result type, and both halves of the
  lowering — including "`and then` evaluates both operands", which the counted
  side effect exists to see.
- The **differential** caught everything about ISO 7185: dropping the refusal,
  and joining only under `--std=extended`. `selfhost/torture.pas` is where that
  program text lives, as it does for `**`, so those mutations are invisible to
  ctest by construction.
- The precedence test had to be rewritten before it discriminated. Written as
  `false and then true or else true`, the correct parse and the one-level parse
  agree — left association happens to give the same answer. Only the other
  order, `true or else false and then false`, tells them apart: one operand
  evaluated against two. A test that passes under the mutation it was written
  for is worse than no test, because it is counted.
