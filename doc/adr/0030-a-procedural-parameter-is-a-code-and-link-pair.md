# 30. A procedural parameter is a code-and-link pair

Date: 2026-08-10

## Status

Accepted.

## Context

Procedural and functional parameters (ISO 7185 §6.6.3.1) are the third of the
features left after sets and `goto`. A procedure may be passed to another
procedure and called there:

```pascal
procedure Apply(var a: vector; function f(x: integer): integer);
```

Two things make this more than a function pointer. The first is that a passed
procedure may be *nested*, and its body reads the variables of the block it
was declared in — so calling it needs a static link that the caller cannot
derive, because the caller's own chain says nothing about where the passed
procedure was declared. The second is that a procedural parameter has no type
in the type part: the heading *is* the type, and §6.6.3.6 compares two of them
by *congruity* of their parameter lists rather than by identity.

## Decision

**The value is a pair: the code, and the static link to call it with.** Naming
a procedure with a body takes its address and the frame it was declared under
— `staticLinkFor`, the same computation an ordinary call already does. Naming a
*procedural parameter* forwards the pair that parameter already holds, so a
procedure handed on through three levels still runs in its own scope.

**The pair never exists as an LLVM value.** One frame slot of type
`{ptr, ptr}`, written and read through its own two getelementptrs, and *two*
arguments in the signature. Nothing then depends on how a struct is passed —
which matters because the textual `.ll` backend (ADR-0006) would otherwise
need `insertvalue`/`extractvalue` and an opinion about the C ABI. It is why
`appendParamTypes` exists: a caller and a callee agree on the shape only by
both coming through one place.

**A call through a procedural parameter is an indirect call** whose signature
is rebuilt from the parameter's own formal list, with the loaded link in place
of the static one. Everything else — the by-address rule for `var` and
structured parameters, the range check on a value parameter — is the code that
was already there, because `emitUserCall` was made to take the target and the
signature as variables rather than to look them up.

**Congruity is checked on symbols, not on types.** ISO §6.6.3.6 compares
parameter lists pairwise: the same count, the same passing mode, the same type
— and, for a procedural parameter of a procedural parameter, congruity again.
`Symbol::params` already holds exactly that, so the rule is written over it and
`Type` for a procedural parameter carries only the result type, for the
diagnostic. Sets needed `assignable` to learn a structural rule (ADR-0028);
this one does not touch `assignable` at all, because a procedural parameter is
never assigned.

**An actual procedural parameter is resolved against its formal**, not on its
own. `f` written as an argument denotes the function; written anywhere else it
is a call of it. That is why `checkArguments` now checks each argument knowing
which parameter it is for, instead of checking them all first — the one place
in Sema where an expression's meaning depends on where it sits.

**The formals of a procedural parameter are descriptors.** They say how an
argument travels and what type it has; the frame they will occupy belongs to
whatever procedure is eventually passed. So they get no slot and no scope, and
two of them sharing a spelling cannot be ambiguous — the actual procedure
supplies the names its body uses.

## Consequences

**A procedure's address now outlives the call that made it** — the first time
that is true here. It is safe only because Pascal has no way to store the pair:
there is no procedure type in the type part, so the pair cannot be assigned to
a variable, put in a record, or returned. Its lifetime is bounded by the call
it was passed to, and the frame it points at is still on the stack for all of
it. **Extended Pascal does not change this and ISO 7185 has nothing further to
add, but a later language that gains a procedure type would have to answer the
question this decision is currently allowed to ignore.**

**There is deliberately no SMT rule.** The catalogue proves lowerings of
arithmetic, conversions and comparisons against a property-style statement of
the standard; a procedural parameter involves none of those, and a rule saying
"the link stored is the link loaded" would restate the lowering and prove
nothing — the mistake ADR-0013 warns against and ADR-0019 declined for pointers
for the same reason. It is covered by the cross-check instead: `tests/procparam.pas`
is run under both backends, and the differential dump carries the checks.

**Fourteen mutations, all caught — but three only after the corpus was
extended.** Congruity compares four things in order, and the first three
badsema cases differed in more than one of them at once: the parameter-count
check rejected them before the result-type, parameter-type and recursion checks
were reached. A mutation of each survived a green suite. `CharOf`, `TakesChar`
and `DeepDiff` each differ in exactly one thing, which is what makes the check
for that thing the only one that can reject them. This is the fourth time
counting the branches a corpus reaches has found one uncompared; it is not a
coincidence, and the rule is in CLAUDE.md for a reason.

**What ISO 7185 has left is non-text files and the non-local half of `goto`.**
Neither is blocked by this.
