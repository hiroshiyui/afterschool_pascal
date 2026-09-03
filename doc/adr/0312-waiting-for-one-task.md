# 312. Waiting for one task

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Closes the middle row of
[ADR-0268](0268-two-threads-of-control.md)'s table of what two threads of
control left open — the row [ADR-0303](0303-a-task-is-handed-a-handle.md)
named as still open when it closed the first and third. AP 6.4.17 and
AP 6.9.3.14 are added; AP 6.9.3.12 gains a second form of the statement.
AP 6.9.3.12.1 is unchanged, which is the point.

## Context

There was one join and a program could not name it.

AP 6.9.3.12.1 says every activation a block commenced is complete before that
block's activation ends, and before any variable of that block is released.
That is collective — it names no activation, and it happens at a moment the
program did not write. It is the whole safety argument of the construct
(ADR-0201, ADR-0268), and it was also the only thing a program could get.

So a program that wanted a result at a point of its own choosing had to write
a second channel and receive on it, which works and says the wrong thing: the
channel is there to carry a value, and a program using one to carry *finished*
has written a semaphore out of a queue. A program that wanted to spawn eight
workers and collect them one at a time could not, there being no variable that
held one worker. And a program that wanted to spawn a task inside a loop and
wait before the next iteration had to end the block to do it.

Two things were already in place and were the reason this is a small change.
A handle (AP 6.4.12) is a type whose value is owned by one variable, released
when that variable ceases to exist, released early on request, moved with
`take` — everything a name for an activation needs. And ADR-0303 had just
proved the shape by making a channel and a socket two flags apart.

## Decision

**A task-type, and it is a handle.** AP 6.4.17. `task` is a required
type-identifier in the scope enclosing the program-block, shadowable under
§6.1.3 — `int64`'s route (ADR-0128, ADR-0140) and not a word-symbol. The type
is a `tyHandle` carrying `isTaskType`, exactly as a channel-type is a
`tyHandle` carrying an element type, so every rule a task needs is a rule
already written: it is released by the block that declared it, released early
by `release`, moved by `take` (AP 6.4.12.7), affine, admissible as a task's
formal parameter (AP 6.7.8.1), and refused as an assignment source, as an
operand of a comparison other than with `nil`, and as a function result.

There is **one** task-type and not one per denoter, `task` being the whole of
its denoter — which is where the analogy with AP 6.4.12.1's new-type rule
stops, and the clause says so.

**A second form of the spawn-statement.** AP 6.9.3.12.

    spawn-statement = 'spawn' [ variable-access ':=' ] procedure-identifier
                      actual-parameter-list? .

`spawn t := P(x)` commences the activation exactly as `spawn P(x)` does and
additionally makes the variable name it. The statement **threatens** the
variable (§6.9.4 a) as an assignment does, so a `for` control-variable
(§6.8.3.9) and a protected parameter (§6.7.3.1) are refused there by the rule
that already refuses them, and not by a second one.

The forms are told apart by scanning from the identifier after `spawn` for
`:=`, consuming nothing. It is decidable with no symbol table because a
procedure-identifier is followed by `(` or by a terminator and never by a
selector — so `spawn P(x)`, `spawn P` and `spawn P;` read exactly as they
read before, and `spawn := 3` and `spawn(x)` still belong to a program that
declared its own `spawn`. The scan reads *through* a selector, which is what
buys `spawn ws[i] := Worker(jobs)` — the statement a pool of workers is
written with, and the reason the grammar takes a variable-access rather than
an identifier.

**`wait`.** AP 6.9.3.14. A required identifier naming a procedure — `send`'s
and `exit`'s route (ADR-0177) — taking one variable of the task-type and not
returning until that activation is complete. Waiting on an activation already
complete, or waiting a second time, is a statement with no effect. Waiting on
an **empty** task-variable is an error and stops the program: it is Annex A.7's
error and carries Annex A.7's message, the variable being lent exactly as
AP 6.4.12.4 lends a handle. `send` gives an empty channel-variable the same
treatment for the same reason — answering quietly would make a variable a
program forgot to spawn into read as a task that finished, and tell a program
that work was done which was never started.

**AP 6.9.3.12.1 is unchanged and is still the safety argument.** The block
still joins every activation it commenced before it releases anything of its
own. `wait` does not take an activation out of that set; it completes it
earlier, so the block's join then finds it complete and returns at once.
Waiting for one task and joining all of them are **the same statement asked
twice**, which is why naming a task cannot weaken ADR-0201's rule that a
borrow cannot outlive the call: every alias argument in this language is an
argument about the join, and the join is untouched.

### The runtime, which is where the work was

The block's task set now holds a reference-counted `struct pas_task` rather
than a bare `pthread_t`, because a named activation may be joined from two
places — `wait` on the variable, or the block's own join — and `pthread_join`
may be called once for a thread. The join is **claimed** under the record's
mutex: the first arrival takes it, unlocks, joins, and broadcasts on a
condition variable; a second arrival waits on that variable. That is what makes
a second `wait(t)` a statement with no effect rather than undefined behaviour.

