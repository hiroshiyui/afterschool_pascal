# 271. The padding was the lexer

Date: 2026-08-31

## Status

Accepted, 2026-08-31.

## Context

ADR-0270 profiled this compiler for the first time and its headline was a
surprise: over `selfhost/apfront.pas`, lexing is 26% of a compile and parsing
is 5%. **The lexer cost five times the parser.**

It named the suspect in the same breath. `LookupKeyword` is called once for
every identifier in a source, and it was a linear scan of all forty-five
word-symbols in which each iteration did two things:

```
    n := kwWidth;
    while (n > 0) and (kwText[i][n] = ' ') do n := n - 1;
```

`kwLit` is `packed array [1..9] of char` — nine, for `procedure`, the longest
reserved word — so every entry is blank-padded and every entry's real length
was recomputed by walking backwards over that padding. Forty-five entries, up
to nine steps each, **per identifier in the source**, for a fact that is fixed
when the table is built.

And the loop was a `for` with no way out: having matched `begin` at entry 3 it
went on to compare the remaining forty-two, because a `for`-statement cannot
stop early and nothing had made it a `while`.

## Decision

`kwLen: array [1..kwCount] of integer`, filled in `DefineKeyword` where the
spelling arrives, and the loop rewritten as a `while` that stops once a
word-symbol has been found.

A separate array rather than a field on a record, because `kwLit` is the type
`DefineKeyword` takes and a record would have changed all forty-five calls for
nothing.

Stopping early is safe because a spelling appears once: the old loop took the
*last* match and the new one takes the first, which is the same answer over a
table with no duplicates, and it has none.

## Consequences

**Lexing `apfront.pas` and the ApTypes its translation reads — 28 501 lines —
goes from 98.9 ms to 66.2 ms, a third off.** A whole compile of the same
component goes from 377.6 ms to 342.7, and of `compiler.pas` from 319.2 to
269.1 — 16%, that component reading both others.

**The split between the two changes is the part worth keeping**, and it is the
opposite of what one would guess:

| | lexing |
| --- | --- |
| before | 98.9 ms |
| `kwLen` alone, `for` loop kept | 68.0 ms |
| and stopping at the match | 66.2 ms |

The padding trim was **31%** of lexing. The early exit — the change anyone
would reach for first, and the one that reads like the optimisation — is worth
2.6%. Measured by building the compiler both ways rather than reasoned about,
because the reasoning would have got it backwards.

**`benchmark` fired, in the direction that matters here.** `share:lex` moved
0.262 → 0.194, outside its 15% tolerance, and the gate confirmed it with a
second measurement and printed *faster*. That is ADR-0270's claim working:
a proportion that drops by a quarter is a stage that stopped doing something,
and whether that is a fix or a defect is for the reader. The baseline is
rewritten here with this record as its argument, which is what
`benchmark.txt`'s own header asks for.

**Nothing else moved.** 774 cases green, the stage-2-equals-stage-3 fixed point
included — which is the one that matters, the compiler having lexed itself with
the new code to build the compiler that lexed itself again.

**What this does not claim.** Lexing is still 19% of a compile and the scan is
still linear: forty-five integer comparisons per identifier, with a character
loop only where the lengths agree. Bucketing the table by length would cut that
to about ten, and it was not done, because the measurement above says the
remaining scan is no longer where the time is and ADR-0270's gate is now in
place to judge a claim that it is.
