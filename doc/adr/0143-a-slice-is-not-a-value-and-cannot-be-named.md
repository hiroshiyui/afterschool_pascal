# ADR-0143: A slice is not a value, and 6.4.9 could name one

Date: 2026-08-20

## Status

Accepted. Corrects two defects in ADR-0125's slice, found by the specification
audit recorded in ADR-0144. Extends ADR-0139, which fixed one caller of the
same permission and stopped there.

## Context

Two independent readers, working from different clauses, found the same feature
admitting more than it states — one memory-unsafe, one worse.

### The permission, again

AP §6.4.5 makes two slices compatible when their component types are the same,
for parameter passing. ADR-0139 found that the relational operators ask
compatibility too, wrote the refusal out for them, and closed. **Assignment is
the other caller**, and `Assignable` never had a slice arm at all: a slice is
not `IsStructured` — its kind is `tySlice`, not `tyArray` — so `p := r` between
two slice formals fell to the function's last resort, `tb^.kind = fb^.kind`,
which is true for **any two slices whatever their component types**.

CodeGen then reached each slice through `AddressOfSym`, which has no slice arm:
a slice formal is a var parameter, so the var-parameter branch dereferenced the
slot and yielded the address of the caller's array **data** rather than of the
two-word descriptor. The assignment copied descriptor-sized bytes from one
array's contents into the other's:

```pascal
var small: array [1..1] of integer;
    big:   array [1..8] of integer;
procedure q(var p: array of integer; var r: array of integer);
begin p := r end;
...  q(small, big)
```

Sixteen bytes over a four-byte array and its neighbours, **exit 0**, at `-O0`
and `-O2` alike. AP §6.7.7.7 NOTE 3 says "A program cannot spell a buffer
overrun here"; it could.

### And the argument that a slice type cannot be named

AP §6.7.3.9.2 confines a slice-parameter-type to a formal parameter's own
denoter, and its NOTE gives the reasoning:

> This is stronger than "a slice may not be a variable" and needs one test
> rather than a list of positions: a type that cannot be named cannot be
> created anywhere the list might have missed.

ISO/IEC 10206:1991 §6.4.9 names it:

```
type-inquiry = 'type' 'of' type-inquiry-object .
type-inquiry-object = variable-name | parameter-identifier .
```

and the clause's **own worked example** is a `var` parameter with a local
variable declared from it. The dialect contains Extended Pascal, so `type of a`
is available wherever a slice formal is in scope — and every position
§6.7.3.9.2 lists was reachable through it. A variable, a type-definition, a
record field, an array component, a pointer domain and a file component were
all accepted, each holding a descriptor nothing had filled in; `length` of one
answered `-1`.

With the assignment hole still open, that composed into a write to an address
the program chose.

## Decision

**Two refusals, each at the one place that closes its whole family.**

**a) `Assignable` refuses a slice**, beside the arms that already refuse a file
and a procedural parameter — and those two are the precedent, not an analogy:
each says "not a value, and the one place it may travel has its own arm". A
slice travels only to another slice parameter, which `CheckActualParams`
handles without asking here.

**b) `ResolveInquiry` refuses a slice.** A type-inquiry is the only denoter
that can produce a slice type without writing `array of`, so refusing it there
closes all six positions at once. The NOTE was right that one test suffices and
wrong about where it already was; §6.7.3.9.2 now has one.

**The message is chosen inside the failure, not before it.** The first version
put a slice arm *ahead* of the `Assignable` call in the assignment check, to
give better words than `WriteDistinctTypeNote`'s advice to declare a shared
named type — advice that names something a slice cannot have. That arm masked
the predicate at the only site reaching it, and mutating `Assignable`'s refusal
away then changed nothing: **all 623 cases stayed green over a restored
out-of-bounds write.** The check now asks `Assignable` first and only chooses
words afterwards.

## Consequences

`tests/dialect/slice_assign.pas` and `tests/dialect/slice_escape.pas`.

**Mutations, two, each killing one named test.** Disabling `Assignable`'s slice
arm restores the out-of-bounds write and fails `slice_assign` alone. Disabling
`ResolveInquiry`'s fails `slice_escape`. Restored with plain `cp` and `touch`,
rebuilt, green.

**The masking is the lesson worth keeping**, more than either defect. A guard
placed ahead of a predicate to improve a message silently made the predicate
untested, and the suite could not tell — the observable behaviour was identical
and only the mutation exposed it. `doc/sop.md` §7 records the general form.

**AP §6.7.3.9.2's NOTE is amended** and §6.8.3.5's neighbour gains the
assignment half. Annex E.8 records that this was a divergence between the
document's *reasoning* and the processor rather than between its requirements
and the processor: the requirement was right and unenforced, and the NOTE
explained why enforcement was unnecessary.

## What this does not do

**It does not add a slice arm to `AddressOfSym`.** Every other slice path
reads the slot directly and is correct; assignment was the only path that
reached a slice through it, and assignment is now refused. Adding one would be
storage for a construct no program can write.

**It does not fix the second reader's `a[i..j] := b[k..l]` finding
separately** — that form is refused by the same `Assignable` arm, having the
same operand types.

**It does not address `frame1`**, which the same audit found unreserved as a
foreign name, or the other citation defects. Those are ADR-0144's list.
