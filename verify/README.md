# Formal verification of the lowering

This directory proves that what the compiler emits means what ISO 7185 says the
source meant — for *every* input, rather than for the inputs a test happens to
try.

```sh
pip install z3-solver
python3 verify/verify.py                                 # both halves
python3 verify/verify.py --prove                         # proofs only
python3 verify/verify.py --crosscheck                    # the real binary only
```

It runs as part of `ctest`, and *skips* rather than fails when z3 is absent.

**Which z3 decides whether the proofs pass, and a slow one looks like a wrong
compiler.** `verify.py` gives each rule 30 seconds (`--timeout`) and reports
`unknown` through the same channel as a counterexample — so with Debian
trixie's z3 4.13.3 the two symbolic 32-bit modulo rules time out and the run
says *"verification FAILED: mod-is-non-negative"*, which reads as an accusation
against the compiler rather than against the solver. z3 5.0.0 proves the same
two in well under a second. Install the pip package above rather than a distro
one, and if a rule fails, read its detail line before believing it: a
counterexample names an input, and a timeout says so.

## What is actually being claimed

A proof is only as good as the honesty about its scope, so:

| | |
| --- | --- |
| `iso.py` | the specification — ISO 7185 semantics as **properties** (a range, a divisibility, a uniqueness), never as a second implementation |
| `lowering.py` | a **model** of what the code generator emits, written to mirror it instruction for instruction |
| `rules.py` | the catalogue pairing the two, with the status of each claim |
| `verify.py` | the runner: proves each rule, then cross-checks the real compiler |

The specification says *what must be true of an answer* rather than computing
one. That is deliberate: if `iso.py` calculated `mod` the way the compiler does,
proving them equal would prove nothing, and the circularity would be invisible.
Instead the solver is asked whether any input makes the lowering fall outside the
range ISO requires, or break the divisibility ISO requires.

## The gap this approach has, and what closes it

**The proofs reason about `lowering.py`, not about the compiler.** If the model
drifts from `selfhost/compiler.pas`, the proofs keep passing and start being
about nothing.
A stale proof is worse than no proof, because it reassures.

`--crosscheck` is the countermeasure: it compiles and runs a real Pascal program
with the real compiler at the adversarial points, and compares against the
specification computed independently in Python. It is compiled at **both `-O0`
and `-O2`**, because a disagreement between them is the signature of undefined
behaviour in the emitted IR being exploited by the optimiser.

So: a cross-check failure means the model is lying, not merely that a test broke.
Fix `lowering.py` before believing anything else in this directory.

## Bounded rules

Rules marked `proved*` are established at widths 4, 6, 8 and 10 rather than at
the real 32. Any claim involving a *symbolic* division or multiplication
bit-blasts into a circuit far too large to solve at 32 bits — measured, not
assumed: both 32- and 64-bit encodings ran past 60 seconds without an answer,
while the same claim at 10 bits solves in under a second.

The lowering is the same instruction sequence at every width, which is the
argument for generalising from the small cases. **It is an argument, not a
proof**, and the report says so every run.

## Known gaps

Rules with status `KNOWN_GAP` are places the compiler is known to be wrong or
unchecked, kept in the catalogue with the counterexample as documented evidence.
They are not failures.

The catalogue is symmetric on purpose: **if a known gap starts holding, that is
also a failure.** It means someone fixed the compiler and this directory is now
describing a compiler that no longer exists. Update the rule to `MUST_HOLD` in
the same change that fixes the gap.

## Adding a rule

1. Model the lowering in `lowering.py`, naming the construct it emits.
2. State the ISO property in `iso.py` — a property, not a computation.
3. Add a `Rule` to `rules.py` with its ISO clause, its source reference, and its
   status. Start at `FULL` width; move to `BOUNDED` only when the solver times
   out, and say so.
4. If the operation is expressible in the Pascal accepted today, add its
   adversarial points to the cross-check tables in `verify.py`.
