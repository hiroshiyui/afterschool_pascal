# ADR-0323: `take` inside a generic

Date: 2026-09-04

## Status

Accepted. Amends AP 6.4.14.6 with a paragraph and four NOTEs. ADR-0182 is not
superseded: the operation, the position rule and the order are all unchanged,
and what is added is a reading of the same word inside a generic's body.

## Context

`doc/roadmap.md`'s second memory-safety row asks whether a general-purpose
container should own its storage, and priced the conversion of `PasContainer`
at "about 22 sites, `v := take(fresh)`". **It is two sites**, and neither the
count nor the shape was the obstacle.

Making them `take` converts the module and *unconverts* every other client:

    lib/dialect/pascontainer.pas:359:15: error: 'take' empties an owned pointer
    or a handle and this is pvec: nothing else has a value one variable can
    stop holding

`PasContainer` is one module written once over a type argument, and it has both
kinds of client in this tree. `examples/word_freq.pas` wants the block to own
its map and its vector. `lib/dialect/pasjson.pas` cannot: its `JsonChars` is a
field of a variant part and AP 6.4.14.2 refuses an owned pointer there, so a
JSON document's growable vector is an ordinary `^Vec(char)` and always will be.

So the question is not which the container should be. It is that **the two
dialect features do not compose**: 6.4.14's ownership and 6.7.3.10's generics
meet in exactly one operation, and that operation cannot be written.

`take` is the only operation in this language whose *applicability* is a
property of the type it is applied to. Every other one either works for every
type or is refused by a category (AP 6.7.3.10.5, ADR-0266) that an
instantiation is checked against at the call. A body that must replace what a
variable holds — which is what every growable container does — has to write
either `v := fresh` or `v := take(fresh)`, and each is refused by half of the
instantiations.

## Decision

**Within the body of a generic, `take` is applicable to a variable of a type
that is not affine, and denotes that variable's value.** The variable is
unchanged and is not threatened. Everything else about the operation stands:
the position rule, the order, the type requirement, and the refusal outside a
generic.

Read inside a generic, `take` means *move where the type moves*.

Four things make it narrow rather than a general widening.

**It is a reading and not a lowering.** Where the argument is not affine, Sema
replaces the assignment's value with the argument — ADR-0044's husk — so what
CodeGen sees is the assignment written without the word. `EmitCall` still has
no arm for `biTake`, which is the property AP 6.4.14.6 relies on to make every
position but the two affine arms of `EmitAssign` unreachable: a `take` that
escaped this collapse stops the compiler rather than emitting a move nobody
can see. `verify/lowering.py` is untouched because there is nothing new to
model.

**The condition is `not IsAffine` and not `not IsOwned`**, which is ADR-0181's
split read once more. A **file** is affine, has a value one variable would
have to stop holding, and has no representation in which it can — so `take` of
one is refused inside a generic exactly as outside it, by the same words.

**The threat is the emptying**, so §6.9.4 a) is asked only where something is
emptied. A generic may `take` its own protected variable-parameter, and the
same body at an owned-pointer type argument may not. That is the one place in
this language where a statement's acceptability is a fact about the
activation-point rather than about the statement, and AP 6.7.3.10.2 already
reports it at the generic's declaration with the activation named after it.

**`genDepth` is a counter and not a flag**, a generic being free to activate
another.

## Consequences

**`PasContainer` is written once for both, at two lines.** `VecReserve` and
`MapPut` say `v := take(fresh)`; every other routine is untouched, and the
module's ordinary-pointer clients compile as they did.

**`examples/word_freq.pas` is the client.** Its `CountMap` and `WordVec` are
`owned` now, the two `Free` calls at the foot of the program are gone, and
`heap_balance.txt` records the same balance it did before — which is the
result: what was written by hand is now performed by leaving the block, and
neither more nor less is given back.

**`lsp/pasls.pas`'s two are still not converted, and the roadmap's table was
wrong about why.** `PathVec` is a *field* of `Document`, and `DocMap` holds
`Document` values in a map — so an owned `PathVec` makes `Document` affine and
takes away the whole-record assignment the map is built on. That is AP
6.4.14.3 doing its job and not a restriction to lift. It is the table's third
error in two days, and each was a reason written by hand beside a count taken
by machine.

**A reader of a generic body can no longer tell from the line whether a move
happens.** That is the cost, it is real, and it is unavoidable: the body is
written before the type is known, and a spelling that told the reader would be
a spelling that could not be written once.

## What this does not do

**It does not widen `take` outside a generic.** `x := take(y)` for two
integers in ordinary code is refused by the message it always was, and
`tests/dialect/take_errors.pas` still pins it.

**It does not make a container owned.** Whether `PasContainer`'s storage is
owned is still the caller's choice per instantiation, which is what the
roadmap row says and what this change makes true rather than aspirational.

**It adds no category.** A constraint (ADR-0266) names operations a body may
use so that an instantiation outside it is refused at the call. The opposite is
wanted here: the body must be admitted for *every* type, so the operation is
made total over the non-affine ones instead of a category being invented that
half the clients would fail.

**It does not touch `release`, `dispose` or the spawn position.** `take` as the
actual of a spawn-statement is a handle's alone and unchanged.

## Alternatives rejected

**Convert `PasContainer` to owned-only.** `lib/dialect/pasjson.pas` is a
shipped module that cannot follow, so this makes the generic container
unavailable to the one library in this tree that most needs it.

**Two modules, one owned and one not.** It is the copy-a-file answer this
module exists to have removed — its own header says so, four monomorphic
containers having been what it replaced.

**A category, `T: affine`.** It refuses the ordinary instantiation at the call,
which is the problem restated rather than solved.

**Make `take` total everywhere.** One rule instead of two, and it costs the
word its meaning in ordinary code: `x := take(y)` would read as a move that
does not happen, in the one construct in this language whose whole purpose is
to make a move visible.

**Admit the copy silently — let `v := fresh` mean a move at an owned type.**
It is Rust's rule, where the assignment moves or copies according to the type,
and it is the one this language decided against in ADR-0182: a move is spelled
because it is the operation a reader must not miss. Making it invisible inside
a generic is where that would start.
