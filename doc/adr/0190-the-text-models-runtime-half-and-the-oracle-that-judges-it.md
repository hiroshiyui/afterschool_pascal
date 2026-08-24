# 190. The text model's runtime half, and the oracle that judges it

Date: 2026-08-25

## Status

Accepted. Implements the first of ADR-0189's four increments. AP 6.4.15 stays
`[not yet implemented]`: this is the runtime, and no language rests on it yet.

## Context

ADR-0189 decided that a text value is well-formed UTF-8 in Normalization Form
C whose elements are extended grapheme clusters, and staged the work in four
increments with the tables and the runtime primitives first — "where all the
risk is, and where the UCD's own conformance files become an oracle nobody here
wrote".

The order was chosen for a reason worth restating: this is the only part of
this language whose correctness is settled by a document written elsewhere.
Every other oracle in this repository compares the compiler against a reading
taken here — the goldens agree with whoever wrote them, `verify/` proves the
lowering matches a model of the lowering, and difftest's two front ends are one
author's reading twice. A misread clause is invisible to all of them at once
(ADR-0072). Normalisation and segmentation are exactly the kind of thing that
would be misread and never contradicted, and Unicode publishes the answers.

## Decision

**Four functions, strict ISO C11, over tables transcribed from the pinned
database, judged by that database's own conformance files.**

`runtime/pasrt_unicode.c` provides `pas_text_validate`, `pas_text_nfc`,
`pas_text_next` and `pas_text_count`, plus `pas_text_unicode_version`.
`runtime/pasrt_unicode_data.h` is generated from the Unicode Character Database
by `runtime/unicode/generate.py` and committed; the database itself is fetched
by `runtime/unicode/fetch.sh` into a gitignored directory and is not.

Five things are worth having written down.

**They are `pas_` and not `pasx_`.** ADR-0131 divides the runtime: `pas_` is
what the code generator names and `ReservedForeignName` refuses, `pasx_` is
what a program may bind. Increment 2 will emit calls to these, so they are
`pas_` from the start rather than renamed later — which costs this increment
its Pascal-level test, since a program cannot bind them. That is the right
trade: the oracle here is a C driver over 20,034 published cases, and a Pascal
smoke test would add a second, weaker reader of the same code.

**The tables are committed and the database is not**, which is `seed/`'s shape
(ADR-0085) and *not* `tests/bsi/`'s reason. Unicode does permit redistribution;
this is a size and provenance decision. The generated header is what a build
needs and the database is what a *refresh* needs, so the gate asks both
questions — the conformance files against the code, and a regeneration against
the committed header. Without the second, the header could drift from the
version it claims and every conformance case would still pass, the run
exercising the header rather than the database.

**A starter is not always the beginning of a normalisation segment.** This is
the finding, and it is the kind that a spot check does not produce. The obvious
streaming rule — flush at each character of combining class zero — is wrong for
**59 primary composites whose second element is itself a starter** — 33 vowel
signs across sixteen Indic and Southeast Asian scripts, where U+09C7 + U+09BE
composes to the Bengali vowel sign O although both are of class zero — and
Hangul, where L + V and LV + T do the same. A normalisation written to the obvious rule silently drops exactly those
compositions and passes everything else. The generator derives the excluded set
from the composition table rather than a hand-written list, and
`combines_back()` is where it is asked.

**A limit is reported, not applied in silence** (ADR-0110). One starter and its
marks are normalised in a fixed buffer of 256 code points, and a longer run
answers `PAS_TEXT_SEGMENT` rather than truncating. Unicode places no bound on
how many marks may follow a base character; real text does not approach this
one, the longest segment in `NormalizationTest.txt` being **six** — a base
letter and five marks, measured rather than guessed.

**The width of a canonical decomposition is measured, not assumed.** The C side
decomposes into an array of `PAS_U_DECOMP_MAX`, which the generator computes
from the database by expanding recursively; it is 4 today. A release that made
it five moves the constant rather than overrunning the array quietly.

### What the oracle actually says

20,034 normalisation cases, 766 segmentation cases, 1,094,978 code points swept
for `NormalizationTest.txt`'s second invariant — every code point Part 1 does
not list is its own NFC — and 18 well-formedness cases. It passed on the first
run, which in this repository is a reason for suspicion rather than confidence,
so four mutations were made and each was caught by the section it should be:
`combines_back` made constantly false (the 59-pair trap, caught on Sinhala),
GB9c deleted (caught on Devanagari conjuncts), the surrogate range admitted in
the UTF-8 decoder, and canonical ordering made unstable.

