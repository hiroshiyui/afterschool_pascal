# 302. The release a program wrote closes the channel

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Closes [ADR-0295](0295-a-corpus-written-to-be-read.md)'s
finding 1 and the third row of
[ADR-0268](0268-two-threads-of-control.md)'s table of what two threads of
control left open. AP 6.4.16.4 is added; AP 6.4.16.3 gains a note.

## Context

ADR-0295 wrote twelve programs to be read and reported what writing them
found. The first finding is the worst failure mode this language has:

> `release(c)` on a channel a task was handed does not close it, and a program
> that expects it to deadlocks with no diagnostic.

The first draft of `examples/pipeline_tasks.pas` was a producer, a filter and
a reader, each stage closing the channel downstream of it as
`tests/dialect/concurrency.pas`'s main program closes its job channel. It
compiled, and it hung, and nothing — not the compiler, not the runtime, not
the linker — said why.

The reason was a rule that is right about one question and was answering
another. A channel is a handle (AP 6.4.16.2), so it has a closer, and a task's
channel parameter is given a different closer from the owner's:
`pas_chan_unref` drops the reference and does **not** close, because a worker
of a pool that has run out of work must not close the channel its colleagues
are still draining. `runtime/pasrt_task.c` says so in a comment. Nothing a
program's author reads did, and the compiler admitted the call.

The roadmap offered two answers and this record takes a third.

## Decision

**A release the program *wrote* closes the channel; a release the end of a
block performs goes on meaning what it meant.** AP 6.4.16.4.

The two are two questions and the closer could only answer one of them:

- *This activation has finished with the channel* is what the end of a block
  says, and for a task's lent parameter the right answer is to drop the
  reference. That is unchanged.
- *Close it* is what a program writing `release(c)` says. Before this it did
  nothing at all — the count went down, the channel stayed open, and every
  reader downstream waited for ever.

**Three spellings, one operation.** `release(c)` (AP 6.4.12.5), `c := nil`
(AP 6.4.12.2) and `c := take(d)` (AP 6.4.12.7) each release what `c` held, so
each closes. Separating them would have been a rule about syntax rather than
about the channel, and `tests/dialect/task_close.pas` exercises all three.

**A task closing a channel cannot destroy it.** AP 6.9.3.12.1 makes the block
that spawned a task join it before releasing any of its own variables, so a
variable of the spawning block holds the channel the whole time the task runs;
where no such variable does, the task is the last holder and freeing is right.
The reference count already decides which, so nothing here has to know.

### The lowering is one call in front of a release that did not change

```llvm
%v = call ptr @pas_handle_peek(ptr %slot)
call void @pas_chan_shut(ptr %v)
```

`pas_chan_shut` marks the channel closed and broadcasts on both condition
variables; it does not touch the count. Whatever release follows — the
function, or the `pas_handle_set` inside an assignment — then does exactly
what it did before, and the owner's closer marking the channel closed a second
time is idempotent.

It is deliberately **not** a change of closer. Which closer a variable was
initialised with is the whole of what says whether it owns the channel or
shares it, and that distinction is still needed by the end of a task's block.
Adding a third closer would have meant a variable answering the wrong question
at one of its two release sites instead of the other.

`pas_handle_peek` is in `runtime/pasrt.c` and not beside the channel, because
`struct pas_handle` is private to that file. It is the non-trapping twin of
`pas_handle_lend`: a foreign routine given NULL dereferences it, and a release
of an empty variable is not an error anywhere in this language.

## The second finding: a channel could not carry a string

ADR-0268 closed with *a channel cannot carry a string — `Transferable` admits
one and the implementation copies `esize` bytes, which is right for a
fixed-capacity `string(n)`; it has no case yet and is therefore unclaimed.*
That is ADR-0080's distinction, and writing the case is what showed the
reading was wrong twice over.

`send` chose between two paths with `IsStructured`, and a `string(n)` is
`IsMemory` and **not** `IsStructured` — ADR-0191's split met a second time. So
a string took the scalar path, which `store`s a register value through a
pointer `EmitExpr` had answered with, and the module did not assemble at all:
*'%v8' defined with type 'ptr' but expected '{ i32, [16 x i8] }'*.

