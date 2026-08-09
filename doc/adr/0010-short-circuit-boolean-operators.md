# 10. Boolean operators short-circuit

Date: 2026-08-09

## Status

Accepted

## Context

ISO 7185 does not specify whether both operands of `and` and `or` are evaluated.
The standard permits complete evaluation, and a conforming program may not
depend on either behaviour.

Real Pascal code depends on it anyway. The guarded-search idiom

```pascal
while (i <= n) and (a[i] <> x) do
  i := i + 1;
```

reads `a[i]` out of bounds on the final test under complete evaluation. Once
arrays and pointers arrive — both on the critical path in ADR-0004 — the
compiler's own source will be full of tests of this shape.

Free Pascal short-circuits by default; Turbo Pascal did not, and its users
wrote around it.

## Decision

`and` and `or` evaluate the right operand only when the result is not already
determined. Codegen emits a branch and a φ node rather than a bitwise `and`/`or`.

## Consequences

Guarded tests are safe to write, which matters most in the compiler's own
source. Where the right operand is a constant or an already-materialised value,
the optimiser folds the branch back into a select, so the cost of the extra
blocks is not paid in practice.

This is a choice among behaviours the standard permits, not a deviation from it:
a conforming program cannot detect the difference. A program that *does* detect
it — one whose right operand has a side effect the left operand can suppress —
was already relying on unspecified behaviour.

The visible cost is in the IR. Every `and` produces two extra basic blocks and a
φ, so unoptimised output is noticeably wordier than the arithmetic suggests.
That is worth knowing when reading `--emit-llvm -O0`.
