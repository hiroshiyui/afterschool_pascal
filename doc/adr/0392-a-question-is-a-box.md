# ADR-0392: A question is a box

## Status

Accepted. The second user of ADR-0391's primitives, and the invariant that
keeps its central decision true.

## Context

ADR-0391 built two drawing primitives and gave them **one** user, the menu's
drop-down, and said so in its own consequences: *no dialogs yet; the prompts
are still a line.* One user can always be special-cased. Two is the test of
whether an abstraction is one.

The prompts were also the last chrome drawn as a bottom line, so a person
searching saw a box for a menu and a line for a question, which is a
difference that says nothing.

## Decision

**`Find`, `Go to line` and `Save as` are centred framed boxes**, three rows
deep, titled in the top edge, with the answer inside and the cursor in it.
`EditMode` is unchanged: what changed is how three modes *draw*, which is the
whole point — the state was already right, and ADR-0387 put it in the model so
that a golden could hold it.

**A dialog is drawn after the document and before the menu bar, and there is
deliberately no way to open a menu over one.** That ordering is what keeps
ADR-0391's *there is no panel stack* true rather than lucky: two panels can
never be open at once because the only route into a dialog closes the menu
first, and the only route into a menu is a key the dialog's own mode does not
pass on. The invariant is stated here so that whoever adds a third panel finds
out from a record that it is load-bearing, rather than from a screen.

## Consequences

**The abstraction held.** `Frame` and `PutAt` took the second user with no
change — the dialog is one `Frame` call, one `PutAt` and a cursor. That is the
evidence ADR-0391 could not produce for itself.

**The message line went back to being a message.** It had been doing two jobs,
and the older test for which was `mode <> mdEdit` — right while every mode was
a prompt, and wrong the moment `mdMenu` existed, which is what made a menu
report `Line:` on the message row for a few minutes. One state, one job.

**Four goldens changed and eleven did not**, which is the blast radius a
one-idea increment should have: `find`, `goto`, `saveas`, and `funckeys`
because F2 opens `Save as` on an unnamed document.

**Both mutations fail**: skipping the `Frame` call, and leaving the cursor on
the old bottom line. Each kills all four.

**What it does not do.** No buttons, no more than one field, no tab order, no
Replace — every one of which needs a second focusable thing inside the box,
which is the next abstraction and not this one. No resizing to the answer, and
no history of previous answers.

## Alternatives rejected

**Leave the prompts as a line.** It works, it is what shipped, and it costs
nothing. Rejected because it leaves the primitives with one user, and because
a program that draws a box for a menu and a line for a question is telling a
person the two are different kinds of thing when they are not.

**Give the dialog its own mode.** `mdFind`, `mdGoto` and `mdSaveAs` already
say everything a dialog needs; a `mdDialog` beside them would be a second
place to keep the same fact, which ADR-0388 removed from this program once
already.
