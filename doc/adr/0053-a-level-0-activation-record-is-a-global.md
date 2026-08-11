# 53. A level-0 activation record is a global

Date: 2026-08-11

## Status

Accepted. It is the last of the eight features on the Extended Pascal list, and
the only one that changes what a *program* is.

## Context

ISO/IEC 10206:1991 §6.13:

```
program-block   = program-component { program-component } .
program-component = main-program-declaration '.' | module-declaration '.' .
```

§6.11.1 gives a module two halves — a module-heading that says what it exports
and a module-block that implements it — and lets them be written as one
program-component or as two. §6.11.2 gives the heading an
interface-specification-part, §6.11.3 gives every block an import-part, and
§6.2.3.6 says when each module's activation commences and terminates.

## Decision

**A module is a block at level 0 whose activation record is a global**, and
that one sentence is the whole of the code generator's share of the feature.

A module has exactly one activation for the whole run of the program (§6.2.3.6)
and that activation has to outlive the function that commences it, so its frame
cannot be an `alloca`. The main program is in the same position — it also has
exactly one activation, and it is not recursive — so the rule is stated for
*level 0* rather than for modules, and the program's frame became a global too.

Two things fall out, and they are the two that make the feature work at all:

- **An imported variable needs no static chain.** `addressOf` asks for the
  frame of the symbol's *owner* rather than for the frame at the symbol's
  level, and a level-0 owner answers with its global. A module's static chain
  says nothing about the program's frame and the program's says nothing about
  any module's, so a walk could never have found either.
- **`input` and `output` stay where they were.** They are the program's frame
  variables, created once on demand, and a module reaches them by the same
  rule. §6.11.4.2 makes them constituents of the required interfaces
  `StandardInput` and `StandardOutput`, so a module can import them — and the
  file it gets is the same one the program's parameter list names.

ADR-0016's "there is no separate global path" is *not* retired by this: there
is still exactly one path, `addressOf`, and it still answers for every
variable. What changed is where the walk stops.

**Written order is a legal activation order, and no sort produced it.**
§6.2.3.6 requires the commencement of B to precede that of A whenever B
supplies A, and §6.2.2.9 already requires a module-heading to precede
everything that imports its interface — so a supplier is always textually
earlier than what it supplies, and `main` calls the initialization parts in the
order the modules were written and the finalization parts in the reverse. The
partial order the standard states is one this compiler gets for free from the
order the standard also states.

**Two modules can still supply each other**, and §6.11.1 is written for exactly
that: it forbids an initialization-part or a finalization-part in either of
such a pair. The shape is only reachable because a module may be *split* —
A's heading exports what B imports, and A's *block*, a later program-component,
imports what B exports, which is NOTE 2's own example. It is the one case
§6.2.3.6 leaves no order for, which is why the standard takes the ordered parts
away rather than picking one; the check is a reachability question asked
per module-block. The clause about nonvarying expressions needs nothing: every
expression this compiler admits in a module-heading is already a constant.

**Only the modules that supply the main-program-block are activated**
(§6.2.3.6), and supplying is transitive (§6.2.2.13). A module nothing reaches
is compiled and never run, which matters rather than being a nicety: its
initialization-part could write to `output`.

**A module's heading and its block share one scope**, because §6.2.2.12 makes
every defining-point of the heading a defining-point of the block. The two may
be separate program-components, so the scope the heading built is kept until
the block arrives rather than discarded at the end of the component.

**A procedure heading in a module-heading is `forward` under another name.**
§6.11.1's procedure-and-function-heading-part declares the name and the
parameters and leaves the body to the module-block, which repeats the name
alone — which is exactly what ISO 7185 §6.6.1 already does. So it reuses
`declareProcHeading` unchanged and the only new code is the diagnostic, which
says `heading` where the other says `forward` because nothing here was written
forward.

**An interface is a table, not a scope.** §6.2.2.2 says the region that is an
interface "shall not be a part of the program text and shall be disjoint from
every other interface", so exporting a name changes nothing about how visible
it is inside the module, and one table serves the whole program-block.

**A qualified name is told from a field selection by the symbol, not the
syntax** — the same shape ADR-0044 used for a variant-selector. `i.x` and
`r.f` are one production, and only what `i` resolves to can part them. The one
place the *parser* can decide is a call: `a.b(` has exactly one reading,
because there is no procedure type in the type part (ADR-0030) and so a record
field is never followed by `(`.

