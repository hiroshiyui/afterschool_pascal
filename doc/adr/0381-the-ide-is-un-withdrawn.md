# ADR-0381: The IDE is un-withdrawn, and the reason is a different one

## Status

Accepted. Reopens what `doc/history.md` records as withdrawn on 2026-09-01,
and does not reverse the judgement that withdrew it. `lsp/pasls.pas` stays
exactly what it is.

## Context

A text-mode IDE in Turbo Pascal's mould was proposed in `doc/roadmap.md` from
the day the dialect's tooling chapter was written, carried for six increments
as *later, not struck*, and then **withdrawn by decision** — not deferred, and
not blocked. The record is plain about why:

> what withdrew it is not a discovery but a judgement: **the language server
> is the better tool for what the IDE was wanted for**, it exists, it answers
> eight questions about a document, and it is this project's own development
> tooling over MCP.

That judgement was right and is not disturbed here. The server answers
diagnostics, outline, definition, hover, folding, selection, formatting,
references, rename, completion and code actions; it speaks MCP as well as LSP
from one binary; it is what drives this project's own work. **An IDE would be
a worse tool for that job**, and this record does not claim otherwise.

What the withdrawal *also* recorded is what it gave up:

> The thing the IDE was proposed to buy — a *Pascal-lineage answer key*, so
> that "this was easier in Turbo Pascal" would be a finding rather than a
> matter of taste — was real and is given up.

And it recorded that the prerequisite was already built: ADR-0262 landed
`PasTerm` on 2026-08-30, **two days before** the withdrawal, with raw mode, an
`atexit` restore, cursor addressing, window size and unbuffered key reads.
So the item was withdrawn at the moment its only stated blocker disappeared —
which is not a contradiction, since the blocker was never the reason, but it
means nothing in the way stands today.

## Decision

**The IDE is un-withdrawn, and its reason is stated fresh rather than
inherited.** Two things, and the first is not one the old argument could have
weighed:

- **This is a hobby project, and the IDE is the part its author wants to
  build.** ADR-0109 made the test of a dialect feature *does a program someone
  would actually write today need it* — and the strongest evidence a facility
  is wanted is somebody wanting to write the program. A project that is
  enjoyed is a project that continues; that is a real engineering property of
  a one-person tree and it is not written down anywhere else here.
- **The answer key the withdrawal gave up is still worth having.** A Pascal
  programmer arriving here already knows that IDE. *This was easier in Turbo
  Pascal* becomes a finding rather than a matter of taste, and `doc/roadmap.md`
  names the other Pascals as an authority exactly where one has already
  answered a question this dialect is asking.

**It is not a replacement for the server and must not become one.** The
division is: `pasls` answers questions about a document for a *tool*; the IDE
is a *program somebody uses*. Where they overlap, the IDE asks the compiler's
`--dump-*` flags directly rather than speaking LSP to a second process — the
server's value over the raw dumps is the wire shape, UTF-16 columns and a
per-document cache, and a terminal editor counts columns rather than code
units and holds its own buffer.

**Milestone one is: open, edit, save, compile, land on the error.** No
debugger, no mouse, no `SIGWINCH` (this language has no signal facility at
all — the redraw loop asks `TermSize` again), no East Asian display width,
which AP 6.4.15 NOTE 14 declares out of scope. A byte-column editor that says
so.

## Consequences

**It lives in `tui/`, a third source root**, and takes `lsp/`'s arrangement
wholesale — a `build.py` reading a `.components` sidecar, `AFTERSCHOOL_PASCAL_OPT`
honoured because an editor's whole shape is a loop and an alloca in one is
invisible at `-O2` (ADR-0102), and per-component coverage attribution. The
corpus sweeps reach it by being *named* as a root, the way `lsp/` is, and not
by the glob.

**The design decision that makes it testable is that the terminal is not in
the loop.** The editor is a *model* — buffer, cursor, key decoding, and a
redraw producing a screen buffer of rows × columns — and a *shell* of a few
dozen lines that reads keys through `PasTerm.ReadKey` and writes the screen
with `CursorTo`. A session harness feeds a scripted key sequence to the model
and diffs the rendered screen as ordinary text.

That is `lsp/run.py`'s mechanism moved one directory over: a conversation
replayed, compared byte for byte, with the parts that cannot be written down
once (a path, a terminal size) normalised. **It needs no pseudo-terminal**,
which ADR-0262 declined once already on the grounds that a case needing one
would become a test of the PTY binding.

**What stays unchecked is what a real terminal does**, and that is a
`doc/sop.md` §7 row rather than a silence — one ADR-0262 already owed and
that was never written. Raw mode's flags, a read answering on one keystroke,
the settings put back being the settings taken, the `atexit` restore, a real
window size, and `EnterRaw`'s `errFull` arm are asserted by nothing and were
checked once by hand under a pseudo-terminal. An IDE makes that gap matter
more, so it is written down now.

**`PasTerm` gains three sequences**, each the shape of `HideCursor` and none
touching the runtime: the alternate screen, colour, and cursor save/restore.
They are strings a caller writes, so `lib_term.pas` checks them exactly, with
control bytes rendered as ordinals, and no terminal is needed to do it.

## Alternatives rejected

**Leave it withdrawn and build editor support into `pasls` instead.** That is
the withdrawal's own logic followed one step further, and it answers the
wrong question: the server already serves editors well, and what is wanted
here is not a better server but *this program*.

**Build it outside the tree.** It would then not be swept by `format-check`,
`warning-free`, `variant-check` or the `-O0` corpus run, and the dialect would
lose the thing that makes an in-tree client valuable — ADR-0349's lesson, when
a `trait` in a source stopped the compiler and 888 cases were green, because
no fixture here declared one.

**Wait until the wasm work lands.** They are independent, and this one is the
one with a person wanting to write it.
