# ADR-0268: Two threads of control

Date: 2026-08-30

## Status

Accepted. Builds the construct ADR-0201 designed and declined, on the
prerequisite ADR-0267 landed. Closes the concurrency bullet of
`doc/roadmap.md`.

## Context

ADR-0201 did three things: it withdrew ADR-0151's ARC-or-borrow-checking fork
as unanswerable in this language, it named the **one** thing left of that
fork — *two threads of control* — and it decided what a concurrency construct
here would have to be, then declined to build it under ADR-0116 because nothing
in the tree wanted it.

Four times since, something looked like it wanted one and something cheaper
answered instead: `select` for a socket server (ADR-0205), a cache for the
language server's hovers (ADR-0252), the `didChange` drain (ADR-0257), and a
measurement showing the cheap-looking route would cost 124× what it could save.
`doc/roadmap.md` records all four, and the rule it drew from them — *measure the
cost before naming the mechanism* — stands.

**This record does not overturn that reasoning; it acts on an instruction to
build the construct anyway.** ADR-0116's bar is not met and is not claimed to
be: what is here has no caller in this tree, and the compiler is one thread and
must stay so. What it has instead is a design that was decided four increments
early, and the discipline of building it exactly as decided.

## Decision

**A task, a channel, and a spawn — share-nothing, as ADR-0201 required.**

    channel-type    = 'channel' '[' constant-expression ']' 'of' type-denoter
    task-declaration= 'task' identifier formal-parameter-list? ';' block
    spawn-statement = 'spawn' procedure-identifier actual-parameter-list?

with `send` a required procedure and `receive` a required function.
AP 6.4.16, 6.7.8, 6.9.3.12, 6.9.3.13.

**No word-symbol is reserved**, which is ADR-0140's rule and the three
positions ADR-0201 itself listed as free: an identifier followed by `[` where a
type-denoter is expected; an identifier at a declaration-part, where a
conforming program may write only seven word-symbols; and a statement-initial
identifier followed by an identifier, which is `defer`'s position. A program
declaring `channel`, `task`, `spawn`, `send` or `receive` keeps every one of
them, and `tests/spec/features/dialect_task.feature` has the scenario that
compiles such a program.

### A channel is a handle, not a new kind

Everything a channel needs from the language is what AP 6.4.12's handle already
has: no copy, released when its variable dies, `release` to release it earlier,
comparison with `nil` and nothing else. So a channel-type **is** a handle-type
whose closer is the runtime's, with the element type in the field a handle does
not use. A kind of its own would have been a parallel mechanism where a field
does, and every routine that asks a question about a handle would have needed a
second answer.

One thing is not the handle's: a channel-variable does not start empty. Its
capacity is in its type, so there is nothing for an assignment to decide, and
`channel [8] of integer` is a declaration rather than a constructor.

### Share-nothing is enforced at the formals — and that was not enough

AP 6.7.8.1 admits exactly two kinds of formal: a value parameter of a
**transferable** type — no pointer, file, handle, owned pointer, slice or
procedural type at any depth — and a **channel**, which crosses as the one word
it is and is the only thing two activations may name.

That looked like the whole of it, and the argument was good: a task's body
cannot name a variable of the spawning activation except through a formal,
because this language has no address-of and `new` is the only producer of a
pointer.

**It was wrong, and a probe found it.** Pascal's scope rules let a nested block
name a variable of an enclosing one, and a program's variables enclose every
block in it. Four tasks incrementing one global compiled, ran, and printed the
right answer three times out of three — a data race that the formals rule
cannot see and that no golden would ever catch.

AP 6.7.8.2 is the answer: a variable-access in a task's block, or in any
routine declared within it, shall denote a variable of that block or one
inside it. Asked of the **owner**, so constants, types, routines and the task's
own formals are all still nameable. It is **not** transitive — a task may call
a procedure declared outside it, and that procedure may touch what its own
scope admits — and that is recorded in `doc/sop.md` §7 rather than claimed.

### The join is the safety argument

Every task a block spawned is joined before that block's activation ends **and
before any of its variables is released**. The emitter puts the join first in
the epilogue, ahead of the deferred statements and ahead of the file-and-handle
walk, and the order is the rule.

ADR-0201's sentence was *a borrow cannot outlive the call, because the caller is
not running during it*, and it named two threads of control as the one thing
that breaks it. The join is what makes it true again: a task cannot outlive the
storage it was lent, because the lending block waits.

