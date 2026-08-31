# 274. A branch is not a statement, and 784 of them were invisible

Date: 2026-08-31

## Status

Accepted, 2026-08-31.

## Context

`line-coverage` (ADR-0104) counts a **statement**: `pascalc --coverage` emits
one `pas_cov_hit` per statement, keyed on the line it begins on, and the
denominator is read back out of the same IR so the two halves of the figure
cannot disagree about what was instrumented. It is the finest instrument here
and it stands at 393 statements never run of 18 754.

It cannot see a branch, and its own record said so — `doc/sop.md` §7 has
carried the row since ADR-0104, and `doc/roadmap.md` named the gap in the
chapter about what working on this compiler lacks:

> `line-coverage` counts a **statement**, so `if c then a else b` on one line
> is covered when either arm runs. The ratchet stands at 456 uncovered of
> 18 700 — a statement denominator, and nobody knows the branch one.

Three shapes are invisible to a statement counter and each of them is ordinary
Pascal:

- **Two statements on one line.** The identity is the line, so `if c then a
  else b` written on one line emits one counter for each arm and both carry
  the same number. Either arm running covers both.
- **A decision with nothing on its false side.** `if c then a` has no
  statement to count when `c` is false, whatever line anything is on.
- **A short-circuit operator.** `a and b` may never evaluate `b`, and `b` is
  an expression, so no statement counter exists for it at all.

Nothing else here reaches them either. `procedure-coverage` is coarser by
construction; `kind-exhaustive` reads a dispatch over an enumeration and a
condition is not one; `verify/` proves a lowering and says nothing about what
was executed.

## Decision

`--coverage` emits a second counter, `pas_cov_branch(line, col, direction)`,
on **each edge of every decision the source writes** — an if-statement, a
while-statement, a repeat-statement, and each short-circuit `and`, `or`,
`and then` or `or else`. Direction 1 is the condition true and 0 is false; for
a repeat that is the iteration which ends rather than the one which runs.

The identity is a **pair**, line and column, because two decisions written on
one line is the whole complaint being answered and a line alone would collapse
them again. Every node carries a position and an operator node carries the
operator's own, so the column separates nested short-circuits without anything
new being recorded.

`line-coverage` reads both files one sweep produces and gates two ratchets,
`line_coverage.txt` and `branch_coverage.txt`. One sweep because the sweep is
the expensive half — three instrumented compilers over the whole corpus — and
asking a second question of a run already being made costs 0.0 s of the gate's
19.7. Two ratchets because a statement lost and a direction lost are different
regressions, and one number would let either hide behind the other's slack.

**The four constructs are the decisions a program *writes*, and that is the
boundary.** Three things are deliberately outside it:

- A **`for` statement**'s test is generated from its bounds; the program wrote
  no condition, and the only fact the edge would add is whether some loop ever
  ran zero times.
- A **case-statement** is n-way, and each arm *is* a statement that already
  carries a counter. The one edge it has that no arm holds is the trap for a
  selector matching no label, which is a runtime check.
- A **runtime check** — a bounds test, a subrange store, a nil dereference —
  is the compiler's branch and not the program's, and its false direction is
  `pas_runtime_error`. `verify/` is what holds those.

## Consequences

**784 of the 853 directions never taken sit on lines statement coverage calls
covered**, and 0 of those decisions were unreached — every one was evaluated
and only ever went one way. That is the size of the blind spot, measured
rather than argued: 92% of what this finds, nothing else here can express.

The first census is 9247 of 10 100 directions taken over 5050 decisions,
91.6%, against 97.9% of statements. The three worst are `EvalConstCall` at 60
of 210, `CheckStdProc` at 30 of 312 and `CheckBinary` at 28 of 252 — the
constant folder and the two largest checkers, whose refusal arms the corpus
enters from one side only.

**The untaken direction needs a block of its own, and three of the four could
not share one.** A while's exit block is where AP 6.7.5.10's `break` lands, so
a counter there would report a condition that never became false in a loop
only ever left by a break; a repeat's body block is entered once before the
first test, so a single-iteration loop would report both directions; and a
short-circuit's join is reached from the evaluated side as well, which also
moves the phi's incoming label to the new block. Only the if-statement's then
part was already a block nothing else reaches. Each of the three is a wrong
answer that would have looked like a working instrument.

**The ratchet cannot see a miswired counter, so a second check reads the IR.**
Changing `CovBranch(s, 0)` to `CovBranch(s, 1)` in `EmitIf` makes both edges
of every if report the same direction; the pair collapses into one key, the
denominator falls from 10 100 to 6995, uncovered falls with it, and the gate
reports an *improvement* and exits 0. So every site is required to emit one
counter per direction, checked from what the compiler wrote and not from what
the corpus ran — no case can satisfy it and none can hide it. The mutation now
names 3105 sites and exits 1. There is a floor too, `variant-check`'s: fewer
than 100 directions is a failure, so an instrument that measures nothing
cannot pass by measuring nothing.

**Nothing in the corpus had ever driven `--coverage`**, so every `covOpt` arm
in the code generator reported as unreached while this gate drove them on
every run — the sentence `coverage.py` already carried three times, for
`--dump-limits`, for `--version` and `-h`, and for `--target=`. A job over
`tests/control.pas` was added, that source holding all four decision kinds.
It is worth 17 statements and 17 directions.

**A decision inside a schema's body is counted once however many tuples
instantiate it**, because §6.4.7 re-emits the body per tuple and the key is a
source position. Covering it in one instantiation covers it in all. The
statement counter has had exactly this property since ADR-0104 and it is
stated here rather than discovered later.

**`--coverage` under `spawn` is a data race**, on the branch table and on
ADR-0104's statement table alike: neither is `_Thread_local`, ADR-0268 having
made that decision for the four runtime globals a task really owns. Nothing
measures a concurrent program today — the corpus sweeps the compiler, which is
one thread — and `doc/sop.md` §7 carries the row rather than a `_Thread_local`
that would give each task a table nothing merges.

The IR under `--coverage` grows: an if with no else-part now has an else
block, and each loop and short-circuit gains one. It is a measuring
instrument's cost, paid only under the flag, and no program compiled without
it emits a byte that differs.

## Alternatives rejected

**A counter per arm, which is what the roadmap proposed.** The arms already
have counters — they are statements — and the defect is that the *identity* is
a line. Adding a third counter to a statement that has one would have measured
the same thing again.

**Widening `pas_cov_hit` to carry a column.** It would separate two statements
on one line, which is one of the three shapes, and leave the other two: an
absent else-part has no statement to widen, and a short-circuit's right
operand is an expression. It would also rewrite a working denominator for a
partial answer.

**A separate gate with its own sweep.** Three instrumented compilers over the
whole corpus, run twice, to ask two questions of the same executions. The
suite is 262 seconds and `doc/roadmap.md` already says sixteen cases are 234
of them.

**Instrumenting every conditional branch in the emitted IR.** It would need no
decision about scope and would answer a different question: the bounds checks
and subrange stores would swamp the census, their false directions are traps
`verify/` already proves unnecessary or necessary, and a figure dominated by
them would move with the *checks* rather than with the corpus.
