# ADR-0389: A cell carries a role, and not a colour

## Status

Accepted. The enabling change for a Turbo Pascal-shaped editor, and the record
that declines `ncurses`.

## Context

`PasTerm` gained `Colour`, `SetColour` and `clDefault` with ADR-0381, for the
editor. **The editor cannot express any of it.** `Screen` is

    ScreenRow = string(ColsMax);
    line: array [1..RowsMax] of ScreenRow;

which is characters and nothing else, so a library feature was built for a
client that has no way to use it — the shape ADR-0349 warns about from the
other side, and it went unnoticed because nothing fails when a capability is
merely unreachable.

Everything that makes a Turbo Pascal, Turbo C or QuickBASIC screen look like
one — the blue field, a highlighted menu bar, a hint line, a framed dialog,
selected text — is colour before it is anything else. So this is the step that
blocks the rest.

## Decision

**A cell carries a `CellRole` and not a colour.** The model says what a cell
*is for* — document text, the status line, the hint bar, an open prompt — and
the shell maps a role to a foreground and a background.

Three things follow, and each is why it is roles rather than colours:

- **`ApEdit` still imports no `PasTerm`.** The model touches no descriptor and
  now names no terminal capability either. It was already true that a key
  comes in and a screen comes out; naming `Colour` in the model would have put
  a terminal's vocabulary inside the part that has no terminal in it.
- **A golden stays readable.** A session prints the role plane as one letter
  per cell, so what a reader diffs is `sssssss` under the status line rather
  than a row of SGR numbers. A colour plane would have been a golden nobody
  reads, which is the defect `tests/dialect/lib_term.pas` already solved once
  by rendering control bytes as ordinals.
- **A theme is the shell's.** Changing what colour the status line is touches
  neither the model nor a single golden, because no golden asserts a colour.
  A palette is a preference and a role is a fact.

**And the bottom row is a hint bar**, which is the first thing the roles buy:
the key bindings were discoverable only by reading `tui/README.md`, which is
not where somebody sits when they are looking at the editor.

## Consequences

**Every golden changes**, and that is argued rather than assumed. Two things
moved: each screen gained a role plane, and the document lost a row to the
hint bar. Both are real changes to what a person sees, so a golden that did
not change would be the defect. Each one was read before it was saved, which
is `tui/README.md`'s standing rule, and the mutation that flattens every role
to `crText` fails the suite.

**The hint bar names the bindings this editor has**, which are control keys.
Turbo Pascal's were function keys, and those need decoder arms (`ESC O P`,
`ESC [ 1 1 ~`, and the several spellings terminals disagree about) — that is
the menu increment's work and not this one's, so the bar says `^S Save` today
and says so honestly.

**What this does not decide.** A *panel* — a stack of overlapping rectangles
composited onto the one screen, which is what a menu, a drop-down, a dialog
and a document window all are — is the next structural step and is not decided
here. It is named because the roles are chosen to serve it, not because it is
settled; a hypothesis filed as a record is ADR-0343's defect and this record
declines to repeat it.

## Alternatives rejected

**Bind `ncurses`, as a submodule of `PasTerm`.** This was asked directly and
the answer is no, for the reason the whole editor exists in this shape:
`ApEdit` answers a *screen as a value*, which is what `tui/run.py` diffs byte
for byte with no terminal anywhere. ncurses owns the screen and the terminal,
so drawing through it makes the drawing no longer a value anything can
compare. Today the unchecked surface is about thirty lines of shell, and it is
a `doc/sop.md` §7 row; binding ncurses would make the unchecked surface the
entire drawing layer *plus* the binding, which is ADR-0262's own argument
against a pseudo-terminal — *a case needing one becomes a test of the binding*
— arriving a third time.

Three costs stand behind that argument. The foreign boundary here is gated —
`WINDOW *`, `chtype`, `attr_t` and varargs like `mvprintw`, each a claim
`foreign-width` (ADR-0364) and ADR-0376 require somebody to hold. The editor
would stop building for `wasm32-wasi`, a target admitted one increment ago,
because ncurses does not. And Turbo Pascal did not use anything of the kind:
its CRT unit wrote to screen memory, and `PasTerm` already has raw mode,
cursor positioning, the alternate screen and SGR.

What ncurses would genuinely buy is terminfo capability lookup, diff-based
screen update, and a key database for function and Alt keys across terminals.
**Only the third is a real gap**, and it is a table of escape sequences rather
than a library. If a full redraw ever costs too much, the diff belongs here:
compare the last screen with the new one and emit the changed cells, which is
what ncurses' optimisation does, and whose output is a string a golden can
hold.

**Put colours in the model instead of roles.** Fewer indirections, and it
makes the palette part of the goldens — so a decision about how the status
line looks would be a change to thirteen recorded screens, and the model would
name a terminal's vocabulary.

**A separate attribute type in the model, mapped to `PasTerm.Colour` by the
shell.** This is what roles are; naming them `Colour` in the model and mapping
colour to colour would have been the same indirection stating the same fact
twice, which ADR-0388 has just finished removing from this program.
