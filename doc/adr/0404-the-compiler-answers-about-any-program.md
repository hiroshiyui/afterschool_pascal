# ADR-0404: The compiler answers this about any program

## Status

Accepted. Widens [ADR-0145](0145-every-enumeration-not-only-the-type-kinds.md)'s gate from the
compiler to every program in this tree, and is the gate the commit before it
says would have caught a crash.

## Context

`kind-exhaustive` asks whether every dispatch over an enumeration names every
constant, and it is one of the sharper things here: a constant left off a
**case-statement** stops the program (§6.9.3.5, ADR-0018), so it is a crash
and not a wrong answer. ADR-0229 and ADR-0230 moved it off reading Pascal with
regular expressions and onto `--dump-dispatch`, which is the compiler
answering about its own tree — which types are enumerations, how many
constants each has, what a selector's type actually is.

**And it was pointed at the compiler and at nothing else**, for the whole of
its life. `--dump-dispatch` is an ordinary flag that works on any Pascal
program; the gate handed it `components.translate(root)` and read the answer
about `selfhost/`.

The cost came due the day before this record. ADR-0396 added `kkOpen` and
`kkNextDoc` to the editor's `KeyKind`, and `MenuKey` dispatches over that
enumeration with a `case` and no `otherwise`. F3 or F6 with the menu open:

```
runtime error: case: no label matches the selector at apedit.pas:1509:9
```

in the shipped v3.10.0, with twenty-one sessions, `tui-palette`, `tui-terminal`,
`warning-free`, `variant-check` and the whole suite green — no session having
pressed one of those keys while a panel was up. The compiler had the answer
the entire time and was never asked:

```
case menukey:keykind:1 names 24 of 26 at 1509:3 missing kkopen kknextdoc
```

That is the finding, and it is not about the editor. **A gate whose corpus is
written into it stops growing when the tree does**, and this one's corpus was
one line of code.

## Decision

**Every program in this tree is a corpus.** Five today: the compiler's three
components, and `tui/apedit.pas`, `tui/apide.pas`, `tui/session.pas` and
`lsp/pasls.pas`. Adding one is a line in `EXTRA`.

Four things about doing it are decisions rather than mechanics.

**A site belongs to the first corpus that reaches it.** `apedit.pas` is
imported by both the shell and the session replayer, so its `case` statements
come back three times, and an argument written three times is the *fact stated
twice* ADR-0388 removed from this program once. The corpora are ordered so the
owner is the program the code is in, and a site an earlier corpus claimed is
skipped.

**Whether a constant is named by *no* case-statement is a question about the
tree and not about a program.** `crText` is named by nothing in `apedit.pas`,
which decides what a cell is *for*, and by `RoleColour` in `apide.pas`, which
decides what it looks like. That split is ADR-0389's whole point, and asking
each corpus on its own would have made eight catalogue entries out of it. A
constant is unused when **every** corpus declaring its enumeration leaves it
unnamed.

**The catalogue grew a section header and not a prefix.** `[tui/apedit.pas]`
switches the corpus for the rows under it; the ninety-three rows that were
there keep their spelling and belong to the compiler, which is what every one
of them already meant. A header naming a corpus this does not sweep is an
error, so the two lists cannot drift apart.

**The if-chain floor is the compiler's and not every program's.** *No chain
dispatching on a field named `kind` at all* means this stopped reading, of a
tree of variant records; of a program with no variant record it means nothing,
and `lsp/pasls.pas` is one.

## What it found on its first run

Sixteen more case-statements and twenty-two more enumerations than the gate
had been measuring — 63 to 79, and 13 to 35. Four sites needed an argument and
eight constants needed one, each written into the catalogue: `PromptKey`'s two
(a mode that has its own handler, and the four keys a question means anything
by), the shell's two chains, and the constants three modules compare with `=`
rather than dispatching over.

None of the twelve was a defect. **The defect was the commit before**, and
that is the evidence for this record rather than an absence of findings: the
mutation is that crash, put back —

```
tui/apedit.pas:1354 (menukey) names 23 of 25 keykind constants and argues
for none of it -- missing kkopen, kknextdoc
```

— and the catalogue fails in both directions as it always has, a row whose
numbers stop matching and a row naming a site that is not there being as loud
as a site with no row.

## What this does not do

It does not sweep `lib/`. A module is not a program and has no
main-program-block to translate from; reaching its dispatches means compiling
a client for it, which is `lib-coverage`'s problem and has a different answer
(ADR-0350). What is covered is every dispatch a module has that one of the
five programs *reaches*, which is most of them and is not all.

It does not extend `variant-check`, `predicate-kinds` or `ast-fields`, which
are about the compiler's own AST and are not questions about another program.
Whether other gates here have a corpus written into them is now a thing worth
asking about each, and `doc/sop.md` §7 carries the question.

It does not make the editor's dispatches *complete*. It makes them argued for,
which is the same bargain ADR-0145 struck: the catalogue is a list of places
somebody has said why, and its value is that the list cannot grow in silence.
