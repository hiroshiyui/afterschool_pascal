# The editor

A text-mode editor in Turbo Pascal's mould, written in this dialect
([ADR-0381](../doc/adr/0381-the-ide-is-un-withdrawn.md)). It is the second
program here written to be *used* rather than to be tested, after the language
server — and it is the first whose whole shape is a screen.

**Milestone one is: open, edit, save, compile, land on the error.** What is
here now is the half that decides things.

## What is in it

| File | What it is |
| --- | --- |
| `apedit.pas` | the editor, with no terminal in it: a key comes in as a value and a **screen** comes out — rows by columns of characters, with the cursor's cell |
| `session.pas` | a program that replays a script against it and prints what it drew |
| `session.components` | ISO/IEC 10206:1991 §6.13's other program-components, one path per line, in dependency order |
| `build.py` | builds either program from its sidecar; `lsp/build.py` with the program as an argument, since `tui/` has two over one model |
| `run.py` | replays every session and compares the screens |
| `sessions/*.keys` | a script, one directive per line |
| `sessions/*.screen` | what it drew, exactly |

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
```

A screen is printed inside a border, so that a line ending in blanks and one
that does not are visibly different in the golden — a diff of bare text cannot
show which is which.

To add one: write the `.keys`, run `run.py`, and **read what it drew before
saving it as the golden**. A golden agrees with whatever wrote it; that is the
standing rule everywhere in this tree, and regenerating one is a decision to
argue for in a commit message rather than a step.

## What milestone one leaves out, on purpose

- **No horizontal scrolling.** A line wider than the window is cut and the
  cursor stops at the last column while the status line goes on counting in
  the document. `sessions/wide.keys` is that limitation, written down.
- **No display width.** AP 6.4.15 NOTE 14 puts the number of columns a value
  occupies outside this language, so a column here is a byte. A program
  drawing East Asian text will draw it wrongly.
- **No resize.** `SIGWINCH` is a signal and a signal has no shape in this
  language; the caller passes the size on every render, so a shell that wants
  to notice asks `PasTerm.TermSize` again.
- **No mouse, and no undo.**
