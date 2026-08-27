# 227. A real-valued constant-expression

Date: 2026-08-28

## Status

Accepted. Retires the **real-valued** half of
[ADR-0054](0054-a-constant-expression-is-one-folder-and-every-context-follows.md)'s
refusal, and with it the reason that record gave for it; the set-valued half
stands. Retires the consequence
[ADR-0226](0226-a-string-valued-constant-expression.md) recorded as *"eight
refused required functions remain"*. Both records stand otherwise.

## Context

ADR-0224's audit returned two over-strict findings. ADR-0226 was the first;
this is the second, and the larger one. A constant-definition could not be
given a real-valued expression at all:

```pascal
const unity = 1.0;
      third = unity/3.0;
      pi    = 4 * arctan(1);
```

The first two lines are ISO/IEC 10206:1991 §6.3.2's **own worked example** of a
constant-definition-part, and it cites §6.8.2 against the second of them. This
compiler refused it, along with every real-valued operator and eight required
functions, with *a real constant expression is not folded: a real constant is
carried as the text that was written and never converted*.

The reason was true about the compiler. §6.8.2 has no such restriction. It
makes an expression nonvarying unless it contains a variable-identifier, a
non-static type-name, a function declared by the program, or `eof`/`eoln`;
NOTE 1 adds `empty`, `position` and `LastPosition`, and gives the reason —
they need a variable as a parameter. Every other required function belongs in
a constant-expression, and `trunc`, `round`, `sqrt`, `sin`, `cos`, `ln`, `exp`
and `arctan` are eight of them.

What stood in the way was ADR-0025's decision that **a real literal is carried
as its source text all the way into the IR** — LLVM's assembler is the
`strtod`. Three earlier records deferred writing a conversion on the grounds
that it was never needed, and each was right at the time. Folding needs it in
both directions: a decimal text to compute with, and a way to write a computed
value back as text the assembler will read to the same bits.

## Decision

Fold real-valued constant-expressions, and keep ADR-0025 by **feeding** it
rather than overturning it: a folded result is written back into the string
pool as decimal text, so `realAt`/`realLen`/`realNeg` keep their meaning and
nothing downstream learns that a real can be folded. `EmitRealText` is
unchanged.

Both directions were already in the language this compiler is written in, and
neither had ever been called from it:

- `readstr` (§6.10.4) parses the literal. That is deliberate and not merely
  economical: the conversion it reaches is the one §6.9.1 already specifies
  for reading a number from a text. A hand-rolled digit accumulation would be
  a second opinion about what a decimal literal denotes, free to disagree with
  the assembler's `strtod` on the very literals it was added to fold.
- `writestr` at a total-width of 30 writes it back. §6.10.3.4.2's
  floating-point representation spends six characters on the sign, the point
  and the exponent, so that is 24 significant digits where 17 name a binary64
  uniquely. Probed against `0.1`, `4*arctan(1)`, `1e300` and the smallest
  denormal `5e-324`; all four round-trip exactly, and LLVM's assembler accepts
  the `E+00` exponent the representation produces.

The operations are written as **this compiler's own operators and calls**, so
`**` and `pow` reach `pas_pow_real` and `pas_pow_realint` and the six
mathematical functions reach the same library the emitted code calls. That is
what makes the accuracy statement §6.8.2 NOTE 2 requires a short one — see
Consequences.

Every error §6.8.3.2 and Annex D name is asked **before** the operation, not
after it. This is the one respect in which folding an error differs from
committing one: the emitted code traps on each of these, and the compiler's own
arithmetic is what performs the fold, so a fold that let the operation happen
would abort the compiler on a program it exists to diagnose. Eight diagnostics
result — a zero divisor, a zero base to a non-positive power, a negative base
of `**`, `sqrt` of a negative value, `ln` of a value that is not positive,
`trunc` and `round` out of integer range, and overflow.

