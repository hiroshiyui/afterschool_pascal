# ADR-0341: A trait crosses a component, and an implementation need not

Date: 2026-09-06

## Status

Accepted. Follows [ADR-0340](0340-four-things-a-trait-heading-cannot-do.md) and
completes the design family for increment B's separate translation, which none
of [ADR-0338](0338-a-bound-belongs-where-the-type-is-written-down.md),
ADR-0339 or ADR-0340 had asked about.

Written from the implementation on the `traits-b` branch, which is the second
record in this family with that provenance and, like the first, contradicts
what was expected of it.

## Context

**None of the three records asked how a trait reaches a client**, and the
question turned out to be two questions with different answers.

§6.13 has a client translate against the **interface** alone. So an
implementation written in a module-block is invisible to every importer: the
bound cannot be checked there and a call cannot dispatch. The obvious reading
is that this makes the whole feature unusable in a library, which is where its
entire measured justification lives — 30 call sites in
`lib/dialect/pascontainer.pas` threading `StrHash, StrEq`.

**That reading is wrong, and probing is what showed it.** A module may declare
a trait in its interface, use it as a bound on a schema's discriminant there,
and have its own routines dispatch to an implementation **the client wrote**:

    module Boxm interface;
      trait Key; function Hash(k: Self): integer; end;
      type Box(KeyT: Key; cap: integer) = record … end;
      function BoxTop(Ptr: type; var b: Ptr): integer;
    …
    function BoxTop;
    begin BoxTop := Hash(b^.items[b^.n]) end;

    program usebox2; import Boxi;
      impl Key for Point; function Hash; begin Hash := k.x * 31 end; end;
      type PBox = ^Box(Point);
    … writeln(BoxTop(b))                    { 93 }

The library's own body reached the client's implementation. It works because
such a routine is **generic over its pointer**, and AP 6.7.3.5 re-reads a
generic's body in the translation that *activates* it (ADR-0211) — which is the
client's, where the client's implementations are. That is exactly the shape
`PasContainer`'s routines already have.

**So one case remains, and only one**: a module shipping its own
implementation for its clients — `impl Key for string` inside PasContainer. A
*non-generic* module routine calling a trait routine compiles and fails to
link, the call naming a routine no translation defines.

## Decision

**A trait crosses a program-component; an implementation does not, and is not
made to.**

A module-heading may declare a trait, which is what makes a trait exportable
and therefore bindable by a client. An implementation-declaration is refused in
a module-heading — it has routine bodies and a heading holds none — and one
written in a module-block is that module's own.

**The module-side implementation is recorded as not provided**, with its clause
note and an entry in `doc/implementation-defined.md`, rather than built.

**The argument is ADR-0116's and not cost.** What the module-side
implementation buys is that PasContainer could supply `impl Key for string` so
that clients need not. A client writing one `impl Key for MapKey` block still
removes `StrHash, StrEq` from all 30 call sites — **the whole measured payoff
survives without it**. That makes it a convenience with no caller asking, which
is a row and not a design.

## Consequences

**Two ways to build it were put and one of them does not exist.** The
alternatives were a derived linkage name and a per-impl scope surviving
translation. `NameForLinkage` derives a cross-component name from *(interface
name, export item name)*, so anything callable across components must be an
export-part item. Separate translations share no symbol table: a client
reconstructs symbols from the interface and still needs a name both sides
agree on. **The scope option therefore collapses into the naming option plus
extra machinery**, and that was not visible until the routine was read. Should
this be reopened, there is one candidate and not two.

**An implementation is a fact about one translation.** That is now a rule
rather than an accident, and it is what makes the refusals below correct rather
than expedient: an implementation may be written where a whole translation can
see it — a program-block or a module-block — and nowhere else.

**Three defects were found by building this, and each was invisible to reading.**

- **An implementation nested in a procedure gave a wrong answer with a zero
  exit status.** The table is one unscoped list, so such an implementation was
  handed to callers outside the procedure whose frame its routines need; a
  sibling's call read the implementation's locals through its own frame,
  printing 14 where the answer was 106. Called from the program block instead,
  it emitted IR naming a `%frame` no value defines, which clang refused and the
  compiler had not. Refused now.
- **A module-heading did not interleave its declarations by written position.**
  It checked the constant, type and variable parts and then walked the
  routines, so a trait was invisible to anything declared above it in its own
  interface — and a schema discriminant's bound stands in the type part. A
  module could declare a trait and not use it. The chain is handed to
  `CheckDeclarations` now, as a block's is (§6.2.2.9, ADR-0100).
- **A call that selected two implementations selected the last one declared,
  silently.** Two traits may each declare a routine of one name and one type
  may implement both. It is refused.

**`SpliceImpls` is now conditional, and the reason is worth keeping.** It ran
at the end of every `CheckDeclarations`, including the one a module-heading
makes with no routine chain — emptying a chain nobody had read yet, so a trait
written in an interface vanished before the loop that would have declared it.

## What this does not do

**It does not decide how a module-side implementation would be spelled.** If it
is built, the clause is the §6.11.1 split — the implementation's routine
headings in the module-heading, their bodies in the module-block — and the
open part is the linkage name, above.

**It does not settle `impl` for a schema.** ADR-0338 decided `impl Key for
string`, and it is refused today: `'string' is not a type, so a trait cannot be
implemented for it`. With the module-side implementation deferred, a client
that wants a string key implements the trait for a string *type* of its own
naming, which every client already has. The two are recorded together because
the same decision governs them.

**It does not change what works.** Everything single-component is untouched,
and the cross-component shape above is now the tested one.

## Alternatives rejected

**A derived linkage name** — the implementation's routines become export-part
items with compiler-derived spellings. It fits: `NameForLinkage` needs no
change, derived names are unique by construction so `export-unique`'s rule
holds, and being synthesized they never reach that gate's reader. Rejected only
because nothing has asked for what it buys; it is the candidate if this is
reopened.

**A per-impl scope surviving translation.** Rejected as above: it does not
avoid the naming question and adds a lifetime the module record does not have.

**Requiring every implementation to be written in the program.** Rejected
because it is already what happens and does not need saying — and because
saying it would forbid a module implementing a trait for its *own* type, which
works today and is a module's own business.
