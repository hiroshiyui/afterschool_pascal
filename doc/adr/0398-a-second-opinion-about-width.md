# ADR-0398: A second opinion about width

## Status

**Superseded by [ADR-0399](0399-a-differential-oracle-catalogues-causes.md),
and then by [ADR-0400](0400-icu-reads-the-same-database.md), which replaced
the oracle itself.**
The decision to hold an enumerated list of disagreeing *code points* was wrong
and CI said so within the hour: a range list is a fact about one C library's
table, and this one passed where it was written and failed on macOS and on
ubuntu:24.04. The oracle and its argument survive; what changed is what gets
written down.

## Context

ADR-0395 added AP 6.4.15.13 and a `pas_u_width` table generated from
`EastAsianWidth.txt`, and opened a register row saying plainly what stood
behind it: a simple transcription, one assertion in the generator, and seven
answers in `tests/dialect/lib_unicode.pas`.

**Normalisation and segmentation each have a conformance file Unicode
publishes** (ADR-0189, AP 6.4.15.12 NOTE 17), which is what makes
`unicode-conformance` the one oracle in this tree written by neither this
project's author nor its specification's. **East_Asian_Width has none.** So
`unicode-conformance` regenerating the header and diffing it checks that the
*generator* is stable, which is a different claim from the table being right,
and a release that changed a range's value would be transcribed faithfully,
would move the editor's cursor, and nothing here would disagree.

The C library has a table of its own, built by other people from the same
database, and `wcwidth` is how a program asks it.

## Decision

**`wcwidth` is a differential oracle and not an authority**, which is
`fpc-differential`'s rule (ADR-0234) and its reason: where the two differ, the
clause decides and the disagreement is catalogued with which way and why.
`tests/checks/wcwidth_disagreements.txt` holds sixteen ranges in four causes,
and it fails in **both** directions — a range that stops disagreeing is as
loud as a new one, either being a table that moved.

**What a second opinion actually buys is narrow and worth having**: a
transcription error here would show up as a range with no explanation. That is
the whole claim, and it is smaller than "the table is correct".

The four causes, and none is a defect in this table:

- **format** (ten ranges) — a Cf character. AP 6.4.15.13 b) gives it no cell;
  glibc gives it one. UAX #11 has no opinion, the clause does, and it is what
  makes `Columns` agree with what a terminal draws.
- **jamo** (three ranges) — and this is the interesting one: **the two agree
  about every text and disagree about every code point.** `wcwidth` is per
  code point, so it gives a leading jamo two cells and a medial and final
  none, summing to two for a syllable. AP 6.4.15.13's unit is the *element*,
  and UAX #29's GB6, GB7 and GB8 put L, V and T in one cluster, so the
  syllable is one element of two cells and the parts are never measured alone.
  Probed rather than argued: `Columns` of U+1100 U+1161 is 2, and so is 2 + 0.
- **filler** (two) — the same case one step further.
- **ambiguous** (one) — NOTE 19's choice, recorded in
  `doc/implementation-defined.md`.

**The gate has a floor of 100 000 code points compared.** glibc answers -1 for
anything outside the locale's charmap, so in the "C" locale this would compare
nothing and report perfect agreement — ADR-0282's failure mode exactly.

## Consequences

**The §7 row is narrowed, not struck.** What is checked now is that two
independent readings of one database agree except where this language decided
otherwise. What is *still* unchecked is whether either reading is right: both
could transcribe the same upstream change, and glibc lags Unicode releases, so
a range that moves in a new UCD may show up here as a *new* disagreement
rather than as a confirmation.

**The jamo rows are evidence for the element rule** and not only a
disagreement. ADR-0395 chose the element as the unit and an element's width as
its first code point's, and a per-code-point table built by somebody else sums
to the same answer for a Hangul syllable. That is the closest thing to
independent confirmation the property has.

**A new Unicode release will move this catalogue**, and that is the point:
the rows are where the two tables' *versions* show through, so a refresh that
changes them is a refresh that has to be looked at.

## Alternatives rejected

**Treat `wcwidth` as the oracle and match it.** It is one implementation's
reading, it lags, and it is per code point where this language measures
elements — matching it would mean giving up the unit that makes a Hangul
syllable and a family emoji come out right.

**Compare against a second Python library.** `wcwidth` on PyPI is a
transcription of the same file by a third party and would add a dependency
that is fetched rather than present. The C library is already required to
build anything here.

**Write the catalogue per code point.** 275 rows where 16 ranges say the same
thing, and a range is what a person can read and check against the cause.
