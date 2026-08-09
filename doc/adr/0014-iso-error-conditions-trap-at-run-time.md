# 14. ISO error conditions trap at run time

Date: 2026-08-09

## Status

Accepted

## Context

ADR-0013 pointed a solver at the lowering and it found four places where the
compiler was silently wrong: `chr` truncated instead of rejecting an
out-of-range ordinal, `INT_MIN div -1` was undefined behaviour the zero-divisor
guard did not catch, `succ(maxint)` wrapped, and `sqr` overflow was `nsw` poison
rather than an error.

Each is a place where ISO 7185 says an *error* occurs. The standard defines an
error as a condition a processor is not required to detect, but which, if
undetected, means the program's meaning is undefined (§3.1). So "what should
happen" was genuinely open, and the four gaps were left unfixed until it was
answered rather than being patched one at a time.

The options were: detect nothing and document the language as unsafe, which is
what the compiler was accidentally doing; detect at compile time where possible;
detect at run time; or narrow the type system so the errors become
unrepresentable.

Detecting at compile time alone cannot work — `chr(i)` for a variable `i` is not
decidable at compile time. Doing nothing is defensible for a systems language
but not for this one: the compiler is going to compile *itself* (ADR-0004), and
a silent wrap inside the bootstrap is precisely the bug class that costs weeks.

There was also a precedent already in the code. Division by zero has always
called `pas_runtime_error`, which flushes, writes to stderr and exits 1. That
established the answer for one error condition; the only real question was
whether to apply it consistently.

## Decision

**Every ISO error condition the compiler can detect is detected, and reported at
run time through `pas_runtime_error`.** The program stops with a message on
stderr and exit status 1.

Concretely:

* Integer `+`, `-`, `*` (and `sqr`) go through `checkedArith`, which uses LLVM's
  `*_with_overflow` intrinsics and traps on the overflow bit. They no longer
  carry `nsw`.
* `chr(i)` traps unless `0 <= i <= 255`.
* `succ`/`pred` trap at the ends of their ordinal type.
* `div` keeps the zero-divisor guard and gains an explicit `INT_MIN / -1` test.

Two decisions follow from taking ISO's integer range literally. The type is
**-maxint..maxint** (§6.4.2.2), which is narrower than the `i32` it is
represented by: `INT_MIN` fits the machine word but is not a value of the Pascal
type. So `checkedArith` traps on a result of `INT_MIN` even when the hardware did
not overflow, and an **integer literal above maxint is now a compile-time error**
— previously `2147483648` truncated silently to `-2147483648`, which was how
`INT_MIN` entered the program in the first place.

A check is omitted only where its absence is *proved* sound. The `for` loop's
step and unary negation are both unchecked, and `verify/` carries the theorems
that say they cannot overflow.

## Consequences

The four gaps are closed and the catalogue now proves a *biconditional* for
each: the compiler traps exactly when ISO says the operation is in error. That
two-sided form matters — trapping always would satisfy "never produces a wrong
answer", and never trapping would satisfy "never rejects a valid program". Only
proving both directions says the check is in the right place. Twenty-two rules
now hold, eighteen of them for every 32-bit input.

Arithmetic costs a branch it did not cost before. The branch is perfectly
predicted and the error block is cold, so the practical cost is small, but it is
not zero and `-O3` will not remove it — verified, since removing it is exactly
what `nsw` used to permit. Losing `nsw` also costs some loop optimisation, which
is a real trade of speed for conformance, made deliberately.

The behaviour is a deviation in one direction worth naming: ISO does not
*require* detection, so a conforming processor may say nothing. Detecting more
than required cannot make a valid program invalid — every program this rejects
had undefined meaning already.

Rejecting out-of-range literals will surprise someone eventually, because
`-2147483648` looks like it should work and does in C and in Free Pascal's
default mode. It is nevertheless what §6.4.2.2 says, and the diagnostic names
`maxint` so the reason is visible at the point of failure.

## Not fixed here

`trunc` and `round` on a real too large for the integer type remain unchecked —
a bare `fptosi`, which is poison out of range. It stays in the catalogue as the
one documented gap. It needs a floating-point range test rather than an integer
one, and it is the natural next thing to close.
