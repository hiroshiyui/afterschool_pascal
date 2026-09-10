# ADR-0400: ICU reads the same database

## Status

Accepted, superseding [ADR-0398](0398-a-second-opinion-about-width.md) and
[ADR-0399](0399-a-differential-oracle-catalogues-causes.md). The oracle those
records reached for was the wrong one; the question they were asking was
right.

## Context

AP 6.4.15.13's table is generated from `EastAsianWidth.txt` and
`UnicodeData.txt`, and East_Asian_Width is the one Unicode property in this
tree with **no conformance file** — so `unicode-conformance` regenerating the
header and diffing it checks that the *generator* is stable, which is a
different claim from the table being right.

ADR-0398 put the C library's `wcwidth` beside it. That gate was wrong three
times in a day, each time found by CI and not by me:

1. It catalogued sixteen **ranges of disagreeing code points**, which is a
   fact about one libc's table. macOS and ubuntu:24.04 failed it at once.
2. Catalogued **causes** instead — but the break classes alone missed that
   UAX #29 does not put every Mc in `SpacingMark`, so macOS failed again.
3. Then ubuntu:24.04 failed on the trigrams U+2630..U+2637, because its glibc
   predates the release that made them Wide — and **which code points a
   library is behind on is a property of that library's age**, which no
   catalogue closes. ADR-0399 gave up exact agreement and bounded divergence
   at 500 code points instead.

That third answer was coherent and it was a retreat. It left two things
invisible, both written into `doc/sop.md` §7: an error in a *single* code
point, under the bound by construction; and a systematic error *inside* a
class the clause itself declares open — a generator that stopped giving marks
no cell would have had every disagreement explained and passed.

The defect was in the choice of oracle, and it took being told to see it.
`wcwidth` answers a **width**, which is a policy that library holds about
characters the standard leaves open; it names no version; and every machine
has one, all different.

## Decision

**ICU is the oracle, and the reasons are properties of the oracle rather than
preferences.**

- It exposes `UCHAR_EAST_ASIAN_WIDTH` and `u_charType` — **the properties the
  clause is written over** — rather than a width of its own. So the probe
  applies AP 6.4.15.13's own three rules to ICU's data, and what is compared
  is two independent transcriptions of two files, not two opinions about
  rendering.
- It reports **which Unicode version it was built from**. So the comparison
  can be exact, and can **abstain** when the versions differ, which is what
  makes exactness a claim worth making.

The catalogue is gone. There are no causes, no excused classes and no bound:
**1 112 064 code points, exact agreement.** Every scalar value there is.

**A missing ICU and a version mismatch are different skips**, and
`ICU_WIDTH_REQUIRE` covers only the first. A job that meant to install ICU and
did not is set up wrong and the variable says so; a machine whose ICU predates
the pinned Unicode cannot answer this question however loudly it is asked, and
forcing that to fail would make the gate report a defect in a distribution's
packaging schedule. ADR-0282's shape: say what could not be measured rather
than measure something else.

## Consequences

**It sees both things ADR-0399 could not.** One code point transcribed wrongly
is caught by name. Dropping `Cf` and `Cc` from the zero-width rule is caught
as 235 disagreements. Both were measured against the old gate first, and both
passed it.

**On an image whose ICU is older than the pinned Unicode, this abstains and
says so.** That is the honest cost of exactness, and it is smaller than it
looks: the gate runs wherever ICU is current, the abstention names both
versions, and the alternative was a gate that ran everywhere and asserted
almost nothing.

**Three records for one gate is the process leaking**, which ADR-0343 names
and this is an instance of. The cause is worth writing down because it is not
carelessness: each correction was a real finding about the *previous* oracle,
and none of them was reachable by thinking harder about the catalogue. What
would have avoided all three is asking, before writing a differential, what
the second implementation is a second implementation *of* — `wcwidth` is not
another reading of `EastAsianWidth.txt`, it is a rendering policy, and that
was knowable on day one.

**`fpc-differential`'s rule survives and is narrowed.** Where two
implementations differ, the clause decides and the disagreement is
catalogued — but that is a rule for comparing against another *processor*.
For a data table, the right comparison is against another reading of the same
data, and then the answer is agreement rather than a catalogue.

## Alternatives rejected

**Keep `wcwidth` beside ICU.** Two oracles, one of which needs 500 code points
of tolerance and a five-cause catalogue to say anything at all. Its entire
apparatus existed to work around not being a reading of the database.

**Match the C library's Unicode version by pinning an older UCD.** It inverts
the dependency: this compiler would draw today's characters wrongly to agree
with a library it does not use.

**Compare ICU's `u_getIntPropertyValue` against the UCD directly.** That is
`unicode-conformance`'s regeneration, one file further out, and it needs the
database — which is fetched and never committed, so the gate would skip on
every checkout that had not fetched.

**Use ICU's own `u_getIntPropertyValue(cp, UCHAR_EAST_ASIAN_WIDTH)` as the
width.** UAX #11 assigns a property and not a number of cells; turning it into
one is AP 6.4.15.13's decision, and having ICU make it would be comparing this
table against itself.
