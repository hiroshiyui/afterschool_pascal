# 307. `dispose` is what releases an owned pointer

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Closes ADR-0295's finding 4, the first of the three
smaller reports in `doc/roadmap.md`'s row *Three smaller reports from the same
pass*. The other two — `PasJson` rendering `0.75` in exponential form, and
`MapKey`'s 63 characters — stay open.

## Context

A handle takes `h := nil` as its early release (AP 6.4.12.2, ADR-0202). An
owned pointer refuses it, and until this record said:

```
error: an owned pointer may be assigned only 'take' of a variable of its own
type: it owns what it identifies, and there is no copy
```

Every word of that is true and none of it is what the reader wanted, which was
`dispose(p)`. ADR-0295 recorded it as *the refusal does not name what to write
instead*, and asked the further question: whether `p := nil` should simply be
admitted, AP 6.4.14 giving the two owned kinds different releases *for no
reason a reader can see*.

## Decision

**The reason is that an owned pointer already has a release and a handle has
none, and the message says so.**

- **`p := nil` stays refused.** `dispose` (§6.7.5.3) releases an owned
  pointer, and admitting `nil` as a second spelling of it would give one
  operation two ways to be written — which is the thing §6.7.2's
  result-variable rule is careful about elsewhere in this language. Admitting
  it as a plain *store* is not available at all: it would leave the identified
  variable held by no variable, which AP 6.4.14.3 forbids. A handle has no
  `dispose` and nothing else that releases it, so `h := nil` there is the only
  spelling and not a second one. The asymmetry ADR-0295 could not see a reason
  for is that one type has a release statement and the other has not.

- **The refusal gets its own arm and its own words**, because a message that
  is right about the rule and silent about the remedy is what the finding
  was:

  ```
  error: 'dispose' is what releases an owned pointer: assigning nil would
  leave what it identifies with no owner
  ```

  It stands ahead of the general refusal and is selected by `IsNil` on the
  value, which is the same test the handle's admitting arm uses one type over.

- **AP 6.4.14.6 gains NOTE 6**, stating the asymmetry and its reason, and
  saying that a processor is expected to name `dispose` where it reports this.
  The clause's normative text is unchanged — `take` was already *the only
  value of an owned-pointer-type an assignment-statement admits* — so nothing
  the compiler accepts moves.

## Evidence

`tests/dialect/owned_errors.pas` gains `p := nil` after the `new(p)` that
begins its statement part, so the variable really does identify storage when
the statement is refused. The golden gains one line, and it is a **new**
diagnostic, which `diagnostic-coverage` requires to be named by one.

| Mutation | Killed by |
| --- | --- |
| the `IsNil` arm deleted, so the general refusal answers again | `owned_errors`, at the last line of the golden |

The mutation is the interesting direction here: deleting the arm leaves a
program that is still refused, still with exit 1, and still with a true
sentence written about it. Only the golden can tell the difference, which is
why the case is the evidence and the compilation is not.

## What is not done

**The general refusal's wording is unchanged**, and eleven goldens across
three cases keep it. It is correct for what reaches it — `q := p`, `p := z`,
a copy in either direction — and none of those is answered by `dispose`.
Widening it to mention `dispose` would have put the remedy on ten refusals
that do not have it.

**`take(p)` of a variable a program then wants empty is still the spelling for
a *move*, and `dispose` for a release.** Nothing here adds a third.

**ADR-0295's findings 5 and 6 are untouched.** `PasJson` writing `0.75` as
`7.500000000000E-01` is §6.9.3.4.1's default real output arriving unchanged
through a library that never chose it, and it needs a decision about what JSON
number formatting this library owes — not a one-line fix. `MapKey`'s 63
characters is a bound recorded as a bound, and ADR-0290's `string` hash is
what a wider one would be built on. Both stay in `doc/roadmap.md`.

## Consequences

**A refusal that is right and unhelpful is a defect with no oracle.** The
compiler was correct, the case was green, `diagnostic-coverage` had the
message named, and the only thing that reported it was somebody writing a
program and wanting to be told what to do next. That is the same instrument
ADR-0295 was built to be, and this is the cheapest of the seven things it
found.

**An asymmetry between two clauses is either a reason or a defect**, and it
has to be written down as one of the two. AP 6.4.12.2 and AP 6.4.14.6 had
looked arbitrary to a reader holding both, and the reason had never been
stated anywhere — it was implicit in the fact that `dispose` exists.