Asking `IsMemory` instead makes it assemble and is still wrong, which is the
part worth carrying. A `string(n)` is a length beside a buffer, so a *value* of
one occupies only as many bytes as it has: `'be' + 'ta'` lives in the string
arena and is four bytes and two, where the channel's element is twenty. Copying
the element's size out of that address reads past what the expression produced
— a segfault, and one this case reproduced. And §6.4.6 c)'s padding has to
happen somewhere, because what crosses is a value of the *element type* and not
of the expression's.

So a string or a text element is stored into a temporary of the element type by
the ordinary assignment path, which is where padding, the capacity check and
AP 6.4.15.5's normalisation already live, and the channel is sent that. The
temporary is bracketed by `llvm.stacksave`/`stackrestore` for the reason the
scalar path already was (ADR-0102).

## Evidence

- **The deadlock, before**: `timeout 5` on a two-stage pipeline whose stages
  write `k := release(out)` exits 124 with nothing printed. After, it prints
  its five odd squares and `done`.
- `tests/dialect/task_close.pas` is the case: a producer and a filter each
  closing what they write to, a channel of `string(16)` carrying a literal and
  a concatenation, and `c := take(d)` closing what the target held, reported
  through a second channel so that every line is deterministic. Five runs,
  one digest.
- `examples/pipeline_tasks.pas` is rewritten to close rather than to end on a
  sentinel, and its golden is unchanged — which is the readable statement that
  the program the reader would have written now works.
- Two scenarios in `tests/spec/features/dialect_task.feature` cite
  AP 6.4.16.4, one per spelling, and a third cites AP 6.4.16.3 for the string.
- **ThreadSanitizer** is clean on `concurrency.pas`, `task_close.pas`,
  `task_handle.pas` and `pipeline_tasks.pas`, over a runtime built with
  `-fsanitize=thread`. It is the oracle this construct rests on and it is
  still not a gate (`doc/sop.md` §7).
- `line-coverage` named the one direction the first draft of the case did not
  reach — the `take` spelling — which is the ratchet doing exactly what it is
  for.

## What is not done

**Nothing bounds a send to a channel a task has closed.** Sending to a closed
channel stops the program, which is AP 6.9.3.13.1 and this language's ordinary
discipline, and a pipeline whose stages close in the wrong order will find it
at run time rather than at compile time. That is unchanged by this record and
is the remaining sharp edge of closing from a task.

**`release` on a channel parameter is not refused, and that was the cheap
answer.** The roadmap's first suggestion was to refuse it in Sema, on the
argument that it can never do what the program means. It can now, so there is
nothing to refuse; but the choice cost a runtime routine and a rule with two
halves where a refusal would have cost one message.

**A channel still cannot carry a handle**, `Transferable` refusing one at any
depth. A task may be *given* a socket (ADR-0303) and may not be sent one; what
would make that expressible is a rule about which activation owns a value
sitting in a bounded queue, and no program here has wanted it.

## Consequences

- `runtime/pasrt_task.c` gains one routine and stays bounded by `<pthread.h>`;
  `runtime/pasrt.c` gains one and catalogues no new foreign name, so
  `runtime-isoc` is unmoved.
- Two cases and one example; 828 of 828 ctest cases green, stage 2 = stage 3,
  and `producttest` 25 of 25.
- `benchmark` could not answer: on this machine, shared with other agents, one
  binary reported `share:parse` at 0.036, 0.010 and 0.114 over three runs.
  That is ADR-0282's own condition — a stage share is a measurement, and the
  tolerances are margins over a spread taken on an idle machine.

## Alternatives rejected

**A compile-time refusal of `release` on a channel parameter inside a task.**
The roadmap's cheap answer, and it is a real one: the call could never do what
the program means, so refusing it with a message naming the sentinel would have
turned a silent deadlock into a diagnostic. It was rejected because a stage
closing the channel downstream of it is not a mistake — it is the shape a
pipeline has in every language that has channels — and refusing it would have
left the language without it while claiming the refusal was the design.

**A sentence in AP 6.9.3.13.** The second answer the roadmap named, and the
weakest: it documents the trap rather than removing it, and a reader who has
not read that sentence still writes the program that hangs.

**A third closer for a lent channel that closes.** It would put the whole rule
in one place, and it is wrong: the end of a task's block would then close what
its colleagues are draining, which is the property `pas_chan_unref` exists for.
The two release sites ask different questions and the closer can only answer
one.
