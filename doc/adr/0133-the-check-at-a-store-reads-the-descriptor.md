# 133. The check at a store reads the descriptor

Date: 2026-08-19

## Status

Accepted. Completes ADR-0113 and ADR-0127, and closes the deviation ADR-0127
recorded in its place.

## Context

ISO/IEC 10206:1991 §6.4.2.4 writes

> subrange-type = subrange-bound '..' subrange-bound .
> subrange-bound = expression .

and §6.2.3.8 b) evaluates a subrange-bound "not contained by a
schema-definition and closest-contained by ... the block" in the commencement
of the activation. ADR-0113 took that for a **variable's** denoter and ADR-0127
for a **type-definition's**, and both stopped in the same place: the bound was
admitted in an array's *index-type* and refused everywhere else.

The reason was in ADR-0127, and it was a good one. What an index-type's bounds
are for is the subscript check, which reads them out of the descriptor
§6.2.3.8 b) filled. What every **other** subrange's bounds are for is the range
check at a store, and `CheckedForSubrange` compared against the two numbers on
the type — which for a dynamically bounded subrange are placeholders, 1 and 0,
never read from anywhere. Left accepted it was worse than refused:

```pascal
var a: array [1..m] of 1..m;   { m = 3 }
a[1] := 2                      { traps: value out of range (1..) }
```

a **legal store, stopped**. So ADR-0127 confined such a subrange to an
index-type, called the confinement a deviation, and wrote down what would lift
it: "`CheckedForSubrange` has to read the descriptor the way the subscript
check does, and the message has to be built by the runtime the way an array's
already is". `doc/implementation-defined.md` §6 and `doc/sop.md` §7 have carried
it since as the one conformance defect that was known and unfixed.

## Decision

**The range check at a store reads its bounds the same way the subscript check
does**, and the confinement comes out with the flag that expressed it.

- `CheckedForSubrange` calls `BoundValue` for each end instead of `OpInt` on
  the type's two numbers. `BoundValue` answers a constant where there is one
  and loads the discriminant where there is not, so this is a strict
  generalisation of what was there: nothing about a subrange with constant
  bounds changed.
- The comparison moves to **i32** where a bound is dynamic, because that is the
  width a discriminant is loaded and widened to; a char or boolean value widens
  to meet it with `zext`, which is exact because their ordinals are
  non-negative. That is the same widening the subscript check makes on an
  index.
- `NeedsSubrangeCheck` answers **yes** whenever a bound is a discriminant. It
  cannot do otherwise: the question it asks is whether the subrange covers its
  whole host, and reading the placeholders to answer it would answer about the
  subrange 0..0, which is a subrange nobody wrote.
- `dynBoundsIndex` — one-shot, set by `ResolveArray`, read by exactly one
  condition in `ResolveType` — is **deleted**, in the compiler and in `src/`.
  The withdrawal it qualified now reads `if (d^.kind <> nkArray) and (d^.kind
  <> nkSubrange)`, and the two kinds together are the whole of what the clause
  reaches: a bound written in a variable-declaration or a type-definition of
  this block, at any depth of arrays and subranges.

**A subrange needed no clause of its own about sizing**, which is why the
change is this small. §6.2.3.8 b) is otherwise about storage whose extent is
not known until entry; a subrange's storage is its host's whatever its bounds
are. The bounds decide what a store is *compared against* and nothing else.

**`tests/extended/dynbounds_subrange.pas` is the property**, with every host
the feature admits — an integer, a char and an enumeration — a component at two
array dimensions, a nested procedure reading the descriptor of an enclosing
activation, and a heap variable of such a type through `q = ^t`.
`tests/extended/trap_dynsubrange.pas` is the check doing its work.

### The three things that had to move with it

Each was invisible while the only dynamically bounded subrange anywhere was an
array's index-type, which is asked about the *array*.

**`DynamicExtent` answered yes for a subrange**, on the strength of its
discriminants. Wrong the moment one can be a variable: it would have allocated
the variable by a size the descriptor answered, for a type whose size is four
bytes. A subrange is now asked before its bounds are.

**The anonymous schema leaked into two rules that are about §6.4.8's.**
ADR-0113 gives a variable with non-constant bounds a schema with no body and no
name, because everything downstream of a dynamically sized variable is keyed on
one — `IsGeneric` is "a schema and no tuple". For a structured type that is the
whole point. For a subrange it made two rules answer about the wrong thing:

- `Assignable` returned `toT^.schema = fromT^.schema`, so `x := 3` into
  `var x: 1..m` was **refused**. What the type is is a subrange, and §6.4.6
  asks about its host.
- The assignment lowering took the tuple-check-and-memcpy path, so a four-byte
  store became a comparison of discriminants and a copy sized from a
  descriptor.

Both are now exempt by kind, and the exemption is written as what it is: the
schema on such a type is a compiler device, not something a schema-definition
produced and not something a tuple selects.

**§6.4.2.4's other requirement had nowhere to be checked.** "The value denoted
by the first subrange-bound shall not be greater than the value denoted by the
second" is decided by Sema where both fold. Where one does not, an empty
subrange has no values, so every store into it traps — and a block that
declares such a variable and never stores into it would run to completion with
a type that is not a type. `CheckSchemaDomain` already walks a dynamic array's
component, so the arm is ten lines beside the one that reports an array with no
components. `tests/extended/dynbounds_subrange_empty.pas` is that program.

