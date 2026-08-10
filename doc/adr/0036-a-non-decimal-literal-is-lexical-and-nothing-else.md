# 36. A non-decimal literal is lexical and nothing else

Date: 2026-08-10

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.1.5 extends the unsigned-integer:

```
extended-number         = base '#' extended-digit-sequence
base                    = digit-sequence
extended-digit          = digit | letter
```

The base is a decimal digit-sequence whose value is in 2..36, and a letter is
the digit worth ten more than its position, so base 36 runs `0`..`9` then
`a`..`z`. `16#ff` is 255; `10#16` is sixteen, because the base is decimal even
when what follows it is not.

This is the fourth Extended Pascal feature, and the first that adds no node, no
type rule and no instruction. It would have shipped without a record — it
decides nothing a later feature has to live with — but the project has settled
that **every feature of the second standard gets one**, so that the language's
growth is readable end to end from `doc/adr/` rather than only where a decision
happened to be hard. What follows is therefore a short record, and that is the
honest shape of it.

## Decision

**The literal is consumed entirely in `lexNumber`, and what the parser receives
is an ordinary integer literal.** No token kind, no AST field and no flag
records that a number was written in base sixteen. That is the whole design:
`16#ff` is a constant definition, a case label, a subrange bound, a `for` limit
and an array index with no rule of its own in any of those places, because by
the time any rule runs there is nothing left to see. `tests/extended/
nondecimal.pas` puts it in each of those positions for exactly that reason —
the test's job is to demonstrate that nothing downstream can tell.

**The extended-digit sequence is maximal.** `16#ffand` is *one ill-formed
number*, not `16#ff` followed by `and`. In this production a letter genuinely
is a digit, so scanning stops at the first character that is neither, and the
diagnostic names the offending digit rather than the base. Longest-match is
what the grammar says; the alternative would make the token boundary depend on
the value of the base, which is a semantic property.

**Overflow is caught while accumulating, not by converting and comparing.** The
bound is `maxint`, not what a 64-bit conversion happens to survive, and the
Pascal lexer has no wider type to overflow into and inspect afterwards. Both
compilers must agree on precisely where a literal stops being one, so both
decide it digit by digit.

**Under `--std=iso7185` the literal is consumed and then refused.** `#` is not
a character of ISO 7185 at all, so bailing at the `#` would leave the digits to
be lexed as an identifier and the program would fail again for a second,
misleading reason. One diagnostic, no cascade — the same rule the rest of the
lexer follows.

## Consequences

**Five diagnostics, and one of them is not new.** The ISO refusal, a base
outside 2..36, an empty digit sequence, and a digit worth at least the base are
this feature's; "integer literal out of range" is the existing message, reused,
because the value is out of range for the same reason and by the same rule
(ISO 7185 §6.4.2.2 — the integer type is −maxint..maxint). A literal too large
to be one is not a lexical property of how it was spelled.

**The overflowing value differs between the two compilers, and the dumps still
agree.** The C++ keeps the partial value and stops accumulating; the Pascal
stops before the multiply that would overflow. Neither value is meaningful, and
neither is printed: the dump writes `int ?` for anything above `maxint`. The
differential compares what is printed, so the two are free to disagree about a
number that is not a value of the type — and they do.

**The error paths live in two corpora, split by which language they are in.**
The ISO 7185 refusal is a lexical error path, so it belongs in
`selfhost/torture.pas` with the rest; the extended-mode refusals are a valid
`--std=extended` compilation that reports errors, so they are
`tests/extended/nondecimal_errors.pas`. The same feature, two files, because
the corpora are divided by standard and not by topic.

**Eleven mutations, eleven caught, and the golden files do most of the work for
once.** A wrong digit value or a decimal accumulation still compiles and still
prints a number, so what catches them is that `nondecimal.pas` writes every
value out and the same value is written in four bases on one line. The
differential covers what golden output cannot see — which of the five
diagnostics came out, and where the token ended.
