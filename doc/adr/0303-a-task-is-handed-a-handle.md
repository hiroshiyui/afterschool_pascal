# 303. A task is handed a handle

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Closes the first row of
[ADR-0268](0268-two-threads-of-control.md)'s table of what two threads of
control left open, and spends the increment
[ADR-0267](0267-a-handle-moves.md) was landed for. AP 6.7.8.1 and
AP 6.9.3.12 are amended; AP 6.4.14.6's position rule is widened.

## Context

Three records name this gap and each names it as somebody else's to close.

ADR-0201 declined a concurrency construct and wrote down what one would need
first:

> A task cannot be **given** a socket or a file until a handle can move.

ADR-0267 built the move and closed saying it *does not, on its own, let a task
be given a handle. AP 6.4.14.6's position rule stands, so `take` may not yet
appear as an actual-parameter. That is the concurrency construct's to widen.*

ADR-0268 built the construct and closed saying *a task cannot be given a
handle. AP 6.4.12.7's move exists and the argument block does not use it… that
was ADR-0267's stated motivation and it is one increment early; the record says
so rather than letting the two imply each other.*

So the move existed, the construct existed, and the one thing missing was the
**position**: `take` stood on the right of an assignment and nowhere else, so
a socket could go from one variable to another and not into a task. A task took
transferable values and channels, and a server written with tasks could not
hand a connection to one.

## Decision

**A formal parameter of a task may be of a handle-type, and it is moved in.**
AP 6.7.8.1.

    spawn Serve(take(conn), back)

The actual shall be `take` applied to a variable-access of the formal's own
handle-type. AP 6.4.14.6 gains that as its second position and its only one
outside an assignment.

**Moved, where a channel is lent, and the difference is what makes each safe.**
A channel is the one object two activations may name and it is safe because it
is the only object in this language with a lock in it. A socket has no lock, so
what crosses is not a second name but ownership: the variable is emptied before
the activation commences, the formal holds the value, and the task's block
releases it exactly as the block that used to hold it would have. At no moment
do two activations hold one handle, which is the affine model unchanged rather
than a hole in it.

**The spelling is required rather than inferred.** Nothing would have stopped
the compiler from treating a bare `spawn Serve(conn, back)` as a move — it
knows the formal's type. It is refused, because a reader of the spawn-statement
has to be able to see that `conn` is empty from that point on, which is
ADR-0182's argument for `take` existing at all read one position over.

### Where it landed

The whole change is that one position, and every mechanism it needs was
already there:

- Sema's task-formal check admits `IsHandle`; the value-parameter refusal that
  already excepted a channel in a task excepts any handle in one.
- `CheckArguments` sets `takeOk` for that one argument before checking it, as
  the assignment sets it and for the same cause — the flag is a permission
  granted syntactically, before the value has resolved (ADR-0182).
- The argument block's field is a `ptr`, which is what a channel's already was.
- The spawn emits `pas_handle_take` on the actual's slot and stores the value
  into the block; the task's prologue does `pas_handle_init` with the type's
  own closer and `pas_handle_set`. That is AP 6.4.12.7's two calls with the
  argument block standing between them — and the order that matters for a move
  is not at risk, because nothing holds the value in between but a block that
  belongs to the thread about to be started.

**AP 6.9.3.12.1's join is not what keeps this correct**, and saying so is worth
a line: the join is what makes a *lent* channel safe. A moved handle is the
spawning activation's no longer, so there is nothing for the join to protect —
which is why the two kinds of parameter can share one position with two rules.

## Evidence

- `tests/dialect/task_handle.pas` is the case the row asked for: a program
  listens on an ephemeral port, connects to itself, accepts, and hands the
  connection to a task by `take`. The task reads the line the program wrote,
  writes an answer back through the socket it now owns, and reports through a
  channel; the program checks `conn = nil` after the spawn and reads the
  answer on the client side. The connection is closed by the *task's* block.
- The refusals are in `tests/dialect/concurrency_errors.pas`: a handle actual
  that is not a `take`, and a `take` of something that is not the formal's
  type. The heading `task GoodHandle(s: Stream)` that used to be an error is
  now the thing that compiles, which is the golden saying what changed.
- Two scenarios in `tests/spec/features/dialect_task.feature`, one citing
  AP 6.7.8.1 and AP 6.4.14.6 together for the move, one for the refusal.
- **ThreadSanitizer** is clean on `task_handle.pas` over a runtime built with
  `-fsanitize=thread`, and `sanitizers` — ASan, UBSan and LeakSanitizer over
  the whole corpus — passes with the case in it, which is what says the socket
  is closed once.
- 828 of 828 ctest cases green, stage 2 = stage 3, `producttest` 25 of 25.

## What is not done

**A handle cannot be *sent* through a channel**, `Transferable` refusing one at
any depth (AP 6.4.16.3). A task may be given a socket at the moment it starts
and not afterwards, so a server that wants to hand connections to a fixed pool
of workers still cannot; what it needs is a rule about which activation owns a
value sitting in a bounded queue, and no program here has wanted one yet.

**A file still has no move**, which is ADR-0267's own sentence and is not an
omission: there is no value in a file-variable for a variable to stop holding.
So a task can be given a socket, a stream or a directory and not a `text`.

**Nothing gives the handle back.** The task owns it and releases it, so a
program that wants the socket afterwards has to arrange it through a channel of
values, and there is no channel of handles. That is the same gap as the first
row above, seen from the other end.

**Two of ADR-0268's three rows are now closed** and the middle one is not:
there is still no way to wait for one task, no `Task` variable, no select over
several channels and no timeout on a send or a receive.

## Consequences

- The runtime is unchanged. Every routine this needed — `pas_handle_take`,
  `pas_handle_init`, `pas_handle_set` — was already there for ADR-0267 and
  ADR-0174, which is the evidence that ADR-0267 built the right thing one
  increment early.
- `tests/dialect/concurrency_errors.err` is regenerated: one refusal is gone
  because the language now admits it, two are new, and the rest shift by the
  line the new variable added. `handle_move_errors.err` and `take_errors.err`
  are regenerated too, five occurrences of one message whose text was a claim
  about `take`'s positions and is now a claim about two.
- `doc/roadmap.md` loses the first and third rows of *What two threads of
  control left open* and the concurrency finding from ADR-0295; they go to
  `doc/history.md`.

## Alternatives rejected

**Inferring the move from the formal's type.** Cheaper for the caller and it
hides the one thing the caller must know. `spawn Serve(conn, back)` reads as
though `conn` is still usable, and it is not; the whole reason ADR-0182 gave
`take` a spelling was that an affine value leaving a variable is a fact about
the *source* and not about the lowering.

**A `var` parameter, so that the task borrows rather than owns.** That is the
escaping alias this language has never had, running at the same time as the
lender — ADR-0201's finding, and AP 6.7.8.1's first refusal. The join would
have made the *lifetime* safe and nothing would have made the concurrent use
safe.

**Widening `take` to every actual-parameter position.** It would close this row
and several nobody has asked for, and the position rule is what keeps an
emptied value owned by somebody. One position, named in the clause, is what
ADR-0140's discipline asks for even where a spelling is not at stake.
