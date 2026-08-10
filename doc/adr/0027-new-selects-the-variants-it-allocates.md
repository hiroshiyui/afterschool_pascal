# 27. `new` selects the variants it allocates

Date: 2026-08-10

## Status

Accepted. Reverses the restriction ADR-0019 recorded.

## Context

ADR-0019 built pointers and rejected the second form of `new`. ISO 7185
§6.6.5.3 gives it as

    new(p, c1, ..., cn)

which creates a variable with the variants those tag values select — one value
per nested variant part, outermost first — and `dispose(p, c1, ..., cn)` gives
it back. This compiler always allocated the whole record: safe, but not the
feature.

ADR-0026 is what makes the form worth having. With one level of variants `n`
can only be 1, and the saving is whatever the largest arm costs; with nesting
the selection is a path and the saving compounds.

## Decision

**Sema folds the tag values into a path.** `ProcCallStmt::variantSelection` is
the arms the values select, as indices into the variant part at each level —
the same shape ADR-0026 gave `Field::variant`, and it is what `--dump-sema`
prints as `variants 1.0`. Each value must be an ordinal constant of that
level's tag type and must select some arm; five diagnostics say which of those
failed, and a sixth separates "this record has no variant part" from "no more
nested variant parts to select", because they are different mistakes.

**CodeGen trims the tail, and only the tail.** `selectedSize` walks the
selection and returns

    offset of the shared storage + the selected arm's size

at each level, with the offsets taken from the *full* type. That is the part
worth stating: every selected field still lies exactly where the full layout
puts it, so nothing else in codegen has to know that this variable is smaller —
`p^.field` is the same `getelementptr` it always was. Only the tail, which the
unselected and possibly larger arms would have needed, is left off.

`dispose` checks its tag values the same way and then ignores them: the runtime
frees by address.

## Consequences

The three ISO deviations the roadmap listed after the bootstrap are now closed,
and the "known limitations" section is down to the deliberate ones.

**The saving is not observable, and that shaped the test.** A conforming
program cannot tell how much was allocated, so the only property worth
checking is that the allocation is *sufficient* — and that is harder to test
than it looks. `malloc` rounds its chunks up, so a record short by eight bytes
still fits and nothing goes wrong. The first version of
`tests/new_variants.pas` therefore caught **none** of three deliberate errors
in `selectedSize`. The sizes in it are now deliberately coarse — two hundred
bytes of fixed part, four hundred in the selected arm, four thousand in the one
not selected — so that dropping the storage offset, descending the wrong arm,
or counting only the fields is short by hundreds of bytes rather than by eight,
and a hundred live records make the overrun land on a neighbour. All three are
caught now.

**A fourth mutation still escapes, and should.** Trimming only the outermost
level *over*-allocates, and over-allocating is conforming: §6.6.5.3 says what
the created variable is, not how many bytes it costs. There is no test that can
distinguish it from the exact answer, and inventing one would mean testing an
implementation detail rather than the standard. The honest statement is that
the sufficiency of `selectedSize` is tested and its minimality is not.

**This is also where a sanitiser would have paid**, and ADR-0025 already
records why there is none: instrumentation happens during IR generation from C
or C++, and Debian's LLVM 21 ships no `libclang_rt.asan.a`. An under-allocation
is precisely the bug ASan reports immediately and a golden file reports only by
luck.

**ISO's restriction on the created variable is not enforced.** §6.6.5.3 says a
variable created by the second form may not be an operand of an assignment or
an actual parameter — because its unselected variants do not exist. Detecting
that needs the pointer's *value* to carry which form created it, which is a
run-time property, and nothing here tracks it. The compiler is permissive where
the standard is restrictive, which is the same shape as the use-after-dispose
gap ADR-0019 recorded, and is listed with it.
