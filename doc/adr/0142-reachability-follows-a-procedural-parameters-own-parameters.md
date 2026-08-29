# ADR-0142: Reachability follows a procedural parameter's own parameters

Date: 2026-08-20

## Status

**Deprecated.** It was accepted, correcting a defect in
[ADR-0137](0137-a-module-is-mode-locked-by-what-it-exports.md) found by the
specification audit recorded in
[ADR-0144](0144-the-first-audit-of-the-dialects-specification.md), and
is retired by [ADR-0232](0232-afterschool-pascal-is-the-language.md) with the
record it corrected. `SymCarriesTag` and `TypeCarriesTag` are both gone from
the compiler: the walk existed to decide whether a module's interface could be
linked by a program in the *other* conformance mode, and there is no other
mode. The reading below is still true of the language -- a procedural
parameter's own parameters are part of what its interface reaches -- and
nothing asks the question any more.

The defect it records is worth keeping for its shape rather than its subject.
A reachability walk that asked a *type* where it should have asked a *symbol*
missed everything reachable through a procedural parameter's own parameter
list, and was found by an audit rather than by a test.

## Context

ADR-0137 made a module's mode-lock a property of its **interface** rather than
of the flag it was translated with: a module whose interface exposes no record
with a tagged variant-part emits its activation names under the dialect's
spelling as well as its own, so `lib/`'s six conforming modules became
reachable from an Afterschool Pascal program.

AP §6.13.1 ¶2 states the condition:

> A module's interface exposes nothing checked when no type reachable from it —
> through a field, an array component, a file component, a pointer domain or a
> **parameter** — is a record-type having a variant-part with a tag-field.

`ComputeModePortable`'s walk asked each parameter about its own `stype` and
stopped there:

```pascal
p := sym^.params;
while (p <> nil) and not got do begin
  if TypeCarriesTag(p^.sym^.stype, 64) then got := true;
  p := p^.next
end
```

A **procedural** parameter's own parameters are in *that parameter's* `params`
list, which is never entered, and `TypeCarriesTag` has no arm for `tyProc` —
correctly, since a procedure type is not a type a value is held in. So

```pascal
procedure ApplyR(procedure Q(var t: Tagged));
```

reaches `Tagged` through two parameters and the walk reported the module
portable.

**The consequence is the one ADR-0119 exists to prevent, reached anyway.** A
module translated `--std=extended` linked into a dialect program, wrote a real
into a record whose tag said the integer arm — which only a component *without*
the dialect's write rule can do — and handed it to the program's callback. The
program's guard ran, consulted the tag, and **passed** the read:

```
Q sees i = -266631570
```

`0xF01B866E`, the low word of the double `3.14159`, typed as an `integer`,
exit 0. ADR-0137's own record says of exactly this shape: *"a check answering
`safe` for an unsafe read, which is the only outcome ADR-0118's claim cannot
survive."*

The comment above the procedure already stated the intended rule — "A
constituent that is a procedure or a function is asked of its parameters and of
its result as well as of itself, because a variant record crosses at an
argument exactly as it does at a variable" — and the code implemented a weaker
one. The *function* case was half-covered by accident: a function's `stype` is
its result type, so `Apply(function G: Tagged)` was caught while
`Apply(function G(var t: Tagged): integer)` was not.

## Decision

**`SymCarriesTag` recurses.** Each parameter is asked as a *symbol* rather than
as a type, so its own parameter list and result are walked, to any nesting
depth a source can write.

It is depth-bounded and **answers true when it cannot tell**, matching
`TypeCarriesTag`: an exhausted depth locks the module rather than freeing it. A
parameter list cannot be cyclic the way a pointer domain can — the source has
to write each nesting out — so the bound is unreachable in practice. It is
there because a walk that can only be wrong in the safe direction is worth more
than one that is merely provably terminating.

## Consequences

`tests/checks/mixed_mode_link.sh` grows from seven combinations to eight, over a
new three-component corpus: `tagbase.pas` holds the record, `callback.pas`
imports it and exports **only** `ApplyR`, and `callbackuser.pas` is the dialect
program.

**Three components, and the third is the point.** The first version of this test
put the record in the module under test, which exports the type — and a module
exporting the type is locked by that constituent alone, whichever way the
parameter walk goes. It passed against the unfixed compiler. The mutation step
caught it; nothing else would have, and it is the clearest instance in this
repository of `doc/sop.md`'s rule that a test which has never failed is a test
of nothing.

**Mutation**: restore `TypeCarriesTag(p^.sym^.stype, 64)` in place of the
recursive call. **All 621 cases pass**, `dialect-containment` included, and
`mixed-mode-link` fails — printing the wrong value the link produced. Restored
with plain `cp` and `touch`, rebuilt, green.

`lib/`'s six modules each still emit their two aliases, so ADR-0137's payoff is
untouched.

## What this does not do

**It does not close the other under-strict reachability the audit found.** A
module exporting an **undiscriminated schema** whose record has a tagged
variant-part — `Box(n: integer) = record … case k: Sel of …` — is still reported
portable. No misbehaving program was built from it: every way of giving the
module something to write re-discriminates the schema and is then caught, so it
appears reachable only in combination with the defect fixed here. It is a link
AP §6.13.1 forbids and it is recorded in `doc/sop.md` §7 rather than fixed,
because the fix belongs with a probe that demonstrates the harm.

**It does not add a gate over the walk itself.** What is checked is the
*outcome*, one shape at a time, in `mixed_mode_link.sh`. A reachability walk
with eight shapes checked is not a walk proved correct, and the audit found this
shape by enumerating the ways a type can be reached rather than by running
anything — which is the method to repeat, not a check to install.
