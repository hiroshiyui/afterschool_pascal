# 26. A variant part may contain a variant part

Date: 2026-08-10

## Status

Accepted. Reverses the restriction ADR-0018 recorded.

## Context

ADR-0018 built variant records and rejected one thing the standard allows: a
variant part inside a variant. The reasoning was that nothing in the bootstrap
needed it and that rejecting it kept the gap visible. That was true, and the
bootstrap is now finished, so "nothing needs it" has stopped being a reason.

ISO 7185 §6.4.3.3 does not treat an arm as a special construct. A record is a
field-list; a field-list is record-sections followed by an optional
variant-part; and *an arm's field-list is a field-list*. So an arm is shaped
exactly like a record, and the nesting has no depth limit.

What blocked it was the representation, not the parser. `Field::variant` was a
single `int` — the index of the arm the field lives in, or `-1` for the fixed
part — and one integer cannot say *where* a field is once arms contain arms.

## Decision

**A field records a path, not an index.** `Field::variant` is a
`std::vector<int>`: empty is the record's fixed part, `[k]` is arm k of its
variant part, `[k, j]` is arm j of the variant part inside arm k, to any depth.
On the Pascal side it is a `numPtr` list, built by `PathAppend` and shared by
every field of one field-list, since a path is never changed once built.

**An arm is a record.** `Variant` gained the three members that made a record a
record — `variants`, `tagField`, `tagType` — and `VariantArm` in the AST gained
the tag members `TypeExpr` already had. Everything that used to special-case
"the record" and "an arm" collapsed into one pair of functions keyed by a path:

- `fieldsAt(record, path)` and `armsAt(record, path)` — the field-list and the
  arms at that point, the record's own when the path is empty;
- `variantType` builds an arm's struct, which now carries the storage for its
  own variant part as a last member, exactly as the record does;
- `variantStorageType` measures the arms at a path rather than at the top;
- `fieldAddress` walks the path. At each step the shared storage is the last
  member of the struct it is in, and the arm laid over it starts at the same
  address — so stepping in is one `getelementptr`, not two.

The layout rules are unchanged, and so is ADR-0018's reason for them: the
storage's element type carries the alignment, so `[k x i64]` rather than
`[n x i8]`, at every level.

**The dump grew a path too.** `--dump-sema` prints a field's variant as `-`,
`0` or `0.1` where it printed `-1` or `0`, and names each arm by its path. That
is the differential contract, so `src/astdump.cpp` and
`selfhost/compiler.pas` changed together.

## Consequences

The parser, Sema, CodeGen and both dumps recurse where they used to iterate,
and the code is *smaller* for it — the record and an arm are one case now
instead of two that had to be kept in step.

**The depth guard had to move.** ADR-0020 bounds the tree at 1000 levels, and
every recursion in a type-denoter used to pass through `parseTypeExpr`, where
the guard is. A nested variant part does not: `parseVariantPart` calls itself
directly. It takes its own `Depth` guard for that reason, and without it a
deeply nested variant part would have been the one shape that could still blow
the stack.

**`--dump-ast` was not printing an arm's variant part at all.** The recursion
had to be added to the dump as well as to the parser, and the corpus would not
have shown it: no file in the tree had a nested variant part until this change
added one, so both compilers would have agreed by both omitting it. That is the
same failure mode counted in ADR-0022, ADR-0023, ADR-0024 and ADR-0025 — a
branch no test reaches is not compared, and agreement between two implementations
of nothing is worth nothing.

**The test is known to be able to fail.** Three mutations of the layout —
an arm that omits the storage for its own variant part, a path walk that stops
after one level, and storage measured only at the top level — are each caught by
`tests/nested_variants.pas`. The record there has a `real` in one second-level
arm and a `char` in another, which is what makes the alignment observable; the
`deep` record covers the tagless `case T of` form and three levels of nesting.

**What is still not done** is the other half of §6.6.5.3: `new(p, c1, ..., cn)`
still allocates the whole record. Nesting is what makes that form worth having
— with one level, `n` can only be 1 — so it is now unblocked rather than
finished.
