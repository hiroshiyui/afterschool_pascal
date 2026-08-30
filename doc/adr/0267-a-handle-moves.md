# ADR-0267: A handle moves

Date: 2026-08-30

## Status

Accepted. Widens ADR-0182's `take` from an owned pointer to a handle, which is
the prerequisite ADR-0201 named for a concurrency construct.

## Context

ADR-0182 gave the dialect a move, and gave it to one type:

```
'take' empties an owned pointer and this is text:
nothing else has a value one variable can stop holding
```

That sentence was written of the three affine kinds together and is true of
only one of them.

A **file-variable** is `IsMemory` — several storage units the processor is
holding — and there is genuinely no value in one for a variable to stop
holding. But a **handle** is one word: `struct pas_handle` is a value, a
closer and two list links, and what the variable owns is the value. That is
what an owned pointer is, one word of the heap, and the reason neither may be
copied is precisely the reason both need a move.

So the refusal was over-broad by one kind, and nothing had noticed because
nothing had wanted it. ADR-0201 is what wants it, in as many words:

> A task cannot be **given** a socket or a file until a handle can move.
> Whatever demands concurrency will meet that first, and it is a smaller
> increment than the construct.

`doc/roadmap.md`'s "to hand an owned value to something else" row is the same
gap seen from the library: it recorded that a k-way merge over open streams is
writable today at the cost of one indirection — a heap over *positions* in an
array rather than over the records themselves, because the records hold
`Stream`s and `Swap` cannot exchange two of them.

## Decision

**`take` applies to a variable of a handle-type as it applies to one of an
owned-pointer-type, and to nothing else.** AP 6.4.12.7.

The test is `IsOwnedPointer or IsHandle` and **not** `IsAffine`, and that is
the decision rather than an implementation detail: `IsAffine` is the file's
predicate too, and widening to it would admit the one kind that has no value to
move. The clause says so, and the refusal's own wording now names the two kinds
it admits.

Everything else is ADR-0182's, unchanged. The position is the same — the whole
right side of an assignment to a variable of its own type, and nowhere else,
because anywhere else what it emptied would be owned by no one. The permission
is the same `takeOk` flag, set syntactically before the value is checked. And
`Threatened` still refuses a `take` of a for-statement's control variable or of
a protected parameter, because emptying a variable threatens it.

### The lowering is two calls and the order is the whole of it

```llvm
%v = call ptr @pas_handle_take(ptr %src)
call void @pas_handle_set(ptr %dst, ptr %v)
```

`pas_handle_take` empties the source **without calling the closer**, which is
what makes this a move rather than a release; `pas_handle_set` then releases
what the target held and stores.

Emptying first is ADR-0182's decision read one type over, and it is what makes
`h := take(h)` a no-op: the source is emptied, so the release inside
`pas_handle_set` finds nothing and the value goes back where it was. Doing it
the other way round closes the very handle being moved — and that is the
mutation, which fails `tests/dialect/handle_move.pas` at the self-move line
with the runtime's own words, *the handle is empty, and a foreign routine may
not be lent it*.

It is deliberately not one runtime routine. A `pas_handle_move(dst, src)` would
hide the order inside C where the clause could not state it, and the order is
the correctness property.

## Consequences

`tests/dialect/handle_move.pas` is the case: a move, the source emptied, the
moved handle still live, a self-move, a target whose own handle is released
first, a move across a call through two `var` parameters, and a move of an
empty variable. `tests/dialect/handle_move_errors.pas` is the other half —
a file refused, an integer refused, a plain copy still refused, `take` of a
value rather than a variable, `take` in an argument position, and a move
between two different handle-types.

Three scenarios in `tests/spec/features/dialect_handle.feature` cite AP
6.4.12.7, and the third is the one that matters: a file is still refused.

**Two goldens were regenerated and the reason is the rule, not the wording.**
`handle_errors.err` and `take_errors.err` each held a message that is now
false: a handle may be assigned three things rather than two, and `take`
empties two kinds rather than one. The new text says what the language now
does.

`tests/checks/partial_cases.txt` gains an entry for `EmitAssign`. The new arm
tests `s^.asValue^.kind = nkCall`, which is ADR-0230's if-chain shape, so
`kind-exhaustive` now sees `EmitAssign` as a dispatch over `nodeKind` — two of
sixty-three. The entry argues that it is not one: the routine dispatches on the
**target's type**, the two `kind` tests identify the one construct AP 6.4.12.7
and AP 6.4.14.6 each admit in that position, and the trailing `else` is the
ordinary assignment every other node kind is meant to take.

### What it does not do

**A file still has no move and will not get one.** It is not an omission to be
filled later; there is no value in a file-variable for a variable to stop
holding, and a "move" of one could only mean closing and reopening, which is
not what the word means anywhere else in this language.

**It does not make a handle copyable, and does not weaken anything.** At no
moment do two variables hold one value: `take` empties before the target takes,
which is why this is the move the affine model admits rather than a hole in it.

**It does not, on its own, let a task be given a handle.** AP 6.4.14.6's
position rule stands, so `take` may not yet appear as an actual-parameter. That
is the concurrency construct's to widen, and it is stated here so the next
reader does not conclude the prerequisite is more than it is.
