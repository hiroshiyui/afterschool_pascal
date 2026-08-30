# 255. A function may answer a handle

Date: 2026-08-30

## Status

Accepted, 2026-08-30.

It is the first half of `doc/roadmap.md`'s *factory* item — the one entry on
that page with a named cost — and is superseded by nothing.
[ADR-0256](0256-a-fallible-value-may-be-owned.md) is the other half and ships
with it, because this one alone would be a regression.

## Context

Every producer in `lib/` makes its caller declare a variable and pass it as a
`var` parameter:

```pascal
procedure StreamOpen(path: PathName; var s: Stream; var e: ErrorCode);
```

Nobody wrote it that way by choice. `function Open(path: PathName): Stream` was
refused, and the refusal's own message said why — *only an `external` function
answers one, and only to a handle variable* — which is AP 6.4.12.2's rule that
a handle-valued function-designator may stand in exactly one position, because
anywhere else there is nothing to own what it answered.

## Decision

A function-declaration that is not an external-declaration may have a
handle-type as its result type (AP 6.4.12.6).

**It cost no new lowering, and the reason is worth stating because the roadmap
predicted it and was right.** A handle is `IsMemory`, so a function answering
one was *already* receiving the address of the variable its result is to
occupy — that is how every result that does not fit a register is passed. The
factory's own `Open := ExtFopen(path, 'r')` is AP 6.4.12.2's assignment made
through that very address. So the value is born in the variable that will own
it and is never held anywhere else, which is precisely the property
6.4.12.2's position rule exists to guarantee. A factory over a factory passes
the address on and holds nothing at any depth; the emitted IR for
`OpenAgain` contains no `pas_handle_set` at all.

**Nothing is stored at the call, and that is the correctness crux rather than
an optimisation.** A `pas_handle_set` after the call would release what the
callee had just written into that same slot. `factory_handle.pas`'s
re-assignment case is what fails when it is put back, and the mutation was
run.

**How CodeGen learns where to build it.** `factoryInto` is a file-scope
variable set by `EmitAssign` immediately before the value is emitted and
read-and-cleared by `EmitUserCall`. That is deliberately the shape Sema's
`handleBirth` has, and it is the same statement seen from the other end of the
pipeline: a handle-valued call may stand in exactly one position, so the
*statement* knows the destination and the call does not. Threading it as a
parameter instead would have meant a second reader of "which node kind holds a
call" — `EmitExpr` dispatches that three ways — and that is the drift ADR-0230
is about.

**Sema decides, CodeGen obeys.** `nkAssign` gains `asFactory`, set where the
assignment is admitted. The question is *was the callee an external
declaration*, and CodeGen never asks about a symbol's linkage what Sema could
have answered.

**A bare handle only.** A record containing one is still refused, and the
reason is not squeamishness: a handle result has exactly one destination and
its address can be handed over, and a structure has no such destination for
each of its components. The message had to learn to say which affine kind it
found, which is `ContainsHandle` — until now a bare handle took that branch
and a record was told it contained a file it had not got.

## Consequences

**Three claims in the roadmap were checked rather than trusted, and all three
held**: a handle result already takes an address; `CloseFiles` already skips
the result variable, it being a `var` parameter; and a factory over a factory
passes `%res` through. The third needed the arm that does it, which did not
exist — `EmitUserCall` would have dereferenced a nil `slotSym` — so "free once
the arm exists" is the accurate form of it.

**A gate found a name too long for a buffer.** `IsHandleBirthTarget` is
nineteen characters and `msgLit` holds sixteen, so `--dump-predicates` stopped
the compiler. It is `IsHandleBirth` now. That is ADR-0012's fixed buffers doing
what they are for, in the smallest possible way.

**`predicate-kinds` gained a row** because the new question *is* a type
predicate and belongs where that gate can watch it — which meant moving it from
ApFront to ApTypes and exporting it, rather than renaming it out of the gate's
sight.

**What this does not give** is the thing `lib/` actually wants, and that is
ADR-0256: a factory that can answer only `nil` says that something went wrong
and never what, which is worse than the `var` parameter and status code it
replaces. Neither record is worth shipping without the other.
