# The editor

A text-mode editor in Turbo Pascal's mould, written in this dialect
([ADR-0381](../doc/adr/0381-the-ide-is-un-withdrawn.md)). It is the second
program here written to be *used* rather than to be tested, after the language
server — and it is the first whose whole shape is a screen.

**Milestone one is: open, edit, save, compile, land on the error.** What is
here now is the half that decides things.

**Milestone two is undo, find and go-to-line**
([ADR-0387](../doc/adr/0387-an-undo-is-a-journal-and-a-prompt-is-a-mode.md)),
and each of the three turned out to be a design question rather than a
feature: what an edit *is* — one of four operations, held in a journal that
can reverse it — and who owns the keyboard while the editor is asking
something, which is the model and not the shell.

## What is in it

| File | What it is |
| --- | --- |
| `apedit.pas` | the editor, with no terminal in it: a key comes in as a value and a **screen** comes out — rows by columns of characters, with the cursor's cell |
| `apide.pas` | the shell a person runs: `PasTerm.ReadKey` in front of that model and `CursorTo` behind it, plus the file and the compiler |
| `session.pas` | a program that replays a script against it and prints what it drew |
| `session.components` | ISO/IEC 10206:1991 §6.13's other program-components, one path per line, in dependency order |
| `build.py` | builds either program from its sidecar; `lsp/build.py` with the program as an argument, since `tui/` has two over one model |
| `run.py` | replays every session and compares the screens |
| `palette.py` | the two claims about colour a golden cannot hold: every role is drawn by some session, and every pairing is legible (ADR-0393) |
| `sessions/*.keys` | a script, one directive per line |
| `sessions/*.screen` | what it drew, exactly — the characters, then the **roles**, one letter per cell |

## Colour

A cell carries a **role** and not a colour (ADR-0389), so a golden holds the
role plane — one letter per cell — and the shell is what turns a role into an
escape sequence. That split is what makes the drawing a value anything can
diff, and it leaves the whole of what a person notices first held by nothing.

`palette.py` closes the half that can be closed (ADR-0393). **Every role but
`crText` pairs black or white with a colour** — never a colour with a colour,
never `clDefault` — and the floor over the table is WCAG AAA's 7:1, which against
xterm's own eight every pairing clears at 7.5:1 or better. The rule is the structural one and the ratio is its evidence: what a
terminal makes of the eight ANSI colours is its own business, so a pair that
measures well on one theme can flatten on another, and only *one side is an
extreme* survives that. `crText` is exempt and has to be — the document is the
terminal's own text in the terminal's own colours, and painting it would be
this editor overriding a choice the person made.

**There are two tables and the terminal picks** (ADR-0394). A terminal that
sets `COLORTERM` to `truecolor` or `24bit` understands SGR's direct
twenty-four-bit form and gets five colours of the *LUXE* scheme — `#DDC5B9`,
`#F5F5F4`, `#E1D6D2`, `#142E85` and `#070B2F`; every other terminal gets the
eight ANSI colours, which is what a plain `ssh`, a `screen` session and the
Linux console have. Both tables are held to the same floor, because a fallback
nobody looks at is exactly where an unreadable pair survives. **Five of the
scheme's ten and not all of them**: its rose, khaki, slate, blue and vermilion
reach 6.7:1 at best against anything else in it, and every cell here is text.

**Legible is not the same as distinguishable**, and this project shipped the
proof. ADR-0393 moved the selected menu title to black on white — 16.7:1 to
read — against a black-on-cyan bar, whose background is 1.6:1 away from white,
so nothing said which menu was open. The gate now also requires two regions
seen at once to differ in their **backgrounds** by 3:1, which is written as
*pairs* and not as sets: with an extreme on one side of every pairing, no
three of the eight ANSI colours are mutually 3:1 apart, so what it asks is
what a person actually compares — each bar against the bar touching it.

Its other claim is that **every role is drawn by some session**, which is not
a tidiness rule. `crPrompt` — the role meaning *the editor is waiting for
you* — was declared, coloured, given a letter and drawn on no screen at all
for the life of ADR-0392, because a prompt became a box and the box drew its
contents in its own role. All fifteen goldens agreed, a golden holding what
was drawn.

## Why it can be tested at all

`ctest` has no terminal. `tests/dialect/lib_term.pas` says what that costs —
it can pin the *negative* path of `PasTerm` and nothing else — and ADR-0262
declined a pseudo-terminal binding on the grounds that a case needing one
becomes a test of the binding rather than of the program.

So the terminal is **not in the loop**. `apedit.pas` renders into a buffer,
and what a session compares is that buffer, frame by frame. The shell that
puts it on a real terminal is a few dozen lines and is the only part no
oracle here reaches — which is a row in
[`doc/sop.md` §7](../doc/sop.md), written honestly rather than left implied.

## Writing a session

The directives are documented at the top of `session.pas`, which is also the
program that **refuses** one it does not know: a directive that silently did
nothing would be a session asserting less than it appears to, which is
`tests/spec/`'s rule for the same reason.

```
name  <text>     what the status line calls the document
push  <text>     append a line, as loading a file does
size  <r> <c>    the terminal to draw for
keys  <text>     every character of <text>, as bytes
esc   <text>     ESC [ <text>, so `esc A` is an up arrow
ctrl  <letter>   the control byte for that letter: `ctrl S` is Ctrl-S
draw             render, and print what was drawn
say   <text>     what the shell would have put on the message line
fault <text>     a compiler's output, landed on as Ctrl-B lands on it
```

`ctrl M` is Enter and `ctrl H` is Backspace: those are the two keys a session
presses through their control bytes rather than through a directive of their
own.

