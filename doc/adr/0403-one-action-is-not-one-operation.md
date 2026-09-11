# ADR-0403: One action is not one operation

## Status

Accepted. Closes the last of the three things milestone two said it left out,
and extends [ADR-0387](0387-an-undo-is-a-journal-and-a-prompt-is-a-mode.md)'s
journal without touching its claim.

## Context

`tui/README.md` listed, under *what the two milestones leave out, on purpose*:

> **No replace, no search backwards and no regular expressions.** Milestone
> two is a search that finds, and says so when it wraps and when it does not.

Replace is the one of the three a person actually misses. The search half of
it already exists — `Seek` finds a pattern anywhere in the document and
answers whether it wrapped — and the editing half is `DoRemove` and
`DoInsert`, two of ADR-0387's four operations. So the feature looked like a
prompt and a loop.

It is not, and the reason is the journal. ADR-0387 made an edit **one of four
operations, each with one entry**, which is what makes undo complete by
construction: there is no way to touch the buffer that undo cannot reverse.
What it has no notion of is an **action** — a thing a person did. It gets away
with that because every key a person presses is one operation, with one
exception it handles by hand: a typed run coalesces, which `Note` does with
three conditions about a person's fingers.

A replacement is two operations. Replacing every occurrence of a word in a
file is a great many — six, in the session written for this. An undo that
reversed one of the six is an undo of nothing anybody did, and a replace-all
that costs thirty Ctrl-Z is worse than no replace at all, because the person
has to count.

The alternative considered and rejected was **confirm-each**, Turbo Pascal's
*Change all / Confirm* — a third prompt whose keys are `y`, `n`, `a` and `q`
rather than text, and so a third kind of mode. It was rejected because it
answers the same question worse: what a person wants after a replace that went
wrong is to *undo it*, and an editor that can undo it in one keystroke does
not need to have asked six times first.

## Decision

**An entry may say that the undo continues through it.** One boolean, `more`,
false on every entry a keystroke makes:

```pascal
  EditRec = record
    kind: EditKind;
    row, col: integer;
    text: EditLine;
    atRow, atCol: integer;
    more: boolean;
    next: EditRecPtr
  end;
```

**It is a property of an entry and not a fifth operation**, which is the whole
of why ADR-0387's claim survives: what touches the buffer is still `DoInsert`,
`DoRemove`, `DoSplit` and `DoJoin`, still the only four, and every one of them
still has exactly one entry describing it. A replace that reached into the
buffer would be as unreversible as anything else that did.

`Undo` and `Redo` split into the one-entry routine and the loop, so the
reversal of an edit is still written once. The two read the flag from opposite
ends and that is stated rather than made symmetrical: `Undo` reads it off the
entry it has **just** reversed, `Redo` off the entry it is **about** to
perform, because `Undo` pushes what it reversed onto the redo stack in the
order it took them — so the entry that *starts* the action ends up on top and
the ones that continue it beneath. Pretending the two are the same shape is
how an undo and a redo come to disagree about what one action was.

**Replace is two prompts and then every occurrence in the document.**
`Ctrl-R`, `Replace:`, `With:`; matching is `Seek`'s and therefore
case-insensitive, §6.1.3's reason, and what goes in is the replacement
exactly — which is what makes changing one spelling to another a thing this
can do. The first answer goes into `ed.seek` rather than being held in the
prompt, so it survives the second being typed *and* so that Ctrl-L afterwards
repeats the same search.

An empty answer to `With:` is a **deletion** and not a refusal, that being the
commonest thing anyone does with this. The scan for the next match starts past
the text just written, which is what stops `a` → `aa` running forever; where
the replacement is empty the start does not move and the line does instead, so
that terminates on the line getting shorter. Both are the same loop and
neither is a special case.

## What holds it

`sessions/replace.keys`, and five mutations each producing a working editor:

| Mutation | What fails |
| --- | --- |
| the group flag never set | one Ctrl-Z leaves two of three replacements standing |
| `Undo` does not loop | the same, one operation deep |
| `Redo` does not loop | Ctrl-Y puts back one replacement of three |
| the scan stops at the first match of a line | `WriteLn(two)` survives; `3 replacements` becomes `2` |
| matching is not case-insensitive | the same two failures, for the other reason |

The last two failing identically is worth knowing and is why the session has
both a second occurrence on one line **and** a differently-cased one: either
alone would have left one of the two mutations alive.

`kind-exhaustive` moved four rows the day this landed — `kkReplace` raises
every `KeyKind` denominator — which is ADR-0404 doing exactly what it was
widened for.

## What this does not do

It does not confirm. Two prompts and then it happens, and the answer to a
replace that went wrong is the Ctrl-Z this record was written to make work.

It does not replace **backwards**, in a **selection**, or by **regular
expression**, and there is still no search backwards. A selection is the
larger missing thing here and it is missing from every other feature too:
this editor has no notion of a region, so cut, copy, paste and
replace-in-selection are one design and not four.

It does not make a **typed run** into a group. A run coalesces into a single
entry, which is `Note`'s older mechanism and reaches the same place by a
different route; the two are not unified, and unifying them would mean a run
became several entries that undo together, which is more journal for the same
behaviour.

It does not group an **open, a save or a document switch**. `more` is set in
exactly one routine, and a second user of it is a decision to take when there
is one.
