# 293. A trap names where it happened

Date: 2026-09-03

## Status

Accepted. Extends [ADR-0014](0014-iso-error-conditions-trap-at-run-time.md),
which made every ISO error condition the compiler can detect a trap, and
[ADR-0017](0017-name-equivalence-and-checked-subscripts.md), whose subscript
check is the trap a program meets first. Closes the first row of
`doc/roadmap.md`'s "What would make this practical to pick up".

## Context

Sixty-eight distinct trap messages stood in the corpus' `.err` files and not
one carried a file or a line. `runtime error: array index out of bounds
(1..3)` is exact about the bounds and silent about *where*, and a program of
any size has a hundred subscripts in it. The roadmap row that recorded this
also said what the fix was: the compiler holds the line and column of every
node -- `ErrorAt` is written against them -- and the trap is the one message
it writes that throws them away.

The row underestimated the shape. Two classes of trap exist and they differ in
who knows the position:

- **The compiler emits the check inline.** A subscript, a subrange store, a
  nil dereference, a `case` with no label, a variant arm, checked arithmetic,
  set membership, `chr`, `succ`, `trunc`, a negative field width, an empty
  schema domain. Thirty-five emit sites, and at every one the emitter is
  holding the node.
- **The runtime raises it.** A read that found no number, a file that was
  never opened, a string that does not fit, `**` of zero, `ln` of zero, a
  channel closed, a task that could not start. Counted from the runtime's own
  call graph -- `clang -emit-llvm` over `runtime/pasrt*.c`, every `call`
  followed to `pas_runtime_error` or one of the runtime's other printers --
  **72 of the 127 routines the emitter calls can trap**, and 55 cannot. The
  surprise in that list is every `write`: `pas_out` asks `pas_check_open`
  first, so writing to a file that was never opened is a trap and every
  `write_int` is a routine that can. "Bracket the routines that trap" is
  therefore nearly "bracket them all", and the cost has to be paid on the
  compiler's own hot path, where a `write` per IR fragment is most of what it
  does.

Three constraints shaped the answer, and each was found by looking rather than
assumed:

- `runtime error:` **must stay at the start of the line.**
  `tests/checks/coverage.py` and `fuzz.py` recognise a crash by
  `startswith("runtime error:")`, `variant_check.sh` by `^runtime error:
  variant:`, and `sanitize.sh` tells this runtime's trap from UBSan's by
  UBSan's carrying `<file>:<line>:<col>:` *before* the words. A position in
  the diagnostics' own leading form would have turned every trap into a
  sanitizer finding. So the position trails the message.
- **The path cannot go through the string pool.** A trap message is a string
  constant assembled in `msgBuf`, which is `strMax` -- 255 -- characters, and
  a path is `pathMax`, 4096 (ADR-0291); `long-path` compiles a source at a
  301-character path and would have watched the compiler stop on its own
  message. And there are 12 179 trap calls in `apfront.pas`'s IR: a path in
  each would have cost the pool, whose headroom `buffer-headroom` watches,
  hundreds of kilobytes. So the file name is **one constant per module**,
  written straight from `mainFile`, and a position is three words that point
  at it.
- **A per-statement "current position" store was ruled out by its own
  semantics before its cost.** A statement's position stored on entry is
  overwritten by every statement in every routine the statement calls, so
  `x := f(a) ** 2` would report the last line of `f`. Restoring after every
  call is a store per call, which is what the design below pays anyway --
  but at the *construct* and not the statement.

## Decision

**Every trap the compiler emits names the position of the construct that
trapped, after the message, in the form the compiler's own diagnostics use:**

    runtime error: array index out of bounds (1..3) at prog.pas:18:17

The file is spelled as it was given to the compiler, which is what `ErrorAt`
writes and what `tests/run_test.sh` already rewrites to `<source>`; a trap in
a separately translated component names that component's file, because the
constant is per translation. The column is the construct's: the index
expression of a subscript and not the designator or the `[`, so `a[i] + a[j]`
on one line says which; the `to`-bound of a `for`; the value being stored,
for a subrange; the selector of a `case`; the operator of a `div`, `mod` or
`**`; the variable of a `read`; the `^` of a dereference.

The two classes get the position two ways, and the split is the whole of the
mechanism:

1. **An inline check passes it as three arguments.** `EmitTrapIf` and its
   four siblings write `call @pas_runtime_error_at(ptr @sN, ptr @at.file,
   i32 L, i32 C)` -- the message, the module's file constant, the line, the
   column -- into the cold block. The emitter holds the node, the block is
   never executed unless the program is stopping, and nothing about it
   depends on state. `pas_index_error_at`, `pas_range_error_at`,
   `pas_length_error_at` and `pas_disc_error_at` take the same three
   trailing words for the messages the runtime formats out of values.
