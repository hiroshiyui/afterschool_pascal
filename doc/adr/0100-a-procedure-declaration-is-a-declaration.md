# 100. A procedure declaration is a declaration

Date: 2026-08-15

## Status

Accepted.

## Context

ISO 7185 §6.2.2.9 requires a defining-point to precede every applied occurrence
of its identifier. ADR-0069 made that true for the constant, type and variable
parts by merging them by **source position**, because ISO/IEC 10206:1991 §6.2.1
lets those parts repeat and interleave. ADR-0088 gave a symbol the machinery to
notice an applied occurrence.

Neither could reach a **procedure body**, because `CheckBlock` walked all of
`CheckDeclarations` and only then the list of procedure declarations. So every
variable of a block existed before any body was checked, whatever the source
order, and this was accepted under `--std=extended`:

```pascal
procedure p; begin writeln(zz) end;
var zz: integer;
```

Under `--std=iso7185` it is refused a clause earlier, by §6.2.1's fixed order
(ADR-0072), so the gap was Extended Pascal's alone.

## Decision

**The procedure-and-function-declaration-part joins the merge as a fourth
list.** A heading is declared and its body checked at the point the source puts
it. A variable written after a procedure is therefore not declared when that
body is walked, and the use reports `undeclared identifier` — the same
consequence ADR-0069 already produces for `var v: t` before `type t`.

**Headings are still declared one at a time**, which is what keeps a procedure
from calling one declared after it without `forward`. That property predates
this and had to survive it.

**§6.10's program parameters are bound in two passes, and the split is
forced.** §6.5.1 confers bindability on the *declaration*, and a body may ask
`binding(f)` of a parameter — so binding must happen before the first body. But
§6.10's diagnostics ("listed more than once", "not declared as a variable in
the program block") need the *whole* block, and a variable-declaration-part may
follow a procedure. So a silent pass binds what is declared so far, and a
reporting pass runs when the declarations are done. Where nothing follows the
last procedure — every ISO 7185 program, and every Extended one not
interleaving — the two collapse into the single reporting call that was there
before, so nothing moves for them.

**The silent pass runs at every procedure-declaration, not once.** A
program-parameter written *between* two procedures does not exist when the
first is reached, and the second's body may still ask `binding()` of it. The
call is idempotent over the binding — it recomputes the same argument positions
from whatever is declared by now — so repeating it costs a walk.

**A procedure-declaration drains the pending pointers.** `CheckProcBody` pushes
a scope, and a domain left pending from an enclosing var part would otherwise
be drained inside the *nested* block and looked up in the wrong scope, which is
the bug ADR-0091 fixed from the other side. A consequence worth stating: a
domain naming a type defined **after** an intervening procedure is now refused,
because §6.2.2.9's exception is scoped to *the* type-definition-part containing
the defining-point and a procedure ends that part. A domain naming a type
further down the same part still works.

## Consequences

**469 cases pass and the compiler still compiles itself** — 25,000 lines of
Extended Pascal with 56 forward declarations, which is where a false positive in
a change to the declaration walk would show first.

**Two goldens moved and both are pure reorderings** — the same messages at the
same positions, in a different order. Checked as sets, not eyeballed. The new
order is the source's: a diagnostic from a body at line 45 used to be emitted
after one from a declaration at line 50, because all bodies came last. That is
the feature rather than a side effect.

**The two-pass binding was written without a test and one had to be added.**
Removing the silent pass left all 469 cases green: no program in this corpus
declares a program-parameter after a procedure and asks `binding()` of it in
one. The first attempt at that test then found a *second* defect — the silent
pass was a one-shot, so a parameter appearing after the first procedure was
never bound at all. Both are pinned now. This is ADR-0067's rule where it bites
hardest: the claim that a mechanism is load-bearing is worth exactly the test
that kills it.

### What this does not do

**A module-heading keeps its own loop.** It has no bodies, so nothing in it can
observe the interleaving, and merging it would be motion without a reason.
