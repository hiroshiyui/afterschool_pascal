# ADR-0388: A document with no name asks for one

## Status

Accepted. Closes a hole opened by making the editor start with no argument.

## Context

The editor became `afterschool` and started fileless, which is how a person
writes a *new* program: run it, type, save. The last step did not work. Ctrl-S
on an unnamed document answered

    this document has no name -- start with a file to save it

which is advice to quit and start again, and Ctrl-B answered similarly. So the
launch path the README had just started advertising dead-ended at the first
thing anybody would do with it.

The commit that introduced that message said so plainly — *"asking for one is
a prompt mode the model does not have yet"* — and it was right that the guard
was better than what it replaced, which wrote to the empty path and reported
`could not write ` naming nothing. But a guard that names no way forward is a
placeholder, and this is the record that removes it.

## Decision

**Ctrl-S on a document with no name opens a prompt, and that decision is the
model's.** `EditMode` gains `mdSaveAs` beside ADR-0387's `mdFind` and
`mdGoto`; the label is `Save as: `; the answer becomes the document's name.

The division of labour is the one ADR-0381 drew for the screen and ADR-0387
drew for the prompt, applied a third time:

- **Which key writes a file is the shell's business** and stays there.
- ***That a document with no name cannot be written and has to be asked
  about* is a decision about the document**, so it is in the model, where a
  session drives it and a golden holds it.

`kkSave` was one of three keys the model deliberately ignored. It is now
handled *only* when the name is empty, so the shell's rule becomes: act on
Ctrl-S when there is a name, and otherwise hand the key to the model, which
opens the question. From where a person sits the key does the same thing
either way, which is the point.

**The name is answered back through a request that is taken once.**
`EditTakeSave` answers true at most once per naming and clears — the shell
takes it, writes the file, and calls `EditSaved`. It is a request rather than
a flag so that a second key cannot write a second time.

## Consequences

**The shell stopped keeping a second copy of the name.** It held `path`,
assigned once from the command line, beside the model's `ed.name`. Two names
for one thing, and this feature is exactly what makes them able to disagree:
the person answers the prompt, the model knows the new name, and the shell
goes on writing the old one. `Save` and `Build` now read `EditName`, and the
`path` variable is only the command line's and `Load`'s, which its declaration
now says. **A fact stated twice is a fact that will disagree with itself**,
and it took a feature to expose one that had been harmless for two milestones.

**The empty answer is the only one the model judges.** Whether a path can be
written is something only the write finds out, and this side has no file in
it; an empty name is refused because it would name nothing.

**Ctrl-B's message changed rather than its behaviour.** It still refuses to
compile an unnamed document — the diagnostic a compiler gives for an empty
argument is about the compiler — but it now advises a key that works instead
of a restart.

**What it does not do.** No overwrite confirmation: a name that already exists
is written, which is what `>` does and what milestone one's Ctrl-S already did
for a named document. No directory completion, no browsing. Ctrl-B does not
offer to name and save before compiling, which would be the next obvious
convenience and is a decision about *what Ctrl-B is* rather than a missing
line.

## Alternatives rejected

**A prompt loop in the shell.** Fewer lines, and it would have put the whole
feature where `doc/sop.md` §7 says nothing is checked. ADR-0387 rejected this
for find and the argument is unchanged; what this adds is that the *third*
prompt cost almost nothing precisely because the first was built in the model.

**Let the shell keep `path` and push the new name into it.** It works, and it
leaves the two-copies defect in place for whatever the next feature is.

**Save to a default name** such as `untitled.pas`. It never asks, and it
writes a file the person did not name into a directory they may not have
chosen — the one behaviour here that could lose work by surprise.
