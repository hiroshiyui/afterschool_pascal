# 5. Tag-dispatched AST instead of C++ RTTI

Date: 2026-08-09

## Status

Accepted

## Context

The AST needs down-casting: Sema and CodeGen both walk a tree of `Expr*` and
`Stmt*` and must recover the concrete node. The idiomatic C++ answer is
`dynamic_cast`, and the first draft of `sema.cpp` used it.

Two things rule it out.

Debian's LLVM is built without RTTI, so anything linking it is normally compiled
`-fno-rtti`. Mixing a `-frtti` translation unit with those headers is possible
but is a configuration that quietly breaks.

The larger reason is ADR-0004. The stage-1 compiler is written in Pascal, which
has no `dynamic_cast` and no vtable to interrogate. Any C++ construct used here
has to have a Pascal translation, and `dynamic_cast` has none. Writing the tree
walk on RTTI now would mean rewriting every walk during the port — exactly when
the most is already in flight.

## Decision

Tag nodes explicitly. `ast.h` defines `enum class NK`, every node carries its
`NK` and declares `static constexpr NK NodeKind`, and casting goes through:

```cpp
template <typename T, typename N> T *as(N *n) {
  return (n && n->kind == T::NodeKind) ? static_cast<T *>(n) : nullptr;
}
```

Adding a node means adding an `NK` enumerator and the `NodeKind` member.
CodeGen dispatches on `switch (s->kind)`, which the compiler can check for
exhaustiveness; Sema uses the `if (auto *x = as<T>(...))` chain.

## Consequences

The C++ tree walks are now a mechanical translation of what the Pascal version
will do with a tag field and a variant record. The port becomes transcription
rather than redesign, and `-fno-rtti` builds cleanly against Debian's LLVM.

Dispatch is a load and a compare rather than a runtime type walk, which is
incidental but not unwelcome.

The cost is that the node hierarchy is closed: a new node kind touches the
central enum, so nodes cannot be added from outside `ast.h`. For a compiler
whose node set is decided by a fixed language standard, that is not a real
constraint.

`ap::ParseAbort` remains the one exception type in the codebase, thrown only by
the parser and caught only in `main`. Pascal has no exceptions, so the port will
replace it with an error flag on the parser state — a contained change because
nothing else in the code depends on unwinding.