**The driver counts what it did not use.** Every line of both files that
survives comment-stripping must yield a case, and one that does not fails the
run. That is `difftest`'s corpus-size check for `difftest`'s reason: a parser
that quietly stopped recognising the format would compare fewer cases and
report success, and "everything agreed" and "nothing was compared" print the
same way. Moving one byte of the boundary-marker test reports 766 lines
ignored where it would otherwise have reported 766 cases passed.

The well-formedness cases are the one part with no conformance file behind
them, and the driver says so: they are written out from The Unicode Standard's
Table 3-7 — an overlong encoding, a surrogate, a truncation, a code point above
the range. That table is short and unambiguous, which is why transcribing it is
defensible where transcribing a normalisation would not be.

`runtime-isoc` grew a fourth pass. `pasrt_unicode.c` is held to strict ISO C11
with **no catalogued name at all** — a stronger claim than either of the other
two translation units carries, and free to make while it stays true. ADR-0186
split the runtime because a third unit invisible to that gate is a dependency
nobody counted; this is that lesson applied to the third unit on the day it
arrived rather than afterwards.

## Consequences

`libpasrt.a` gains a translation unit nothing yet calls. It is a static
archive, so no member is pulled into a program that does not reference one, and
a build that never uses text pays nothing.

**A machine without the database tests none of this.** The gate skips (77) as
`verify-lowering` does without z3 and the BSI runner does without its corpus,
and `UNICODE_CONFORMANCE_REQUIRE` is how CI refuses to pass by skipping. It is
a row in `doc/sop.md` §7 because this file has no other reader: no corpus
program reaches it, `coverage.py` sees Pascal and not C, and difftest has
nothing to compare.

**The Unicode version is now an implementation-defined answer**, and
`doc/implementation-defined.md` states it. AP 6.4.15.12 requires that, and it
is the one entry in that document whose value moves for a reason outside this
repository.

## What this does not do

**Nothing in the language changes.** No mode accepts anything it did not, no
diagnostic is added, and `--std=afterschool` has no text-type. AP 6.4.15 stays
marked `[not yet implemented]` and its clauses stay `not-implemented` in the
triage, so the traceability gate still refuses a scenario claiming otherwise.

**No case mapping, no case folding, no scalar view.** Those are increment 4's,
and they belong to `PasUnicode` rather than here — the runtime carries what the
*language* needs and the library carries what a program wants.

**It does not decode into a caller's buffer.** There is no scalar-at-offset
entry point, because nothing needs one yet and an unused entry point in a file
nothing calls would be an unused entry point twice over.

## What it found for increment 2, and did not decide

**The compiler cannot call these functions.** `selfhost/compiler.std` is
`extended`, so `selfhost/compiler.pas` is an Extended Pascal source (ADR-0082)
and `external` is refused there — the compiler has no way to reach C at all.
That matters because AP 6.4.15.5 says a character-string assigned to a
text-type is "validated and converted to Normalization Form C by the processor
**before the program is executed**", and the conversion needs the tables.

Four ways out, none taken here:

- **Validate at translation time and normalise at run time.** Well-formedness
  is pure arithmetic and needs no table, so the *violation* AP 6.4.15.5
  requires is reportable where the literal is written; the conversion becomes
  an emitted call. Cheapest, changes nothing else, and costs the clause its
  "before the program is executed".
- **A second copy of the tables, in Pascal, inside `compiler.pas`.** Refused on
  sight: two descriptions of one truth free to drift is what `PAS_FILE_SIZE`
  versus `fileSize` and `target-layout` exist to police.
- **Make `selfhost/compiler.std` `afterschool`.** The compiler could then call
  the runtime directly. It is not obviously wrong and it is not free: the
  fixed point holds only while the compiler is an Extended Pascal source, and
  ADR-0082's conversion went the other way for a reason.
- **Require a character-string assigned to a text to be in NFC already**,
  reporting a violation if not. Still wants a table — the quick-check property —
  and makes a source file saved in NFD fail to compile, which is hostile.

This is registered rather than settled because increment 2 is where the
evidence will be, and because AP 5.6 already covers the state it leaves the
document in: a clause stated ahead of the processor is a design, and the
increment that builds it is entitled to amend it. That mechanism was written
yesterday for a different reason and is earning its keep on the first
increment.
