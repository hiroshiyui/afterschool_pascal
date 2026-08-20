# ADR-0139: Two slices are compatible, and that is not permission to compare them

Date: 2026-08-20

## Status

Accepted. Corrects a defect in ADR-0125's slice, found through ADR-0138's
containment sweep. Adds AP §6.8.3.5 to `doc/afterschool-pascal-spec.md`.

## Context

AP §6.4.5 extends ISO/IEC 10206:1991's compatibility:

> Two slices (6.7.3.9) shall be compatible when their component types are the
> same type. Their lengths shall not be required to agree.

That rule exists for parameter passing, and it is the whole point of the
feature: one `array of T` formal has to accept `a[1..2]`, `a[1..99]` and a
whole array, which is why the extent is not in the type.

The relational operators ask compatibility too. So:

```pascal
var a: array [1..8] of integer;
...
  writeln(a[1..2] = a[3..4])
```

was accepted by Sema, handed to CodeGen, and emitted as

```llvm
  %v4 = icmp eq { ptr, i32 } 0, 0
```

— an `icmp` whose operand type is the two-word descriptor and whose operands
are the literal 0. **Invalid IR.** `clang` refuses the module and reports it
against a file the programmer never wrote, which is the exact shape ADR-0121's
`foreign-reserved` gate exists to prevent from the other direction.

All six operators, and every component type: `<` on two slices of `real`
produced `icmp ult`, which is an unsigned integer comparison of two doubles —
three wrong things in one instruction.

**It is a violation of the Sema-to-CodeGen contract**, not merely a missing
check. `CLAUDE.md`'s statement of that contract is "if it needs a fact about
the source program, that fact belongs in Sema", and the fact CodeGen needed
here was that these operands cannot be compared at all.

**It is also ADR-0058's shape, for the second time:**

> A permission granted in a shared predicate leaks to every caller.
> `assignable` is asked by the relational operators too, which is why ADR-0058
> had to write the comparison refusal out separately.

ADR-0058 wrote that sentence about a restricted type and its underlying-type,
where `n = 3` rode in on an assignment permission. The lesson was recorded in
`CLAUDE.md` and the same predicate was extended again without it being applied.

## Decision

**A slice operand is refused by the relational operators, in its own branch.**

```
a slice cannot be compared: 6.4.5 makes two slices compatible so that one
'array of' parameter accepts either, and that is not an order or an equality
-- 6.8.3.5 gives an array no relational operators
```

Three details, each of which could have gone the other way:

**Its own branch, not a condition on an existing one.** The obvious placement
is beside the string comparison, since a slice of `char` and a string are
nearly the same shape. It does not work: `IsStringOrChar` answers no for a
slice — it is unpacked and its extent is not in its type — so the string branch
is not reached, and neither is `IsMemory`, a slice being `tySlice` rather than
`tyArray`. Everything fell to the final `Assignable` fall-through. The branch
sits where the other dialect type's is, immediately after the optional's.

**Either operand, not both.** `a[1..2] = b` for a whole array `b` previously
gave the generic *needs comparable operands* message; it now gives this one.
That is the better answer: there is no type on the other side that would make
the comparison mean something, so the slice is the reason in every case.

**No lowering was written instead.** §6.8.3.5 gives an array no relational
operators at all, and a slice is an array's components with the extent removed,
so there was never anything for the dialect to have extended. Comparing two
slices would need a length rule this feature deliberately does not have — the
whole design is that the callee cannot see where its slice came from — and
inventing an answer would be the dialect adding an operator by accident, which
is what happened.

## Consequences

`tests/dialect/slice_compare.pas` is the case: nine comparisons, all six
operators, three component types, and one mixed operand pair.

**Mutation**: `false and (IsSlice(l) or IsSlice(r))` — Pascal's `and`
short-circuits, so the branch is dead and the compiler is otherwise identical.
Rebuilt, and exactly one case of 619 fails: `slice_compare`. Restored with
plain `cp` and `touch`, rebuilt, green.

**No conformance-mode program could reach any of it.** Slices are dialect-only,
so 618 cases were green over invalid IR for two increments. The corpus never
tried, which is the same sentence ADR-0067 and ADR-0080 close with, and this is
the third time it has been the right diagnosis.

**How it was found is the part worth keeping.** ADR-0138's sweep reported one
case in 228 that diverges for a reason of its own — `substring_errors`, where
`a[1..2]` on an `array [1..4] of integer` is a substring under Extended Pascal
and a slice under the dialect. That is not a defect and is catalogued as such.
Following it — asking what *else* the dialect now accepts in that position —
found this. So the gate did not find the bug; it made a corner of the language
visible and the bug was in the corner. That is a different kind of value from
a test, and it is the argument for sweeps over witnesses.

## What this does not do

**It does not give slices a comparison.** If one is ever wanted, it needs a
decision about unequal lengths and it belongs in the spec before the compiler.

**It does not audit the other operators by construction, though they were
probed.** Eighteen positions were tried against a slice — `ord`, `succ`, `abs`,
`trunc`, `+` on two slices and on a set, `*`, both sides of `in`, `write`,
assignment in both directions, `new`'s tag values, a `case` selector, a `for`
bound. Every one refuses, each through the message that position has always
given. The only two that accept a slice are the two the specification says
shall: `length` (AP §6.7.6) and indexing (AP §6.5.3.2).

That is a probe and not a proof. What has not been done is a systematic sweep
of every predicate AP §6.4.5 newly satisfies, which is the general form of this
defect and of ADR-0058's — `doc/sop.md` §7 carries it.
