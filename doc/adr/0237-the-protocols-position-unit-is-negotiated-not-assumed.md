# 237. The protocol's position unit is negotiated, not assumed

Date: 2026-08-29

## Status

Accepted, 2026-08-29.

It supersedes nothing. It closes the hazard
[`doc/roadmap.md`](../roadmap.md) named as *the sharpest edge in the
language-server idea* before any of that program was written, and it is the
first externally specified test of the choice
[ADR-0199](0199-the-cost-is-made-visible-by-not-offering-the-index.md) made.

## Context

An LSP `Position.character` counts **UTF-16 code units**. That is the
protocol's default and what a client that says nothing means; 3.17 added
`general.positionEncodings`, through which a client may offer `utf-8` or
`utf-32` and a server picks one, and it is an offer rather than a guarantee.

`ErrorAt` counts **bytes**. That was measured rather than assumed —
`writeln('héllo'); zz := 1` puts `zz` at column 22, two past where a
character count would — and it is the right thing for a compiler whose
`char` is a byte.

So `PasLspDiag` shipped emitting a byte offset into a field that counts
something else, correct for every line holding nothing above U+007F and wrong
for the rest. It was landed that way deliberately and its own header said so.

**The roadmap's estimate was that the conversion could not be written.** AP
6.4.15 refuses an integer index into a text and always will (ADR-0199, for
Swift's reason); `PasUnicode` answers in *scalar values*, which is a third unit
again; so the chapter concluded that the protocol's unit is one nothing in the
text model answers in.

That is half true, and the half that is false is the useful one. The index is
refused; the **count** never needed an index. A scalar below U+10000 occupies
one UTF-16 code unit and one at or above it occupies a surrogate pair, which is
two — so the number the protocol wants is a walk over the scalars of a line,
and `PasUnicode.NextScalar` is exactly that walk. It was exported so a program
could see what the language will not — a family emoji is one element and five
scalar values — and it answers this without being changed.

## Decision

**`PasLspDiag.Utf16Column(line, col)`** converts the compiler's 1-based byte
column on a line to a 1-based UTF-16 code-unit column. Both sides stay 1-based:
it converts the *unit* and nothing else, so `DiagJson` remains the only place
the 0-based subtraction happens — which was the module's rule already and is
worth more than saving a line.

Three inputs are counted as one unit per byte, and all three are one decision —
**when the answer is not knowable, hand back what the compiler said**:

- a column past the end of the line, which is what a caller with no line to
  give produces by passing the empty string;
- a column that falls *inside* a scalar, since the compiler pointed at a byte
  and there is no code unit at that position to name;
- bytes that are not well-formed UTF-8, which a source file may hold and which
  the compiler read as bytes.

**`DiagJson` takes the line and the encoding.** The line, because the
conversion needs it and a `Diagnostic` cannot carry it — the compiler reports a
position and not a source, and putting the line in the record would make every
caller that does not convert pay for one. The encoding, because of the
following.

**The server negotiates rather than converting unconditionally.** It reads
`capabilities.general.positionEncodings`, takes `utf-8` when it is offered,
falls back to `utf-16`, and echoes the answer in `positionEncoding` so the
client is never guessing. This is the part the plan had not seen, and it is not
a refinement: under `utf-8` the compiler's own column *is* the protocol's, so a
server that converted anyway would be introducing the error it was written to
remove.

## Consequences

- **The text model came through its first external test unchanged.** No
  language change, no runtime change, no new Unicode table — the conversion is
  eleven lines over a routine that already existed. The refusal of an integer
  index cost this nothing, which is a real answer to the one part of AP 6.4.15
  that was argued for rather than measured.
- **`lsp/sessions/positions_utf16` and `positions_utf8` differ in one offer and
  one number.** The same document, the same two diagnostics, `character` 20
  against 21. A golden pair is the only way to state a negotiation, since
  neither half alone says the other is wrong.
- **Every future position-bearing feature inherits this.** A hover range, a
  symbol range and a rename edit all carry `Position`s, and each must go through
  `Utf16Column` under the negotiated encoding. That is a rule about the server
  and not about the language, and it belongs in `PasLspDiag` because the
  conversion is already there.
- **The line has to be found, and finding it walks the document.** The server
  holds a document as bytes in a `JsonChars`, so `LineOf` counts newlines from
  the start for every diagnostic. A compilation reports few, so this is paid
  where it does not matter — but it is O(document x diagnostics) and would be
  the wrong shape for a feature that reported many.
- **A path is still taken up to the first colon**, which `PasLspDiag`'s header
  already records. Unchanged here.

## Alternatives considered

- **Convert unconditionally to UTF-16.** Simpler, and wrong for every client
  that offers `utf-8` — which is most of them in practice. It would make the
  server correct for a client that says nothing and incorrect for one that says
  something, which is the wrong way round.
- **Put the line in `Diagnostic`.** It would make `DiagJson` a one-parameter
  routine again, at the cost of a 4096-character field on a record whose whole
  job is to hold what the compiler said, and of a `DiagParse` that would have to
  be given the source it is not reading.
- **Count in the text model instead.** `ToText` and `length` answer in extended
  grapheme clusters, which is a *fourth* unit and further from the protocol's
  than the scalar view is. AP 6.4.15's element is the right unit for a program
  and the wrong one for a wire format, and this is the case that shows the
  difference is real rather than academic.
- **Support `utf-32` as well.** Nothing here counts in it and no client this
  was tested against offers it. The fallback covers it: a client offering only
  `utf-32` gets `utf-16`, which the specification permits.
