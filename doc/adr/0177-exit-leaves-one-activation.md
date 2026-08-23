# 177. `exit` leaves one activation

Date: 2026-08-24

## Status

Accepted. AP 6.7.5.9.

## Context

ADR-0176 closed with the one thing error unions do not have: **propagation**.
`try X` needs a way out of a block that is not the end of it, and neither
standard has one — a Pascal block has exactly one exit, and the only ways to
leave early are §6.9.2.4's goto and §6.7.5.7's `halt`, one of which needs a
label at the block's end and the other of which ends the program.

So the roadmap's borrowings table put `exit` before `try` rather than after it:
propagation is a question about *statements*, and until a statement can leave a
block there is nothing for it to be sugar over.

**This is the first dialect feature with an authority that is not a standard.**
Turbo Pascal, Delphi and Free Pascal all have `Exit`; two of them give it a
value. `doc/roadmap.md`'s open question §1 names them as a reference point —
not because they are authoritative, but because a Pascal programmer arriving
here already knows the spelling, and gratuitous novelty is a cost paid by every
future reader. Where they disagree the dialect answers for itself.

## Decision

**`exit` terminates the activation of the block the statement occurs in, and
`exit(e)` first assigns `e` to that block's function result.**

- **It is a required procedure-identifier**, not a word-symbol (ADR-0140), so
  §6.1.3's shadowing is the whole of what keeps it out of a conforming
  program's way. That is `int64`'s shape (ADR-0128) and `argcount`'s
  (ADR-0173), and the third time it has been the right one: `exit` is spelled
  in a position ISO/IEC 10206:1991 admits — a procedure-statement — so no rule
  about *where* it stands could have distinguished it. What makes it the
  dialect's is that the identifier is nobody's under a conformance mode, which
  is why both say *unknown procedure 'exit'* and `src/` needs nothing.
  `tests/dialect/inherits_extended.pas` declares a **function** `exit` and
  calls it, which is the harder case: the name is also what the required
  identifier is.

- **The block is the one the statement is in.** Not an enclosing one, and there
  is no form that leaves two. A goto already leaves as many activations as its
  label is blocks away (ADR-0032), and giving a second construct that power
  would be two answers to one question.

- **Terminating an activation is not terminating the program**, and everything
  that follows from that was already written. AP 6.9.3.11.2 b)'s armed
  statements run, the block's files and handles close, and a function's value
  is taken from its result variable — because the exit branches to *the
  epilogue*, which is where all three already happen. In the main-program-block
  it therefore ends the program the **ordinary** way, so §6.2.3.6's module
  finalizations run; that is the whole of what distinguishes it from `halt`,
  and `tests/dialect/exit_module.pas` is the program that can tell.

- **`exit(e)` is an assignment to the result, written by Sema** (ADR-0044's
  husk). The argument moves out of the argument list into an `nkAssign` on the
  node, and both spellings of a result assignment then go through **one**
  routine: 6.7.2's "at least one", AP 6.4.13's arm shorthand, and
  assignment-compatibility are decided in the same place for `f := e` and for
  `exit(e)`. `exit(errSyntax)` in a function answering a fallible-type picks
  the cause arm because that routine is where the choosing happens, and not
  because anything here knows about fallible types.

- **The lowering is a forward-referenced label and nothing else.** The first
  `exit` of a body claims a block number; each writes `br label %LN` and opens
  a fresh block for whatever follows, exactly as a local goto does; and one
  `br` plus the label itself sits between the body and the epilogue. Textual IR
  admits a label used before it is written, which an instruction list would not
  — the sequential emitter cannot return to a block it has left (ADR-0025), and
  this is the second time that constraint has cost nothing because the output
  is text.

- **A deferred statement may not contain one** (6.9.3.11.3, now four items),
  for the goto-statement's reason: the deferred statement is emitted in the
  block's runner as well as where its sequence completes, and the runner is not
  the activation an exit would terminate. Left in, it emits a branch to a label
  that function does not define, and the assembler says so.

## Consequences

- **What it unlocks.** The guard clause, which is most of what an early exit is
  for; and `try`, which now has something to be sugar over.
- **What it does not do.** It gives an exit-statement no value of its own and
  no way to leave more than one activation. It does not detect a function that
  exits without its result having been assigned — Annex C carries that, beside
  the same omission for a block that falls off its end. And it is not a
  `break`: a loop is left by leaving the activation, and a construct for
  leaving one loop is a separate question with a separate answer.
- **`stdProcKind` grew by one**, appended because `--dump-sema` prints a
  required procedure as its ordinal (ADR-0067), and `kind-exhaustive` named the
  three partial cases over it. `nkProcCall` gained the husk field and a
  `symbol` gained the block number, both cleared where they are made.
- **A ninth row in Annex B**, an eighth entry in `containment_exceptions.txt`,
  and a twenty-third position in `predicate-callers` — the last of which
  changed the *gate*: `exit(e)` can only stand in a function-block, so the
  probe program needed `q` to be a function, and its result assigned before the
  snippet or §6.7.2 would have refused every probe of that position whatever
  type it was given. A gate passing for the wrong reason is worth the six lines
  it took to notice.

## Mutation

Five, each a different line of the design. `EmitExitTarget` moved to *after*
`CloseFiles`: `exit` loses *armed: iteration 2 released*, *writes: released*
and reads the file back as `[empty]` — the three things terminating an
activation is supposed to do. The husk's assignment not emitted: `exit` answers
`firstAbove(10) = 0` and `tally(9) = 10`, the transfer working and the value
lost. The deferred-statement refusal removed: `exit_errors` loses a diagnostic,
and what it stops being is an assembler error. The dialect gate widened to
`HasExtended`: `exit_refused` is *accepted* under `--std=extended` where the
mode must refuse it — the conformance surface moved, which is the one thing
ADR-0117 does not allow. And a fifth over the module path, which fails
differently and is worth the sentence, as ADR-0175's did: with `EmitExitTarget`
not called for a module's initialization, `exit_module` fails at the assembler
with *use of undefined value '%L2'* rather than at run time.
