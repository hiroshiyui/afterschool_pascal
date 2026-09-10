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
  format character, a combining mark, a joiner, a prepended sign. Selected by
  `Grapheme_Cluster_Break`, which the committed header already carries for
  segmentation. A library measuring code points must answer for these with no
  cluster to hang the answer on, and libraries answer differently.
- **jamo** — a conjoining Hangul jamo, where **the two agree about every text
  and disagree about every code point**. Also a break class, and the same one
  the clause's own unit is defined in terms of.
- **ambiguous** — East_Asian_Width is Ambiguous, and the 179 ranges are
  written out.
- **filler** — U+3164 and U+FFA0, named, because their break value is Other
  and a rule over two code points hides them.

**The Ambiguous ranges are data and not a rule, and that is the sharpest part
of this record.** The obvious rule is *this table says one and the library
says two*, which is what Ambiguous produces — and it would also excuse a
generator that turned every **Wide** code point into one cell, which is
precisely the error the gate is for. Mutating the committed table so
`{0x3250, 0xA48C}` measures one cell is caught now and would have passed
before.

**A floor of 100 ranges** on that set, so the class cannot come to excuse
everything by being empty.

## Consequences

**The gate is machine-independent and was proved so before being committed
again**, by replaying the comparison against a synthesised table with every
spacing mark at zero — the shape that broke it — and against tables that
mis-measure a Latin letter and a CJK ideograph. The first passes; the other
two fail.

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
