# ADR-0387: An undo is a journal, and a prompt is a mode of the model

## Status

Accepted. Milestone two of ADR-0381, which named milestone one and stopped
there on purpose.

## Context

ADR-0381 un-withdrew the editor and built *open, edit, save, compile, land on
the error*. It is a usable program and using it is what produced this record:
the three things missing within a minute are undo, a search, and a way to get
to a line by number. That is not a survey of what editors have — it is what
the answer-key argument ADR-0381 rests on actually returned when the key was
used, and it is the reason the milestone is these three and not a longer list.

Two of them look like features and are really one design question each.

**Undo asks what an edit *is*.** Milestone one changed the buffer in place:
each arm of `EditKey` computed a new line and wrote it back. Nothing was
wrong with that until something had to reverse it, at which point there was
no *it* to reverse — the edit existed only as the difference between two
strings, and the difference between two strings is not enough to put the
cursor back where the person was.

**A search asks who owns the keyboard.** An editor that is asking a question
is in a state, and the state has to live somewhere. The obvious place is the
shell — read keys in a loop until Enter, then call the model — and that is
the wrong place for the reason ADR-0381 already gave about drawing: the shell
is the part no oracle here reaches.

## Decision

**An edit is one of four things, and the journal holds them.** `EditKind` is
`ekInsert`, `ekDelete`, `ekSplit`, `ekJoin`, and the four routines that
perform them — `DoInsert`, `DoRemove`, `DoSplit`, `DoJoin` — are now the only
code in the editor that touches the buffer. Every arm of `EditKey` is one of
those calls and one `Note`.

That is what makes the journal complete **by construction rather than by
inspection**. An arm that reached into `PasStrVec` directly would be an edit
undo could not reverse, and after this change there is no longer a way to
write one without noticing: the buffer is not addressed anywhere else.

An entry carries the kind, where it happened, what text went in or came out,
and **where the cursor was before it**. One entry therefore both reverses the
edit and performs it again, so redo is the same mechanism read forwards and
not a second one with a second set of defects.

**A run of typing is one entry.** Characters typed left to right, backspaces
taken right to left, and forward deletes taken in place coalesce; a split or a
join never joins a group, because undoing half a line's typing together with a
structural change is not an action anybody performed. Every key that is not
more of the same run closes the group, and **the default is to close** — an
arm that wants to go on says so. That is the safe direction to be wrong in:
forgetting it gives an undo smaller than expected, which a person sees and
repeats, where the other way round gives one that swallows an action they
never performed and cannot get back.

**A prompt is a mode of the model.** `EditMode` is `mdEdit`, `mdFind`,
`mdGoto`; the label and the half-typed answer are fields of `Editor`; and
`EditRender` draws the question on the message line **with the cursor in it**.
The shell is told one thing, `EditPrompting`, and while that is true it does
nothing of its own with a key — Ctrl-S inside a search is part of what is
being searched for.

So a session drives a prompt and a golden holds one, which is ADR-0381's rule
met a second time and the reason this is where the state lives.

## Consequences

**Search is case-insensitive, and that is the one thing this editor knows
about the language it edits.** §6.1.3 folds every letter of an identifier, so
a person searching for `writeln` means `WriteLn`; `sessions/find.keys` pins
exactly that. The fold is ASCII's, because a column here is a byte — AP
6.4.15 NOTE 14 puts display width outside this language, and ADR-0381 already
wrote that limitation down.

**A wrapped search says so.** Without it there is no way to tell the second
match from the first one again, which is the one genuinely confusing thing a
search can do quietly. A search that finds nothing leaves the cursor where it
was: moving it would lose the person's place in order to tell them nothing.

**Escape cannot close a prompt, and Ctrl-C does.** This is a fact about the
decoder and not a preference. `DecodeByte` is handed one byte at a time and an
arrow arrives as `ESC [ A`, so a bare Escape and the start of an arrow are the
same byte and only a timeout tells them apart; the decoder took the first
reading in milestone one and said so. This is the first place that reading
costs anything, and Ctrl-C is what it costs.

**Undoing back to what was on disc still reports the document as modified.**
The editor does not record which entry the last save was at, so it says the
document differs rather than claiming it does not — the honest direction to be
wrong in is the one that offers to save.

**The journal is unbounded and heap-balanced.** It is a list of records
reached by `new`, dropped by `dispose` when a fresh edit makes the redo stack
unreachable and when the editor is freed; the four new sessions run with
`PASHEAP_BALANCE` set report `live=0`. A fixed depth was considered and
rejected: the document itself is unbounded (`PasStrVec` grows), so a bound
here would be the only one in the program, and its drop path would be a
behaviour no session of a readable length could reach — a limit nothing
exercises is ADR-0282's shape.

**What it does not do.** No replace, no undo *grouping across lines*, no
regular expressions, no search backwards, no incremental search that moves as
you type, and no marks. Milestone one's four exclusions stand unchanged:
horizontal scrolling, display width, resize and mouse.

## Alternatives rejected

**Snapshot the whole document per edit.** Much simpler, obviously correct, and
it makes redo trivial. It was rejected on what it teaches rather than on cost:
the buffer would have stayed a thing that gets overwritten, and the property
that matters here — *every change is one of four named operations* — would
never have been forced. That property is what a later multi-file or
collaborative milestone would need, and it is what makes the journal
auditable now.

**Put the prompt loop in the shell.** It is where a terminal editor
traditionally puts it and it would have been fewer lines. It would also have
moved the search — the part of this milestone a person most notices being
wrong — into the one part of the program `doc/sop.md` §7 says nothing checks.

**Undo per character.** Predictable, and nobody wants it. The coalescing rule
is the whole reason `sessions/undo.keys` exists, and the mutation that
disables it is the one that proves the session is evidence.
