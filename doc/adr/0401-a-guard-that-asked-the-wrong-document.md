# ADR-0401: A guard that asked the wrong document

## Status

Accepted. Supersedes nothing and corrects [ADR-0396](0396-more-than-one-document.md),
whose *Consequences* recorded this as a gap when it was a regression.

## Context

ADR-0396 put eight documents behind one screen. It listed what it did not
close, and one of the entries reads:

> Quitting still asks about the document on screen only. The dirty mark
> travels with the document, so the second press over a *different* document's
> changes is not asked for.

That sentence undersells what had happened by a wide margin. The shell's quit
guard is

```pascal
if (not EditDirty(ed)) or asked then running := false
```

and `EditDirty` answers about `ed.doc` — the document being drawn. Before
there was a second document that was the whole editor and the guard was
complete. Afterwards it was not a missing prompt: it was **a silent loss of
work on a keystroke people press constantly**. Measured under a pseudo-terminal
rather than reasoned about — type into `a.pas`, open a clean `b.pas` over it
with F3, press Ctrl-Q **once**:

```
=== after ONE Ctrl-Q the editor is *** GONE -- a.pas edits lost ***
=== a.pas on disc: program a(output);
```

No prompt, no message, exit status 0. It shipped in v3.10.0.

The reason it was written down as a gap rather than found as a defect is worth
keeping, because it is a shape rather than an oversight. **A question that was
complete becomes incomplete when what it is asked about grows a second
instance, and nothing about the question changes at the moment it stops being
right.** `EditDirty` is as correct today as it was written; what moved was the
editor underneath it. Every oracle here agreed throughout — the twenty
sessions, `warning-free`, `tui-palette` — because none of them can press
Ctrl-Q, quitting being the shell's (ADR-0381).

## Decision

**`EditDirty` and `EditDirtyCount` are two questions, and the shell asks the
second one.** The model answers both:

```pascal
function EditDirtyCount;
var i, n: integer;
begin
  n := 0;
  if ed.doc.dirty then n := 1;
  for i := 1 to ed.docs do
    if (i <> ed.cur) and ed.bank[i].dirty then n := n + 1;
  EditDirtyCount := n
end;
```

Three things about those six lines are decisions.

**The current slot is skipped, and that is a fact about how ADR-0396 stores a
document rather than about dirtiness.** `ed.doc` is live and
`ed.bank[ed.cur]` is a *stale copy*, written back only as `EditGo` moves away
from it, so a document that has been left and returned to appears in both and
a count reading the bank flat answers one too many. `EditFind` is written the
same way and for the same reason, which is the argument for the shape: the
skip is not a special case, it is the second instance of the rule that the
bank holds the documents that are not on screen.

**It answers a count and not a boolean.** The guard needs only *any*, but the
message needs *how many* — a person looking at a document with no mark on it
has nothing else to tell them what is being asked about — and a boolean would
have had to be widened the moment the message was written. It is also the
answer that makes a mutation visible: a count that stops at the first dirty
document it finds is a different number, where a boolean would be the same
answer.

**The question stays in the model and the guard stays in the shell.** This is
ADR-0381's line and it is what was got right even here: the shell was asking a
real question of the model and asking the wrong one, which is a far cheaper
failure than a shell keeping its own idea of what is unsaved. The fix is one
identifier, plus the message.

The contract does not change: two presses still discard. What the second press
now discards is named.

## What holds it

Two sessions, and neither can press Ctrl-Q. What they hold is the *question*:
`tui/session.pas` prints `dirty` and `unsaved` on its closing line, so every
one of the twenty goldens now carries the editor's answer beside the
document's.

- `sessions/dirty_others.keys` ends on a third document that was never typed
  into, with two others holding changes: `dirty FALSE unsaved 2`. This is the
  defect written as a golden — the two answers differ, and the count has
  passed the first document it found.
- `sessions/dirty_return.keys` comes back to where it started, which is the
  only way to make the current bank slot hold anything: `dirty TRUE unsaved 2`
  with one of the two under the cursor.

Three mutations, each killed by a named case:

| Mutation | What fails |
| --- | --- |
| `EditDirtyCount` counts `ed.doc` alone — ADR-0396's behaviour | `dirty_others`, `unsaved 2` → `0` |
| the loop does not skip `ed.cur` | `dirty_return`, `unsaved 2` → `3`; and `documents`, `1` → `2` |
| the shell asks `EditDirty` again | **nothing** — the pseudo-terminal run above, by hand |

That third row is the finding this record leaves behind, and it is why the
next increment is the one it is. The defect lived in the shell; the fix lives
in the shell; and the only thing that can see either is a person at a
terminal. `doc/sop.md` §7's row saying so has been open since ADR-0389 and is
no longer a note about colour.

## What this does not do

It does not offer to **save** the other documents, and it does not say which
they are. Ctrl-Q twice discards, as it always has, and F6 is how a person
reaches what the message counted. A quit that walks the open documents asking
about each is a dialog with three answers per document and belongs with
whatever else needs one.

It does not make the count reachable from a key: nothing draws it but the
message on the second press. The status line already says `n/m`, and a
document list is ADR-0396's own deferral.

It does not revisit `EditDirty`, which is the right question for the status
line's mark and is asked by the model in exactly one place.
