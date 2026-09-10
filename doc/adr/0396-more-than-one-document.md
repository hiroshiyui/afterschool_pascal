# ADR-0396: More than one document

## Status

Accepted. What `doc/roadmap.md` called *what actually makes it usable on this
compiler*, and the feature the previous commit's fix was standing in for.

## Context

The editor held one document. `doc/roadmap.md` had already written the
argument for more: *more than one file at once, which is what actually makes
it usable on this compiler, since a diagnostic often names a component that is
not on screen.*

That sentence turned out to be describing a **defect** and not only a missing
feature. `EditFault` parsed `file:line:col:` and threw the filename away, so a
diagnostic about another program-component jumped to that line number in
whatever document was open and displayed the message as though it had landed
there. The commit before this one made that honest — a diagnostic about
another file is reported and the cursor stays put — and said in its own message
that opening the file is a second document and this editor holds one.

It holds eight now.

## Decision

**A `Document` is a record**, and the editor *embeds* one rather than indexing
an array everywhere: the buffer, the cursor, the scroll, the name, the dirty
mark and both journals. Changing which document is being edited is

```pascal
ed.bank[ed.cur] := ed.doc;
ed.doc := ed.bank[n];
```

— two whole-record assignments, which a structured assignment makes one copy
each way (ADR-0017). **No list of fields is written twice anywhere**, which is
the whole reason for this shape: a `SaveDoc` beside a `LoadDoc` is exactly the
*a fact stated twice will disagree with itself* that ADR-0388 removed from this
program once already, and a field added to `Document` later joins the switch
with no second site to remember.

**The journal is per document.** An undo that reached across a switch would
reverse an edit in a file the person is not looking at.

**F3 opens and F6 goes to the next**, Turbo Pascal's positions — and
`tui/README.md` had promised F3 would be Open *when there is something for it
to open*, which there now is. Open asks for a name in the same framed box
`Find` and `Save as` use, so it is the fourth user of ADR-0391's primitives
and adds no drawing machinery. `File ▸ Open` names the same key, which is
ADR-0391's rule about a menu item.

**The model makes room and the shell reads the file.** `EditAdd` makes an
empty document current, the name goes on it as `Save as` puts one on this one,
and the shell reads it back with `EditName` and holds no copy. ADR-0381's line,
drawn again.

**A file already open is switched to and not opened twice.** Two buffers over
one file would be two answers to *is this saved*.

**A diagnostic naming an open document is landed on**, which is what this was
for: `EditFind` answers which document has a name, `EditGo` goes there, and
the cursor lands. One naming a file that is *not* open is still reported and
not jumped to — opening it there would be the model reading a file.

**The status line says which of how many, and only when there is more than
one.** A `1/1` on every screen is a number that never says anything.

## Consequences

**Every session golden changed in one row**, because the hint bar names the
keys this editor has (ADR-0389) and it has two more. That claim is why the bar
exists, so the alternative — adding keys and not saying so — would have made
the bar quietly false. `^Z Undo` left the bar to make room and is still on the
Edit menu.

**`EditFree` frees every document**, not the one on screen. Freeing only the
current one would leak a buffer and two journals per file opened, and nothing
here would have noticed: `heap-balance` sweeps the corpus and `tui/` is not in
it.

**Eight is a bound and not a limit anyone measured.** More than a person
tracks by name on one status line, and more than the three
program-components the compiler this editor was written for has.

**There is no window list, no split and no tiling.** F6 cycles; the status
line says where you are. A list is worth having when eight documents is a
number people actually reach.

**Nothing prompts to save on switching away**, because nothing needs to: the
dirty mark travels with the document and Ctrl-Q already takes two presses over
unsaved work. What is *not* covered is quitting with another document dirty —
the second press asks about the one on screen only, and that is a gap this
records rather than closes.

## Alternatives rejected

**Index an array everywhere** — `ed.doc[ed.cur].lines` at 224 sites. It works
and it is what most editors do, and it makes every line longer and the switch
free. Embedding cost one mechanical rename and made the switch two statements
that cannot drop a field; the mutation that hand-copies six fields and forgets
the journals is caught by a golden, which is the evidence for the choice.

**A save routine and a load routine.** The obvious shape, and the one this
tree has been bitten by: two field lists that must agree, with nothing
comparing them.

**Open the file from `EditFault`.** It would make the landing seamless and it
puts a file read in the model, which is the one thing `tui/`'s testability
rests on not doing (ADR-0381). The shell can do it later by asking; the model
would have had to stop being a value in, value out.

**A window menu with the open files listed.** Worth having and not yet: it is
a fifth menu and a list whose length is data, and F6 with a status line covers
two and three documents, which is what this compiler needs.
