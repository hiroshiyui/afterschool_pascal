# ADR-0337: A container owns its storage only when one block can keep it

Date: 2026-09-05

## Status

Accepted. Answers the roadmap row left open by ADR-0323, which made a container
writable once for both kinds of pointer and thereby turned "should a container
own its storage" from a library question into a client one without saying how a
client should choose.

## Context

**The library disagreed with itself and nothing said which was right.**
`lib/dialect/paslist.pas` declares `List = owned ^ListNode`, has no `Free`, and
cannot be made to leak. `lib/passtrvec.pas` is an ordinary pointer with
`SVecFree`. Both are correct and the difference had no stated reason, so a new
module was a guess.

**The client evidence does not point one way, and that is the finding.** The
small self-contained programs are block-owned — `word_freq`, `arena_graph`,
`owned_list`, `dir_sizes`, `lib_container`. The two *large* clients are not:
`lsp/pasls.pas` puts a `PathVec` in a `Document`, copies a whole `Document` out
of a map and aliases `lines := d.uses_`; `lib/dialect/pasjson.pas` returns a
`JsonPtr` from 22 functions.

**The two shapes are not symmetric**, which is what settles it. An unowned
container can always be *used* in the owned shape — declare it, `Free` it at
the end. An owned one cannot be used in the pass-around shape at all: AP
6.4.14.3 refuses it as a value parameter and as a function result, and a record
holding one is itself affine, so it cannot be a map's value. So "all containers
own" is refuted outright by `Document`, and "all containers are unowned" throws
away leak-freedom to buy what the unowned form already gives.

## Decision

**Both, chosen per container, with the rule written down** in
`lib/dialect/README.md` as its fourth rule.

Prefer writing the container generic over its pointer type and letting the
client answer, which is what ADR-0323 made possible. Where that is not open,
own it only if every variable of it can be one a block declares and never lets
out of its hands — four questions, and one *no* settles it as `^T` with a
`Free`: is it ever a value parameter, ever a function result, ever a field of a
record that is assigned or stored as a map's value, and does it ever hold a
file, a handle or another owned pointer.

`lib/` itself is not in scope and takes no decision: it is the conforming layer
ADR-0120 keeps portable, and `owned` is the dialect's word.

## Consequences

**Two costs of the generic form are now named rather than discovered**, and the
second was found by implementing the obvious fix and watching it fail.

`VecFree` and `MapFree` do not instantiate at an owned type argument. Their
bodies end by assigning nil, which AP 6.4.14.6 refuses because `dispose` is
that spelling for an owned pointer. Nothing is lost — an owned vector is
released where its block ends — so this is documented and pinned by
`tests/dialect/owned_container_free.pas` rather than fixed. The case pins the
*second* diagnostic line as much as the first: the assignment is in a component
the program never opened and the activation is in the program, so the refusal
has to say whose call it was.

**And the read-only routines may not take `protected var`.** This record's own
first draft said they should — an owned client otherwise hands every reader a
parameter it could release through, and `protected var` is the word AP 6.4.14.8
gives that meaning. It does not compile. `Protectable` (`aptypes.pas`) answers
false for a pointer that is not owned:

    else if IsFile(t) or (IsPointer(t) and not IsOwnedPointer(t)) then
      Protectable := false

so protecting `var v: Ptr` in a module generic over `Ptr` compiles for an owned
client and refuses every ordinary one. Measured, not reasoned: 19 cases failed,
including every JSON and language-server case, with *`v` cannot be protected:
intvec is not a protectable type*. **That is a real cost of one container
serving both kinds** — an owned client's readers are also its releasers — and
it is the price of ADR-0323 rather than an oversight. A module that wants the
borrow must give up being generic over the pointer kind, which is `PasList`'s
bargain and why it can take the word four times.

**`tests/checks/heap_balance.txt` does not move.** An owned container still
calls `new`, and its release still reaches `pas_dispose` through `@ownrelN`, so
the tally is what it was.

**No existing module changes.** The rule is written so that today's tree
already satisfies it — `PasList` passes all four questions, `PasStrVec` fails
the third, `PasContainer` answers neither way by construction. That is
deliberate: a rule that condemned a module on the day it was written would be a
rule nobody could have followed, and this one is a statement of what the
library already knew rather than a migration.

## Alternatives rejected

**All containers own their storage.** Refuted by `lsp/pasls.pas`: `Document`
holds a `PathVec` and is copied whole out of a map, which AP 6.4.14.3 ends the
moment the field is owned. A rule refuted by the largest client in the tree is
not a rule.

**All containers are unowned, with an explicit `Free`.** Consistent, matches C,
and throws away the one property the owned form has — that it cannot be made to
leak — to buy flexibility the unowned form already supplies. It would also
require rewriting `PasList` against its own design.

**Leaving it to the module author**, which is the status quo and is what
produced two containers disagreeing with no stated reason. The generic form
removes the choice where it applies; the four questions decide it where it does
not.
