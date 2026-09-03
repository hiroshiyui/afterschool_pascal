# 309. The shortest number that reads back

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Closes ADR-0295's **finding 5**, carried in
`doc/roadmap.md`'s chapter *What would make this practical to pick up* as half
of the row *Two smaller reports from the same pass*.

## Context

`PasJson` wrote `0.75` as `7.500000000000E-01`.

That is §6.9.3.4.1's floating-point form with the default width, arriving
unchanged: `RenderNumber` called `writestr(s, v^.num)` and stripped the leading
blank. Every real in every document this library wrote came out in it —
thirteen digits, a capital `E`, and a two-digit exponent — whatever the value
was.

**It was never invalid, and that is worth saying before anything else.** RFC
8259 §6 is `number = [ minus ] int [ frac ] [ exp ]` with `exp = ("e" / "E")
[ minus / plus ] 1*DIGIT`, so a capital `E`, an explicit `+` and a leading zero
in the exponent are all admitted; the grammar puts no bound on the digits
before it either. Every parser that reads JSON reads what this module wrote.
The finding is about a **reader who is a person**: `examples/json_pretty.pas`
prints a document for someone to look at, and the number that went in as
`0.75` came out as something they have to decode. ADR-0295 put that spelling in
`examples/json_pretty.out` deliberately, so that the day it changed would be
visible in a golden.

Two things were *not* wrong and had to stay that way. A number the document
wrote without a fraction and without an exponent is carried as an integer —
`whole`, ADR-0120 — and written back with `writestr(s, v^.inum:1)`, because
JSON has one number type and an LSP request id re-emitted as `3.0` is a
different message. And nothing in the module converts a decimal to a double or
back: `writestr` is §6.10.3's own formatting (ADR-0057) and `readstr` is
§6.10.4's own reading.

## Decision

**A real is written as the shortest decimal that reads back as the same
value**, and the module decides only how many digits to ask the processor for
and where to put the point.

- **The round trip is the definition.** `ShortestReal` asks `writestr` for the
  value at a precision, builds the spelling, hands that spelling to `readstr`,
  and keeps it if what comes back is the value it started from. No conversion
  is written here and none is trusted: the two halves of the trip are the
  processor's own, and the loop stops on the *answer* rather than on a rule
  about how many digits ought to be enough.

- **The search starts at fifteen digits, not at one.** Asking upwards from one
  costs a `writestr` and a `readstr` per digit, both about 1.8 µs, and a value
  needing seventeen pays seventeen of each — 27 µs a number, measured over
  200 000 of them. It starts at fifteen and strips the trailing zeros off the
  answer, which recovers the short spellings without looking for them:

  > if a decimal of k ≤ 15 digits reads back as x, then rounding x to fifteen
  > digits **is** that decimal with zeros after it — x lies within a relative
  > 2⁻⁵³ = 1.1e-16 of it and half a fifteenth-digit step is 5e-16, so no other
  > fifteen-digit decimal is nearer.

  So one probe answers for `0.75`, `0.1`, `3.0` and every number a document is
  likely to hold, and the worst case is four. Measured at **1.0 probes a
  number** over a spread of quarters and **2.6** over the reciprocals of the
  first hundred thousand integers: 5.8 µs a number against the 27 µs the naive
  loop cost.

  That argument is about the relative half-ulp, so it holds for a **normalised**
  value and not for a denormal, whose ulp is relatively enormous. A denormal
  starts the search at one digit instead, where the shortest answer is found by
  looking for it — which is why `1e-320` comes out as `1E-320` and not as
  `9.9998886718268E-321`.

- **Where the point goes is ECMAScript's rule**, the `Number::toString`
  algorithm of ECMA-262, JSON being that language's notation: with *n* the
  position of the point relative to the digits, a fixed form when
  `-6 < n ≤ 21` and an exponent otherwise. That is what makes `10` print as
  `10` rather than `1E+01`, `1e20` print as its twenty-one digits, and `1e-7`
  print as `1E-7` rather than as six zeros and a digit. It is a rule with a
  citation rather than a threshold somebody picked, and it is the one every
  reader of JSON has already seen.

