# 55. A result that lives in memory is the caller's storage

Date: 2026-08-12

## Status

Accepted.

## Context

ISO 7185 §6.6.2 restricts a function's result to a simple type or a pointer
type. ISO/IEC 10206:1991 §6.7.2 replaces that list with a prohibition:

> A type-name shall not be permissible as the type-name of a result-type if it
> denotes a file-type, a structured-type having any component whose
> type-denoter is not permissible as a component-type of a file-type, or the
> bindability that is bindable.

So a record, an array and a set become results. §6.7.2 also adds a
**result-variable-specification** — `= identifier` between the parameters and
the result type — which names the result and makes it an ordinary variable of
the block.

The two arrive together because neither is much use alone. ISO 7185 §6.8.2.2
makes every *read* of a function-identifier a recursive call, so `f` can be
assigned and never inspected; a structured result could then be assigned whole
and never built a field at a time. `function mk(a, b: integer) = r: point`
is the shape the feature exists for, and without the second half it cannot be
written.

## Decision

**The caller supplies the storage.** ADR-0017 gives a structured value no
register form, and the callee's activation record dies at the return — so the
result cannot live there. Each *call site* keeps a hidden frame slot, and its
address travels as a hidden argument after the static link. The function
returns void.

This is ADR-0030's shape for the fourth time: a procedural parameter's pair, a
schematic parameter's tuple, a string's pointer-and-length and now this all
travel as extra scalar arguments. Nothing depends on how a struct is passed,
because none ever is — which is what keeps the textual `.ll` backend free of an
opinion about the C ABI, and why neither backend needed `sret` or `byval`.

**The mechanism already existed.** ADR-0052 built `binding(f)`'s record in a
hidden frame slot, and said why: it was "the only required function returning a
record, and this compiler returns none." `Call::resultSlot` is that field,
unchanged; this record only made a second thing use it. The slot is per *site*
rather than per callee, so `f(g(x))` and a call in a loop each get their own,
and a recursive call needs nothing extra because each activation brings its own
frame and so its own slots.

**The callee binds the address as a `var` parameter does.** `Symbol::resultVar`
becomes a `VarParam` when the result lives in memory, and the prologue stores
the incoming pointer in its slot. `addressOf` dereferences a `VarParam` without
being told why, so assignment, whole-variable copying, subscripting, field
selection and passing the result on all needed *nothing*. That one line is the
whole of the callee side.

**One helper decides the signature.** `CodeGen::signature` is to the two ends of
a function's shape what `appendParamTypes` is to its middle: a caller and a
callee can only agree, because both come through it.

**The result-variable-specification is one scope entry.** §6.7.2 makes the
identifier "a variable-identifier for the region that is the block", and it
denotes the same storage the function identifier assigns to — so it is bound to
`resultVar`, the symbol that already existed. Nothing else in Sema or CodeGen
learns that a body used the other spelling.

**The two rules about writing the result are exclusive**, which is why one flag
answers both. With a result-variable-specification the block "shall contain no
assignment-statement" to the function-identifier; without one it shall contain
at least one. `Symbol::resultNamed` says which rule applies and
`Symbol::assignedResult` records the syntactic containment the standard asks
about — an assignment inside an `if` counts, because §6.6.2 asks what the block
*contains*, not what it executes.

**A refused result type suppresses the never-assigns message.** The body cannot
assign a type the heading does not have, so the second diagnostic describes a
program the author did not write. ADR-0054 made the same call for the constant
folder, and for the same reason: one mistake, one message.

## Consequences

**It found a real bug in `selfhost/compiler.pas` on the day it landed.**
`ParseTypeDenoter` ended with `ParseTypeExpr := t` — assigning a *sibling*
function's result, so it never assigned its own. The bootstrap closed, every
golden file matched and both compilers agreed, for as long as that line has
been there. Whatever the accidental mechanism was, it was not the program
anyone wrote, and the new check is the only thing in five oracles that noticed.
That is the argument for implementing a rule the standard states even when it
looks like it can only ever fire on a typo.

**What is not checked is the other half of the same sentence.** With a result
variable §6.7.2 asks for "at least one statement threatening" it, and
*threatens* (§6.9.4) is weaker than *assigns* — a `read` into it counts, and so
does passing it to a `var` parameter. Only the assignment form is required
here, so a function with a result variable is never told it left the result
unwritten. Stated rather than silently omitted.

**Nor is a sibling assignment refused.** §6.8.2.2 associates an assignment's
function-identifier with the block containing it, so assigning an enclosing
function's result is legal and assigning a sibling's is not. This compiler
accepts both; the never-assigns rule catches the case where the sibling
assignment was the *only* one, which is the shape the bug above had, but not a
body that assigns its own result and a sibling's too. A deviation with a
diagnostic behind most of it, not a gap nothing sees.

**§6.7.2's result-type is a `type-name`, and this compiler accepts a
type-denoter.** A schema production — `function f: vector(3)` — is admitted
where the standard asks for a name. The latitude is permissive and harmless:
every named type has a static size, and so does every production with constant
discriminants, which is what lets the caller allocate the slot at all.

**A dynamically sized result cannot arise**, and that is the standard's doing
rather than a restriction invented here. §6.2.3.2's permission to compute
discriminants on block entry (ADR-0041) is withdrawn inside a type definition,
so no *named* type has a dynamic extent — and a result-type is a name. The
caller can therefore always size the slot, and no path in either backend has to
ask what a result's size is at run time.

**`verify/` gained nothing**, for the ninth record running. A calling
convention produces no arithmetic, and what it must agree with is that a caller
and a callee lay out the same arguments — which is a property of one function,
`signature`, rather than of a lowering rule. The oracles that do speak to it are
`irtest.sh`, which runs what the Pascal compiler builds, and the fixed point,
which fails immediately if the two backends disagree about the shape.

## What this does not do

**A function-access is still not a designator** (§6.8.6): `mk(7, 8).y` is
refused, so a structured result must be assigned to a variable before a
component of it can be read. That clause is its own feature and its own record.

**A structured-value constructor** (§6.8.7) is not here either, so a record
result is built through a result variable or copied from an existing variable,
never written as a value.

**`f := e` where `f` is a schematic type** is unaffected: the tuple check
ADR-0042 makes at an assignment is the one that applies, because the result
variable is an ordinary variable and the assignment is an ordinary assignment.
