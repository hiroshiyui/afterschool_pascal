# 78. The second Annex D was almost clean

Date: 2026-08-13

## Status

Accepted.

## Context

ADR-0077 put a probe against each of ISO 7185's sixty errors and found six
reported as values. ISO/IEC 10206:1991 has an Annex D of its own with a hundred
and five — the same sixty plus the ones its features brought: strings,
schemata, complex, direct-access files, bindable variables, function-accesses,
constant-accesses, `readstr` and `writestr`.

That is the larger list and the newer language, so it should have been the
worse one. It was not.

## Decision

**One error from the second annex was unreported, and it is in the first one
too.** D.32 (D.57 there, for both types in one sentence): "sqr(x) computes the
square of x. It is an error if such a value does not exist." For an integer
that is the overflow `checkedArith` has reported since ADR-0014; for a real it
is an infinity where the operand was finite, and it now traps.

The magnitude is what is tested rather than the value — `sqr(-1e200)` is `+inf`
too, and an operand that was *already* infinite is D.74's error, using a value
the type does not have, rather than this one.

**Everything else the second annex adds was already checked.** Probes were
compiled for the complex `ln` of zero (D.59), `x**y` with a negative left
operand (D.79), a `substr` running past the end (D.71), `bind` of a variable
already bound (D.54), the three `Seek` procedures past the end (D.33–D.35),
indexing an array-function's and a string-function's result (D.82, D.83), and
a `readstr` whose input runs out (D.51). Every one stopped the program.

## Consequences

**The interesting result is the ratio, not the fix.** Six of sixty in the older
annex, one of the forty-five the newer one adds — and the difference is not the
standards but *when the code was written*. Every Extended Pascal feature here
arrived with a record that had to say what it did not do, and an error
condition is the first thing that question turns up: ADR-0037 lists `**`'s,
ADR-0050 lists the direct-access file's, ADR-0051 lists the string's, ADR-0052
lists `bind`'s. ISO 7185's arithmetic predates that practice, so `sqrt`, `ln`,
real `/` and `mod` were written when the question was "does this compute the
right answer" and nothing later asked the other one.

That is an argument for the ADR habit rather than for the sweep, and it is the
first time one of these sweeps has produced evidence about the method instead
of about the compiler.

**ADR-0077's closing paragraph over-stated the gap it left, and cited the wrong
clause for it.** It named D.32 *and* D.47 as making "a value the type cannot
represent an error", and said an operation on reals that overflows still yields
an infinity. D.47 is about **integer** arithmetic — "it is an error if an
integer operation or function is not performed according to the mathematical
rules for integer arithmetic" — and that has been checked since ADR-0014. And
no clause makes a real `+ - * /` overflow an error at all: §6.7.2.2 makes the
accuracy of those operations implementation-defined, which is an Annex E
question and is answered there (E.8).

So the gap was one function, not a family, and it is closed here rather than
being left. The record itself stays as written — ADR-0001 makes these immutable
and superseding one means adding a record, which is what this is — and
`doc/implementation-defined.md` no longer carries the row that repeated the
claim. That row was written in the same hour as the record; a wrong citation
surviving one commit is the same fault ADR-0072 and ADR-0074 each found, and
the interval between making it and finding it is the only thing that has
improved.

**`verify/` gains nothing again**, and for ADR-0077's reason: the check's
condition is the emitted test. Nothing in `lowering.py` models real arithmetic,
because the proofs are about the integer semantics ISO 7185 pins exactly and
FP-internal properties where it does not.

### What this does not do

**It does not check the errors that need run-time bookkeeping**, which in the
second annex are the same ones as in the first: an undefined variable (D.11,
D.13, D.74), a reference outliving what it refers to (D.10, D.14, D.15, D.17),
an inactive variant of a *variable* (D.12), and `dispose` matching the `new`
that made it (D.40–D.42). All are recorded in `doc/implementation-defined.md`.

**It does not enforce the direct-access length bound** (D.4), which ADR-0050
stated and this sweep confirms is still open: an eleventh component may be
written to a `file [1..10] of T`. That one is a check per component written,
not a comparison at a single point.
