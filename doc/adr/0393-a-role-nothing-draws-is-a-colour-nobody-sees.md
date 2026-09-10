# ADR-0393: A role nothing draws is a colour nobody sees

## Status

Accepted. The first oracle over `tui/`'s colour, and the finding that made it
necessary.

## Context

ADR-0389 put a **role** on every cell and a colour nowhere near the model: a
session golden holds the role plane, one letter per cell, and the shell turns
a role into an escape sequence. That split is what lets a golden hold what the
editor decided without holding what a terminal made of it, and it is right.

What it leaves uncovered is everything a person sees first. Two defects were
sitting in that gap, and neither could have been found by any oracle here.

**The first is a role that had stopped being drawn.** ADR-0392 turned the
Find, Go to line and Save as prompts from a bottom line into a framed box, and
the box drew its contents in its own role — so `crPrompt`, which is *the
editor is waiting for you*, was declared in the enumeration, mapped to a
colour in `RoleColour`, given the letter `p` by `tui/session.pas`, and drawn
on **no screen at all**. Every golden agreed, because a golden holds what was
drawn. The role plane of all fifteen sessions contained no `p`, and fifteen
green sessions said nothing about it.

**The second is that two of the eight pairings were not legible.** `PasTerm`
offers the eight ANSI colours and `clDefault` and no bright ones, and what a
terminal makes of the eight is its own business. `crFrame` was cyan on blue,
which is 4.8:1 against xterm's own palette and visibly worse against a muted
theme — and it is the whole body of a drop-down, so the menu was the least
readable thing on the screen. `crMessage` was yellow on `clDefault`, which is
not a low ratio but *no ratio*: on a light terminal it is yellow on white.

Both were reported by a person looking at the screen, which is the oracle this
project had for the editor's colour and the one it should not rely on.

## Decision

**Every role but `crText` pairs black or white with a colour, never a colour
with a colour, and never `clDefault`.**

That is the rule, and the ratio is the evidence for it rather than the rule
itself: a terminal's eight are whatever its theme says, so the structural
property — one side of the pair is an extreme — is what survives a palette
nobody here chose. The floor is WCAG AAA's **7:1** for body text; against
xterm's own eight the worst pairing in the table clears it at 7.5:1.

`crText` is the exception and must be. The document is the terminal's own text
in the terminal's own colours; painting it would be this editor overriding a
choice the person made.

**A dialog's answer is a field, in `crPrompt`, filled to the width of the
box.** That restores the dropped role, and it is the right drawing anyway: an
input with edges a person can see when it is empty is what every editor of
this shape drew.

**`tui/palette.py` is the gate**, run as `tui-palette`, and it holds two
claims in both directions:

- every `CellRole` is drawn by some session and every role letter a golden
  holds is a `CellRole` — which is the claim that fails today without the
  field, and failed on the tree as it stood;
- every pairing is an extreme against a colour, is not `clDefault`, and clears
  the floor.

It reads the enumeration from `tui/apedit.pas`, the letters from
`tui/session.pas` and the pairs from `tui/apide.pas`, so a role added to one
and not the others fails before either claim is reached.

## Consequences

**The shell's colour is now checked, which it was not.** `doc/sop.md` §7's row
said the shell that turns roles into sequences is reached by no oracle; that
is still true of the *sequences*, and is no longer true of the table they come
from. The row is narrowed rather than struck.

**`crMessage` and `crPrompt` are the same colour and that is deliberate.**
ADR-0389 asked that a message and a question not look alike; since ADR-0392
they cannot be on the screen together — a message is the row above the status
line and a question is a box in the middle — so what tells them apart is the
model, which is what ADR-0389 wanted. The gate does not require distinctness,
because requiring it of roles that are never co-visible would be a rule with
no reader.

**The floor is a floor and not a target.** A role added later has six pairings
to choose from that clear it; one that wants a mid-tone has to argue for it
here rather than in a commit message.

**It does not check what the shell emits.** `PutRow` could write every run in
one colour and this gate would pass — that claim is held under a pty, by hand,
and stays a §7 row. Nor does it know what a *user's* terminal does with the
eight; it knows what xterm does, and says so.

## Alternatives rejected

**Hold the colours in a golden.** A session would print the escape sequences
and a diff would compare them. That makes the model's own goldens depend on
the shell, which ADR-0389 separated on purpose, and it would have caught the
unreadable pair only by somebody reading escape codes.

**Check the ratio and not the structure.** Ratios against xterm's palette are
a fact about xterm. A rule that admits `clCyan` on `clBlue` at 7.1:1 on one
palette and 3:1 on another is a rule that passes where it matters least, which
is why the extreme-against-colour test is the rule and the ratio is the
evidence.

**Delete `crPrompt`.** It was drawn by nothing, so removing it would have made
every claim true and the editor no better. The role was right and the drawing
was missing.

**Lower the floor to AA (4.5:1) to admit more pairings.** Nothing needed one.
A floor raised later is a floor that catches nothing in between.