### The runtime, and what a task's body cannot be handed to

`runtime/pasrt_task.c` is a fourth translation unit, bounded by **one** header
beyond ISO C — `<pthread.h>` — as `pasrt_posix.c` is bounded by six. A system
without it loses the construct and not the language.

A task's body cannot be given to `pthread_create`: §6.6.3.1's procedural
parameter is a code-and-link pair (ADR-0030) and C takes one word, which is
ADR-0201's finding 4 and the reason concurrency here had to be a language
construct at all. So the **compiler emits** the C-callable function — one per
task, taking an argument block, unpacking the static link and the actuals, and
making an ordinary call. Nothing a program wrote becomes a function pointer.

The argument block is allocated by the runtime and freed by the thread. Not an
`alloca`, which a spawn in a loop would claim per iteration (ADR-0102); not a
frame slot, which would have to be sized to the largest block in the block
before the frame type knows any of them.

### ThreadSanitizer found what nothing else could

TSan reported a race on the **first run of the first program that spawned two
tasks**, in `pas_handle_done`: two threads unlinking their own handle slots
from one process-global list. The runtime's per-activation bookkeeping — the
open files, the live handles, the armed deferred statements, and the string
arena with its cursor — is a stack of what the *current chain of activations*
owns, and a task is a second chain.

All five are `_Thread_local` now, which is ISO C11 and costs the runtime's
conformance nothing. What it costs is storage: the arena is a megabyte and a
program with eight tasks has eight. That is the honest price of a share-nothing
model whose arena is a stack; the alternative is a lock on every string
temporary, which would make every single-threaded program pay for a feature it
does not use.

**The cursor forced a reseed.** `pas_str_at` is named by the emitted module, so
making it thread-local changes what the compiler *emits* — and `seed/*.ll`
declared the old form, which the linker refuses to mix. CLAUDE.md's own
sentence covers this: *a feature must be expressible in what `seed/*.ll`
accepts, or the seed is refreshed first.* It is the first reseed outside a
release, it is 260 000 lines of churn, and it was not optional.

## Consequences

`tests/dialect/concurrency.pas` is the case — a four-worker pool over one job
channel, a value crossing by copy, a record crossing by copy, and a block
spawning twice — and every line of its output is deterministic, which a test of
concurrency has to be. `tests/dialect/concurrency_errors.pas` carries the
refusals, and `tests/spec/features/dialect_task.feature` has eleven scenarios.

`ThreadSanitizer` is the oracle this feature actually rests on, and it is not
wired into a gate: it was run by hand over the corpus's concurrent programs.
`doc/sop.md` §7 records that.

Two mutations are caught and one is not, and the third is the honest part:

- **`pas_chan_close` not marking the channel closed** hangs the case, which
  `tests/dialect/`'s per-case TIMEOUT reports.
- **`receive` reporting the close without draining first** loses the values in
  flight and the sums are wrong.
- **The join removed entirely leaves `concurrency.pas` green.** Every task in
  it happens to finish before its block ends, so nothing observes the
  difference. AP 6.7.8.2 removes the sharpest consequence — a task can no
  longer read a dead frame's variables, because it can no longer read them at
  all — but the property is still asserted by argument rather than by a case.
  `doc/sop.md` §7.

`kind-exhaustive` moved 49 counts, one per partial case over the four
enumerations that grew, and gained two entries. Every one was read and decided
rather than bumped: a spawn is not an expression, `receive` is dispatched by an
if-chain, and `EmitStdProc`'s `send` arm tests a type rather than a tag.

### What it does not do

**A task cannot be *given* a handle.** AP 6.4.12.7's move exists (ADR-0267) and
the argument block does not use it, so a task cannot be handed a socket or a
stream — only channels and values. That was ADR-0267's stated motivation and it
is one increment early; the record says so rather than letting the two imply
each other.

**There is no way to wait for one task**, no `Task` variable, no select over
several channels, and no timeout on a send or a receive. A program that needs
any of them writes a second channel.

**A channel cannot carry a string.** `Transferable` admits one and the
implementation copies `esize` bytes, which is right for a fixed-capacity
`string(n)`; it has no case yet and is therefore unclaimed.

**Nothing here bounds a task's stack, priority or count.** `pthread_create`
with a null attribute is what it is, and a program that spawns in an unbounded
loop will find the system's limit rather than one of this language's.
