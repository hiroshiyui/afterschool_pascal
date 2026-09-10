# ADR-0399: A differential oracle catalogues causes, not code points

## Status

Accepted, superseding [ADR-0398](0398-a-second-opinion-about-width.md), whose
oracle and argument stand and whose catalogue did not survive contact with a
second machine.

## Context

ADR-0398 put the C library's `wcwidth` beside AP 6.4.15.13's table, on
`fpc-differential`'s terms: not an authority, so where the two differ the
clause decides and the disagreement is catalogued with which way and why. It
catalogued **sixteen ranges of code points**, taken on the machine that wrote
it, and it passed there.

CI failed it on macOS and on ubuntu:24.04 within the hour, with hundreds of
uncatalogued rows — the C library on macOS gives a Devanagari matra no cell
where glibc gives it one and this table gives it one.

**The catalogue was a fact about one C library's table and not about this
one**, which is the whole defect. `fpc-differential` gets away with an
enumerated catalogue because it compares against *one* processor, absent or
present, and skips when it is absent. Every machine has a libc, and they
differ.

## Decision

**What is catalogued is a cause, and a cause is a property of the code
point.** Every disagreement must fall into one, and one that falls into none
is the transcription error the gate exists to find. Four:

- **cluster** — a code point that is not a base of its own: a control, a
  format character, a non-spacing mark, a joiner, a prepended sign. Selected by
  `Grapheme_Cluster_Break`, which the committed header already carries for
  segmentation. A library measuring code points must answer for these with no
  cluster to hang the answer on, and libraries answer differently.
- **mark** — General_Category is Mc, a *spacing* combining mark, which
  AP 6.4.15.13 b) gives one cell and the C library on macOS gives none. **A
  class of its own and not part of `cluster`**, and that is CI's second
  correction rather than a design: UAX #29 does not put every Mc in
  SpacingMark — the Myanmar marks are Other — so the break classes alone still
  failed there. The 193 ranges are written out.
- **jamo** — a conjoining Hangul jamo, where **the two agree about every text
  and disagree about every code point**. Also a break class, and the same one
  the clause's own unit is defined in terms of.
- **ambiguous** — East_Asian_Width is Ambiguous, and the 179 ranges are
  written out. Box-drawing is in it, which is worth knowing: a terminal
  configured for East Asian text draws `─` two cells wide, and that is not a
  defect in anybody's table.
- **filler** — U+3164 and U+FFA0, named, because their break value is Other
  and a rule over two code points hides them.

**The Ambiguous ranges are data and not a rule, and that is the sharpest part
of this record.** The obvious rule is *this table says one and the library
says two*, which is what Ambiguous produces — and it would also excuse a
generator that turned every **Wide** code point into one cell, which is
precisely the error the gate is for. Mutating the committed table so
`{0x3250, 0xA48C}` measures one cell is caught now and would have passed
before.

**Exact agreement is not the claim, and cannot be.** ubuntu:24.04's glibc
predates the release that made the trigrams U+2630..U+2637 Wide, so it says
one cell where this table says two — and *which* code points a library is
behind on is a property of that library's age and not of any property of the
character, so no catalogue closes it. What is claimed is that divergence is
**bounded**: at most 500 code points may disagree for no catalogued reason,
and every one of them is printed whether or not the run fails.

**The bound is measured, not chosen.** The smallest systematic error this
table could contain is every zero-width code point transcribed wrongly — 2 307
of them — and the largest is every Wide one, 182 869. An upstream version skew
is tens: the trigrams are eight, and a whole block of symbols a release behind
comes to 45. Five hundred separates those by a factor of four in one direction
and three hundred in the other.

**A floor of 300 ranges** over the two generated sets, so neither class can
come to excuse everything by being empty.

**`--write-classes` regenerates both** from the pinned database, which is a
step a *refresh* takes: the UCD is fetched and never committed.

## Consequences

**The gate is machine-independent and was proved so before being committed
again** — after being *insufficiently* proved so once. Nine synthesised C
libraries are replayed against it: one giving every spacing mark no cell (the
macOS shape), one giving every zero-width character a cell, one widening every
Ambiguous, one zeroing every jamo — all four pass; and tables that mis-measure
a Latin letter, a CJK ideograph, or every Wide code point — all fail, naming
the first code point they got wrong.

**What this cannot see is a systematic error *inside* a class the clause
itself declares open**, and that is the honest boundary rather than an
oversight. If the generator stopped giving marks no cell, every mark would
measure one, every disagreement would be explained by `cluster`, and this
would pass — because a library giving a mark one cell is exactly what
`cluster` exists to permit. The same is true of the spacing marks and of
Ambiguous. What the gate does see is an error that crosses those lines, which
is what a misread of the width file looks like: narrowing every Wide code
point leaves 115 396 unexplained.

Nor can it see an error in **one** code point, which is under the bound by
construction. `unicode-conformance` covers that half by regenerating the
header and diffing it. Between them, what stays uncovered is a
`generate.py` bug that misreads fewer than five hundred code points *and*
stays inside one of the three open classes. That is a `doc/sop.md` §7 row and
is the smallest this can be made without a second Unicode implementation that
agrees about the version.

**A cause with no members on this machine is reported and not a failure.**
Two libraries decide these differently, so a cause that is idle here is one
this machine's library happens to agree about, and saying so is what keeps
the catalogue from quietly describing nobody.

**The Ambiguous set moves with the Unicode version**, so
`tests/checks/wcwidth.py --write-ambiguous` regenerates it from the pinned
database — a step a *refresh* takes, the UCD being fetched and never
committed (ADR-0189).

**The lesson generalises past this gate.** A differential oracle against
something every machine has is not the same shape as one against something a
machine may lack. `fpc-differential` may enumerate because Free Pascal is
absent or present; a libc is always present and never the same one, so what
can be written down is the *reason* two implementations are allowed to
differ.

## Alternatives rejected

**Pin the catalogue per platform.** Three lists to keep, each right on one
machine, and a fourth platform is a new list rather than an answer.

**Skip unless the C library is the one the catalogue was taken with.** That is
a gate that runs in one place, which is what `doc/sop.md` §7 exists to warn
about.

**Compare only the code points both libraries agree are simple.** It defines
the comparison in terms of the answer and would have excused the defect that
motivated the whole thing.
