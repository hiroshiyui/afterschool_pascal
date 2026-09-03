# 313. Waiting for whichever comes first

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Closes the row
[ADR-0312](0312-waiting-for-one-task.md) left open — *no select over several
channels, and no timeout on anything* — for the channels half of it, and says
plainly which part of the timeout half stays open and why. AP 6.9.3.15 is
added, with 6.9.3.15.1 to 6.9.3.15.4; AP 6.9.3.13 gains a cross-reference and
Annex A gains two errors. AP 6.9.3.12.1's join is unchanged, which is again
the point.

## Context

A task could wait for one thing at a time.

`receive` waits for a value on one channel and `send` waits for room in one
channel (AP 6.9.3.13), and neither can be given up on. So a task that must
service a job queue *and* notice a shutdown signal had exactly one shape
available to it: fold both into one channel, as a record with a tag saying
which of the two arrived. That is a program writing a discriminated union
because the language would not let it wait for two things, and the union has to
be threaded through every sender — the shutdown signal is then a value of the
job type, which is a lie about the job type.

The same absence made a deadline unwritable. A program that wanted to wait for
a value *or* give up after a second had nothing to write, and a program that
wanted to look without waiting at all had nothing either. Both are wanted for
the same construct and for different reasons: the first is a timeout, and the
second is a poll.

ADR-0312 closed the row above this one and named this one as open. It also
named the reason the *third* thing on that row is different: a `wait` that gave
up would leave a program holding a task-variable whose activation is still
running, and no clause says what that is. That reasoning is about a task and
not about a channel, and it is what makes this record the channels' answer
rather than a general timeout facility.

## Decision

**A select-statement.** AP 6.9.3.15.

    select-statement = 'select' select-arm { ';' select-arm }
                       [ [ ';' ] 'otherwise' statement-sequence ] 'end' .
    select-arm       = channel-arm | timeout-arm .
    channel-arm      = [ variable-access ':=' ] identifier
                       actual-parameter-list ':' statement .
    timeout-arm      = 'after' expression ':' statement .

The shape and the punctuation are the case-statement's (§6.9.3.5): arms
separated by `;`, an optional `otherwise` last whose separator is optional,
`end` to close. Nothing was invented for the syntax that a reader of a case
does not already know; what differs is that an arm's head is an operation and
that the arm which runs is chosen by what happened elsewhere.

The statement waits until one channel-arm can proceed, performs that operation,
and executes that arm's statement and no other. A `receive` arm can proceed
when a value is available **or** when the channel has been closed
(AP 6.4.16.4) and drained; a `send` arm can proceed when the channel is not
full. At least one channel arm is required, and at most one `after` arm.

**`select` is spelled by position and reserves no word-symbol**, which is
`defer`'s and `spawn`'s argument unchanged (ADR-0140, ADR-0175, ADR-0312): a
statement beginning with an identifier can continue only as a designator, as a
call, or not at all, and a select's first arm always begins with an identifier
— `receive`, `send`, `after`, or the variable of `ok := receive(c, v)`. So
`select;`, `select(x)` and `select := 3` stay what a program that declared
`select` meant.

**`send` and `receive` in an arm are decided by the symbol and not by the
spelling.** They are required identifiers a program may declare its own of
(§6.1.3), so an arm naming one the program declared names a routine that
cannot be waited on, and is refused rather than quietly meaning the required
operation. That is ADR-0087's rule met again — the parser cannot tell a
channel arm from a call, and Sema can, because it can look the name up.

**`after` is the one spelling this construct reserves, and only inside a
select.** No conforming program can be inside a select at all, so it costs
nothing outside those brackets (ADR-0140). `after E: S` takes an integer
expression in **milliseconds**, evaluated once where the statement stands;
when no arm can proceed within that time the select gives up and executes `S`.
A negative value is an error that stops the program (Annex A.9).

**`otherwise` is a deadline of zero.** The select does not wait at all: it
looks at its arms once and, where none can proceed, executes the
statement-sequence. An `after` arm and an `otherwise` in one statement are
**refused** — two ways of saying *give up after this long* is a contradiction
and not a refinement, and a rule taking the earlier of the two would have
hidden it.

