# 314. A decimal is the language's to round

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Closes the first item of
[ADR-0309](0309-the-shortest-number-that-reads-back.md)'s *What is not done* —
the reader that change made visible.

## Context

ADR-0309 made `PasJson`'s writer render the shortest spelling that reads back
as the same value. That is what let `tests/dialect/lib_json_number.pas` ask a
question nobody could ask before: does `JsonParse` read the writer's own
output? The answer was **no** for four of sixteen values — `1E+300`, `1E-7`,
`1.7976931348623157E+308` and `2.2250738585072014E-308` — and ADR-0309 put the
column in the golden "so that the day it is fixed, the case says so".

The cause was in one line. `ParseNumberNode` accumulated the digits into a
`real` and then scaled by ten **once per decade**:

    for k := 1 to ex do
      if exneg then mant := mant / 10.0 else mant := mant * 10.0

so a value was rounded as many times as its exponent had decades, and a
mantissa past 2⁵³ was already inexact before the scaling began. It was not a
regression — the old writer put an exponent on *every* real, so the trip
failed for all of them — but it was a defect in the reader.

**The module was the only half of the trip doing its own arithmetic.** The
writer had been consulting `readstr` all along: its search renders a
candidate, reads it back through the processor's own reader, and keeps the
first spelling that returns the value it started from. So the case was not
measuring a reader against a specification. It was measuring two converters
disagreeing, one of which was the language's.

## Decision

**The reader stops computing.** The scan is unchanged: it still validates
RFC 8259 §6's grammar exactly — which is stricter than Pascal's, admitting no
leading `+`, no bare `.5`, no `5.` and no leading zeros — and still advances
the position. What it no longer does is arrive at a value. It normalises what
it reads into a significand and a decimal exponent, writes them as a Pascal
real-literal, and converts once:

    writestr(text, sig, 'E', dexp:1);
    readstr(text, mant)

ISO/IEC 10206:1991 §6.9.5's two required procedures are how a program hands a
value to the language's own number reading and takes the answer back, and that
reading is correctly rounded. So this module gets the answer without owning
the arithmetic, and the two halves of the round trip now consult one converter
by construction rather than agreeing by two arithmetics written twice.

The normalisation is a local procedure of nine lines, and its two asymmetries
are the whole of its content. A leading zero contributes no digit — before the
point it contributes nothing at all, and after it, it shifts what follows one
place down. And a digit dropped for want of room leaves its place behind when
it came from the *integer* part, so the exponent takes it, while one dropped
from the *fraction* part cancels against the −1 that appending it would have
carried, so nothing happens.

## Evidence

All four FALSE columns are TRUE. Six values were added to the case, chosen for
what the old arithmetic could not have got right, and every one round-trips:

| Value | What it asks |
| --- | --- |
| `5.0e-324` | a denormal, which decade-at-a-time scaling loses entirely |
| `4.9406564584124654e-324` | the least subnormal, spelled with seventeen digits |
| `3.1415926535897932e-300` | seventeen digits *and* a large exponent — both halves of the old defect at once |
| `9007199254740992.0` | 2⁵³, the last integer that is exactly a double |
| `9007199254740994.0` | just past it, where a decimal mantissa stops being exact |
| `1.0000000000000002` | one ULP above one |

**Mutation**: putting the scaling back — `readstr(sig, mant)` and then a loop
multiplying or dividing by ten — turns **eight of the twenty-two** round-trip
columns FALSE. Eight rather than the original four because the case has more
adversarial values in it now, which is what those six were added for.

Edges probed by hand, all as before or better: a 60-digit significand
truncates at 40 and is right to double precision; a 60-digit integer gives
`1.234567890123E+59`; `1e400` gives `inf`; `1e-400` gives zero; `1e99999`
gives `inf`; `-0.0` reads as zero. `examples/json_pretty.out` did not move,
the writer being untouched.

## What this does not do

**It is not exact for a number written with more than forty significant
digits**, and that is stated rather than hidden. At most `SigMax` = 40 digits
are kept and the rest move into the exponent. Seventeen identify a double, so
what is dropped can only matter where the value sits within about 10⁻²³ of a
halfway point — which a document has to be built to hit rather than reach by
accident. Keeping every digit a document may write would need a string with no
capacity, and this language has none.

**The `ex > 10000` guard stays**, and its purpose has changed. It used to
bound a loop; it now bounds the exponent arithmetic and the literal's length.
What is outside it is `inf` or zero either way.

**Nothing about the language moves.** No clause of
`doc/afterschool-pascal-spec.md` changes and no `docs:` commit follows: the
language accepts exactly what it accepted, and the specification says nothing
about how a library spells a number. That is ADR-0309's own reasoning for the
writer and it holds for the reader.

**The reader still answers `inf` rather than an error for a number outside the
range of a double.** RFC 8259 §6 says an implementation may set limits on the
range and precision of numbers; this one has always answered the nearest
representable value and goes on doing so.

## Alternatives rejected

**Implement correct decimal-to-binary rounding in the module.** It is a
decision with its own arithmetic — a big-integer comparison against the
halfway point, or Clinger's, or Eisel–Lemire — and the language had already
taken it. A second implementation would be a second thing to drift, and
nothing here would compare them.

**Bind `strtod` with an `external` declaration.** It would work, and it was
refused for a reason `doc/sop.md` §7 already carries: nothing checks a foreign
declaration against the function it names, so a signature is documentary. The
required procedure reaches the same `strtod` with nothing to get wrong.

**Clinger's fast path** — an exact integer mantissa times an exact power of
ten, correctly rounded whenever the exponent is within ±22 because 10^|e| is
then exact in a double. It is correct where it applies and it would have fixed
`1E-7` and none of the other three. A partial answer to a whole problem, and
it would still have needed the slow path underneath it.

**Keep every digit.** It needs a string with no capacity.

## Consequences

`JsonParse` and `JsonRender` are now inverse for every value in the case,
which is the property a serialiser is for and the one a protocol depends on.
`PasHttp` and the language server both read JSON this module parsed, so what
they receive is now the number the peer sent.

The lesson generalises and this is not the first time: **a library that needs a
numeric answer the language already gives should ask the language.** The same
shape settled ADR-0290's congruity rule and ADR-0310's key capacity — in each
case the module had taken on a decision that belonged one level down.

`tests/dialect/lib_json_number.pas` is now a round-trip case with no FALSE in
it. That is worth watching: a column that only ever reads TRUE is a column
whose failure nobody has seen, so the mutation above is the evidence and the
golden is only its record.
