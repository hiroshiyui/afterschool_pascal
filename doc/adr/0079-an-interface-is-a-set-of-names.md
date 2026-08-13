# 79. An interface is a set of names

Date: 2026-08-14

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.13 is one sentence — "A processor should be able to
accept the program-components of the program-block separately" — and it was the
last item on `doc/roadmap.md`. ADR-0053 deferred it twice over: it "would need
an interface artefact this compiler does not define", "a second file format,
and one the stage-1 compiler could not write".

Both halves of that turned out to be wrong, and in different ways.

## Decision

**The artefact already exists, and it is the module-heading.** §6.11.1 makes a
module-heading declare exactly the exported constants, types, variables and
procedure headings, and puts everything the module keeps to itself in the
module-block. So the interface *is* the heading, it is written in Pascal, and a
component that imports it needs the other component's **source** and nothing
else. `--import` reads one and emits no code for it. No third format was
defined, and the stage-1 compiler reads one with the lexer and parser it
already has.

An `.ll` file could not have served. LLVM IR has no Pascal type system — a
record is an anonymous struct of machine types, a subrange and an enumeration
are both `i32` — and ADR-0017's name equivalence has no representation in it at
all. The IR is the *product*, downstream of every fact Sema would need to read
back.

**What the boundary costs is that nothing numbered may cross it.** Two things
did, and neither was visible until a second translation existed:

- a procedure was `p.<name>.<counter>`, and the counter is the order *this*
  translation walked the tree in;
- a variable was a frame index, and a frame's layout is decided by the
  module-**block** — which is exactly the half a separate translation does not
  have. `tests/extended/components/counter.pas` has a variable the heading
  never mentions, so the two translations do not agree on how many variables
  the module's activation record holds, nor on its type.

So `Sema::nameForLinkage` derives a name from the module-heading alone — the
interface's name and the constituent's spelling, both of which every
translation importing the interface has read — and CodeGen puts that name on
the storage. **Per interface, not per constituent**: §6.2.2.2 makes each
interface a region disjoint from every other, so two modules may both export a
`tally` and the names must still differ.

**An exported frame slot is named with an alias.** The activation record stays
internal and keeps its layout private; each slot another component may reach
gets an external symbol of its own beside it, which costs nothing at run time —
it is the same address under a second name. `nm` on a translated component is
then literally its interface:

```
B frame.counter          T m.counter.init      T p.counting.bump
B v.counting.tally       T m.counter.fini      T p.counting.clear
B v.counting.ticks
```

**The required files are the one thing a module reaches that the *program*
declares.** `input` and `output` live in the program's frame (ADR-0053), which
a module compiled separately can neither name nor index, so they carry the
fixed linkage names `pas.input` and `pas.output` — fixed rather than derived,
because §6.10 and §6.11.4.2 make them one per program however it was divided
into components. The component holding the main-program-declaration defines
them; every other one declares them. Under ISO 7185 no name is emitted at all,
that language having no modules to reach them from.

**A component with no main-program-declaration is an ordinary translation that
cannot be linked.** The parser accepts it, Sema checks its modules, CodeGen
emits them and no `main`, and the driver refuses to link — naming the missing
component rather than complaining about this one, because nothing about this
one is wrong. §6.11.1's "has an interface but no implementation" is likewise
withdrawn for a module whose block is another translation's business.

## Consequences

**Both compilers do it, and their objects are interchangeable.** A module
translated by `selfhost/compiler.pas` links against a program translated by
`pascalc` and runs. That is a sharper statement than either compiler passing
its own tests: the linkage names are a contract, and two independent backends
arrive at the same one from the same heading.

**The stage-1 compiler takes the components as one more program parameter, and
concatenated.** ISO 7185 gives a program no access to its command line beyond
its program parameters, and those are files, so it cannot open one whose name
it computes — ADR-0033's constraint, met a third time after `--std` and
ADR-0024's single source file. Concatenation costs nothing to define, because
**a sequence of program-components is exactly what a source file already is**:
what the parameter holds is ordinary Pascal, and the same parse reads it.

**The Pascal backend had to stop numbering three things.** It named a frame
`@frame<irId>`, a module's parts `@m<irId>i`/`f` and a procedure `@p<irId>`.
Modules and exported procedures now take names, and the program's frame keeps
its counter — nothing outside a program can name it. Stage 2 still equals stage
3 after that change, which is the only evidence that mattered.

**Both dumps segfaulted on a component with no main-program-declaration**, in
the same place and for the same reason, so `difftest` compared two compilers
crashing identically. ADR-0067's shape again: no corpus program had that form,
so no oracle had an opinion. It is the fourth sweep in a row to find that the
absence of a *shape* is what hides a defect, not the absence of a check.

**A mutation that survived is why there are two components.** Dropping the
interface from a linkage name — `v.tally` instead of `v.counting.tally` —
passed every test, because with one interface a consistently wrong name is
still a consistent one. The second component exports a `tally` too, and the
mutation now fails at link time with "multiple definition of `v.tally`". The
test did not become larger to be thorough; it became larger because a
deliberate design property had nothing checking it.

**`verify/` gains nothing**, and this time not because a rule would restate a
lowering: there is no arithmetic here at all. Separate translation moves where
a name is decided, and every check the emitted code makes is the one it already
made.

### What this does not do

**It does not check that the component being imported is the one that was
linked.** Nothing stamps a translation, so a heading edited after its object
was built is a stale interface that links cleanly — the ordinary hazard of
separate compilation, and the reason real toolchains carry timestamps or
hashes. A processor could catch it; this one does not, and `--import` naming
the *source* rather than an artefact makes the mismatch easier to create than
it would otherwise be.

**It does not offer a search path.** Every component is named on the command
line. §6.13 says nothing about how a processor finds one, and a rule invented
here would be a rule the other compiler has no way to follow.

**It does not make module-level declarations separately *checkable*.** The
importing translation re-resolves the heading from source, so an error in the
heading is reported again in every component that imports it. That is a
consequence of having no artefact and is stated rather than hidden: the
alternative is the format this record declined to define.
