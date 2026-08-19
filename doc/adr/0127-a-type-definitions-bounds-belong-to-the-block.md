# 127. A type-definition's bounds belong to the block

Date: 2026-08-19

## Status

Accepted. Completes ADR-0113, whose *Consequences* named this as "a second
decision about ownership rather than a continuation of this one".

## Context

ISO/IEC 10206:1991 §6.2.3.8 b) puts

> for each actual-discriminant-part or subrange-bound not contained by a
> schema-definition and closest-contained by the module-heading of the module,
> by the module-block of the module, or by the block, the corresponding
> evaluation of the actual-discriminant-part or subrange-bound

in the commencement of an activation, after a) attributes the formal value
parameters. ADR-0113 took the **variable-declaration** half of that sentence, so

```pascal
procedure p(m: integer);
var a: array [1..m] of real;
```

works. The type-definition half did not:

```pascal
procedure p(m: integer);
type t = array [1..m] of integer;   { refused }
     u = vec(m);                    { refused }
```

A type-definition *is* closest-contained by the block, so both are legal and
both were refused. ADR-0107's second independent reading called the whole entry
the finding most likely to break a real program;
`doc/implementation-defined.md` §6 has carried what was left of it since.

ADR-0113 said why it stopped: "a variable's descriptor belongs to the variable,
a type's would belong to the *block* and be shared by every variable of it". That
is the decision, and it turns out to be the answer rather than the obstacle.

## Decision

**A type-definition whose bound or discriminant does not fold gets a hidden
frame variable of the block, and every variable of the type reads that one
descriptor.**

- `CheckTypeDecl` makes the same offer `CheckVarDecl` makes, to a symbol
  standing for the type-definition rather than for any variable. It is named
  `bnd$N` for the reason `for$` and `with$` are named — the Sema dump prints a
  frame's variables and a nameless one is indistinguishable from the next — and
  `$` is not an identifier character, so no program can write it.
- The slot is **claimed after the denoter is resolved**, not before. Most
  type-definitions have no bound that fails to fold, and a slot reserved for
  every one of them would move the layout of every frame in every Extended
  Pascal program. So the symbol is built outside the frame and `ClaimBoundsSlot`
  joins it, correcting the `frameIndex` of every discriminant already made
  against it.
- A variable of such a type gets `boundsFromType`: its slot holds the **address
  alone**, and its `discSyms` are the *type's* list, so every reader of a bound
  goes through the block's own slot by the walk any enclosing variable makes.
  Sharing the list rather than copying the values is what makes the extent the
  type's — nothing anywhere can hold a different answer.
- The prologue therefore does one of two things rather than one thing:
  `boundsOwner` fills its discriminants and allocates nothing, a type having no
  storage; `boundsFromType` allocates and fills nothing.

**Evaluated once is the property, and it is observable.**
`tests/extended/dynbounds_type.pas` bounds a type by a function that counts its
own calls and declares two variables of it: the count is 1 per activation. The
mutation that re-evaluates per variable makes it 3, and also makes `c` read the
extent the *last* variable stored, which is the shape of bug a copy would have
had.

**Both spellings, because the clause names both.** `array [1..m]` and `vec(m)`
go through the one mechanism: the bare bound needs ADR-0113's anonymous schema
and the schema production brings its own, which is the only branch between them.

**A parameter of such a type needs no descriptor.** `procedure fill(var r: row)`
inside the block that defines `row` reaches the bounds up the static chain,
because they are in an enclosing activation record. That is a *simplification*
over a schematic formal, which has to carry address-and-tuple as separate
arguments (ADR-0040), and it falls out of the descriptor belonging to the block.

## The defect found on the way, and the deviation that replaces it

Making the offer at a type-definition made `type t = 1..m` reachable, and it
did not work: the variable could be read and not assigned to. Probing the same
shape one denoter further found something worse, present since ADR-0113 and
reached by nothing in the corpus:

```pascal
var a: array [1..m] of 1..m;   { m = 3 }
a[1] := 2                      { traps: value out of range (1..) }
```