### The message, and the near-miss

ADR-0127 predicted the message would have to be built by the runtime. It was
right, and this is worth recording because the compile-time path *exists* and
looks like it works.

Where the bounds are constants the trap names the **type** — `value out of
range (small)`, or `(1..3)` where the subrange is anonymous, or `('a'..'c')`
for a char host. `WriteTypeName` handles a dynamic bound already, through
`WriteBoundName`, which writes a discriminant as **its own name**. That is
right for a schema, whose discriminant the program wrote; a bound in a
variable-declaration has no name, the program having written an expression. So
the compile-time path produces

```
runtime error: value out of range (1..)
```

which is the *defect's own message*, arrived at for a different reason and
indistinguishable from it. `pas_range_error` names the bounds as values
instead, exactly as `pas_index_error` does and for the same reason — and prints
them as ordinal numbers whatever the host is, again as the index message does.

## Consequences

**A program that was refused now compiles**, in `--std=extended` and
`--std=afterschool`. ISO 7185 §6.4.2.4 writes `subrange-type = constant '..'
constant`, so nothing changes there.

**One diagnostic changed wording, in two goldens.** With the offer live at a
subrange denoter, a bound that fails to be *ordinal* is now reported by the arm
that says so — *the bounds of a subrange must be ordinal* rather than *must be
ordinal constants*. `tests/extended/constnil_errors.err` has `q..q` with
`q = nil` and `tests/dialect/int64_types.err` has `1..maxint64`; in both the new
message is the accurate one, and neither fault was ever about constancy. This
is the same correction ADR-0127 made for a schema's discriminants.

**`tests/extended/dynbounds_errors.pas` is now the catalogue of what is left
refused** rather than of what was refused. Three of its five cases moved to
`dynbounds_subrange.pas`.

**No lowering rule changed.** The bounds check is the one ADR-0017 proved, with
the bounds read from a descriptor rather than from the type — ADR-0113's
situation exactly, and ADR-0127's. The commit carries `Model-unchanged:`.

**`src/` carries the Sema half.** This is the conformance surface, so the
reference front end implements the same clause: the withdrawal, the deleted
flag and the `Assignable` exemption. `difftest` is what would say if it did
not.

### What this does not do

**A record field, a set's base type and a file's component still refuse a
non-constant bound**, and the reason is not the one ADR-0127 gave. That record
said a field's storage "is sized where the record is", which is an argument
about *sizing* and a subrange needs none — so the sentence does not survive
this change even though the refusal does.

What actually holds them is the shape of the withdrawal. It is made at the
**container**: `set of 1..m` stops at the set denoter, `record f: 1..m end` at
the record denoter, and `file of 1..m` at the file denoter, before either
recurses. Letting a subrange through there would let an *array* through with
it — `record f: array [1..m] of integer end` is a genuine sizing problem — so
it needs a rule that distinguishes them, which is a second one-shot flag of
exactly the kind this record deletes. One of the three has a reason of its own
besides: a set is one 256-bit word laid out from its base type's ordinal range
(ADR-0028), so a dynamic base type has no representation to give.

They are legal under §6.2.3.8 b) — a bound inside a record-type written in the
block is closest-contained by the block — so this is a deviation, narrower than
the one it replaces, and `doc/implementation-defined.md` §6 and `doc/sop.md` §7
carry it in those words.

**It does not let the type escape its block**, which is ADR-0127's sentence
unchanged: the descriptor is a frame slot, so such a type means something only
inside activations of the block that defines it. A heap variable of one works
because `^t` names `t`, and `t` is nameable only there.

**It does not make the diagnostic spelling of such a type any better.**
`WriteTypeName` still writes `1..` for a subrange whose upper bound is an
anonymous discriminant, so *cannot assign real to a variable of type 1..* is
what a program is told. That is ADR-0113's wart rather than this change's — an
array's type reads the same way — and the trap message, which is the one a
running program sees, no longer has it.

## Alternatives rejected

**Keep the compile-time message.** It costs nothing, `WriteTypeName` already
writes a discriminant by name, and for `type t = 1..m` it even produces the
right answer, `t`. For the anonymous case it produces `value out of range
(1..)`, which is the message the defect this record fixes used to print. A
message that is right for one spelling of a type and misleading for another is
worse than one rule, and the rule the array already follows is to name the
values.

**Name the bounds at compile time and the values at run time, choosing by
whether the type has an alias.** One more spelling-dependent message, for a
saving of one runtime call in the case that needs it least.

**Emit no check where the bounds are dynamic.** It compiles, it is small, and
it silently drops a check the standard requires — the alternative ADR-0127
rejected for the same reason, and the reason has not changed.

**Give the subrange its own descriptor kind rather than reusing the anonymous
schema.** It would have kept `Assignable` and the assignment lowering from ever
seeing a schema on a subrange, which is the confusion this change had to fix
twice. It would also have been a second descriptor mechanism to keep in step
with the first, and the two exemptions are four lines. Exempting by kind says
what is true — a subrange is not produced from a schema — where a second
mechanism would only have hidden the question.