2. **A call into a routine that can trap is bracketed.** `EmitAt(line, col)`
   writes `store ptr @at.N, ptr @pas_at` before the call, `EmitAtDone`
   writes `store ptr null, ptr @pas_at` after it; `@at.N` is a
   `{ ptr, i32, i32 }` constant -- the file, the line, the column -- and
   `pas_at` is a `_Thread_local` word in the runtime that every printer of
   `runtime error:` reads on its way out. **The clear is the correctness
   argument and not tidiness**: with it, a call the emitter forgot to bracket
   reports *no* position, where without it the previous bracketed call's
   position would stand -- and a wrong position is worse than none. It is
   also why nesting is safe: the operand of `Half(0.0) ** (-1.0)` is a
   function whose body makes bracketed calls of its own, each of which clears
   the word on return, and the `**`'s own store comes after the operand is
   evaluated. `pas_jump_go` never returns, so it clears the word itself
   before the `longjmp`. A task is a second chain of activations and a fresh
   thread's word is null (ADR-0268's reason for `_Thread_local`).

`@pas_at` is declared `thread_local(initialexec)`, which a Pascal program can
always claim -- it is an executable linked with the static runtime -- and
which makes the clear one instruction; the default model spent 50 KB more of
the compiler's text on `__tls_get_addr` sequences. `pas_str_at` keeps the
default model; changing it is not this record's business.

**The two-word entry points stay.** `pas_index_error(i32, i32)` and its three
siblings are what the seed compiler calls, and `seed/*.ll` is refreshed at a
release and not for this. They are wrappers passing no position, so a
seed-built compiler's own trap is positionless rather than reading a file
pointer out of whatever register held one -- which is what a signature change
under the seed's feet would have been, and would have passed every test until
the compiler crashed.

## Consequences

**Ninety-seven goldens changed, and the class is argued once here.** Each
gained ` at <source>:L:C` or ` at <dir>/components/name.pas:L:C` and nothing
else; the messages are unchanged. Twelve were checked by hand against their
source lines and every column lands on the construct named above. All 68
distinct messages in the corpus now carry a position, and the grep the roadmap
row gave -- filtered for a line -- goes from empty to all of them.

**Three cases are the evidence.** `tests/trap_position.pas` puts two
subscripts on one line and traps on the second, so a position taken from the
statement, the designator or the first subscript is a different column: the
mutation that reports `e^.ixBase`'s position instead of `e^.ixIndex`'s fails
it at column 15 against 17. (The mutation that reports the `nkIndex` node's
own position does *not* fail it, because the parser stamps that node with the
index expression's position -- the two are the same number, and the case
cannot tell a right answer from an equivalent one.)
`tests/trap_position_call.pas` traps inside `pas_pow_real` with a function
call for its left operand: deleting the `EmitAt` before that call leaves the
message with no position, and the case fails. `tests/extended/trap_in_module.pas`
traps in a separately translated module and the golden names
`<dir>/components/trapmod.pas`.

**What it costs was measured, and the honest number is size and not time.**
Two stage-2 compilers built from one source, differing only in whether
`EmitAt`/`EmitAtDone` emit anything, compiled `apfront.pas` in 0.347 s and
0.288 s (medians of eight, the bracketed one the faster sample, on a machine
shared with three other agents) -- no measurable cost. The compiler's own
text grew from 1 059 829 to 1 356 821 bytes, +28%, at roughly 47 bytes per
bracket -- a `lea`, a store through `%fs`, the clear, and the spills they
cause -- plus 101 KB of position records; `apfront.pas`'s IR grew 9.7%, from
8 948 999 to 9 816 214 bytes, carrying 2746 records. A one-entry cache on the
records was tried and removed: it hit once in 2747, because a statement's
calls name *different* positions -- each write-parameter its own, the
`writeln` the statement's.

**The bracket list is by hand, and the direction it fails in is the safe
one.** The 72 routines were found by a call graph over the runtime's IR and
bracketed at every emit site; the 55 that cannot trap are not. A routine that
begins to trap tomorrow, or a new emit site nobody brackets, reports its
message with no position -- visibly, in the golden of the first case to reach
it -- and never with another call's. Nothing compares the emitter's brackets
against the runtime's call graph; `doc/sop.md` §7 carries the row.

**What is still positionless.** In the corpus, nothing. By construction: a
trap from a runtime routine the emitter calls without a bracket, of which
there are none the call graph knows; and the seed-built compiler's *own*
traps, until the next reseed, because it calls the two-word entry points --
`procedure-coverage`'s subject is built by `build/bin/pascalc` and is not in
that class. `doc/afterschool-pascal-spec.md` Annex E.5 quotes a positionless
message from the processor's own history and is left as the quotation it is.

**`verify/` is untouched.** The check is the same test in the same place; only
the call in the cold block gained arguments, and `rules.py`'s
`accepted-index-selects-the-right-element` proves the subtraction after a
check that did not move. `Model-unchanged:` in the commit says so.

## What is not done

**Debug metadata.** The IR still carries no `!dbg`, so a debugger stopped at a
trap shows nothing; the roadmap row named it as the second half and it is
textual metadata that links nothing new, which is ADR-0085's bar. It is a
separate change with its own record.

**A gate over the bracket list.** The call graph that found the 72 is a
sixty-line script over `clang -emit-llvm` output, which is `runtime-isoc`'s
shape; it would compare the emitter's `EmitAt` sites against the routines
that reach a printer. Declined for now because the failure it guards against
is visible in the next golden rather than silent, and recorded in §7 so the
decision is a row and not a memory.

**A position for a trap raised while the program is leaving** -- a deferred
statement run by `pas_halt`, a file closed at block exit -- is whatever the
deferred statement's own brackets say, and nothing was written to check it.
