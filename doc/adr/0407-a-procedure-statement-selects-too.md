# ADR-0407: A procedure-statement selects too

## Status

Accepted. Closes a gap [ADR-0340](0340-four-things-a-trait-heading-cannot-do.md)
left and its own clause never had, and is the prerequisite
[ADR-0315](0315-methods-and-traits-without-inheritance.md)'s staging table does
not name.

## Context

AP 6.7.10.2 has read, since the day it was written:

> Where a **function-designator or a procedure-statement** names an identifier
> that has no defining-point in force, and the first actual-parameter is a
> variable-access, the identifier shall be identified as a routine of the
> implementation, if there is one, that implements a trait declaring that
> identifier for the type of that variable-access.

Only the function half was built. Its own NOTE 14 then said:

> Only a function-designator selects an implementation. A trait may declare a
> procedure and an implementation may define it, and calling it is not yet
> provided.

**So the normative sentence and its note contradicted each other**, and the
note was right about the processor. That is the one thing AP 5.6's
`[not yet implemented]` marker exists to prevent — a clause running ahead of
the compiler is marked, its triage row says `not-implemented`, and the
traceability gate then refuses a scenario citing it, so the specification
cannot come to claim a feature is there. Nothing is marked today and nothing
was marked then; the gap was written into prose instead, where no gate reads
it.

The defect was catalogued rather than hidden — `tests/dialect/traits_no_selection.pas`
carried `Emit(i)` with the comment *a procedure is not yet dispatched at all*
and a golden `.err` pinning `unknown procedure 'emit'` — so this is a
limitation that was recorded, and recorded in the place a limitation goes.
What it was not, was **reachable from the clause it contradicted**.

**Why it matters now beyond tidiness.** ADR-0315's increment C is the trait
object: a two-word value carrying a vtable of the trait's routines. A vtable
whose procedures cannot be called is half a vtable, so this is C's
prerequisite, and it is not in that record's staging table — which says A is
the prerequisite for B and B for C, and has already been wrong once (B was
built without A).

## Decision

**The procedure-statement consults `DispatchTrait`, in the position the
function-designator does.**

That position is the decision. The ordinary lookup is tried first, so a
program declaring its own routine of the name goes on meaning what it meant
(§6.2.2.11, and NOTE 10 already said so); the trait is asked next; the
**required procedures are asked last**, exactly as `LookupBuiltin` is on the
function side.

Asking the trait *after* the required procedures was the alternative, and it
is the smaller change — nothing already resolving could change meaning. It was
rejected because it would make one clause resolve a name in two orders
depending on which half of it you read, which is the *fact stated twice*
ADR-0388 removed from this tree once. The symmetry is the point: a reader who
knows how `Rank` is found knows how `Emit` is found.

**A trait's function reached by a procedure-statement is refused**, by the
test every other function is refused by: a call that yields a value is not a
statement. The arm is written out rather than falling through to the ordinary
one, because by then the symbol came from the trait scope and the ordinary
arm's message names a symbol the block does not have.

## What holds it

`tests/dialect/traits_procedure.pas` — the procedure half of `traits.pas`, in
the positions §6.7.10.2 names: two implementations selected by the first
actual, a third over `integer` reached by a `digit` through **host-type**
selection (NOTE 13), a procedure that calls the trait's own function through
the same lookup, and a receiver taken `protected var`.

`tests/dialect/traits_no_selection.pas` **gained more than it lost**, and the
golden was regenerated for that reason rather than to accept a new answer. One
line went — the limitation closed — and four arrived, because that case's
subject is *what a trait-keyed call cannot select* and it had been asserting
the function half of every limitation and the procedure half of none. It now
carries: a literal selecting nothing as a procedure-statement; two traits
declaring one procedure for one type selecting neither; and a trait's function
used as a statement. The third needed a type with **one** implementation to be
visible at all — over `Point` the ambiguity fires first and masks it.

Two mutations, each a working compiler and each killing different cases:

| Mutation | What fails |
| --- | --- |
| the procedure arm never asks `DispatchTrait` | `traits_procedure` and `traits_no_selection` |
| the function-as-a-statement guard dropped | `traits_no_selection` |

## What this does not do

It does not record the **use**. Sema records a use where it resolves one, and
`DispatchTrait` is the one resolution that does not — on *neither* side, which
is why the procedure arm was written to match the function arm rather than
fixed on one side alone. `--dump-uses` reports nothing for a call to a trait
routine, so `definition`, `references` and `rename` all miss one in an editor.
Pre-existing, found here by asking the dump, and now a `doc/sop.md` §7 row:
no oracle here can see it, a use that is absent looking exactly like a name
that was never written.

It does not revisit **what selects**. A literal, an expression and a
function-designator still select nothing, for NOTE 12's reason — the type is
read from the designator, before the expression is checked — and the procedure
half inherits that unchanged, which is what the extended case now pins.

It does not build the trait object. It makes a trait's routines callable,
which is what a vtable would dispatch; whether ADR-0315's increment C is built
is still open and is still not a promise either way.
