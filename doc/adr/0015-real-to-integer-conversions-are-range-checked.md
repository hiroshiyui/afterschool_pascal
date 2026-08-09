# 15. Real-to-integer conversions are range-checked

Date: 2026-08-09

## Status

Accepted. Extends [ADR-0014](0014-iso-error-conditions-trap-at-run-time.md),
which applied the same policy to integer arithmetic and explicitly left this
case open.

## Context

ADR-0014 established that ISO error conditions are detected and reported at run
time, and closed four of them. It named one it did not close: `trunc` and
`round` were a bare `fptosi`, which LLVM defines as poison when the value does
not fit the destination — so `trunc(1.0E18)` produced an arbitrary integer and
carried on.

Nothing about the policy was in doubt; the reason it was deferred is that the
check is shaped differently. Integer overflow is detected *after* the operation,
from a flag the hardware sets. A floating-point conversion has no such flag: the
range has to be tested on the operand *before* converting, which raises two
questions the integer cases never posed — where exactly the boundary is, and
what happens to values that are not numbers at all.

## Decision

`checkedFPToInt` tests the value against the two exactly representable powers of
two just outside the integer range, and traps when it is not strictly between
them:

```
-2147483648.0 < x < 2147483648.0
```

Strict inequalities are what make the bound correct: `x > -2147483648.0` admits
`-2147483647` as the smallest truncation, matching the `-maxint..maxint` type
from ADR-0014 rather than the machine word.

The comparisons are **ordered** (`fcmp ogt` / `olt`), so a NaN fails both and
traps. This is the decision worth recording: an unordered comparison would have
let NaN through to `fptosi`, which is poison for NaN, and the resulting integer
would have looked plausible. It is a one-character difference in the IR with no
visible symptom until it matters.

`round` applies the same test to the *rounded* value rather than the argument,
so a real just below `maxint + 0.5` is accepted and one just above is an error.
`llvm.round` takes halfway cases away from zero, which is what §6.6.6.3 asks for.

## Consequences

The catalogue now has **no known gaps**: 25 rules, 21 of them established for
every 32-bit input. Every ISO error condition the compiler can currently detect
is detected.

Three rules cover this conversion, and the specification behind them is stated
as a property of the *truncated* value — that it lies in `-maxint..maxint`,
which is what §6.6.6.2 says — while the compiler tests the *argument* against
±2³¹. Proving those coincide is a real theorem rather than a restatement, and it
is exactly the step where an off-by-one boundary would hide.

Reaching that proof took two attempts, which is worth recording for whoever adds
the next floating-point rule. Stating the specification in real arithmetic via
`fpToReal` is the obvious formulation and mixes the FP and Real theories, which
did not solve in 30 seconds. Restating it with `fpRoundToIntegral` keeps
everything inside FP theory and proves in under a second. Prefer FP-internal
formulations; reach for Real only when nothing else expresses the property.

The cost is a compare and a branch on every real-to-integer conversion, and the
loss of the optimiser's freedom to assume conversions are in range. Both are the
same trade ADR-0014 made.
