# ADR-0411: An implementation travels with its type

Date: 2026-09-12

## Status

Accepted. Reopens the one case
[ADR-0341](0341-a-trait-crosses-a-component-and-an-implementation-need-not.md)
deferred, and builds the candidate that record named for it. ADR-0341's other
decisions stand: an implementation is still a fact about one *source* — refused
in a procedure and refused in a module-heading — and what changes is which
translations may read it.

Written from the change, after the two probes below; the design question it
turns on was not visible from either record.

## Context

**The object model does not cross a program-component, and nothing said so.**
The library judgement ADR-0315 left open — one module rewritten with methods as
proof, the rest judged after reading it — begins with a module, and a module is
§6.13's separate translation. So the first thing to ask is whether a client can
call a method at all. Two probes, both a few lines:

    { probemod.pas }  impl Counter; procedure Bump(…); function Get(…); end;
    { probeuse.pas }  import ProbeMod;  c.Bump(4);  writeln(c.Get)

    probeuse.ll:31:19: error: use of undefined value '@p4'

and, for a trait implementation written in a module:

    /usr/bin/ld.bfd: undefined reference to `p2'

Sema accepted both with no diagnostic. **This is the shape ADR-0341 predicted
and a shape it did not**: that record deferred *a module shipping an
implementation for its clients* and said a non-generic module routine calling a
trait routine "compiles and fails to link". What it did not say is that a
**client** calling into a module's implementation does the same — and that is
the direction the library needs, because the client is where the call is
written. AP 6.7.10.1 NOTE 9 recorded the restriction, and the entry in
`doc/implementation-defined.md` that the same record's Decision promised was
never written: `trait` appears in that register zero times. A restriction with
no register entry is one nothing can be searched for.

**A restriction that is not refused is not a restriction.** Whatever is decided
about reachability, accepting the program and emitting a call to a name nothing
defines is wrong on its own: §5.1 e) wants it reported, and the report a
program got was an assembler's or a linker's, naming a symbol no source
spells — ADR-0216's own complaint, one construct further on.

## Decision

**An implementation-declaration in a module-block is selected by AP 6.7.10.2 in
every component that can name its type.** It is AP 6.7.10.5, and it is granted
rather than added: 6.7.10.2 identifies a routine from the *type* of the first
actual-parameter and never from a name in scope, so a client that can name the
type can already name the selection. §6.11.2's one scope is not reached, which
is the whole payoff — two modules may each implement a `Put` where two exported
`Put`s would collide.

**The routine takes a composed linkage name**, which is the candidate ADR-0341
named for this if it were reopened, and it is the only one: separate
translations share no symbol table, so anything callable across them needs a
name both sides compose from what both have read. The shape is

    p.<module>.<type>.<routine>              an inherent implementation
    p.<module>.<type>.<trait>.<routine>      a trait's

— the module's own name rather than an export-part's, because a method is not
a constituent. The trait stands in the name because two traits may declare one
spelling for one type: AP 6.7.10.2 refuses that *call* as ambiguous and lets
both implementations stand, so both are emitted and neither may take the
other's name. Four parts against five is what keeps the two forms apart with
no marker, a trait name never occupying a routine name's position.

**The implementation stays in the module-block**, and §6.11.1's split —
headings in the module-heading, bodies in the block — is rejected. An inherent
implementation's headings would then be written twice, and a trait
implementation's are written in the trait already (AP 6.7.10.3), so a third
copy could disagree with the first two. What the split would have bought is
the digest, and the digest is taken directly instead.

**AP 6.13.2 grows to cover the implementations.** This is the mechanism ADR-0341
did not have to think about, because it was not making anything in a block
reachable. §6.13's agreement is enforced by a digest of the module-heading's
tokens in the name of the module's activation procedures; an implementation is
in the *block*, so the same rule would let a method's parameter list change
under a component already translated against it. What is digested is each
implementation-declaration's own line and each of its routines' headings, and
**not** the bodies — NOTE 3's distinction, one construct further in. The
digests are summed rather than chained, so neither the order the routines were
written in nor the order the components were read in enters into it, which is
what lets §6.11.1's split form answer alike on both sides.

## Consequences

**A method is now the collision-free name ADR-0315 wanted, across components as
well as inside one.** `export-unique` still reads the export-part and a method
is still not in it, so nothing is forced; what changes is that the 187 exported
names that repeat their own module's noun (580 exports over 33 modules today —
run `tests/checks/export_unique.py`, the number has moved twice) can now be
methods rather than merely being able to be methods in a program.

**Three things it made work, and each was a separate omission.**

- An implementation's routine was `define internal`, so the name was not there
  to link against even where the two translations agreed on it.
- A vtable built in a client names routines it does not define, and a call site
  registers its callee where a table does not: AP 6.7.11's table is an address
  taken and never called, so it had to register its own.
- `SameLink` compared two of a linkage name's parts. With no linkage name at
  all every impl routine answered alike, so a module's *second* method reached
  a client with no `declare`, the first having been taken for it. The composed
  name removes the cause; comparing four parts rather than two is the
  function's own question answered, and no case kills it — the pool does not
  intern, so two spellings of one identifier already sit at different offsets.

**The counter is reproducible more often than its comment suggests, and that
is why the claim needed a gate rather than a case.** `AppendProcName` says a
counter is "a fact about the order this translation walked the tree in"; in
practice two translations handed the same components in the same order walk
them identically and the counters agree. `tests/run_test.py` always hands them
the same list, so **no ctest case can tell a composed name from a counter** —
the first mutation of this change passed the whole corpus. What distinguishes
them is a build where the module was translated **alone** and the client has
another component in front of it, which is the ordinary situation for a
library; `tests/checks/stale_component.py` holds it, and under a counter it
fails with `undefined reference to p4`.

**`stale-component` gained three claims and is no longer only about
staleness.** A method's heading changing without a rebuild is refused, a
method's *body* changing is not, and a method is reached by its name. The
middle one matters as much as the first: a check that refuses too much trains
people to rebuild everything and is then worth nothing.

**`tests/spec/` gained a step.** `Given the program-component` takes a module
and may be written more than once. Until this there was no clause here whose
requirement was about a boundary, and every scenario was one component — so a
suite whose unit is a clause could not have stated AP 6.7.10.5 at all.

**A method may be `external`, and now something says so.** An implementation
declares its routines the way any block does and ADR-0121's directive stands
where a body would, so it was admitted from the day methods landed and nothing
had asked. It is the one implementation shape that keeps a *foreign* linkage
name: what is on the other side was translated by a C compiler that knows
nothing of the type, and the receiver reaches it as the address a `var`
parameter already travels as. `tests/dialect/methods.pas` pins it in a program
and `method_component.pas` across a boundary.

## What this does not do

**It does not make an implementation exportable, hidable, or nameable.** There
is no way to write one in an interface, no way to keep one out of one, and no
`only` or `qualified` for a method. An implementation for an exported type is
reachable and that is the whole rule; a module that wants a routine nobody else
may call writes an ordinary routine and does not export it.

**It does not settle `impl` for a schema.** ADR-0338 wanted `impl Key for
string` and ADR-0341 left it refused. Still refused, and still for that
record's reason.

**It does not rewrite any library module.** That is the next increment and the
judgement ADR-0315 left; this one only makes it possible.

## Alternatives rejected

**§6.11.1's split form** — the implementation's routine headings in the
module-heading, its bodies in the block, which is what ADR-0341 said the clause
would be if this were built. Rejected in the Decision above: it states an
inherent implementation's headings twice and a trait implementation's a third
time, and buys only a digest that can be taken directly.

**Leaving the restriction and refusing the program instead.** It is the
minimum honest change, and it was not taken because the restriction has no
argument left. ADR-0341's was that a client writing one `impl` block keeps the
whole measured payoff — true of ADR-0116's threading of `StrHash, StrEq`, and
not true of ADR-0315's library judgement, where the point is that a library's
own types carry their own routines. A restriction kept for a reason that has
expired is a restriction with no reason.

**Naming the routine after an export-part constituent**, by synthesising one.
It is ADR-0341's "derived linkage name" read the other way, and it would put
a spelling nobody wrote into `export-unique`'s reader. The name is derived
from the implementation-declaration instead, which is text both translations
read and no constituent at all.
