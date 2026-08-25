# 208. `break` and `continue` leave one loop

Date: 2026-08-26

## Status

Accepted. AP 6.7.5.10, AP 6.7.5.11.

## Context

Neither standard has a way to leave a loop early. ISO 7185 §6.8.3 and
ISO/IEC 10206:1991 §6.9.3.6–§6.9.3.9 give a repetitive-statement exactly one
exit — its own condition — and the only ways out are §6.9.2.4's goto and
§6.7.5.7's `halt`, one of which needs a label and the other of which ends the
program. What a program writes instead is a Boolean flag: `finished := true`
tested by the condition, and every statement after the flag guarded by it.

ADR-0177 took `exit` from the other Pascals for that reason, and the roadmap's
borrowings table names these two beside it — Turbo Pascal, Delphi and Free
Pascal all have `Break` and `Continue`, and they agree about both, which the
three do not always do. So the reference point is stronger here than it was for
`exit`, where two of the three give the construct a value and one does not.

**They were held back once, deliberately.** The suggestion list that produced
this record ranked them fourth of four and said they had only ergonomics behind
them where `exit` had a client — propagation stands on it (ADR-0178). That is
still true and is the honest reason this record has to argue for itself: what
it rests on is not a program that could not be written, because every one of
them can, but on ADR-0116's other half. The dialect's job is a Pascal you can
get daily work done in, and a flag variable is the shape a reader has to
decode back into the intent it replaced.

## Decision

**`break` terminates the closest-containing repetitive-statement; `continue`
terminates the current iteration of it.** Both are written with no argument.

- **Both are required procedure-identifiers**, not word-symbols (ADR-0140), so
  §6.1.3's shadowing is the whole of what keeps them out of a conforming
  program's way. `exit`'s shape for the fourth and fifth time, and for its
  reason: a procedure-statement is a position ISO/IEC 10206:1991 admits, so no
  rule about *where* they stand could distinguish them, and what makes them the
  dialect's is that the identifiers are nobody's under a conformance mode. Both
  modes therefore say *unknown procedure 'break'* and `src/` needs nothing —
  which the differential confirmed rather than assumed.

- **The repetitive-statement is one of the block the statement occurs in.**
  `exit`'s "never an enclosing one", for a loop: a `break` in a procedure
  nested in another leaves a loop of the nested procedure, and where that
  procedure has none it is refused. Enforced by a `loopDepth` counter that a
  block boundary saves and zeroes exactly where `stmtPath` is already saved and
  zeroed.

- **`continue` enters the point at which the loop decides to iterate again,
  and that is not always the head.** A for-statement tests the control-variable
  against the final-value *after* its statement and steps only where it has not
  been attained (§6.8.3.9), so continuing at the head would run the body again
  with the same value and never terminate. AP 6.7.5.11 therefore enumerates the
  four forms — while, repeat, for, and the two for-in forms — rather than
  saying "the beginning". The repeat-statement's condition gains a basic block
  of its own for the same reason.

- **Leaving a statement-sequence this way does not complete it**, so what it
  armed waits for the activation to terminate (AP 6.9.3.11.2 b). That is
  6.9.3.11's NOTE 2 about the goto-statement and 6.7.5.9's NOTE 1 about the
  exit-statement, taken unchanged. It costs nothing to implement — the flag is
  read again in the block's runner — and it is what makes the three constructs
  say one thing rather than three.

- **A for-statement left by a break is not completed either**, so §6.8.3.9's
  rule that the control-variable is undefined *after the for-statement is
  completed* does not reach it and the variable keeps the value it had. Stated
  as a consequence of the clause rather than as a new requirement, which is
  what keeps it from constraining an implementation whose loop completes
  normally.

## Consequences

**A deferred statement was where the rule had to be found rather than
written.** AP 6.9.3.11.3 lists what a deferred statement may not contain, and
`break` is deliberately not on it: the list is for constructs that mean nothing
in the runner however they are written, and a `break` whose loop is *inside*
the deferred statement means exactly what it says. So the ordinary requirement
had to do the work, and it does — zeroing `loopDepth` for the duration of the
check refuses `defer break` because it names no loop, and accepts
`defer while c do break` because it names one. Refusal by construction, which
is the answer this repository has reached before (ADR-0058, ADR-0182), and the
reason there is no second list to keep in step with the first.

**`stmtPath` was the obvious mechanism and is the wrong one.** It already
describes the enclosing statements and is already reset per block. But a
deferred statement is checked *where it is written*, so the path there still
holds the loop it stands in — and §6.8.1's reachability, which is what
`stmtPath` is for, must go on seeing that loop. The two questions want opposite
answers at the same point, which is why this is a second counter and not a
reading of the first.

**It cost no new machinery, for the fourth time.** ADR-0123, ADR-0176 and
ADR-0177 each found a feature needed less than the estimate assumed, and this
one needed nothing at all beyond a branch: the loop emitters already name every
block, and what was missing was only which two to remember. Three of the five
loop forms needed no new block; the ordinal for-statement and the
repeat-statement each needed one, and in both cases the block is the point AP
6.7.5.11 c) and b) name.

**What it does not have.** There is no form that leaves more than one loop, and
no label on either. A program leaving two writes a goto-statement, which both
standards have and this document does not change — and if that turns out to be
what daily work wants, the client will say so, which is ADR-0116's rule and not
a promise made here.

**What it is evidence about.** This is the first dialect feature landed with no
client but a reader, and it is worth recording as such: the four before it were
each demanded by a library module or a test case that could not be written
without them. The bar it was admitted under is the other Pascals' agreement
plus the roadmap's own sentence about gratuitous novelty, and that bar is
weaker. It should stay weaker — a feature that only reads better is one the
dialect can afford rarely, and a second one should be argued against this
paragraph rather than against ADR-0116's first half.
