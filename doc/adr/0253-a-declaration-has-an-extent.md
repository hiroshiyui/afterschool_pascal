# 253. A declaration has an extent

Date: 2026-08-30

## Status

Accepted, 2026-08-30.

It closes the half of a finding
[ADR-0239](0239-the-compiler-answers-a-tools-question.md) left open and
`doc/sop.md` §7 carried: *the parse tree records where a declaration starts and
its end is not*, which is why an outline gave `range` and `selectionRange` the
same value.

## Context

3.17 asks a `DocumentSymbol` for two ranges: `range` is the whole symbol —
"everything a client would want to select when picking the symbol" — and
`selectionRange` is the name inside it. This compiler could answer only the
second, because a block's end was recorded nowhere.

ADR-0239 said so and gave the honest answer at the time: report the name
twice, since inventing an end would be inventing a claim about the source. It
also named what would close it — *the parser noting where a block ends, which
nothing has yet needed*.

Something needed it. Go-to-definition and hover landed
([ADR-0246](0246-what-a-name-denotes-and-where-it-was-written.md) onward) and
made the outline the one answer still degraded, and "expand selection to the
enclosing declaration" is the ordinary editor gesture it degrades.

## Decision

**`nkBlock` records where it ends.** Two integers, set in `ParseBlock` after
the compound-statement, which is the one place a block finishes. The position
is the token *past* the closing `end`, because an extent stopping at the `end`
would exclude the word itself.

A module-heading has no compound-statement, so its block records 0 and the
heading's own extent is its name — the §6.13 case where a heading is
translated without its block.

**`--dump-symbols` writes the extent**, so the line is now

```
symbol <depth> <kind> <line> <col> <len> <endline> <endcol> <name>
```

and a declaration with no block writes the end of its own name. That keeps
every line the same shape: a caller reads two positions and never has to know
which kinds have blocks.

**The server maps them onto the protocol's two ranges**, converting each end
against *its own* line — which matters under `utf-16`, where a block spanning
many lines has two ends whose columns are counted in different text.

## Consequences

**"Expand selection to the enclosing declaration" works**, and the independent
client shows it: `Twice` comes back with `range` spanning lines 6 to 9 and
`selectionRange` on the name.

**The format grew and three goldens moved with it** — the two
`tests/dumps/symbols*` cases and the `symbols` session — plus one string in
`selfhost/producttest.sh`, which asserts the driver passes a dump through by
comparing the whole line. That last is the useful one: it is a *harness*
holding a copy of the format, and it failed the moment the format changed,
which is what it is for.

**What is still not recorded is a statement's extent.** A block knows where it
ends; an `if` or a `while` does not, so selection expansion stops at the
enclosing declaration and does not step outward through nested statements. No
caller has asked, and the shape of the answer would be the same — a position
taken where the parser finishes the construct.

## Alternatives rejected

**Deriving the end from the next declaration's start.** It needs no parser
change and is wrong in the ordinary case: the gap between one declaration and
the next is whitespace and comments, so a range built that way swallows both
and lands the selection on text belonging to neither.

**Recording the `end` token's own position rather than the token past it.** It
is one character different and excludes the `end` from the selection, which is
visible the first time anyone uses the gesture.

**A separate flag or a second line kind for extents.** It would have kept the
existing format byte-for-byte and made every caller ask twice. The format is
read by one program and a harness, both of which were updated in the same
change; a second question would have been permanent.