The task-variable's closer drops a reference and does **not** join. The block's
set holds a reference of its own and joins, which is the place the join already
had; so a task-variable overwritten in a loop drops the previous reference and
the set goes on naming both activations, and a program may spawn more than it
waits for without leaking one or joining one twice.

## What this does not do

The roadmap row named three things and this closes one of them. The other two
are open, and so are three more that this construct puts within sight without
answering.

**No select over several channels.** A program cannot wait for whichever of two
channels is ready, so a task that must service a job queue and a shutdown
signal still has to fold both into one channel.

**No timeout, on anything.** Not on `send`, not on `receive`, and not on
`wait`. There is no way to give up. A `wait` that could give up would leave a
program holding a task-variable whose activation is still running, and no
clause says what that means — which is why it is left open rather than
half-answered here.

**No channel of handles** (AP 6.7.8.1 NOTE 6, ADR-0302). A task may be *given*
a socket at the moment it starts and cannot be sent one afterwards, so a fixed
pool of workers taking connections off a queue is still unwritable. This
record closes the row about waiting and not that one.

**A task still yields no result value.** What it computed comes back through a
channel; `wait` answers nothing, because there is nothing for it to answer.

**There is no way to ask whether a task is complete without blocking.** A
non-blocking enquiry is a construct of its own and is not implied by this one.

## Evidence, and what is weak about it

**The behavioural oracle for a join is weak, and this is the place to say so.**
A join's effect is hard to observe deterministically, because the obvious
observation — a value the task sent — is one a channel has already
synchronised, so a test written that way passes with the join removed. The
discriminating case has to observe the task's completion *outside* a channel:
the task owns a file, writes to it, and its block closes the file when the
block ends, so the program reading that file after `wait` is reading something
only the join can have ordered. It is made reliable by the task being
deliberately slow rather than by a construction that could not race, and that
is the honest description of it.

`doc/sop.md` §7 carries a row saying a missing join is caught by no case
(ADR-0201, ADR-0268). This change adds a case that does catch it — for `wait`,
which is the narrower of the two claims; the collective join of
AP 6.9.3.12.1 is still watched by ThreadSanitizer run by hand and by nothing
that fails.

## Consequences

- Every rule the task-type needs is a rule that was already written, so the
  language gained a type and one statement and no new mechanism. The predicate
  `IsTask` is `IsHandle` and a flag, which is `IsChannel`'s own shape.
- An array of task-variables makes a worker pool writable with no further
  construct: `spawn ws[i] := Worker(jobs)` in one loop, `wait(ws[i])` in
  another.
- The runtime's task record is now reference-counted and its join is claimed,
  which is a concurrency change in the one file that is allowed to have any
  (`runtime/pasrt_task.c`, bounded by `<pthread.h>`). ThreadSanitizer over
  every concurrent program is the oracle it rests on, and that is still not a
  gate (`doc/sop.md` §7).
- `doc/roadmap.md` loses the second row of *What two threads of control left
  open*; what remains of that row — select, timeouts, a channel of handles —
  is restated above and belongs in the roadmap in its own words.

## Alternatives rejected

**A `wait` with no argument, joining everything the block has spawned so far.**
Simpler than this by a whole type: no task-type, no second form of the
spawn-statement, no reference count, and the runtime already has the set to
walk. It was refused because it answers a different question — *wait for all,
now* — and the row asked for one task. A program collecting eight workers one
at a time gets nothing from it, and a program that wants a barrier can write
one out of a channel today. It remains available cheaply if a program wants
it, and would compose with this rather than compete: it would join the set,
and the set is still what this leaves in place.

**Making `spawn` an expression that yields a task.** `t := spawn P(x)` reads
well and is what several languages do. It is refused because `spawn`'s whole
spelling argument is a *statement*-position argument (ADR-0140, ADR-0175): a
statement beginning with an identifier can continue only as a designator, as a
call, or not at all, which is what makes `spawn` spellable without reserving a
word. ADR-0178 measured exactly this transfer and found it does not hold for a
factor — a factor may be a variable-access, so `spawn (x)`, `spawn [x]`,
`spawn.f` and `spawn^` all belong to a program that declared one. Spelling the
statement's second form as `spawn t := P(x)` keeps the construct where its
argument works.

**A task-type that is not a handle.** A kind of its own, with its own rules for
release, for the move, for what may be assigned to it. Refused for AP 6.4.16.2's
reason one type further on: everything it needs already exists on a handle, so
a second kind would be a parallel mechanism where a flag does, and every
routine in the compiler that asks a question about a handle would have had to
be taught a second answer.

**Having the task-variable's closer perform the join.** It is the tidy place
for it — the variable names the activation, so let letting go of the variable
be the wait. It is wrong on an **ordering**: AP 6.9.3.12.1 requires the join to
happen before *any* of the block's variables are released, and the release of
one handle is not ordered against the release of another. A task-variable that
joined as it was released would join at a moment no clause fixes, after some
of the block's files, sockets and channels had already been closed under an
activation still running. The closer therefore drops a reference and the set
joins, which puts the join back where the clause already put it.