- **Nothing about a whole number changes.** The `whole` branch is untouched:
  `3` stays `3`, `0` stays `0`, `-7` stays `-7`. A real that happens to be
  integral — `JsonNewNumber(3.0)` — now writes `3` where it wrote
  `3.000000000000E+00`, and it does **not** gain a `.0`, which would be the one
  spelling that changes what a strict client reads.

## Evidence

`tests/dialect/lib_json_number.pas` renders sixteen values, hands the rendered
text to two readers, and prints both answers:

```
0.75             -> {"n":0.75} reads=TRUE parses=TRUE
one third        -> {"n":0.3333333333333333} reads=TRUE parses=TRUE
0.1 + 0.2        -> {"n":0.30000000000000004} reads=TRUE parses=TRUE
very small       -> {"n":1E-320} reads=TRUE parses=TRUE
exponent beyond  -> {"n":1E-7} reads=TRUE parses=FALSE
twenty zeros     -> {"n":100000000000000000000} reads=TRUE parses=TRUE
```

`reads=` is `readstr` on the rendered text and is **TRUE for every value**;
that column is the claim. The spelling is printed beside it because a golden
that pinned only the round trip would pass for a writer that had learned
nothing — `7.500000000000E-01` reads back perfectly.

Neither reader is shown the value it is meant to arrive at, and the case
asserts nothing about a spelling that the round trip does not already require.

| Mutation | Killed by |
| --- | --- |
| `if y = x then` becomes `if true then` — the first spelling is accepted whatever it reads back as | `lib_json_number`, at `0.1 + 0.2`: fifteen digits is `0.3`, which is a different double, so `reads=FALSE` appears in a golden that has none |

Two goldens move, and both were written to make this visible:
`examples/json_pretty.out`'s `"ratio": 7.500000000000E-01` becomes
`"ratio": 0.75`, which is the finding read back; and
`tests/dialect/lib_json.out`'s `"pi":3.500000000000E+00` becomes `"pi":3.5`.

## What is not done

**The reader is not correctly rounded, and this change made that visible.**
`parses=` in the case above is `JsonParse` reading its own writer's output, and
it is FALSE for `1E+300`, `1E-7`, `1.7976931348623157E+308` and
`2.2250738585072014E-308`. `ParseNumberNode` scales by multiplying or dividing
by ten once per decade, and a decade at a time accumulates error; a mantissa
past 2⁵³ is inexact before the scaling begins. **It is not a regression** — the
old writer put an exponent on *every* real, so the trip failed for all of them
and now fails for four values in sixteen — but it is a defect in the reader,
and correctly rounding a decimal to a double is a decision of its own with its
own arithmetic. The column is in the golden so that the day it is fixed, the
case says so.

**The exponent is written `E` and not `e`.** ECMAScript writes `1e+21`; this
writes `1E+21`, which is the same number by RFC 8259 §6 and the letter this
module has always used. Changing it would move a golden for no reader's
benefit.

**No specification clause moves and no `docs:` commit follows.** This is a
library change: the language accepts exactly what it accepted, and
`doc/afterschool-pascal-spec.md` says nothing about how a library spells a
number.

**Seventeen digits identify every double**, so the `PlainReal` fallback at the
end of the loop is unreachable for a finite value. It is written out because
the alternative to an answer there is no answer at all, and because the
non-finite guard above it — a value `JsonParse` cannot produce and
`JsonNewNumber` can — needs the same routine.

## Consequences

**A number costs 5.8 µs to write where it cost 1.8 µs**, and a document of ten
thousand reals costs 40 ms more than it did. Nothing in this tree writes such a
document: the language server's numbers are line and character positions, which
are `whole` and never reach this loop, and `lsp/sessions/*` holds no real at
all. The cost is paid by whoever writes reals, which is the reader this change
is for.

**The claim about fifteen digits is an argument and not an oracle.** It is
written out in the module and in this record because nothing here can check it
— the case probes a spread of values, and a spread is not every double. What
*is* checked on every value is the round trip, which is the property a client
depends on; the shortness is the part taken on the argument above.

**`readstr` in a library routine is new here.** No other module in `lib/` reads
its own output back to decide what to write. It is what makes this routine's
correctness independent of any table of decimal exponents — the two directions
are the processor's, and a port that changes either changes both.
