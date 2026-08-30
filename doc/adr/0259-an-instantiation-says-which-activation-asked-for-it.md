# 259. An instantiation says which activation asked for it

Date: 2026-08-30

## Status

Accepted, 2026-08-30.

It closes the `doc/sop.md` §7 row *a generic's diagnostic names the generic and
not the call that asked for it*, which
[ADR-0254](0254-a-generic-activation-need-not-write-its-types.md) had just made
worse and said so.

## Context

AP 6.7.3.10.2 checks a generic's body once per distinct type-argument-tuple, in
the region and the source the generic was *written* in (ADR-0210). So every
diagnostic inside it is reported at the generic's own line, and nothing said
which activation had asked for that translation:

```
sum.pas:5:12: error: operator '+' needs numeric operands, found point and point
```

With two activations naming two types, the reader is left to work out which one
this was about. §7 recorded that as an ergonomic gap and noted that the
machinery for an instantiation backtrace — a stack of demanding call sites —
did not exist.

**ADR-0254 made it materially worse**, which is what turned the row from a
grumble into a demand. An inferred activation writes no type at all, so a
reader working backwards from an error inside a generic has neither a type
argument nor a call to look at.

## Decision

`InstantiateGeneric` takes the error count before checking the body and
compares it after. If the body produced diagnostics, one more is reported at
the **activation's** position:

```
sum.pas:5:12: error: operator '+' needs numeric operands, found point and point
sum.pas:5:3: error: cannot assign integer to a result of type point
sum.pas:47:9: error: this activation is what asked for that instantiation of 'add'
```

Three things about the shape.

**It is an ordinary diagnostic line, not a new kind.** The format is
`file:line:col: error: message` and nothing else — so `paslspdiag` parses it,
the language server publishes it, and every golden holds it, with no reader
taught anything. A `note:` severity would have been a second format for two
callers to agree about, which is the drift ADR-0258 and ADR-0230 are about.

**It is reported after the source is restored.** `ErrorAt` names whichever
source is current, and inside the body that is the generic's (ADR-0210). The
line belongs to the caller's file, so it is written once `curFile` is back.

**A generic activating a generic produces one line per level**, innermost
first, which is the backtrace other languages carry — arrived at by putting the
report where the recursion already is rather than by building a stack.

## Consequences

**One attribution per tuple, not per activation**, and that is AP 6.7.3.10.2
working rather than a gap. A second activation naming the same types finds the
instantiation in the cache, never re-checks the body, and is silent: there is
nothing new to report and a second copy of the same errors would be noise. The
activation named is therefore the one that *produced* the tuple.
`tests/dialect/generic_errors.pas` stages exactly that — three activations of
one generic over two types, and two attributions.

**A cheaper answer than the one the row implied.** §7 described the fix as a
stack of demanding call sites, and the demand behind it is only *which
activation was this about* — which the recursion already knows at the moment it
matters. No stack, no new state, six lines.

**It does not attribute a diagnostic to a nested activation's own arguments.**
The line names the activation and the generic; it does not say which *type
argument* was the problem, because the errors above it already name the types.
Nothing has asked for more, and a fuller backtrace would want a format this
deliberately does not have.
