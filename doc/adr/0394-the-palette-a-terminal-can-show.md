# ADR-0394: The palette a terminal can show

## Status

Accepted. Extends ADR-0393, which set the rule this is measured against, and
adds twenty-four-bit colour to `PasTerm`.

## Context

ADR-0393 raised the editor's contrast and built `tui-palette` to hold it. Then
a specific scheme was asked for — *LUXE*, a published ten-colour palette of
beiges, two blues and a vermilion accent — and two things stood in the way,
one of them a defect ADR-0393 had just shipped.

**`PasTerm` had eight colours.** It says so deliberately: *eight and not 256,
and no bold, italic or underline*, on the grounds that a small palette every
terminal has had since the 1970s is what tells one region of a screen from
another, and that a wider one is a caller's `writestr` away. That argument was
right for the editor's chrome and it is not an argument against a program
naming a colour it means.

**Five of the ten cannot carry text.** The scheme's middle — rose, khaki,
slate, blue, and the vermilion accent — sits at luminances that reach 6.7:1
against the darkest colour in the scheme and 4.9:1 for the accent. Every cell
this editor draws is text, so a colour that cannot be read on is a colour it
has no place for.

**And ADR-0393 had made a menu unusable while making it legible.** It moved
`crChosen` to black on white, which is 16.7:1 to read — and the menu bar is
black on cyan, whose background is 1.6:1 away from white. The selected title
was perfectly readable and indistinguishable from the four beside it, so
nothing on the screen said which menu was open. That is a defect a contrast
floor cannot see, because both pairs pass it.

## Decision

**`PasTerm` gains `SetRgb` and an `Octet` subrange**, `SetColour`'s question
in twenty-four bits: SGR's `38;2;r;g;b` direct form, one call for one region
for `SetColour`'s own reason. `SeqMax` goes from 24 to 48, that sequence being
36 characters at its longest and every other one in the module a handful.

There is no `clDefault` in it and there cannot be — the terminal's own colour
has no numeric value to name — which is not a gap: a program drawing a
*document* should leave the person's own colours alone, and `SetColour` is how
it says so.

**Whether a terminal understands the form is the caller's policy**, not this
module's. There is no query a terminal without the direct form answers safely,
so what exists is `COLORTERM`, which an emulator sets to `truecolor` or
`24bit` when it means it. `apide` reads it once at start and keeps **two
tables**: `RoleColour` for the eight, `RoleRgb` for the twenty-four.

**Both tables hold the same eight roles and both are gated.** A fallback
nobody looks at is exactly where an unreadable pair survives.

**Five of the ten colours are used, and that is the finding.** Numbers 1, 4,
7, 8 and 9 — two darks to reverse out of and three lights to separate the bars
— which is what a screen of chrome wants. The worst pairing in the table is
10.9:1. Saying which half of a scheme a text screen can use is more useful
than using all of it badly.

**`tui-palette` gains two claims.** The twenty-four-bit table is held to the
same 7:1 floor. And **two regions a person sees at once must differ in their
backgrounds by 3:1**, WCAG's non-text threshold, in both tables — which is the
claim that catches the menu defect above, and does catch it: reinstating it
fails the gate naming `crMenu` and `crChosen` at 1.6:1.

The co-visible set is written as **pairs and not as sets**, and that is
measured rather than tidy. The three bars along the bottom are adjacent as
(message, status, hint), with the status between the other two — and with
black or white required on one side of every pairing, **no three of the eight
ANSI colours are mutually 3:1 apart**. A rule demanding it would be one the
palette cannot satisfy, so what is required is what a person actually compares:
each bar against the bar touching it.

## Consequences

**The ANSI table changed as well**, and not only for the menu defect. Once
backgrounds have to differ, the three bottom bars have to be chosen together:
the status line moved to white on blue so that the message above it (black on
yellow) and the hints below it (black on white) are each 3:1 clear of it. The
drop-down is now the bar's own cyan, which is Turbo Pascal's scheme and is why
a panel has a border — with `crChosen` on blue, 4.7:1 clear of both.

**A terminal that lies about `COLORTERM` gets a scheme it cannot render.**
Nothing here can detect that. The cost is bounded by the variable being set by
the emulator rather than guessed at, and the fallback being a table this gate
holds to the same floor.

**`apide` imports `PasEnv`**, its first reason to read the environment.

**The document is never painted in either table.** `crText` has no arm in
`RoleRgb` and `PutRow` routes it through `SetColour` whatever the terminal can
do. That is the one place where having no `clDefault` in the direct form is
load-bearing rather than a limitation.

**It does not make the palette configurable.** A scheme in a file is a
different feature, with a parser, a search path and a way to be wrong; this is
two tables in the shell, which is where ADR-0389 put the colour.

**Nor does it use the accent.** #E05143 reaches 4.9:1 against the darkest
colour in the scheme, and there is nothing on this screen that is not text.
A construct that is not text — a rule, a shadow, a progress bar — would be the
thing that earns it, and there is none.

## Alternatives rejected

**Detect twenty-four-bit support by querying the terminal.** There is no query
a terminal without the feature answers safely; the ones that exist rely on
reading back a response that a terminal lacking it may not send, leaving a
program blocked or reading a keystroke as an answer. `COLORTERM` is what
emulators actually set.

**Use all ten colours by lowering the floor to AA (4.5:1).** It was offered and
declined: the increment before this one was raising the contrast because the
screen was hard to read, and spending that immediately would make the record
say two opposite things a day apart.

**Use the accent for the frame's border only.** A box character is a rule and
not text, so it carries no legibility claim — but the border and the body of a
panel are one role, and splitting them costs a `CellRole` whose only purpose
is to let one colour in.

**Drop the eight-colour table now that there is a better one.** `COLORTERM` is
absent over plain `ssh` to many hosts, inside `screen` by default, and on the
Linux console, and the editor must be readable there. It is also the table
every other program in this tree would use.

**Put the palette in `PasTerm`.** ADR-0389 put colour in the shell on purpose:
the model says what a cell is *for*. A library of named colours would make a
scheme a property of the terminal module, which is the one place it is not.
