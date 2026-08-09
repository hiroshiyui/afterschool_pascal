# 8. Sema hands CodeGen a fully annotated tree

Date: 2026-08-09

## Status

Accepted

## Context

Type information can be recovered during code generation, and for a language as
small as milestone 1 it is tempting to skip a separate pass: codegen already
walks the tree and could look identifiers up as it goes.

That collapses two responsibilities. Codegen would then report user-facing
errors, which means it must continue after finding one, which means every
`emit*` function must cope with a tree it has already found to be wrong. Error
recovery and IR construction end up interleaved in the same functions.

The pressure gets worse with nesting: with procedures, scopes, and static links
arriving, a codegen that also resolves names has two stacks of state to keep
straight.

## Decision

`Sema` runs as a separate pass and establishes an invariant that CodeGen may
rely on without checking:

* every `Expr::type` is non-null,
* every `VarRef::sym` points at a resolved `Symbol`,
* every `Call::builtin` is resolved,
* constant expressions are folded and their values live on the `Symbol`.

The invariant holds on error paths too. When Sema reports an error it still
assigns a placeholder type rather than leaving null, so a half-checked tree
cannot crash a later pass. `main` stops before codegen if any diagnostic was
recorded, so those placeholders are never actually lowered.

Consequently CodeGen produces no diagnostics. If it needs a fact about the
source program, that fact belongs in Sema. Its only failure mode is
`verifyModule` rejecting what it built, which is a compiler bug and is reported
as one.

`Sema::variables()` exposes the declaration-ordered variable list, so codegen
allocates slots without re-walking declarations.

## Consequences

`codegen.cpp` is a translator with no error handling, and each pass can be read
on its own. Type errors are found before any IR is built, so a rejected program
costs nothing in the backend.

Sema and CodeGen must agree on the invariant, and nothing enforces it
mechanically. A new node kind that Sema forgets to annotate is a null
dereference in codegen rather than a diagnostic. This is the main cost, and it
argues for adding node kinds to both passes in the same change.

The tree is annotated in place — `type` and `sym` are mutable fields on the
nodes — rather than kept in a side table. Fewer moving parts, at the price of an
AST that is not const during checking.
