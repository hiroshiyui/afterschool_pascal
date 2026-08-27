# 222. A variant record has no member initialisers

Date: 2026-08-27

## Status

Accepted.

## Context

The AST is the **only** variant record in this compiler. `case kind:` appears
once in 36,000 lines; symbols and types carry an ordinary `kind` field, which
is why the 29 `^.kind :=` assignments elsewhere are harmless.

That one record has 63 arms and 138 pointer fields, and Pascal gives a variant
record no member initialisers. A field of the arm the tag selects holds
whatever `new` returned until something writes it — and a `nodePtr` holding a
value that is neither nil nor a node is the one shape nothing downstream can
recover from, because the walk follows it.

Two things write those fields, and the compiler uses both deliberately:

- **`NewNode` clears it.** Its own comment says which: *"What Sema will fill
  in. A C++ struct gets these from its member initialisers; a variant record
  has none, and the dump reads them whether or not Sema ran, so they are
  cleared where the node is made."* 88 fields.
- **The construction site assigns it.** The structural fields the *parser*
  fills — `ifCond`, `bnLhs`, `arElem` — are set within a few lines of `NewNode`
  returning, and clearing them first would be a store nothing reads. 50 fields.

**The split is who fills the field, and it was written down nowhere a reader
could check.** It came up in review as a suspected defect: `tqObj` is cleared
at the parse site rather than in `NewNode`, which looked like a departure from
the pattern `NewNode`'s comment states. It is not — `tqObj` is filled by the
parser, so the parse site is its home. What makes it unusual is that it is the
only parser-filled pointer field set **conditionally**, which is exactly why it
needs the explicit `:= nil` it has.

So the suspected defect was a misreading of the convention. What survived is
that the convention is real, load-bearing, and checked by nothing.

## Decision

`ast-fields` reads the variant part, `NewNode`'s cleared set and every
construction site, and requires each pointer field to be on one side of the
split: cleared in `NewNode`, or assigned at every `v := NewNode(nkK, …)` site
before the enclosing routine ends.

The routine is the boundary rather than a line count, because a parser
production builds a node and fills it before returning, and there is no shorter
scope true of all of them.

It also reports a pointer field assigned nowhere and cleared nowhere, which is
a field that is dead or an arm that outlived it.

**It passes today with no catalogue at all** — 135 assignments over 70
construction sites, zero exceptions. That is the useful part of the result: the
convention is not merely a convention, it is currently universal, and the gate
records that rather than discovering a defect.

Three mutations, each caught by the part it should be:

| mutation | what it says |
| --- | --- |
| `NewNode` stops clearing `frCounter` | `ParseFor builds a nkFor and never assigns s^.frCounter` |
| `ParseIf` stops assigning `ifCond` | `ParseIf builds a nkIf and never assigns s^.ifCond` |
| a new pointer field on `nkOptional` | the site, **and** `assigned nowhere and cleared nowhere` |

## Consequences

**It reports a false positive rather than a false pass**, which is the safe
direction and the reason the catalogue exists at all. A field filled through a
second variable, or by a routine the node is handed to, is invisible to it and
would be reported — `nkKind.field at Routine:line` is then the entry, with
where it is really filled. The file is empty today.

**It says nothing about integer fields.** `svArm` is set to -1 because -1 means
"no arm", which is a decision about a *value*; this gate only asks whether a
field was written. A pointer field holding rubbish is a walk into memory that
is not a node, and an integer field holding rubbish is a wrong answer — the
first is what this is for.

**It says nothing about whether the value is right**, the same limit
`partial_cases.txt` states for `kind-exhaustive`.

## Alternatives

**Clear every field in `NewNode`.** One rule instead of two, and it would make
this gate unnecessary. It is 138 stores per node where 88 are wanted, in the
one allocation the parser makes most; and it would clear `bnLhs` immediately
before the next line assigns it, which reads as though the assignment might not
happen. The split says something true about who owns a field and is worth
keeping.

**Check it in the compiler instead.** Nothing in Pascal can ask whether a field
was written. The dialect's own answer to a related question — ADR-0118, where a
write to a variant's field activates that variant — is about the *tag*, not
about whether an arm's fields were filled, and no reading of §6.5.3.3 extends
it that far.

**Leave it to review.** It was left to review, and review found a suspected
defect that was not one while the real invariant went on being unchecked. A
convention that has to be re-derived by reading `NewNode`'s comment and then
70 call sites is one nobody re-derives twice.
