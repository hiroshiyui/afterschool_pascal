# 13. Formal verification of the lowering

Date: 2026-08-09

## Status

Accepted

## Context

A compiler is the one program whose bugs are silently inherited by every program
it builds. A miscompilation does not announce itself: the source is right, the
test is right, and the answer is wrong. Testing is particularly weak here — the
suite in `tests/` checks a few dozen values of `mod`, while the operation has
2^64 inputs, and the interesting ones are precisely the boundaries nobody thinks
to write down.

This project has more reason than most to care. ADR-0004 commits to self-hosting,
and from stage 1 onward the compiler is built by a binary that was built by a
binary. A lowering bug that survives into stage 1 is reproduced by every later
stage, including the one that would have to be trusted to find it.

The realistic options were: prove the whole compiler correct in the style of
CompCert; mechanise the language semantics and use them as a differential
oracle; or verify the individual lowering rules against a specification.

A CompCert-style semantic preservation proof is the strongest result and the
wrong one here. It is a multi-year effort, it requires the compiler to be
extracted from a proof assistant, and that directly contradicts the self-hosting
plan — the compiler would be Rocq-and-OCaml, not Pascal.

## Decision

Verify the **lowering rules** with an SMT solver: for each construct, state what
ISO 7185 requires of the result, model what `codegen.cpp` emits, and ask Z3
whether any input makes them disagree. This lives in `verify/`, runs under
`ctest`, and skips cleanly where z3 is absent.

Four things make it more than decoration:

* **The specification states properties, not computations.** `iso.py` says
  `mod` yields a result in `0..j-1` that differs from `i` by a multiple of `j`.
  It does not compute `mod`. Had it done so the proof would have compared two
  implementations of the same idea and the circularity would have been invisible.
* **The catalogue is symmetric.** Rules are `MUST_HOLD` or `KNOWN_GAP`, and a
  known gap that starts *holding* fails the build too — that means the compiler
  was fixed and the catalogue now describes a compiler that no longer exists.
* **Proofs are paired with a cross-check against the real binary.** The proofs
  reason about a hand-written model of `codegen.cpp`, and a model can drift. The
  cross-check compiles and runs actual Pascal at the adversarial points, at both
  `-O0` and `-O2`, and compares against the specification computed independently.
* **Bounded rules are labelled as bounded.** Claims involving symbolic division
  or multiplication cannot be solved at 32 bits, and are established at widths
  4–10 instead. Every run prints that this is an argument for generality, not a
  proof of it.

## Consequences

Fifteen rules are now checked on every `ctest` run: eleven claimed correct (nine
at the full 32-bit width) and four known gaps. The semantics that ADR-0002 and
ADR-0010 committed to — the non-negative `mod`, truncating `div`, `odd` on
negatives, ordinal `char` comparison, the exact integer-to-real widening — are
established for all inputs rather than for the handful `tests/` samples. The
`for` loop's "cannot overflow" claim, previously a comment asserting a design
argument, is now discharged as a theorem.

Writing the catalogue immediately found four real defects that the test suite
did not: `chr` truncates instead of rejecting an out-of-range ordinal;
`INT_MIN div -1` is undefined behaviour that the zero-divisor guard does not
catch; `succ(maxint)` wraps silently; and `sqr` overflow is `nsw` poison rather
than a diagnosed error. None were known before the solver was pointed at them.
They are recorded as gaps rather than fixed, because each is a language-design
question (what should an ISO error condition *do*?) that deserves its own
decision.

The costs are real. `verify/` is Python, so it is a second language in a project
whose point is to be written in Pascal — it verifies the compiler but does not
travel with it into the bootstrap, and a Pascal-hosted successor will need this
rewritten or kept as an external tool. The model in `lowering.py` must be
maintained alongside `codegen.cpp`, and a stale model is worse than no model
because it reassures; the cross-check is the only thing standing against that,
and it only covers constructs expressible in the Pascal accepted so far. And a
verified lowering is not a verified compiler: the parser, Sema, and the
translation from AST to the modelled operations are all still trusted.

What this buys is not certainty. It is that the class of bug most expensive to
find — silent arithmetic miscompilation, discovered in the bootstrap — is now
found by a solver at commit time.

## Not decided here

Whether to eventually mechanise the full language semantics, or to attempt
translation validation against the emitted IR rather than a model of it, is left
open. The second would close the model-drift gap properly and is the natural
next step if this proves its worth.
