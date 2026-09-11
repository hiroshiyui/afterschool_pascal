# ADR-0402: What the shell emits

## Status

Accepted. Closes the emission half of `doc/sop.md` §7's oldest open row,
promised by [ADR-0389](0389-a-cell-carries-a-role-and-not-a-colour.md) and again by
[ADR-0391](0391-a-screen-is-cells-and-a-panel-is-a-rectangle.md), and narrows the raw-mode row
[ADR-0262](0262-the-terminal-is-the-runtimes-to-remember.md) promised and never wrote.

## Context

`tui/apedit.pas` takes a key as a value and answers a **screen** — a plane of
characters, a plane of roles, the cursor's cell — and `tui/run.py` replays a
script and compares that, frame by frame (ADR-0381). Twenty sessions do it
today. ADR-0389 then split a cell's *role* from its colour, so the golden
holds the role and `tui/apide.pas` holds the table, and ADR-0391 had `PutRow`
walk a row, group equal roles and write one `SetColour` per run.

Both records promised a `doc/sop.md` §7 row for the half that left uncovered,
and neither wrote one. ADR-0393 wrote it and closed what could be closed
without a terminal: `tui-palette` reads `RoleColour` and `RoleRgb` out of the
source and holds every pairing to an extreme against a colour and to a 7:1
floor, and holds every declared role to being drawn by *some* session — the
claim that found `crPrompt` coloured, lettered and drawn on no screen at all
for the life of ADR-0392, with every golden agreeing.

What that leaves is stated exactly by a mutation: **make `PutRow` take the
first run's role for the whole row** — ADR-0391's own pre-state, and the thing
its comment in `Draw` still claimed was true — and

```
tui-sessions: 20 session(s) replayed, every screen as recorded
tui-palette:  every pairing legible, every role drawn
```

A shell that paints a framed dialog in one flat colour passes every oracle
this project has. So does one that emits the twenty-four-bit table to a
terminal that never asked for it, and one that writes a colour no table
contains.

## Decision

**Drive the real editor under a pseudo-terminal and read the bytes back.**

**This is not the binding ADR-0262 declined, and the distinction is the whole
argument.** That record refused a pseudo-terminal binding *in this language*,
on the grounds that a case needing one becomes a test of the binding. Nothing
here is in the language: `pty.fork` is Python's, exactly as `lsp/run.py`'s
pipe is Python's, and what is under test is a compiled program's bytes on its
own standard output. ADR-0262's reasoning is untouched and its conclusion
still holds — `tests/dialect/lib_term.pas` still pins only the negative path,
because that is a *case* and this is a harness.

**The expectation is derived and not recorded.** A golden of escape bytes
would agree with whoever wrote it, which is this tree's standing rule and is
precisely how `crPrompt` came to be drawn nowhere. So each script is replayed
twice — once through `tui/session.pas`, which already prints the character
plane, the **run decomposition** and the cursor, and once through `apide`
under a terminal — and the two are required to agree, with `tui/palette.py`'s
own parse of the two tables standing between a role and a colour. The run
decomposition is the part that makes this cheap: the model already writes down
what `PutRow` is supposed to walk, so nothing here re-derives it. Three
independent things have to be wrong together for this to pass.

Three claims, each in both directions:

- **every run the shell writes is a run the model decided**, at the same
  columns, and none the model decided is missing;
- **a run's colour is its role's colour in the table the terminal asked
  for** — every script is driven twice over, with `COLORTERM` set and unset,
  because the fallback nobody looks at is where an unchecked emission
  survives, which is ADR-0394's own argument about the palette applied to the
  code that reads it;
- **the frame is bracketed and the cursor is left where the model put it** —
  hidden before the first row, shown after the last.

**A run's columns and colour are compared one at a time and its text a row at
a time**, because a cell is not a character: a wide cell owns two columns and
a grapheme cluster is several code points (ADR-0395), so a golden row is a
string of *cells* and cannot be sliced by column. Concatenating a row's runs
undoes exactly what `PutRow` did to it.

**A script the harness cannot drive is skipped and a floor stops that from
emptying it.** Twelve of the twenty can be driven; the eight that cannot ask
the *model* for something a person at a terminal cannot ask for — `say` is
the shell's own message line, `fault` is a compiler's output being landed on,
a `push` after a keystroke is a file loading itself halfway through, a `name`
after one is `saveas.keys` renaming a document mid-script, and a `size` after
one is a resize, which the editor would follow on the next frame a *key*
provoked and a resizing script provokes none. Each is a session `run.py`
covers; none is a role this does not reach.

## What holds it

Its own mutations, each producing a working editor:

| Mutation | `tui-sessions` | `tui-palette` | `tui-terminal` |
| --- | --- | --- | --- |
| `PutRow` takes the first run's role for the row (ADR-0391's pre-state) | passes | passes | **fails**, four runs of a dialog |
| the `wide` test is dropped, so RGB goes to every terminal | passes | passes | **fails**, on the eight-colour pass |
| a table arm the shell does not emit from | passes | fails on the ratio | **fails**, the emitted colour against the parsed one |

The second row is the one that could not have been caught any other way: the
eight-colour table is what a plain `ssh`, a `screen` session and the Linux
console get, and nothing here had ever read a byte the editor wrote to one.

## What this does not do

It does not check that a **real terminal** renders these sequences as they are
meant. That is not checkable here at all and stays in §7.

It does not check that a terminal setting `COLORTERM` is telling the truth.
There is no query a terminal lacking the twenty-four-bit form answers safely,
so a terminal that lies gets a scheme it cannot render; the cost is bounded by
the fallback being held to the same floor (ADR-0394).

It does not close the raw-mode row, though it narrows it to three claims from
six. What it reaches it reaches *because the editor cannot work without it*:
a read answering on one keystroke, `TermSize` reading a real window, and the
restore at exit. What it does not: that the flags cleared are exactly the
right ones — an echo left on writes bytes between frames, and this parses
frames — that the settings put back are the settings taken, a window size that
*changes*, and `EnterRaw`'s `errFull` arm, which needs a first `EnterRaw` to
succeed and is reached in neither direction.

It does not compare **every** frame of a driven script against a real
terminal's idea of the screen: it compares what was written, not what a
terminal would have accumulated, so a redraw that painted the right runs in
the wrong *order* is invisible. `Draw` writes rows in order and a row's runs
left to right, which is a property of ten lines rather than a checked claim.

It is `tui/terminal.py` and not `tui/pty.py`, because `import pty` in a file
of that name finds itself. Python says so plainly, which is the difference
between a probe and a guess.