**An imported variable is a copy of the symbol; everything else is shared.**
The spelling and the protection belong to the *import* and not to the module's
own declaration, and a copy names the same storage because owner, level and
frame index are what an address is computed from. A constant, a type, a schema,
a procedure and a function are shared outright, because nothing about them can
differ between the two ends — §6.11.2 lets only a variable-name be `protected`.

## Consequences

**The module initializations are emitted after the program's own prologue**,
not before it. §6.2.3.6 puts a supplier's commencement first and the program's
prologue is part of its commencement — but §6.11.4.2 requires `output` to hold
`rewrite`'s post-assertions "prior to the first access to the text file", and a
module's initialization-part is such an access. Nothing is lost by the swap: the
program exports nothing, so no module can name anything the prologue touches.
A module that writes in `to begin do` is the program that says so, and
`tests/extended/module_order.pas` is that program.

**The program is one source file**, and §6.13 permits that: "A processor
*should* be able to accept the program-components of the program-block
separately" is a recommendation, not a requirement. Accepting them separately
means emitting and reading an interface artefact, which is a second file format
this compiler would have to define — and ADR-0024 already has the stage-1
compiler as a single ISO 7185 source for the same kind of reason. What is *not*
given up is the split itself: `module m interface;` and `module m
implementation;` are two program-components in one file, which is the whole of
what the syntax offers.

**Five word-symbols, not seven.** §6.1.5 and §6.1.6 make `interface` and
`implementation` *directives*, which are identifiers in the one position each
may occupy — exactly as `forward` is (§6.1.4). So `module`, `export`, `import`,
`only` and `qualified` are what this feature costs ISO 7185, and
`tests/module_iso.pas` is a valid ISO 7185 program that uses all five as
variable names. The one new special-symbol is `=>`, lexed under both standards
for the reason `**` is: no valid ISO 7185 program can contain it, so consuming
it and refusing it yields one diagnostic instead of a cascade.

**Thirty-six mutations across both compilers, thirty-four caught, one
equivalent — counted twice, because each compiler carries it.**

The equivalent pair is instructive: taking a callee's static link by walking
(`frameAt(level - 1)`) instead of from its owner is *indistinguishable* at
level 1, because a level-1 procedure's static link is never read. Nothing walks
to level 0 any more — `addressOf` goes straight to the global — so the link a
level-1 activation stores is dead, and the two expressions differ only there.
At level 2 and below they are the same expression. Recorded here so the next
reader does not go looking for the test.

The first run escaped fifteen of thirty-one, and every one of those was a
corpus that had not been written yet: no export-range in a *working* program,
no import-renaming, no protected constituent imported under its own name, no
module with a finalization-part, and no module that supplies nothing.
`tests/extended/module_order.pas` exists because of them.

The per-block accessibility of `output` then escaped a second time, and the
reason is worth keeping: the module that tests it was written *before* any
other block had created the file, so the check under test never fired and
removing it changed nothing. A test of "this block did not ask for `output`"
is only a test once some other block has asked.

**`verify/` gained nothing**, for the seventh record running. There is no
arithmetic here at all: the whole feature is name resolution and one call
ordering, and the ordering is a property of the program's text rather than of
its values.

**A module's variable may not have computed discriminants.** §6.2.3.2 lets a
*block's* variable have them and sizes its storage on entry (ADR-0041); a
module's activation outlives the function that commences it, so there is
nowhere on the stack to put that storage. The tuple has to be constant there,
which is the restriction every other position is already under.

## What this does not do

**Program-components are not compiled separately**, as above.

**A module-parameter that is not `input` or `output` is bound to nothing.**
§6.11.1 makes the binding implementation-defined and NOTE 6 says outright that
"variables that are module-parameters are not necessarily bound when the module
is activated". It is still checked to be a variable the module declares, which
is the part of §6.11.1 that is not implementation-defined.

**§6.11.2's principal-identifier rules are enforced only where they can be
seen.** An export-range exports the principal identifier of every value in it,
and a program that has taken one of those names away — by importing `only` two
of three enumeration constants — is refused. What is not tracked is whether an
identifier introduced by a *renaming* is a principal identifier, which NOTE 1
says it is not; nothing in this compiler asks.

**Where a `qualified` import's names may be written is not enforced inside the
import-specification itself.** §6.11.3 makes a constituent-identifier's
defining-point cover the import-specification, so `i qualified only (t => u)`
finds `t` in the interface — which is what this does — but the compiler does
not then refuse the same spelling elsewhere for a different reason.
