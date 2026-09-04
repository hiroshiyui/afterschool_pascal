# ADR-0321: What adopting the owned pointer found

Date: 2026-09-04

## Status

Accepted. Amends AP 6.4.14.1's production. Follows ADR-0318 and ADR-0320, which
between them removed both restrictions that kept `owned ^T` out of the library,
and reports what happened when the adoption they were for was attempted.

## Context

ADR-0320 ended by saying the library is not converted here, and that the
conversion belongs in its own increment. This is that increment, and it did not
go as the roadmap row said it would. Of the nine types that clause made legal,
**two** were converted, **three must not be**, and **four wait on a single
module** — and the reason for each is different from "the accessors need
rewriting".

## Decision

**AP 6.4.14.1's domain is a domain-type (6.4.4.1) and not a type-identifier.**
The clause's production was narrower than the processor, which has accepted
`owned ^Vec(integer)` since 6.4.4.1 was written: that clause defines the
domain-type for *every* pointer-type, and the owned one restated a narrower form
by hand. Nothing changes in the compiler; the specification is corrected to what
it always described. This is a divergence in the direction the project's rules
say is possible and hardest to see — the specification is written from the
records and verified by probe, and this one was found by probing the neighbouring
amendment rather than by reading either clause.

It matters beyond tidiness: the type discriminants of a schema decide the
identified variable's *layout*, which a pointer-type must know, while the ordinal
ones decide its extent, which `new` chooses. So `owned ^Vec(integer)` is what a
growable **generic** container is owned as, and the clause as written forbade
exactly the case ADR-0320 was for.

**`examples/arena_graph.pas` is converted**, and it is the reason this record
exists rather than a note in the last one. The example was written the same day
and said, as a cost of the shape:

> The arena cannot itself be owned: its type is a schema, which AP 6.4.14.2
> refuses

which ADR-0320 made false hours later. The arenas are now `owned ^Nodes` and
`owned ^Arcs`, the `defer dispose` pair is gone, the three accessors take
`protected var`, and the output and heap balance are unchanged. **A document
that states a restriction is a claim that expires**, and this one expired inside
a day.

## Consequences

**Three containers must stay conforming, and that is a layer rule and not a
gap.** `lib/pasvector.pas`, `lib/pasmap.pas` and `lib/passtrvec.pas` are the
top-level library, which ADR-0120 keeps free of dialect constructs so that a
reader can port it to another Pascal; `owned` is a dialect construct. Converting
them would move three containers into `lib/dialect/` and out of reach of a
conforming program. The roadmap's second row had counted them as candidates.

**Four wait on `PasContainer`, and the wait is a design question rather than a
restriction.** `CountMap`, `WordVec`, `PathVec` and `DocMap` are all `^Vec(…)`
or `^Map(…)` reached through that module, whose routines assign to the pointer —
`dispose(v); v := fresh` in `VecReserve` — which an owned instantiation refuses.
The change is mechanical, `v := take(fresh)` at about 22 sites, and it is not
made here because it would decide something for every caller of the generic
container at once.

**The question it decides**: should a general-purpose container own its storage?
An owned one cannot be aliased, cannot be returned from a function and must
travel as a variable parameter. That is right for a tree one block owns and a
real loss for a container callers pass around. `PasList` was written owned and
has no `Free`; `PasStrVec` was written indexed and has one, and the roadmap
already tells a program wanting an index to use the second. That both kinds
exist is not a gap in the library.

**So the memory-safety row's remaining item is a choice per container**, not a
restriction to lift, and the fifth warning is dead for a third reason: not that
nothing *could* take the word, nor that a rewrite is needed first, but that
taking it is sometimes the wrong answer and a warning cannot know which.

## What this does not do

**It does not convert `PasContainer`.** The mechanical part is written down
above so that whoever decides can price it; the decision is not this record's.

**It does not touch `PasJson`**, still refused by the variant-part half of
6.4.14.2.

**It changes no behaviour.** The grammar amendment documents what the compiler
did; the example conversion is an example. The only compiler-visible artefact is
a new case pinning the generic domain, which passed before this record as well —
and that is exactly why the divergence had survived.

## Alternatives rejected

**Narrow the compiler to AP 6.4.14.1 as written**, refusing
`owned ^Vec(integer)`. It would make the specification true at the cost of the
feature ADR-0320 had just enabled, and 6.4.4.1's NOTE 3 already says why the
type-discriminant form exists: without it a generic routine reaches a container
of one fixed capacity and no other.

**Convert the three `lib/` containers anyway**, treating ADR-0120's split as
advisory. It is not advisory: it is the only statement this project makes about
which of its code is portable, and the split is what a reader is told to read it
by.

**Leave `arena_graph.pas` as it was**, with a `defer` and a sentence that is no
longer true. Rejected on the obvious ground, and worth naming because the
alternative was tempting: the example still *worked*, and only its explanation
was wrong. An example whose explanation is wrong teaches the wrong thing more
efficiently than code that fails.