Overflow is the exception to "ask first", and asks afterwards. §6.7.4 leaves it
an error a processor may leave undetected and this one does: `1e300 * 1e300`
returns an infinity rather than trapping, and `writestr` writes that as `INF`,
which is not a signed-number any assembler reads back. One test serves for an
infinity and for a not-a-number — `v/v = 1.0` is false for both, a NaN being
equal to nothing — and the zero is asked first, in a statement of its own,
because §6.8.3.2 makes `x/0.0` an error and this compiler's own division
checks for it.

`trunc` and `round` use the emitted check's bound character for character: a
value strictly inside ±2147483648.0, asked of the *shifted* value for `round`
because §6.6.6.3 defines `round(x)` as `trunc(x±0.5)` and the addition is where
an in-range value can leave the range. Writing the bound as the integer type's
own `-maxint..maxint` would be the tighter reading and would make the fold
disagree with the run-time answer for one value at each end.

## Consequences

**The accuracy statement §6.8.2 NOTE 2 requires is one sentence**: the accuracy
of a real-valued constant-expression is the accuracy of the same operation at
run time. It is `doc/implementation-defined.md`'s entry, and it is exact rather
than approximate only because the fold calls what the emitted code calls. The
previous answer to NOTE 2 was *there are none*.

Two halves of that, worth separating. The four arithmetic operators, `abs`,
`sqr`, the comparisons and the two conversions are exact under IEEE 754, so a
folded result of those is the same value on any conforming processor. The six
mathematical functions are correctly rounded by no standard, so
**cross-compiling to a target whose library differs from the host's may give a
folded constant a different value from the same expression evaluated at run
time on that target.** That is the latitude §6.4.2.2 leaves; it is why NOTE 2
exists; and it is stated rather than hidden.

`tests/extended/constexpr_reals.pas` is split along that line. What IEEE 754
fixes has its value written out. The six mathematical functions are asserted as
a *property* — the folded constant equals the value the emitted code computes —
because writing their digits into a golden would pin this machine's library
rather than the language, and would fail on a machine with another.

**ISO 7185 does not move.** §6.3 there admits a `constant`, not an expression,
so no ISO 7185 program can contain a real-valued constant-expression to fold.
Checked against the pre-change compiler rather than argued: both answer
`const x = 1.0 + 1.0` with *the value of constant 'x' is not a compile-time
constant*, the same words before and after.

**`tests/extended/constexpr_errors.pas` changed contract.** Five of its lines
asserted the refusal this record removes, so they are now legal programs and
could not stay in a case whose subject is what §6.8.2 refuses. They are
replaced by the errors the clause really names, and the golden was regenerated
for that reason — the case still refuses, and now refuses for reasons that are
about the program rather than about the compiler.

**The compiler now calls `readstr` and `writestr`, and does real arithmetic
for the first time.** All three had to be expressible in what `seed/pascalc.ll`
accepts or the seed would need refreshing first; they are, and the fixed point
holds unchanged — stage 2 equals stage 3 with the new source.

**The reference front end carries the same folds.** `src/sema.cpp` has a
`double` in its `Symbol` and needs no pool, so its half is shorter; what has to
match is the diagnostics, which is what difftest compares, and both front ends
answer the nine-error probe identically.

## Alternatives rejected

**Write a formatter.** A shortest-round-trip algorithm in Pascal is a large
piece of work whose failure mode is silent — a value that prints back a bit
short. `writestr` is the language's own answer, already implemented, already
exercised by every program that writes a real.

**Emit LLVM's hexadecimal float form**, which is exact by construction. No
standard Pascal program can obtain the bit pattern of a `real`, so there is no
way to write one.

**Fold only the exactly-rounded operations** — the arithmetic operators, `sqrt`
and the conversions — and go on refusing the five transcendental ones. This
keeps every folded value portable, and loses `pi = 4 * arctan(1)`, which is the
expression the finding was about. The accuracy latitude is the standard's, and
declining to use it while claiming to implement §6.8.2 would be the same shape
of half-truth this record is fixing.

**Document the restriction better and keep it.** §5.1 c) admits restrictions,
and this one has now been written down twice with a reason that was true about
the compiler and not about the standard. The second time was ADR-0224's finding.
Removing the cause is what stops there being a third.
