# ADR-0397: The window moves sideways too

## Status

Accepted. `top`'s rule on the other axis, and the last of the milestone-one
exclusions that ADR-0395 made cheap.

## Context

A line wider than the window was **cut**, and the cursor stopped at the last
column while the status line went on counting in the document.
`sessions/wide.keys` recorded that as a limitation and argued for it: the
disagreement between the two is the limitation showing itself, and is better
than a cursor that vanishes.

It was the right call for milestone one and it stopped being so twice over.
Once because the editor now opens the compiler's own sources, which have lines
past eighty columns. And once because ADR-0395 built the machinery: `PutLine`
already walks a line an element at a time and places each at a computed
column, so scrolling is a change to *where* a cell is put and not to how a
line is read.

## Decision

**`left` joins `top` in the document**, and for the same reason `top` is
there: where the window sits is a property of the last drawing, not of the
document, which is why `EditRender` takes the editor by `var`. It follows the
cursor's **column**, not its byte — a line of Japanese scrolls by what a
person sees.

**A wide element straddling the left edge is dropped rather than half-drawn**,
which is the right edge's rule one line earlier: a terminal handed the second
column of a wide character does not draw the right half of it, and the blank
that leaves is what reads as *there is more over there*.

**The `~` filler stays at column one** however far the window has scrolled. It
says *past the end of the document* and is not text at a column, so scrolling
it away would make a scrolled window look like a longer document.

## Consequences

**`sessions/wide.keys` changed from asserting a limitation to asserting a
feature**, which is the honest shape: the session that recorded why something
was missing is the one that must change when it arrives, or the tree keeps a
golden proving a thing that is no longer true.

**One `left` for the document and not one per line.** Every line scrolls
together, which is what every editor of this shape does and what makes a
column of text read as a column.

**Nothing scrolls horizontally but the document.** The status line, the hint
bar and the message are cut at the window as they were; they are chrome and
have no column to be at.

**There is no horizontal scroll *bar* and no way to scroll without moving the
cursor.** The window follows the cursor and nothing else moves it, which is
the whole mechanism and is why it needed no new key.

## Alternatives rejected

**Scroll by byte.** It is one subtraction cheaper and it puts the window
inside a character, which draws half of one — the exact defect ADR-0395 was
about, reintroduced on the other axis.

**Keep the cursor pinned and scroll in jumps of half a window.** Common in
editors of this age and it makes the cursor's position on screen unpredictable
from the keystroke. Following the cursor by one column is what a session
golden can hold frame by frame.

**Draw the visible half of a straddling wide character.** There is no such
thing to draw: the terminal advances two columns for the character or none.
