# ADR-0395: A column stops being a byte

## Status

Accepted. Stage two of the panel work ADR-0391 deferred, and the first clause
this language has about how a value is *displayed*.

## Context

ADR-0391 made the screen an array of cells so that a Unicode frame could be
drawn, and said in its own consequences that the buffer was a separate
question left for later: *editing East Asian text stays as wrong as it is
today — no regression and no fix.* This is that increment.

What was wrong is one sentence in three places. **A column was a byte.** So
`日本語` drew in nine cells rather than three, everything after it on the row
was nine columns too far right, one press of the right arrow moved a third of
a character, and one Backspace left two bytes that are not a character — which
the undo journal then held as an edit, because ADR-0387 made the journal
complete by construction and it was faithfully recording a fragment.

`tui/README.md` said so under *what the two milestones leave out, on purpose*,
citing AP 6.4.15 NOTE 14: the number of columns a value occupies is outside
this language, so a column here is a byte and a program drawing East Asian
text will draw it wrongly.

**That note was half right, and the half it got wrong is the one that
mattered.** It is true that no property of a character can say how wide it is
on a screen — a proportional font makes every such number meaningless. It is
false that this leaves nothing to answer. UAX #11 assigns East_Asian_Width to
every code point *precisely so that a fixed-pitch device can lay text out*,
and a program with a terminal in front of it has no other way to reach that
assignment. Declining to provide it did not make the editor's problem go away;
it moved it into the editor, where it would have been solved with a private
table.

## Decision

**AP 6.4.15.13 defines display width**, in the standard's own terms: the value
is divided into elements, an element's width is its first code point's, and a
code point is two cells where its East_Asian_Width is Wide or Fullwidth, none
where its General_Category is Mn, Me, Cf or Cc, and one otherwise. NOTE 14 is
amended to point at it rather than to disclaim it.

Three things about that definition are decisions rather than transcription,
and each is a NOTE:

- **The unit is the element**, so the number counts things a person sees.
- **An element's width is its first code point's** and not the sum of its code
  points', because the sum makes an emoji joined out of three people six cells
  wide where a device that renders the sequence at all gives it one glyph.
- **Ambiguous is one**, recorded in `doc/implementation-defined.md`. UAX #11
  leaves it to the context and this language consults no locale (ADR-0189), so
  there is no context to read.

**`PasUnicode.Columns` answers it**, over a `pas_u_width` table generated from
`EastAsianWidth.txt` beside the two the module already had. It reports -1 for
bytes that are not a text value — the one place this boundary reports a
failure rather than an end, because a column count is a number a caller does
arithmetic with, and a plausible answer for bytes that are not a text value
would put the wrongness somewhere else.

**The editor's model keeps counting bytes, and that is the load-bearing
half.** `ed.col` is a byte index, every edit is at a byte, and the status line
shows a byte — because `pascalc` reports a diagnostic's column in bytes, so
Ctrl-B landing on an error means landing on a byte. What changed is that the
byte is converted to a column in exactly one place, where the cursor is handed
to the terminal.

**Four things move by element instead of by byte**: the two arrows, Backspace,
Delete, and — the one found by writing the session rather than by design —
`Clamp`, which is where moving *between* lines can leave the cursor inside a
character, since it keeps the byte and the new line is not the old one.

**A cell holds an element**, so `CellMax` goes from 8 to 16, and an element
longer than that is cut to **whole scalars** with any trailing scalar of zero
width given back. A cut inside a UTF-8 sequence would put bytes on the
terminal that are not a character; a trailing joiner would reach into the cell
beside it.

## Consequences

**Fifteen of the sixteen session goldens are unchanged**, which is the
strongest evidence available that this is not a rewrite: they are ASCII, where
an element, a byte and a column are the same thing, and every one of them still
draws what it drew. `wide_text.keys` is the sixteenth and is the one that can
tell the three apart.

**`tests/spec/` can import a library module now.** Until this clause there was
none whose only reach into the language was through one, so the harness passed
no search path and `import PasUnicode` could not resolve. What was added is
where to *look* (ADR-0244's mechanism); a scenario that imports nothing is
compiled exactly as before.

**A dead transcription was written and removed, and the check that found it
stayed.** `EastAsianWidth.txt`'s header says the unassigned code points of five
blocks default to W; the generator transcribed that, and a mutation removing it
produced a byte-identical header, because 17.0.0 lists every one of them as
`<reserved-…> ; W`. It is an **assertion** now instead of a table: if a release
stops listing them the rows will make them N and the generator will say so.
A transcription nothing depends on is dead code that reads like a fact.

**There is no conformance file for East_Asian_Width.** Normalisation and
segmentation are each settled by an oracle Unicode publishes and nobody here
wrote (ADR-0189, NOTE 17); this property is not, so what stands behind the
table is the transcription being simple, the assertion above, and seven
answers in `tests/dialect/lib_unicode.pas`. That is a `doc/sop.md` §7 row and
is the largest thing this increment does not close.

**It is not a bidirectional or a shaping model.** Arabic and Devanagari are
laid out by rules no per-code-point property expresses, and a terminal that
shapes them will not put the cursor where this arithmetic says. What is
claimed is the fixed-pitch cell count, which is what the clause says and no
more.

**No horizontal scrolling still.** A line wider than the window is cut, and it
is cut by column now rather than by byte — a wide element that would hang over
the right edge is dropped rather than half-drawn, because a terminal handed
the first half of a wide character does not draw half of it.

## Alternatives rejected

**Keep the width table in the editor.** It is a property of the Unicode
Character Database, the runtime already carries that database's tables, and a
second copy in `tui/` would be one no gate compares against the first. The
editor is the first caller and will not be the last.

**Make `ed.col` a display column, or carry both.** Both were considered and
the compiler settles it: `pascalc` reports a diagnostic's column in bytes, so
an editor that stores columns has to convert on every landing, and one that
stores both has two things to keep in agreement — which is the shape ADR-0388
removed from this program when the shell kept a `path` beside the model's
name.

**Sum an element's code points' widths.** It is the obvious reading and it is
wrong on the case that motivated a per-element unit at all: six cells for one
glyph.

**Provide a locale so Ambiguous can be two.** ADR-0189 declined a locale for
case mapping and the argument is the same one. A program that knows its
terminal is configured for East Asian text knows something this language
cannot be told.
