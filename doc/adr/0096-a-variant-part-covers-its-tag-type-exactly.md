# 96. A variant part covers its tag-type exactly

Date: 2026-08-15

## Status

Accepted.

## Context

ISO 7185 §6.4.3.3:

> The values denoted by all case-constants of a type that is required to be
> compatible with a given tag-type shall be **distinct** and the set thereof
> shall be **equal to** the set of values specified by the tag-type.

Distinctness was checked. Neither half of the equality was, so a variant part
could name a value the tag-type does not have and could leave one of its values
selecting nothing.

## Decision

**One sentence, two checks, because it fails in two directions.**

- **Membership** is asked of each label as it is folded, beside the
  compatibility test already there.
- **Coverage** is asked once, after the arms are built, by walking the tag-type
  from its first value and asking which range covers it.

**ISO/IEC 10206:1991 §6.4.3.4 splits the same sentence, and the split is where
the variant-part-completer goes.** Membership is stated unconditionally; the
coverage half is "each value possessed by the variant-type of a variant-part
shall correspond to one and only one variant", and a completer is what the
values nothing names correspond to. So an `otherwise` arm discharges coverage
and never membership — it claims the values nothing names, not values the
tag-type does not have. **No `--std` test was needed anywhere**: under ISO 7185
there is no completer, so the two checks together are §6.4.3.3 exactly.

**The coverage walk asks which range covers a value, not how many values are
covered.** A tag-type of `integer` spans more values than an integer can hold,
so a count would overflow before the answer did. `need` strictly increases and
the step is taken only below the type's last value, so neither the loop nor the
arithmetic can run away.

**A label that failed any earlier check suppresses the coverage question.** A
rejected range is not recorded, so its non-overlapping tail would read as a gap
and earn a second complaint about a fault already reported (ADR-0054).

## Consequences

**463 cases pass, and across all 812 BSI programs only the two targets moved** —
no CONFORM program has a variant part that fails either half, which is the
evidence that the strict reading is the right one.

**Three programs in this tree did fail, and all three were wrong.** Two used
`case integer of` with two labels — legal only if every integer is named — and
each was testing something else entirely (nested tagless variant parts; that
`otherwise` and `only` are ordinary ISO 7185 constants). Both now name a
tag-type whose values are exactly their labels, and a tag-type must be a
type-*identifier*, so the second needed the pair given a name.

**It made an existing diagnostic almost unreachable, and the message is kept.**
`selfhost/badsema/newvariants.pas` relies on a record whose variant part omits
a value, so that `new(p, c)` can report "no variant is selected by c" — and that
record is now itself ill-formed. Under ISO 7185 there is no unnamed value left
to select and under Extended Pascal a completer would claim it, so the message
survives only in a program that is already broken. It is kept because the check
is per call and cannot assume the type was well formed — CLAUDE.md's
"reachable only because Sema refused first" pattern, met again.

### What this does not do

**It does not touch the case-*statement*.** §6.8.3.5 requires only that the
case-constants be "of the same ordinal-type as the expression of the
case-index", and §6.7.1 makes a subrange factor behave as its host — so a case
statement over a `0..3` may name 9 without violating that clause. Different
clause, different answer; the two checks must not be unified.
