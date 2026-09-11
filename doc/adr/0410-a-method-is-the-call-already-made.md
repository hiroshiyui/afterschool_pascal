# ADR-0410: A method is the call already made

## Status

Accepted. Increment A of [ADR-0315](0315-methods-and-traits-without-inheritance.md),
the last of its three. With B (ADR-0338 – ADR-0341) and C (ADR-0408,
ADR-0409) built, that record's proposal is complete and its status for A
becomes *Superseded by this*.

## Context

ADR-0315 measured the cost of not having this: **139 of 486 exported names in
this library repeat their own module's noun** — `JsonMember`, `StreamOpenWrite`,
`NetListen`, `MapPut`. That is not a style. §6.11.2 puts every imported name
into one scope, so two modules may not export one spelling, and `export-unique`
(ADR-0298) refuses a collision outright. The prefix is a receiver, spelled by
hand, at every declaration and every call site.

A method is not an exported name — what a module exports is the *type*, and
its routines travel with it — so the collision the prefixes work around does
not arise.

## Decision

**`impl T;` is an implementation with no trait, and `x.M(a)` is the call
`M(x, a)` already made.**

Neither is a new mechanism, and that is the whole design. AP 6.7.10.2 has
selected a routine from its first actual's type since traits landed
(ADR-0340); an inherent implementation joins the list the selection already
walks, and a method-designator moves the receiver from in front of the dot to
the head of the argument list. So both spellings denote one call, a method is
callable either way, and `tests/dialect/methods.pas` writes both throughout
for exactly that reason — a case asserting only the new one would not say they
meet.

Three things invert in `CheckImplDecl` and nothing else changes: an inherent
routine **writes its own heading** where a trait's is refused one, the trait's
heading list is not consulted, and the completeness check has nothing to be
missing. `Self` is bound as it already was.

### The receiver decides which half of the compiler sees the call

This is the finding ADR-0315 does not have, and it is the one that shaped the
work. Probing the parser before designing:

| written | what the parser builds today |
| --- | --- |
| `p.M(2)` | §6.11.3's **qualified name** — `Greeting.Greet(x)`'s node |
| `k := p.M(2)` | the same, in expression position |
| `p.M` | a field selection |
| `q^.M(2)`, `a[1].M(2)`, `p.f.M(2)` | a **syntax error at the `(`** |

So a method call arrives three ways and the compiler answers each in the place
that can: a **simple** receiver is Sema's, because the parser cannot tell
`Greeting.Greet(x)` from `p.M(x)` and what separates them is what the
qualifier denotes — ADR-0044's recurring answer met an eighth time; a
**complex** receiver is the parser's, a complete variable-access followed by
`(` having exactly one reading; and a **parameterless** one is Sema's again,
its tokens being a field selection's.

That third shape is the husk (ADR-0044, ADR-0173): the node stays, the call
hangs on `fdCall`, and every later pass reads that field first — which is
`nkVar.vrCall`'s shape for a bare `argcount`, one node kind over.

**The complex receiver is not optional.** `PasContainer`'s `Vec` and `Map` are
reached as `^Vec(…)`, so `m^.Put(k, v)` is the call the feature exists for and
is exactly the shape that did not parse.

### What the spelling costs, measured

`x.M(a)` is free because **no field can be a routine**: §6.7.3.1's procedural
parameter is the only place a routine is a value (ADR-0030), so
`record f: procedure end` is not a type-denoter and `x.f(a)` is meaningful for
no `f`. Probed rather than assumed — `expected a type, found 'procedure'`. Had
this language ever had a procedural type in a record, the spelling would have
been spent.

`impl T;` costs one token of lookahead against a word-symbol, so a program
using `impl` as an identifier keeps it, and `tests/dialect/methods.pas`
declares a type and a field of that name to say so.

## The two findings that came from building it

**Chaining onto a method result needs a by-value receiver, and that is the
language's rule rather than one this construct invented.** §6.6.3.3 requires a
variable-access for a variable parameter, and a method result is a
function-access — so `p.Doubled.Len` is refused where `Len` takes
`protected var self`, and accepted where it takes `self` by value. The
alternative would be to give a function result a temporary and call it a
variable, which is a second name for a value nobody declared: exactly what
ADR-0201's aliasing rules refuse, and what §6.6.3.3 exists to prevent.

**A method result is a function-designator, and three predicates had to be
told.** `IsDesignator` must answer **false** for it, or §6.6.3.3's refusal
never fires; `IsCallValue` must answer **true**, or a method result is refused
as an actual for a *structured value* parameter, which is a copy and needs no
variable; and `CalledSym` must read the husk rather than falling through to
`vrCall`, which belongs to a different arm of the variant record and is
§6.5.3.3's wrong-arm read (ADR-0223).

The first of those was a **defect with no diagnostic in Sema**: a method
result reached a `var` parameter, and the emitted call passed an `i32` where
the callee wanted a pointer. clang refused the module, so it was loud — for a
receiver that travels by address it would have been silent. `IsCallValue`'s
own comment already said what the fix was, from ADR-0179: *the rule is about
the construct*, so a site asks it by name rather than listing node kinds, and
a new spelling joins the predicate and nothing else.

## What it cost the gates

Two if-chains moved and both are catalogued with their arguments:
`IsCallValue` 2→3 of 69 and its companion `CalledSym`, and `CheckImplDecl`'s
`symKind` chain 1→2 of 13 — where the second arm buys **wording and not
behaviour**, every arm refusing, which is why a twelfth kind needs none.

`line-coverage` found two gaps in the cases and one dead branch in the
compiler, and each was a question rather than a number: there was no
expression-position call with a simple receiver *and* arguments; there was no
`impl` naming something that is neither a type nor a trait; and a restructure
of `QuietTypeOf` had left an `else` nothing could reach. Statement coverage is
unchanged.

## What this does not do

**It does not give a method its own scope.** A method is resolved from its
first actual's type, so `M(x, a)` reaches it too and no name is hidden. The
consequence ADR-0315 names is real and is not fixed here: `Put` declared in a
dozen implementations cannot be found by grepping its name. `--dump-uses` and
the language server answer it; a person with `grep` does not.

**It does not rewrite the library.** ADR-0315 settled that one module is
rewritten as proof and the rest judged after reading it, and that judgement is
not this record's. No existing name has to move: `export-unique` reads the
export-part and a method is not in one, so `JsonMember` and `doc.Member` may
coexist indefinitely.

**It does not make a method virtual.** Which implementation answers is decided
from the receiver's *static* type, as it has been since ADR-0340. A call
decided at the time of access is AP 6.7.11's trait object (ADR-0409), and the
two are different constructs on purpose.

**It adds no representation and no lowering.** A method is an ordinary routine
with an ordinary first parameter; the emitted call is the one the prefix form
already emitted, and the only CodeGen change is two sites reading the husk
before the selection under it. ADR-0315 predicted this and it held.