A **legal store, stopped**. The component's bounds are discriminants, and
`CheckedForSubrange` compares against the two numbers on the type — which for a
dynamically bounded subrange are 1 and 0, never read from anywhere.

The difference is what a bound is *for*. In an array's index-type it is read by
the subscript check, out of the descriptor, and that path was built by ADR-0113.
Everywhere else a subrange's bounds are read by the range check at a store, and
that check has no descriptor. So **a subrange whose bounds are discriminants is
confined to an array's index-type**, and `dynBoundsIndex` is what tells the two
apart: both are a subrange denoter reached from `ResolveArray`, and only the
position distinguishes them. One-shot, cleared before the recursion, so it says
something about one denoter and not about a subtree.

That is a deviation — §6.4.2.4 permits `1..m` anywhere a subrange may be
written — and it is the entry that replaces the one this record closes in
`doc/implementation-defined.md` §6. Refusing it is a deviation; accepting it was
a defect, and the trap above is why the trade is not close.

## Consequences

**A program that was refused is now accepted**, and one that was accepted is now
refused. The second is in `CHANGELOG.md` under *Programs that used to compile
and no longer do*, and nothing that ran correctly is in it: `var x: 1..m` could
not be assigned to, and `array [1..m] of 1..m` trapped on a legal store.

**A module's type may not have one**, for §6.2.3.6's reason — a module's
activation lasts as long as the program, so there is no stack for storage sized
on entry. That is now four messages rather than two, and they stay four because
each names what the program wrote: a variable's discriminants, a variable's
bounds, a type's bounds, and a variable *of* such a type.
`tests/extended/module_sema_errors.pas` carries all four.

**One diagnostic changed wording.** A type-definition's discriminant may now be
a variable, so *the discriminants of a schema must be ordinal constants here*
became *the discriminants of a schema must be ordinal* where the offer is made
and declined. `tests/extended/constexpr_errors.err` has the one line, and the
new message is the more accurate of the two: what is wrong with `vec([1 .. 3])`
is that a set is not an ordinal, and never was that it is not constant.

**`src/` carries it too.** This is the conformance surface, not the dialect, so
the reference front end implements the same clause — ~70 lines, mirroring the
Pascal — and `difftest` is what said when it did not: three files disagreed and
they were exactly the three goldens.

**No lowering rule changed.** The bounds check is the one ADR-0017 proved, with
the bounds read from a descriptor rather than from the type, which is ADR-0113's
situation exactly. The commit carries `Model-unchanged:`.

### What this does not do

**It does not make a bare dynamic subrange work**, and that is the deviation
above rather than an omission of this record. Fixing it is a run-time check and
not a decision: `CheckedForSubrange` has to read the descriptor the way the
subscript check does, and the message has to be built by the runtime the way an
array's already is where the bounds arrived with an actual (ADR-0040).

**It does not give a record field one.** §6.2.3.8 b) does not reach it — a
field's storage is sized where the record is — and that refusal is unchanged.

**It does not let the type escape its block.** The descriptor is a frame slot,
so the type means something only inside activations of the block that defines
it, which is exactly what a local type-definition is. A `var` parameter of such
a type works because the callee is nested inside that block; nothing else can
name the type at all.

## Alternatives rejected

**Re-resolve the denoter per variable**, which is what ADR-0113 does for a
variable-declaration group. It is the smaller change and it is wrong twice: the
bound would be evaluated once per variable where §6.2.3.8 b) evaluates it once,
so a bound with a side effect answers differently and two variables of one type
get two extents; and the type would be two types, where §6.4.1 makes a type-name
denote one, so `a := b` between them would be refused.

**Copy the discriminant values into each variable's descriptor.** One
evaluation, so the first objection goes — but two places then hold the extent,
and nothing makes them agree afterwards. Sharing the symbol list costs less and
cannot drift.

**Reserve the frame slot before resolving and release it if unused.** Simpler to
write and it assumes nothing else claims a slot while the denoter is being
resolved, which a structured constant in a bound would (ADR-0061). Claiming
afterwards and patching the discriminants has no such assumption.

**Accept a bare `1..m` and emit no range check.** It compiles and it silently
drops a check the standard requires. Refusing is the failure that can be seen.
