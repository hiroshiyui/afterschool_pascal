# 37. Exponentiation is two operators, and a precedence level of its own

Date: 2026-08-11

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.8.1 gives Extended Pascal one more precedence level than
ISO 7185 has, and puts two operators in it:

```
factor                  = primary [ exponentiating-operator primary ] .
primary                 = variable-access | unsigned-constant | ... | 'not' primary .
exponentiating-operator = '**' | 'pow' .
```

`not` binds tighter than either, and both bind tighter than `*`. Table 3 of
§6.8.3.2 is what makes them two operators rather than two spellings:

| operator | operands | result |
|---|---|---|
| `**` | left integer or real, right integer or real; **an integer operand stands for a real approximation to its value** | real |
| `pow` | left integer or real, right **integer** | **the type of the left operand** |

So `2 pow 3` is the integer 8 and `2 ** 3` is the real 8.0. The clause then
states four error conditions: either operator with a zero base and a
non-positive exponent, and `**` with a negative base — which has no logarithm,
and is exactly what `pow` is for.

This is the fifth Extended Pascal feature and the first that is not a change to
a *list*. It touches every stage, and it is the first one whose lowering has no
instruction behind it.

## Decision

**A new production, `parsePrimary`, and `parseFactor` becomes the
exponentiation level.** Everything that was a factor is now a primary, and a
factor is a primary optionally followed by one operator and another primary.
Under ISO 7185 neither operator can reach it, so a factor *is* a primary and
nothing about that language moves — which is why the rename could be mechanical
rather than conditional on the standard.

**A chain is diagnosed, not associated.** §6.8.1 says operators of one
precedence associate to the left, but the syntax of a factor admits exactly one
exponentiating-operator, so `a ** b ** c` is not a sentence of the language and
there is no left-associative reading to fall back on. Picking one would be
inventing an answer; the parser says which parenthesisations exist and stops.

**A sign takes a whole factor, and `not` takes a primary.** `-3 ** 2` is
`-(3 ** 2)`, the same rule that already makes `-7 mod 3` be `-(7 mod 3)`; `not a
** b` exponentiates the negation, because §6.8.1 puts `not` above the
exponentiating operators. The first of those matters beyond taste: a negative
left operand is an error under `**`, so the other reading would turn a legal
expression into a runtime error.

**Three lowerings, all of them runtime calls.** `pas_pow_real(double, double)`
for `**`, and `pas_pow_realint(double, int)` and `pas_pow_int(int, int)` for the
two forms of `pow`. Exponentiation is the one arithmetic operator with no
instruction behind it, so there is nothing to be gained by emitting the error
tests around a call rather than inside it — and a great deal to be lost, since
each of the three conditions would then be written twice, once in each backend.

**Integer `pow` traps on overflow, because it is repeated multiplication.** The
integer type is −maxint..maxint (ISO 7185 §6.4.2.2) and every other integer
operator in this compiler stops rather than wrapping; a power that silently
wrapped would be the single exception, and it is the operator most likely to
leave the type — `2 pow 31` is one multiplication too many and neither operand
looks large.

## Consequences

**`pow` becomes a reserved word under `--std=extended`, and a program named
`Pow` stops compiling.** That is ADR-0033's rule working as intended rather than
a cost: a word-symbol is reserved when the feature needing it lands, and the
test for this feature had to be renamed to `Powers` for exactly that reason. The
other direction is pinned in `tests/iso_identifiers.pas`, which now declares a
*function* named `pow` and calls it — a valid ISO 7185 program that the default
standard must keep accepting.

**`**` is scanned under both standards and refused under ISO 7185.** No valid
ISO 7185 program has two adjacent stars outside a comment or a string, so
lexing them as one token costs that language nothing and buys one honest
diagnostic instead of a cascade from a `*` with no operand. This is the
`16#ff` decision of ADR-0036 applied again, and for the same reason.

**The verification catalogue reaches into the runtime for the first time.** All
eight new rules are about `pas_pow_int` — C, not emitted IR. Two things needed
saying for them not to be circular: the specification evaluates the standard's
own recursion *exactly*, in a domain wide enough that it cannot wrap, and by
repeated squaring rather than by the repeated multiplication the runtime
performs. What is proved is therefore about the checks and the widths, which is
where an implementation of exponentiation can actually be wrong — and the
biconditional rules out a *spurious* trap as well as a missed one. That matters
here more than it looks: the check is applied to every partial product, and a
partial product that left the type while the final one came back would be a
trap on a legal expression. It cannot happen, because the loop only runs with
|x| ≥ 1, and the rule proves that rather than assuming it.

Because the loop has to be unrolled to be symbolic, the claim is "for every
base, at each of these exponents" rather than for every exponent. The exponents
are 1, 2, 3 and 5, and 1 is in the list because a single multiplication is where
an off-by-one in the check would hide.

**`**` gets no rule at all, deliberately.** SMT-LIB's floating-point theory has
no `fp.pow`, so any rule would either restate the call or prove something about
a model of `pow()` that is not the one libm implements. It is covered by the
golden tests, by the three trap programs, and by the differential — the same
answer ADR-0019 gave for pointers, and for the same reason: a rule that cannot
say anything a reader did not already know dilutes what "no known gaps" means.

**The negative exponent is integer division, and looks like a bug.** §6.8.3.2
defines `x pow y` for negative `y` as `(1 div x) pow (-y)`, so `2 pow (-3)` is
0 and `1 pow (-3)` is 1. That is the standard's own answer and not a
truncation this implementation chose; `tests/extended/pow.pas` writes all three
of the interesting bases out so that nobody "fixes" it.

**Twenty mutations, and five of them escaped a corpus that looked complete.**
Each names a test that now exists:

- **A sign in a factor position.** `-2 pow 2` is parsed by the *simple
  expression*'s sign, so it never reaches the branch that decides whether a
  sign takes a factor or a primary. Only `3 * -2 pow 2` does — an expression
  ISO 7185's grammar does not even have, since a sign belongs to a
  simple-expression there. The leniency was already in this parser; nothing had
  ever pinned what it means.
- **`not` before an exponentiation.** Neither grouping is a legal expression —
  `not` yields a boolean and neither operator takes one — so no *value* can
  tell them apart, and the test is a diagnostic: one complaint for the correct
  parse and two for the other.
- **Overflow in the negative direction.** Every power that overflows upwards is
  caught by the other half of the same test, so dropping the lower bound
  changed nothing any test could see. `(-2) pow 31` is exactly −maxint−1,
  which fits the i32 and is not a value of the type.
- **An accumulator no wider than the type.** `2 pow 31` wraps onto a value the
  check catches anyway, so the original test passed with the accumulator
  narrowed. `3 pow 21` wraps onto 1870185139 — in range, positive, and
  plausible.
- **`pow` reserved under ISO 7185.** Caught once the mutation was written
  correctly; the first attempt patched the *extended* keyword table, which is
  not where that mistake would live. A mutation that tests nothing looks
  exactly like a gap in the corpus, which is its own small lesson.

**The proof rules did not catch any of the runtime mutations, and could not.**
`lowering.py` models `pas_pow_int`; mutating `pasrt.c` leaves the model saying
what it always said, and a model that has drifted from the code proves nothing
about the code. That is stated in `verify/README.md` as a general caveat, and
this is the first feature where it had teeth — the C is a second place the loop
is written, and only the tests hold the two together. What the rules do
establish is that the design is right: that checking every partial product
traps on exactly the powers that leave the type, and on no others.
