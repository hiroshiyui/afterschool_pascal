# ADR-0391: A screen is cells, and a panel is a rectangle

## Status

Accepted. Answers the question ADR-0389 named and deliberately left open.

## Context

ADR-0389 said a **panel** — a stack of overlapping rectangles composited onto
the one screen, which is what a menu, a drop-down, a dialog and a document
window all are — is the next structural step, and declined to decide it
without a case. The case is a menu bar, which is the single most recognisable
thing about a Turbo Pascal, Turbo C or QuickBASIC screen.

Drawing one in real box characters ran straight into a fact about this
language: **a column is a byte.** AP 6.4.15 NOTE 14 puts display width outside
it, and `┌` is three bytes and one display column — so `ScreenRow =
string(400)` indexed by byte could not hold a frame *and* keep `role[r][c]`
naming the cell a person sees.

## Decision

**A screen is one array element per display column, and a cell holds the
bytes of that column.** `ScreenCell = string(8)`; `Screen.line` becomes
`Screen.cell`. That is what a terminal is, and it is the only shape in which
compositing a panel is an assignment rather than a byte splice.

**A wide cell is defined now although nothing produces one yet**: the
character lives in its left cell and the right cell holds the *null string*,
meaning continuation. `PutRow` concatenates cells and so emits nothing there,
which is correct — the terminal has already advanced past it. Fixing the
convention now is what stops East Asian text reshaping the type later.

**A panel is a rectangle and a drawing order — there is no stack.** At most
one panel is open at a time: choosing an item closes the menu before anything
else opens. A z-order with one member orders nothing, so `EditRender` draws
the base and then whichever panel is open, in three lines. ADR-0343 calls the
general thing built without a second case a hypothesis, and this declines to
file one. **The case that will force a stack is a dialog opened from a
drop-down**, and it will arrive with its own session.

**An item names a `Key`**, and choosing it sends that key down the path a
typed key goes down — the shell's three become a request it takes, everything
else the model applies itself. A menu is a second *spelling* of a binding and
not a second dispatch, exactly as a bound function key is decoded as the key
it is bound to (ADR-0390's sibling reasoning, one layer up).

## Consequences

**The run split moved into the model, and that closes a blind spot rather
than widening one.** `PutRow` painted a row with `role[r][1]`, which is right
only while every row is one colour — false the moment a panel overlaps a
document row. The obvious fix is to walk the role plane in the shell, and it
would have been **unverifiable**: `tui/run.py` links `apide.pas` and never
runs it, so a shell that ignored the split would pass the whole suite. So
`RowRuns`/`RowRun` are the model's, a session holds them, and `doc/sop.md`
§7's row is struck. `EditFault`'s rule — *where the cursor goes when a
compiler complains is a decision* — met a third time.

**The mutation is what found the two things a reading did not.** Collapsing
`RowRuns` to one run per row passed all fourteen goldens *before* the menu
existed, because every row then was one run: the assertion recorded the split
without distinguishing a wrong one. And making `Frame` skip clearing its
interior also passed, because every caption had been written to the same
width and covered the panel exactly — so the clearing that makes a panel
opaque was dead code, true by accident and silently false the day a caption
got shorter. Captions now have their natural widths, the Search menu has
three different ones, and both mutations fail.

**`EditPrompting` became `EditModal`.** Its body — `mode <> mdEdit` — stayed
exactly right, and its name stopped being: a menu owns the keyboard as
completely as a prompt does. ADR-0388 removed a second copy of one fact from
this same program; this is the same lesson about a *name* rather than a value.

**`EditTakeSave` became `EditTakeCommand`** and answers a `Key`. One request
channel, so `File ▸ Save` and Ctrl-S and an answered `Save as:` prompt are one
path with one place to get wrong.

**The document lost a row**, the bar being permanent as it was in every editor
of this shape. `scroll.keys` was given a row back rather than regenerated: its
own comment claims the `~` filler distinguishes a short document from a blank
one, and at two rows it no longer showed one. **A golden whose session stops
testing what it says it tests is worse than one that fails.**

**F10 stopped being unbound**, which `funckeys.keys` now records as the
transition it is.

**What this does not do.** No display width — the language still does not
provide it and this claims nothing about it; East Asian text draws as wrongly
as before, which is a later increment with its own record. No dialogs yet: the
prompts are still a line. No panel stack, no second file, no mouse, and no
scrolling a drop-down taller than the screen.

## Alternatives rejected

**Keep the byte row and add a per-column offset plane.** Cheaper in memory
(+320 KB against +640 KB) and it preserves the convention that nothing here
assigns into a string by index. It loses on the one operation the increment
exists for: overlaying a rectangle becomes a byte splice plus a rebuild of the
offset plane, per row, per frame.

**ASCII frames, and no cell model at all.** Half the work and it looks like a
DOS text screen, which is most of the way there. Rejected because the cell
model is owed anyway — it is what East Asian text needs — and doing it now
means the frame characters are a constant to change rather than a shape to
redesign.

**A general panel stack with a z-order.** The architecture ADR-0389 gestured
at, and it decides the shape of a thing with one user. See ADR-0343.
