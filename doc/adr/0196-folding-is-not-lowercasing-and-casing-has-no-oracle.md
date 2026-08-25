# 196. Folding is not lowercasing, and casing has no oracle

Date: 2026-08-25

## Status

Accepted. `PasUnicode.Fold`, `.Upper` and `.Lower`, and the last of what
ADR-0189 left open.

## Context

ADR-0193 shipped `PasUnicode` and named what it did not do: case mapping, case
folding and grapheme-indexed slicing, "each wanting a table this runtime does
not carry", and said the honest reason was size rather than difficulty. Two of
the three are here.

The whole text model was chosen partly for its oracle. `NormalizationTest.txt`
and `GraphemeBreakTest.txt` state an input and the answer and were written by
people with no interest in this compiler, which is the one thing every other
check in this repository lacks (ADR-0190). **Casing has no such file.** Unicode
publishes the data and no conformance test over it.

That is worth stating plainly rather than letting the reader assume the whole
of the text model rests on the same footing. It does not: normalisation and
segmentation are settled by a document written elsewhere, and casing is
settled by a transcription and a table walk.

## Decision

**Three routines, and the first is the one that matters.**

`Fold` is **full case folding** — `CaseFolding.txt` statuses C and F — and it
is not lowercasing. `Fold(a) = Fold(b)` asks *are these the same but for case*,
which is what a caseless comparison wants, and comparing two lowercased values
answers it wrongly: the German sharp s lowercases to itself and folds to `ss`,
so `straße` and `STRASSE` are equal under folding and unequal under lowering.
Unicode publishes the mapping for exactly this purpose.

`Upper` and `Lower` are **full mappings** too: `UnicodeData.txt`'s simple
mappings with `SpecialCasing.txt`'s **unconditional** entries over them. So
`Upper('straße')` is `STRASSE` and one character becomes two.

**Every conditional mapping is declined**, and the test prints one rather than
omitting it. A conditional entry names a language or a context — the Turkish
dotless i, and Greek's final sigma, where which of ς and σ a letter lowercases
to depends on where the *word* ends. This language reads no environment
variable to decide what a program means (ADR-0189), and nothing here knows
where a word ends. `Lower('ΣΟΦΟΣ')` is therefore `σοφοσ`, ending in σ, and
`tests/dialect/lib_unicode.pas` says so on the line that prints it: a reader
should meet the limitation in the test rather than discover it in a program.

**The result is bytes, not a text**, and that is not an oversight: case mapping
does not preserve normal form. A caller putting the result into a `utf8(n)`
normalises it there, which AP 6.4.15.5's assignment does anyway — so the
composition is correct by construction and the library needs no opinion.

**The caller's capacity goes in.** A full mapping can make one code point
three, so a destination the size of the source is not enough in general and
the caller cannot compute the room it needs. `errFull` and `errSyntax` are
separate for ADR-0193's reason: one is a fault in the data and the other in
the capacity the program chose. That is `PasDir.Next`'s shape.

## Consequences

**The runtime's case tables are 4653 entries** — 1585 folds, 1580 uppercase
and 1488 lowercase mappings — and 16 conditional casings are declined by name
in the generator, so the number that were skipped is reported rather than
silently absent.

**`pasrt_unicode_data.h` roughly doubles**, to ten thousand lines. It is
generated and committed, and `unicode-conformance` still regenerates it and
diffs, so the tables cannot drift from the pinned version.

**Three more `pasx_` names**, taking the caller's capacity and answering
through the arena. The split established by ADR-0193 holds: the algorithm and
the tables are `pas_text_*` in `pasrt_unicode.c`, held to strict ISO C with no
catalogued name, and the `pasx_` wrappers that speak NUL-terminated strings
live in `pasrt.c`.

**The three routines are written out rather than shared.** One body taking the
mapping as a parameter would need a procedural parameter over an `external`
function, and §6.6.3.1's procedural parameter is a code-and-link pair
(ADR-0030) where a foreign routine has no link. Three lines each, and the
duplication is stated at the site.

## What this does not do

**No grapheme-indexed slicing**, the third of ADR-0193's list. `for g in t`
walks elements and a program wanting the third counts to three; an
`ElementAt(t, i)` is O(n) and would read as though it were not, which is
AP 6.4.15.9 NOTE's own objection to an integer index. If it lands it should be
spelled so the cost is visible, and that is a design question rather than a
table.

**No title case.** `SpecialCasing.txt` and `UnicodeData.txt` both carry it and
neither says where a word begins, which is the only thing that makes title
case meaningful. A `Title` that upcased the first character of the string
would be a different operation wearing the name.

**No locale, and no way to ask for one.** Above. A program needing Turkish
casing needs a Turkish library, and this one should not pretend to be the
place that decision is made.

**No conformance oracle, and that is the honest limit of this increment.**
What stands behind these three routines is that the tables are transcribed and
the walk over them is fifteen lines. `tests/dialect/lib_unicode.pas` pins the
cases a reader would think to check — the sharp s both ways, a digraph, the
declined sigma, an overflow, ill-formed input — and that is a sample where
normalisation and segmentation have a sweep. `doc/sop.md` §7 carries it.

## Alternatives rejected

**Simple case folding** (`CaseFolding.txt` status S) instead of full. It is
1:1, so it needs no length answer and no capacity from the caller, and it gets
the sharp s wrong — which is the single case anyone tests. Simple folding
exists for implementations that cannot change a string's length; this one can.

**Lowercasing both sides instead of folding.** The cheaper thing a caller
reaches for, and wrong for the same reason. `Fold` exists so that a program
does not have to know that.

**Putting the routines on the text-type** — `Upper(t)` answering a `utf8(n)`.
It reads better and it hides the fact that case mapping denormalises. Keeping
the result in bytes forces the caller through `ToText`, which renormalises,
and makes the composition correct rather than merely usual.

**Waiting for a conformance file.** There is not going to be one. Declining
casing until Unicode publishes a test for it would leave the text model
permanently one increment short for a reason that will not change.