A screen is printed inside a border, so that a line ending in blanks and one
that does not are visibly different in the golden — a diff of bare text cannot
show which is which.

To add one: write the `.keys`, run `run.py`, and **read what it drew before
saving it as the golden**. A golden agrees with whatever wrote it; that is the
standing rule everywhere in this tree, and regenerating one is a decision to
argue for in a commit message rather than a step.

## Running it

```sh
cmake --build build -j        # build/bin/apide
build/bin/apide               # a new document, no argument needed
build/bin/apide hello.pas
```

The binary is **`apide`** and so is the source, `apide.pas`. It was
`afterschool` in v3.9.0, on the convention `pascalc` sets over
`selfhost/compiler.pas`; what that cost here is that `build.py` names its
default output after the program it was given, so the script wrote
`build/bin/apide` and the CMake target wrote `build/bin/afterschool` — one
program under two names, with nothing to say which one a document meant. The
script's default is what keeps `build.py '' session.pas` off the editor and
could not move, so the binary did. It is a CMake target and an installed
program because the editor is the one thing here written to be *used*, and
`cmake --install` puts it beside `pascalc`.

`tui/build.py` is still what builds it, and the target drives that script
rather than repeating it: the script reads the `.components` sidecar and
honours `AFTERSCHOOL_PASCAL_OPT`, which ADR-0102 makes load-bearing for a
program whose whole shape is a loop. Every one of its arguments now has a
default, so building by hand is:

```sh
tui/build.py                  # the editor, to build/bin/apide
tui/build.py '' session.pas   # the session replayer
```

| Key | |
| --- | --- |
| F10, Ctrl-O | the menu bar — arrows move, Enter chooses, Ctrl-C closes |
| F3 | open a file into a **second document**, up to eight (ADR-0396) |
| F6 | go to the next open document, wrapping |
| F2, Ctrl-S | save — and on a document with no name, ask for one first |
| F9, Ctrl-B | compile, and land on the first diagnostic — or **report** it, where it names one of the other program-components rather than this file |
| Ctrl-Q | quit — twice when the document has changes in it |
| Ctrl-Z, Ctrl-Y | undo, redo — a typed run is one undo, not one per character |
| Ctrl-F, Ctrl-L | find, find again — case-insensitive, and it wraps and says so |
| Ctrl-G | go to a line by number |
| Ctrl-C | close the question a dialog is asking, or the menu |

The bindings are on the **hint bar** along the bottom now (ADR-0389), so the
table above is a reference rather than the only place they are written down.
| arrows, Home, End | move |
| Enter, Backspace, Delete | the three that change the shape of the document |

**The function keys are decoded and mostly unbound.** F2 and F9 are Save and
Build, in Turbo Pascal's positions, and arrive through either spelling a
terminal uses — `ESC O Q` and `ESC [ 1 2 ~` are the same key. The other ten
are decoded and *reported by number* (`F5 is not bound`) rather than ignored,
because a key that does nothing and a key that was misread look alike to a
person. F3 and F10 are Open and Menu now (ADR-0391, ADR-0396) — that sentence was
written when there was neither a menu to show nor a second document to open
into.

**Some terminals keep F10 for themselves.** GNOME Terminal and Konsole open
their own menu on it; `Ctrl-O` is the same key here, and the terminal's own
setting (*disable menu accelerator*) gives F10 back. A second binding is not a
workaround for a terminal — the decoder is where terminals are accommodated —
so this is a note rather than a feature.

**Ctrl-C and not Escape** closes a prompt, and that is a fact about the
decoder rather than a preference: it is handed one byte at a time, and a bare
Escape and the start of an arrow (`ESC [ A`) are the same byte. Only a timeout
tells them apart, and milestone one decided not to have one.

It refuses to start where its standard input is not a terminal, and says so.

## What the two milestones leave out, on purpose

- ~~**No horizontal scrolling.**~~ Closed by ADR-0397. The window follows the
  cursor sideways as it already did vertically, by **column** rather than by
  byte, and a wide character straddling the left edge is dropped rather than
  half-drawn. `sessions/wide.keys` changed from recording the limitation to
  driving the feature.
- ~~**No display width.**~~ Closed by ADR-0395. AP 6.4.15.13 defines it and
  `PasUnicode.Columns` answers it, so a column here is a **cell**: `日本語` is
  three cells and six columns, the arrows and Backspace move by element, and
  the cursor lands where the character is. `sessions/wide_text.keys` is the
  one session that can tell a byte, an element and a column apart — the other
  fifteen are ASCII, where the three are the same thing.

  What is still true is narrower and is in that record: this is the
  fixed-pitch cell count and not a shaping model, so Arabic and Devanagari
  are laid out by rules no per-code-point property expresses.
- **No resize.** `SIGWINCH` is a signal and a signal has no shape in this
  language; the caller passes the size on every render, so a shell that wants
  to notice asks `PasTerm.TermSize` again.
- **No mouse.**
- **No replace, no search backwards and no regular expressions.** Milestone
  two is a search that finds, and says so when it wraps and when it does not.
- **No prompt to save another document on quitting.** The dirty mark travels
  with each document and Ctrl-Q takes two presses over unsaved work, but the
  second press asks about the one on screen only. ADR-0396 records it.
- **No window list, no split and no tiling.** F6 cycles and the status line
  says which of how many; a list is worth having when eight documents is a
  number people reach.
- **No overwrite confirmation.** `Save as:` writes the name it is given, as
  `>` does and as Ctrl-S on a named document already did (ADR-0388). No
  directory completion and no browsing either.
