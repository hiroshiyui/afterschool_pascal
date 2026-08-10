# 35. A case range is tested, not enumerated

Date: 2026-08-10

## Status

Accepted.

## Context

ISO/IEC 10206:1991 generalised the case-constant-list:

```
case-constant-list = case-range { ',' case-range }
case-range         = case-constant [ '..' case-constant ]
```

Both the case statement (§6.8.3.5) and a variant (§6.4.3.3) name that
production, so the same change reaches both — the third Extended Pascal
feature, and the second one that turns out to be a change to a *list* rather
than to a construct.

ADR-0018 lowered a case statement to an LLVM switch, and Sema folded each label
to a `long long`. The obvious way to add ranges is to keep both and expand
`lo..hi` into its members. That is wrong in a way the corpus would never show:
`1..maxint` is a legal label list, and expanding it is two billion switch cases.
A compiler that hangs on a conforming program is not conforming either.

## Decision

**A label is an interval — `LabelRange {lo, hi}` — everywhere, and a single
constant is `lo = hi`.** Sema folds a case-constant-list to a list of intervals,
and nothing between the parser and the code generator ever holds a label any
other way. This is what makes the rest of the decision possible rather than a
special case bolted on: there is no "range path" and "constant path", only one.

**Codegen tests the ranges and switches on the constants.** A range becomes two
comparisons and a conditional branch, chained ahead of the switch; a single
constant is still a switch case. Sema has already proved the arms disjoint, so
which of the two answers first cannot matter, and the cost is proportional to
the number of *ranges written*, never to the number of values they cover.

**Duplicate detection becomes interval overlap.** "This label appears twice" is
the `lo = hi` case of exactly that question, so both constructs ask the general
form and the ISO 7185 message is unchanged. The value named in the diagnostic is
the lowest one two labels share, which for two single constants is the constant
itself — so no existing diagnostic moved.

**Both ends must be of one type, and a range may not run backwards.** ISO 7185
§6.7.1 makes `[5..1]` the empty set and this compiler honours that in a set
constructor, but a *label* selecting nothing can only be a mistake — nothing
would ever run — so it is refused rather than silently accepted. Reversed ranges
in real code are typos.

## Consequences

**The block order is now decided before the switch is written.** Every arm's
block has to exist before the first range test can name it, so the arm blocks are
created up front in both backends. The emitter stays sequential (ADR-0025) — the
chain is emitted, then the switch, then the bodies, and nothing is revisited.

**A range and a set member are the same pair, and share the node.** The Pascal
AST already had `nkSetMember` with `smLo`/`smHi` and a null `smHi` meaning "a
single value" (the C++ side has `SetMember`), which is exactly a case-range. The
port reuses it rather than adding a kind, and the C++ `CaseLabel` is its twin —
the dumps print a bare expression for a single constant and wrap a range, so
every existing golden dump is unchanged.

**A case with no otherwise-part still traps.** Ranges changed what the switch
tests, not what its default does; `tests/extended/trap_case_range.pas` is what
says so, and `tests/trap_case.pas` still says it for ISO 7185.

**Fourteen mutations, fourteen caught — one only by the differential, and for a
reason worth keeping.** Breaking the interval test in `new(p, c)` so that only a
range's low end matches does not produce an error: the tag value falls through
to the variant-part-completer of ADR-0034 and quietly allocates the wrong arm.
No golden output changes, because nothing then reads the field. The Sema dump
records which variant `new` selected, so the differential sees it. Two features
old, and the completer is already the reason a wrong answer looks like a right
one.

**Constant *expressions* are still not case constants.** `3 * 4 .. 3 * 5` is
refused, because `evalOrdinal` folds a constant and not an expression — the ISO
7185 rule, unchanged. Extended Pascal has constant-expressions in more places
than ISO 7185 does, and that is a feature of its own, not a corner of this one.
