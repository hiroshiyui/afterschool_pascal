# 204. The testable rows, swept from the other side

Date: 2026-08-25

## Status

Accepted. The `testable` half of `tests/spec/clauses/triage.tsv`, and what is
left of ADR-0200's row.

## Context

ADR-0200 read every `structural` row against its clause and found four
misfiled. It closed by naming the mirror failure and leaving it open:

> A clause filed `testable` that states no requirement sits in `pending.txt`
> for ever as work nobody can do — the mirror failure, and about 350 rows wide.
> It is a much weaker signal: "states a requirement" cannot be read off the
> presence of `shall`, and most of those rows carry a reason that is only the
> clause's title.

The weaker signal turned out to be the same signal read the other way. A
`structural` row is wrong when its clause **does** say `shall`; a `testable`
row is suspect when its clause **never** does.

## Decision

**Every `testable` row of the two standards was read the same way**, with the
filter inverted: the clause's own prose, NOTEs excluded, and the question is
whether `shall` is absent.

Of roughly 350 rows, **six** have no `shall` in their own prose. Every one was
read in full, and the result is three rows on each side of the line — which is
the useful part, because it says the filter is not simply an accusation.

**Four are misfiled and become `structural`:**

- **ISO 7185 6.5.2 and ISO/IEC 10206:1991 6.5.2, Entire-variables.** One or two
  productions naming what an entire-variable is. What one *denotes* is
  §6.2.2.11's and what declares one is §6.5.1's, so no scenario can fail here
  alone.
- **ISO 7185 6.6.3.7 and ISO/IEC 10206:1991 6.7.3.7, Conformant array
  parameters.** Their own text is a **NOTE** about the level at which the
  subclause is required — and a NOTE states no requirement. Everything is in
  the three subclauses under each. The reason each carried was a fact about
  *this processor* ("accepted since this became a level 1 processor") rather
  than about the clause, which is the shape to look for on this side as a
  copied reason is on the other.

**Two survive, and their reasons are rewritten:**

- **ISO 7185 6.1.2 and ISO/IEC 10206:1991 6.1.2, Special-symbols.** Each is
  the *whole token list* of the language, and a token given here is given
  nowhere else — `[`, `]`, `:=`, `..` in the first, `**`, `><` and `=>` in the
  second. That is exactly the ground the earlier audit kept §6.7.2.1 and
  §6.8.3.1 on, and it is why "carries a production" is not by itself an
  argument for `structural`: what matters is whether the production introduces
  anything.

**Both survivors are now cited.** `tests/spec/features/special_symbols.feature`
runs one program per standard through the punctuation. The Extended Pascal one
reaches `**` and `><` and not `=>`, which is §6.11.2's renaming clause and
needs a second program-component — `doc/sop.md` §7's gap for 6.11 and 6.13.1,
met from a third direction.

## Consequences

**A feature-level citation had to go with a reclassification.**
`conformant_arrays.feature` was tagged `@iso7185:6.6.3.7 @iso7185:6.6.3.7.1`,
and the container's tag is now wrong — it cited a NOTE. Dropping it is part of
the same change, and it is the first time a triage correction has reached a
scenario file. That is `spec-clause-traceability` working: had the tag stayed,
the gate would have refused a citation of a `structural` clause.

**The denominators fall**, from 100 to 98 testable in ISO 7185 and from 148 to
146 in Extended Pascal, and `pending.txt` loses three entries — work that could
never have been done, coming off a queue rather than being done.

**Both directions of the triage have now been read once**, which is what
`doc/sop.md` §7's row asked for and is the first time either side has been.

## What this does not do

**It does not catch a `testable` row whose clause says `shall` about something
a program cannot exercise.** ADR-0200 found that shape on the other side —
both 5.2 *Programs*, whose `shall` is about a program and not a processor — and
nothing mechanical distinguishes it. Six rows were read here because six had a
detectable signal; the rest were not read, and a reader with the standard is
the only thing that would.

**It does not make a reason an argument.** Most `testable` rows still carry the
clause's title, which is what made this sweep necessary and what will make the
next one necessary. Rewriting 340 reasons is not obviously worth doing, and
saying so is better than leaving the impression that they were checked.

## Alternatives rejected

**Rewriting every testable reason to be an argument**, so that a copied title
could not hide a misfiling again. It is a large mechanical edit whose product
is 340 sentences nobody has independently checked, which is the state the
`structural` side was already in — 51 rows sharing one reason that read as
though someone had checked.

**Leaving 6.1.2 as it was.** Its reason was its title and it was uncited, so it
sat in the work queue with nothing said about why. The clause survives the
sweep on an argument now, and has the two scenarios that argument implies.

**Filing the two conformant-array containers as `not-implemented`.** They are
implemented — this is a level 1 processor (ADR-0153) — and the class is about
what the processor provides, not about what a clause carries.
