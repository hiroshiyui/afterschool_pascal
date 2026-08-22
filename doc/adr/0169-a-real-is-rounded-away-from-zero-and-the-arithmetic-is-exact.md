# ADR-0169: A real is rounded away from zero, and the arithmetic is exact

Date: 2026-08-22

## Status

Accepted. Adjudicates two of the findings ADR-0168 listed and left open.

## Context

ISO 7185 §6.9.3.4.1 and §6.9.3.4.2, and ISO/IEC 10206:1991 §6.10.3.4.1 and
§6.10.3.4.2, say how a real value is written. They do **not** say "rounded" and
leave the direction to the processor. They prescribe an algorithm:

> let eWritten be the non-negative number defined by
>
>     if e = 0.0
>       then eWritten := 0.0
>       else
>       begin
>         eWritten := abs(e);
>         eWritten := eWritten + 0.5 * 10.0 pow(-FracDigits);
>         eWritten := Truncate ( eWritten, FracDigits )
>       end;

Add half a unit of the last printed place, then truncate. That is round-half-
**away-from-zero**. This runtime handed the job to C's `printf`, which rounds
half to **even** — so every exact halfway value came out one unit low half the
time, silently. `0.125:6:2` was `0.12` where the clause requires `0.13`;
`2.5:4:0` was `2.` against `3.`; `0.5:4:0` was `0.` against `1.`.

The same clause conditions the sign on the **rounded** magnitude:

> the character `-` if (e < 0.0) and (eWritten > 0.0)

so a negative value that rounds away to nothing is written without a minus, and
MinNumChars is not incremented for a sign that is not there. `printf` writes the
sign bit instead, so `-0.000001:0:2` was `-0.00` where the clause requires
`0.00`, and the two negative zeros in `tests/extended/complex.pas` — `cos(0+0i)`
has an imaginary part of −0.0 — printed `-0.000`.

Found by ADR-0168's third reader, which implemented the clause and swept 2576
triples against this runtime.

## Decision

Both are fixed, and the interesting part is the second question the fix forced.

### The arithmetic is exact, not real-type

Taken literally the algorithm is real arithmetic — `Truncate` is declared
`(y: real; DecPlaces: integer): real`, and that reading is defensible. **It was
implemented that way first, and it is wrong.** §6.10.3.4.1 scales before
rounding:

> eWritten := eWritten / 10.0 pow ExpValue;

For a denormal, `10.0 pow ExpValue` underflows and the division returns garbage:
`1e-320` printed as `0.000000000000E+00`, a nonzero value written as zero. BSI's
IMDEFB45 catches exactly that — it writes successively smaller reals to a file,
reads them back, and requires each within 0.1% — and it was the one program of
812 that moved.

The literal reading also makes the *fixed-point* answer depend on the precision
of the processor's real-type, because `0.5 * 10.0 pow(-1)` is 0.05 and no binary
format holds it: `0.25 + 0.05` lands a hair under 0.3 and truncates to 0.2.

§6.10.3.4's opening sentence is what settles it:

> If e is of real-type, a decimal representation of the value of e, **rounded**
> to the specified number of significant figures or decimal places, shall be
> written on the file f.

The representation is of *the value of e*. The sub-clauses say which rounding;
they do not license losing the value. So the halving and the scaling are done on
the exact decimal expansion, and `0.25:6:1` is `0.3`.

That expansion is finite — a double is a dyadic rational, `2^-n` has exactly `n`
fraction digits, and the smallest denormal is `2^-1074` — so asking `printf` for
1074 fraction digits (or 767 significant, for the floating-point form) rounds
nothing at all, and the digits can then be operated on directly.

**And on an exact expansion the algorithm collapses to one test.** Adding
`0.5 × 10^-p` and truncating at `p` rounds up exactly when the discarded tail
reaches a half, and that tail is `0.d(p+1)d(p+2)…` — so the whole of it is
"is `d(p+1)` at least 5", and nothing after that digit can matter. The scaling
in the floating-point form becomes reading the exponent off `%e` rather than
dividing, which is where the denormal was lost.

### What the goldens did

**Exactly one existing golden moved**, and the fact that it is one is itself
evidence for the reading. Under the literal real-arithmetic reading four moved:
`fieldwidth` (`-3.75:0:1` from `-3.8` to `-3.7`), `realconsts` (`maxreal:26`
from `…315708` to `…315744`, the division's rounding error made visible),
`readlongreal`, and BSI's IMDEFB45 regressing outright. Under the exact reading
all four come back to what they already said — because `printf` converts the
exact value too, and differs from the clause only in the *direction* it breaks
a tie and in the sign. What is left is:

- `tests/extended/complex.out`: two negative zeros lose their minus.
  `cos(0+0i)` has an imaginary part of −0.0 and `cmplx(0,1) pow 3` a real part
  of −0.0; `-0.0 < 0.0` is false, so §6.10.3.4.2's first condition fails, and
  for a tiny negative that rounds away the second one does.

`tests/write_real_round.pas` and `tests/extended/write_real_round_zero.pas` are
new, and **their expected output was generated from the clause** by an
implementation of it written separately from the compiler — not by running the
compiler, which is the thing a golden must not simply agree with.

That separate implementation is also the evidence: **5022 cases** — both forms,
widths 0 to 26, fraction lengths 0 to 10, `DBL_MAX`, `DBL_MIN`, denormals, the
decade boundary at `1e100`, and randomly generated values across the exponent
range — agree with it exactly.

## Consequences

**A program that writes reals can print different characters than it did in
v2.0.0.** Only at exact halfway values and at negative values that round to
zero, but silently, which is the change users mind most. It is called out in the
changelog under `Changed` rather than `Fixed` for that reason.

Two mutations kill two different tests: rounding exact halves down again fails
`write_real_round` and `write_real_round_zero`; taking the sign from the value
written rather than the value rounded fails `complex` and
`write_real_round_zero`.

### What this does not do

`ExpDigits` is unchanged and still deviates. §6.10.3.4.1 reads as though it were
a fixed implementation constant; here it is 2, or 3 once the exponent needs a
third digit, so the floating-point field is one character wider than TotalWidth
at `|exponent| >= 100`. ADR-0168's third reader raised this as a finding and it
is not one: `doc/implementation-defined.md` E.27 has stated it since ADR-0064,
and `tests/extended/writereal_width.pas` measures it. Making ExpDigits a genuine
constant means choosing 3 and widening *every* floating-point field by one
character, for the benefit of exponents no ordinary program writes.

Nothing here touches `read`. §6.10.1's number syntax and its longest-prefix rule
(ADR-0076) are a separate mechanism and were not in scope.