**`ok := receive(c, v)`.** The optional variable-access before `:=` receives
the boolean the *function* `receive` answers (AP 6.9.3.13.2): true where a
value was delivered, false where the channel was closed and drained. That is
how a select terminates a drain loop, and it is the reason the function form
exists at all. The variable is threatened (§6.9.4 a) as the value is, so a
`for` control-variable and a protected parameter are refused there by the rule
that already refuses them. It is scanned for exactly as the spawn-statement's
target is (ADR-0312), past a variable-access for `:=`, consuming nothing.

**Everything the wait needs is evaluated once, before the wait.** Each channel
designator, each receive destination's address, and each send's value are read
where the statement stands. A select may poll its arms many times, and how
many times is a fact about other activations — an actual that was re-evaluated
would make that number observable from inside the program. A send arm's value
is stored into a hidden frame variable of the element type: a **frame slot**
and not an `alloca`, because a select inside a loop would claim one per
iteration (ADR-0102).

**Which arm is tried first rotates.** Trying the arms in written order would
let a channel that is always ready starve every arm below it — a worker
servicing a busy job queue would never see its shutdown channel, which is
exactly the program this construct exists for. The start rotates, so over *n*
executions each arm is looked at first once. The counter is **thread-local**,
so two tasks selecting do not perturb one another's order and a program's
output stays reproducible. AP 6.9.3.15.3 says the corresponding thing to a
program: where more than one arm can proceed, which one does is not determined
by the order they are written, and a program shall not depend on it.

**A `send` arm on a closed channel is AP 6.9.3.13.1's error** wherever it is
written, and is raised rather than reported as an arm that cannot proceed. An
arm naming an **empty** channel-variable is an error too (Annex A.8), as
`send` and `receive` on one already are.

### The runtime, which is where the work was

There is no way to wait on several condition variables, so a selector waits on
a **single process-wide condition variable** that every channel operation
broadcasts on after it has changed something. The selector polls its own
channels and, finding none ready, waits to be told that *some* channel
changed. The cost is a spurious wakeup for every unrelated channel, and it is
the honest trade rather than an oversight.

**The correctness argument is stated as an invariant and not as an ordering:**
*no thread ever holds a channel's mutex and the activity mutex at the same
time.* A sender changes its channel, releases it, and only then takes the
activity mutex to broadcast; a selector holds the activity mutex and takes
channel mutexes one at a time beneath it. The cycle that would deadlock — one
thread holding a channel and wanting activity while another holds activity and
wants that channel — has no first half. That the selector holds the activity
mutex *across* its poll is what makes a wakeup impossible to lose: a sender
that changes a channel after the selector has looked at it cannot broadcast
until the selector is inside `pthread_cond_wait` and has released the mutex.

The compiler builds a descriptor array — one entry per channel arm: which
operation, whether a receive delivered a value, the channel, the value's
address — in a frame slot **sized to the widest select in the block**. One
slot per block and not one per statement, which is the defer record's and the
task set's shape, and it is sound because the descriptor is read only while
the runtime call is running: a select written inside another select's arm runs
after that call has returned. The emitter writes the descriptor and a `switch`
on the index the runtime answers with. The rotation is entirely the runtime's,
deliberately, because it is a fact about the execution and not about the
program.

## What this does not do

**No timeout on `wait`.** ADR-0312 recorded why and it is unchanged: a `wait`
that gave up would leave a program holding a task-variable whose activation is
still running, and no clause says what that is. A task is not a channel and
does not become selectable here. AP 6.9.3.14 NOTE 5 still names it as open.

**No timeout on a bare `send` or `receive`.** A program that wants one writes a
select with one arm and an `after`, which is what the construct is for; adding
a third argument to either was refused below.

**No channel of handles** (AP 6.7.8.1 NOTE 6, ADR-0302). A task may be given a
socket at the moment it starts and cannot be sent one afterwards, so a fixed
pool of workers taking connections off a queue is still unwritable. This is
still the shape behind the worker pool, and this record does not reach it.

**An activation cannot close a channel and then drain it.** All three
spellings of AP 6.4.16.4 — `release(c)`, `c := nil`, `c := take(d)` — empty
the handle variable as well as closing the channel, so the close a select
reports is one performed by *another* activation: the ordinary pipeline shape,
a producer task closing what a consumer drains. This was met twice while
writing this change and it is a real wart. Closing without releasing would be
a **new operation** on a channel and it is not built here.

