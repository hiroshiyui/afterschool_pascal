# 180. The handle rule reaches both spellings

Date: 2026-08-24

## Status

Accepted. A fix to AP 6.4.12.2, which was right; the processor implemented it
from two node kinds and reached one spelling with neither. 6.4.12.2 gains NOTE 1
and Annex F a row.

## Context

ADR-0179 fixed a value parameter that refused a parameterless function written
as a bare name, and named the same defect one clause away as left undone:

> `t := make` where `make` is a parameterless `external` function answering a
> handle is refused by AP 6.4.12.2's arm, which also tests `kind = nkCall`.

Probing it found the leftover was **two** defects and only one of them was the
one named. AP 6.4.12.2 is two sentences:

> There shall be exactly one form of assignment to a variable of a
> handle-type: an assignment-statement whose expression is a
> function-designator of an external-declaration whose result type is the same
> type. […] A function-designator whose result type is a handle-type shall
> appear in no other position.

The clause says **function-designator**, which §6.8.5 makes optionally
parenthesised — so both sentences reach a bare parameterless one. The
processor implemented each from `kind = nkCall`, and the two failures point
opposite ways:

- the **permission** was too narrow: `t := make` refused, where
  `t := make(0)` and `t := ExtOpendir('.')` are accepted;
- the **restriction** was not applied at all. `if make = nil then …` compiled
  and ran, where `if ExtOpendir('.') = nil` is refused. That is not a missing
  diagnostic: the call opens a directory, the value lands in no variable,
  nothing owns it, and nothing ever closes it. **A leak, with the whole suite
  green** — the property the handle-type exists to guarantee, absent for the
  spelling nobody had written a test for.

The second is why this is not a tidy-up of the first. ADR-0179's defect
refused a conforming program; this one accepted a program the specification
forbids, and the specification forbids it for a reason that shows up at run
time.

## Decision

**One routine for the clause's second sentence, asked of both spellings; and
the clause's first sentence asked of the construct.**

### 1. `CheckHandleBirth` is the restriction, and it has two callers

The refusal and the clearing of `handleBirth` move into one routine.
`CheckCall` calls it for a written-out call and `CheckExpr`'s bare-name arm
calls it for a parameterless one. One sentence of the clause, one routine, one
message — where before there was one site and one of the two spellings.

### 2. `CalledSym` is `IsCallValue`'s companion

The assignment arm needs more than "is this a call": it needs the routine's
`linkKind`, to say the designator is an *external-declaration*'s.
`IsCallValue` (ADR-0179) answers whether, `CalledSym` answers which. Neither
site now names a node kind.

### 3. The permission is a *syntactic* test, and has to be

This is the part a reading would have got wrong, and the first attempt did.
`handleBirth` is set **before** the value expression is checked — it is what
tells the value's own check that it stands in the one admitted position — so
at the moment it is set, nothing has resolved anything. A bare parameterless
call is an `nkVar` whose symbol Sema has not looked up yet, and `IsCallValue`
answers *false* for it. Using the predicate there refused every bare
assignment and, worse, put a diagnostic on a line of `handle_errors` that is
legal.

So the flag is set for either node kind a whole right side could be, and it is
a **permission rather than a claim**: the first designator inside the value
that turns out to be a handle-valued call consumes it, and where the value is
not one, nothing reads it and the next line clears it. The existing comment
already said "this call, **if it is one**" — the test was always provisional,
and widening it is that sentence honoured rather than a new idea.

## Consequences

- **`src/` needs nothing.** The reference front end is frozen at the
  conformance surface and has no handle-type; what a conformance mode says
  about `handle external '…'` is a refusal at the type-denoter, unchanged.
  `difftest` skips `tests/dialect/` besides.
- **CodeGen needed nothing**, for ADR-0179's reason once more: `EmitAssign`'s
  handle arm calls `EmitExpr` on the value, and `EmitExpr`'s `nkVar` arm has
  emitted a bare parameterless call since ADR-0055. `NewResultSlot` already
  declines to give a handle a slot — the answer is a word the assignment
  stores — and it declines identically for both spellings.
- **The specification was not wrong and is now harder to misread.** 6.4.12.2
  gains NOTE 1 saying that "function-designator" is the construct and not one
  spelling of it, and why: a processor read it as one, twice, in opposite
  directions.
- **This is the second of ADR-0179's class and the register entry now has two
  instances.** `doc/sop.md` §7's row says a permission *withheld* too widely
  is looked for by nothing. Half of this one was a permission *granted* too
  widely, which no gate here found either — the program compiled, ran, exited
  0 and leaked. `predicate-callers` sweeps exactly that shape for
  `Assignable`; nothing sweeps it for a rule whose enforcement site a second
  spelling simply never reaches.

## What this does not do

- **It does not audit every rule for the same shape.** Three sites in Sema now
  ask `IsCallValue`/`CalledSym` and every remaining `kind = nkCall` test was
  read: `IsDesignator`'s (where the node kind is the right question) and
  CodeGen's (where Sema has already decided). That is the whole of it, and the
  audit is an observation rather than a proof.
- **It adds no way to own a handle other than a variable.** The restriction
  stays a restriction; what changed is which programs it reaches.

## Mutation

Three, each a different line, and one of them kills two cases.

- **The bare-name arm's `CheckHandleBirth` call removed**: `handle_errors`
  loses two diagnostics, and the one it loses without substitute is the
  comparison — which is the leak, so the mutation restores exactly the defect
  this record is about.
- **The assignment arm put back to `kind = nkCall`**: `handle_bare_call` is
  refused three times with *a handle may be assigned only the result of an
  'external' function of its own type*.
- **The permission asked with `IsCallValue`** — the reading that looks right:
  `handle_bare_call` is refused three times with the *other* message, and
  `handle_errors` gains a diagnostic on a legal line. Two cases, opposite
  directions, from asking a resolved question before anything is resolved.
