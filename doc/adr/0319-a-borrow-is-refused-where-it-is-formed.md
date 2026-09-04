# ADR-0319: A borrow is refused where it is formed

Date: 2026-09-04

## Status

Accepted. Adds AP 6.4.14.9 and **withdraws Annex C.12**, which ADR-0317 opened
and ADR-0318 narrowed. ADR-0317 is not superseded — its two detected forms are
unchanged and its clause still stands; what is withdrawn is its NOTE 6, the
residue it recorded as beyond reach.

## Context

ADR-0317 refused releasing an owned pointer while a borrow of what it owns is
open, in the two shapes one activation-point can be asked about. It recorded
what it could not reach:

> the callee reaching the owner as a non-local, or being handed it by something
> other than the activation-point that made the borrow

and costed two mechanisms for it. A **per-routine summary** of the non-local
owned pointers a routine may release, closed over the call graph — rejected
because §6.13.2's module-heading carries none across a program-component
boundary. A **dynamic borrow flag** — a word beside every owned block, a check
at each release point — pronounced "sound and complete", and deferred as a class
A and C increment.

ADR-0318 then made the hole askable-away wherever the owner is passed: a
protected owned pointer cannot be released, so a borrow lent beside one is safe.
It does not reach an owner the callee names *non-locally*, which is precisely
what Annex C.12 was about.

Re-costing the flag before building it produced a measurement and then a better
question.

**The measurement.** Every borrow site in the tree, counted by instrumenting
Sema: 31, of which 26 are actual-parameters and 5 are with-elements. Sorted by
where the *owner* is declared:

| Owner declared | Sites | Where |
| --- | --- | --- |
| outermost block | 12 | `owned_borrow.pas`, `owned_borrow_errors.pas`, `owned_protected.pas` — every one a test written for this construct |
| a parameter (level 1) | 14 | `lib/dialect/paslist.pas`, `examples/owned_list.pas`, `owned.pas`, `take.pas` |

Six are hot — the per-node step of a recursive traversal, which is the only
traversal an owned chain has — and three of those six were already `protected`
after ADR-0318, so a flag would have skipped them.

**The better question.** A block can release an owned variable only if it can
*name* it, and 6.4.14.3 forbids copying the value — so the only names an
owned-pointer variable has are the variable itself, a variable
formal-parameter bound to it, and a component of a variable containing it. A
block obtains the second at an activation-point, which is what ADR-0317 already
checks. It has the first **by scope**. There is no third way.

Scope is a translation-time fact. It needs no summary, it crosses a
program-component boundary in both directions, and it costs nothing at run time.

## Decision

**A borrow is refused where it is formed, not where the release happens**
(AP 6.4.14.9). A variable-access reached through a dereference of an
owned-pointer-type may not be an actual-parameter corresponding to a variable
formal-parameter of a call whose callee can name the entire-variable that owns
it; and where such a variable-access is a with-element, no call in the body may
activate a block that can name it.

**A block can name a variable** if the variable is declared in the outermost
block of a program-component, or if the block is declared inside the block
containing the variable and is not that block.

Three things about that sentence are load-bearing.

**A block is not within itself**, and this is the case the rule turns on rather
than an edge of it. A recursive call activates a frame of its own, so the
callee's parameters are not the caller's, and `Len(o^.next)` inside `Len` is
admitted. Refusing it would refuse `PasList` entirely — every traversal it has
is that shape.

**The outermost-block clause is not redundant**, though within one component it
looks it: the walk up the owner chain reaches the outermost block too. Across a
component boundary it is the only thing that answers, an imported routine's
chain terminating in *its* module. `tests/dialect/owned_nonlocal_cross.pas` is
that case, and it exists because a mutation of the clause was **not killed** by
the suite until it did — the first mutation written for it produced an
equivalent program and proved nothing.

**The with-form reaches a call that takes no borrow at all**, and one with no
arguments. A with-element is bound for the whole body, so what decides is what
the called block can *name*, never what it is passed. `with g^ do Quiet` is
refused for a `Quiet` whose body is `begin end`.

## Consequences

**Annex C.12 is withdrawn and `doc/sop.md` §7's row is struck.** The two rules
are exhaustive over the ways a block obtains a name for an owned variable, so
there is no residue to record.

**Nothing in `lib/`, `examples/` or `selfhost/` changed.** The rule refuses 12
sites and all 12 were in tests written for this construct. Three files moved
their owned variables from the program's var-part into a procedure, which is a
one-line change each and is now what those files demonstrate.

**The cost is real and it is expressiveness.** An owned structure held in a
variable of the outermost block cannot be lent at all — not to any routine,
because any routine can name it. The program's answer is to declare it in a
block the routines it lends to are not within, which is one procedure. That is
a discipline and not a workaround: a global that anything may dispose is not
something a borrow can be safe against, whatever mechanism is used.

**It is conservative on purpose.** A routine that can name the owner and never
releases it is refused all the same. Admitting it is exactly the summary
ADR-0317 declined, and it is unavailable across a component boundary in either
direction — a module's exported variable is nameable by every importer, and an
imported block's own outermost variables are nameable by it.

**One message per call, and the pairwise rule wins.** Where the owner is also an
argument both rules apply; naming the argument says more than naming the scope,
so this one is silent there. That suppression is pinned by a case, added after a
mutation removing it killed nothing.

## What this does not do

**It does not make the dynamic borrow flag wrong**, only unnecessary. The flag
is exact where this is conservative, and a language that wanted to lend pieces
of global state would need it. This one does not.

**It does not say a borrow cannot escape.** That is still ADR-0201's argument —
no value naming a variable parameter can be formed, because Pascal has no
address-of — and it is still unformable rather than checked. `doc/sop.md` §7
carries what remains of that row.

**It does not change what a release is**, and it adds no run-time code. AP
6.4.14.3's release points are unchanged and the emitter is untouched.

## Alternatives rejected

**The dynamic borrow flag**, costed above and in ADR-0317. It buys the
expressiveness this gives up, and it costs a word on every owned block, a
register-and-unregister on every unprotected borrow — including the per-node
step of every mutating traversal — and an unwind path that must survive a
non-local `goto`, since a stale count is a false trap on a correct program. It
is the right mechanism for a language that must lend from global state; the
measurement says this one need not.

**Refusing only where the callee actually releases.** The summary ADR-0317
declined, for the reason it gave: §6.13.2 has no room to carry one, and the
question must be answerable for an imported routine whose body this compilation
cannot see.

**Asking at the release rather than at the formation.** This is what both
earlier mechanisms did and it is why both were expensive. The requirement is
symmetric — a borrow and a release must not coexist — so it can be enforced at
either end, and one end is a question about scope while the other is a question
about behaviour. Two records costed the second before anybody re-read the
requirement for the first.