**No priority among arms.** Where several can proceed the choice rotates, and a
program must not depend on which. A select is not a way to say *this one
first*.

**Nothing finer than a millisecond.** The `after` deadline is a wall-clock
delay in milliseconds, which is what a shutdown deadline and a poll interval
need and is not a timer facility.

## Consequences

- The construct the concurrency row was missing is now writable in the shape it
  is written in everywhere else: a job channel and a shutdown channel, selected
  over, with the shutdown arm leaving the loop.
- `otherwise` gives a **poll** for nothing extra. A program that wants to look
  without waiting writes the same statement, and the two spellings of *give up*
  are one construct with one deadline.
- The runtime gained a process-wide condition variable and every channel
  operation now broadcasts on it. That is a concurrency change in the one file
  allowed to have any (`runtime/pasrt_task.c`, bounded by `<pthread.h>`), and
  ThreadSanitizer run by hand over every concurrent program is the oracle it
  rests on — still not a gate (`doc/sop.md` §7).
- A program with many channels and many selectors pays a spurious wakeup per
  unrelated channel operation. The fix, if a program ever needs it, is the
  first rejected alternative below, and it can be made later without changing
  a clause.
- Annex A gains two errors, A.8 and A.9, and neither is A.7's: A.7 is about a
  handle lent to a *foreign* routine, and nothing foreign is reached here.
- `doc/roadmap.md`'s row *to wait for whichever comes first* loses its first
  half; what remains of it — no timeout on `wait`, and a channel of handles —
  belongs there in its own words.

## Alternatives rejected

**A list of waiting selectors on every channel, instead of one process-wide
condition variable.** It is the exact fix for the spurious wakeup: a channel
operation would wake only the selectors that named that channel. It was
refused because it puts more state in the one object two threads already share
— a channel would gain a list, and every registration and deregistration would
be a second thing to get right under the channel's own mutex, on the path
ADR-0268's whole safety argument runs through. It buys nothing until a program
has many channels *and* many selectors, and it can be built later without a
clause changing, because AP 6.9.3.15 says nothing about how the wait is
implemented.

**`after` as a required identifier rather than a spelling reserved inside the
construct.** It is the route `int64`, `exit`, `send`, `receive` and `wait` all
took (ADR-0128, ADR-0177), and taking it here would have been the consistent
move. It is refused because the consistency is superficial: `after(x): S`
would then be a **channel arm** in a program that had declared its own `after`
and a **timeout arm** in every other, so the meaning of an arm would depend on
a declaration the reader of the arm cannot see. Reserving the word inside the
select brackets costs nothing — no conforming program can be inside a select
at all — and buys one reading.

**Putting the rotation in the emitted code.** The compiler would emit the poll
loop and a counter, and the runtime would answer one arm at a time. It is
refused because the arms would then be tried in *emitted* order with a program
carrying a counter for it: every program with a select would hold a variable
that is not about the program, and a select in a task would need that variable
to be thread-local, which is a property of the runtime being reinvented in the
front end. The rotation is a fact about the execution and belongs where the
execution is.

**A third argument on `receive` — `receive(c, v, ms)` — instead of a
statement.** It is much the smaller change and it answers the timeout half of
the row on its own. It is refused because the boolean would then have to mean
two things: *false* would report both "the channel was closed and drained" and
"the time ran out", and those are different outcomes with different sequels.
The loop condition `while receive(c, v) do` depends on the first meaning
exactly, so the extra argument would quietly change what an existing program's
loop tests. It also answers nothing about *several* channels, which is the
half of the row that could not be done any other way.

**Trying the arms in the order they are written.** The obvious implementation,
and the one a reader would predict. It is refused on starvation, with the
concrete program: a worker with `receive(jobs, j)` written above
`receive(quit, q)` and a queue that is never empty never looks at `quit`, so
the program cannot be shut down — and that program is precisely the one the
construct was added for. Written order would have made the feature fail on its
own motivating example.

**A select over tasks as well as channels.** Selecting on "whichever task
finishes first" is the natural next sentence, and it is not written. A task is
not a channel: an arm that gave up on a task leaves the same unnamed state
ADR-0312 refused, and an arm that *waits* for one would have to be joinable
from a poll, which is a change to AP 6.9.3.12.1's join rather than to this
statement. It stays open.
