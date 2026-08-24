# 182. `take` is the move an owned pointer needs

Date: 2026-08-24

## Status

Accepted. AP 6.4.14.6, and an amendment to 6.4.14.3.

## Context

ADR-0181 gave a created variable an owner, and the next step was `PasList`: a
library module over the new type, on the reasoning that every dialect feature
so far has found something when a client was written for it the same day.

The module was never written, because the design probe found the type cannot
carry one. An owned pointer has no copy, so a chain of owned nodes admits:

| Operation | Expressible | Why |
| --- | --- | --- |
| push-back, pop-back | yes, O(n) | recurse to the end; `dispose` the last node |
| len, get, set, traverse | yes, O(n) | recursion through `var` |
| clear | yes | `dispose` of the head, released recursively |
| **push-front** | **no** | `fresh^.next := n` and `n := fresh` are copies |
| **pop-front** | **no** | `tail := n^.next` and `n := tail` are copies |

Every operation O(n), no insertion or removal at the head, and no operation in
constant time at all. Beside `PasVector` — O(1) push, O(1) index — such a
module would be worse at everything and its only merit would be needing no
`Free`. A library built on that would be the wrong artefact to ship, and the
finding is not about the library: **the missing primitive is a move.**

The four refusals are all one diagnostic, and it is right every time. What is
missing is a way for one variable to *stop* holding a value so that another can
start.

## Decision

**`take(v)` empties an owned pointer variable and yields what it held, and may
stand only as the whole right side of an assignment to a variable of that
type.**

    fresh^.next := take(n);      n := take(fresh)        { push-front }
    n := take(n^.next)                                   { pop-front, entire }

Four things decided.

**The position rule is 6.4.12.2's, reached by the same shape of flag.** A
`take` anywhere else would empty a variable and leave what it emptied held by
no one, which is the leak ADR-0181 exists to close. `takeOk` is set
syntactically before the value is checked, exactly as `handleBirth` is and for
the same reason — nothing is resolved at that point — and cleared by
`CheckTake`. It is narrower than `handleBirth`: `take` is a required identifier
always written with its argument, so only an `nkCall` can be one, where a
handle-valued call has the bare spelling too (ADR-0179).

**A required identifier, not a position.** `exit`'s and `try`'s shape
(ADR-0177, ADR-0178): the name is nobody's under a conformance mode and §6.1.3
lets any program shadow it. The fifth construct with that spelling, which is
now the commoner of the dialect's two.

**The source is read and emptied before the target's address is taken, and the
order is normative.** A target reached *through* the source —
`p^.next := take(p)` — would otherwise compute an address inside the very node
it is about to orphan, and the store would make that node its own successor: a
cycle held by no variable and reachable by no release. Emptying first makes the
program dereference `nil` and stop. A defect reported beats a leak, and the
order costs nothing in every program where the two are unrelated.

It also makes `n := take(n^.next)` the whole of pop-front. The source is the
identified variable's own field, so releasing what the target held disposes
that variable *alone* — its successor having just been emptied out of it — and
the successor lands in the target. One statement, no temporary, no special
case in the compiler.

**Lowered in `EmitAssign` and nowhere else**, in four instructions and with no
runtime call: read, empty, release, store. `EmitCall` has **no arm for
`biTake` at all**, which `partial_cases.txt` records as deliberate: a `biTake`
reaching `EmitCall` would be a call in a position Sema refuses, so the
compiler stopping there says so, where naming it in the three catch-all lists
would emit an `undef` and a program that quietly moved nothing.

## Consequences

`PasList` is now writable as a real list: O(1) push-front and pop-front, and no
`Free`, because the block that owns the head releases the chain.

Two diagnostics changed wording, and the change is an improvement rather than a
regeneration: `q := p` between two owned pointers now says *an owned pointer
may be assigned only `take` of a variable of its own type*, where it used to
say *it contains an owned pointer, and a second name for one would dispose one
variable twice*. The first names the fix; the second described the refusal. The
old wording survives where `take` cannot help — assigning an owned pointer to
an ordinary one, a value parameter, a result — and `tests/dialect/owned_errors`
holds both.

**One spec scenario was found asserting less than its name claimed.** The
scenario for the target's release passed under the mutation that removed the
release, because the node being leaked held nothing observable. It now puts the
stream in the *target's* old value, so failing to release it leaves the text
unflushed. A scenario that cannot fail is the failure mode `tests/spec/` exists
to avoid, and this one was written by the same hand that wrote the feature —
which is exactly when it happens.

The `Threatened` arm in `CheckTake` is reachable only in a program already
refused for another reason: an owned pointer is not a protectable type, and a
control variable is ordinal. The guard stays and `tests/dialect/take_errors`
carries the two-error case, because `Threatened` is the shared list of §6.9.4's
threats and dropping a check because today's type rules make it unreachable is
how a permission comes to leak later (ADR-0146).

## What this does not do

**It is not a move for handles.** 6.4.12.2 gives a handle one assignment and
this clause does not touch it. A handle move would have to release the source
*without* releasing its value, which `pas_handle_set` cannot express and which
needs a runtime routine of its own — a distinct operation from this one, and it
waits for a client. `PasStream.Close` is that client waiting, and the roadmap's
"there is no `h := nil`" entry stands.

**It does not make an owned pointer copyable.** Everything ADR-0181 refuses is
still refused; what is added is one position in which a value may move rather
than be duplicated, and the source is empty afterwards.

**It admits no borrow.** Reading an owned pointer as an ordinary `^T` is still
refused, so a traversal is still recursive and there is still no second name
for one owned variable. The aliasing fork (ADR-0151) is where it was.

## Alternatives rejected

**A `Move(dst, src)` required procedure.** A statement rather than an
expression, so no position rule would be needed. Rejected because the position
rule is not a cost here — it is already built, and it is what makes the
assignment the single place ownership changes hands. A procedure would put the
release of `dst`'s old value inside a required procedure instead of in the
assignment, where 6.4.14.3 already lists every release point.

**Allowing `take` anywhere and leaking.** The obvious shortcut, and it gives
back exactly the defect ADR-0181 closed.

**Making the assignment `p := q` simply mean a move.** No new identifier at
all: assigning an owned pointer empties the source. Rejected because it makes a
copy and a move look identical, and every other affine type here refuses that
statement outright — the reader of `p := q` would have to know the type to know
whether `q` survives. `take` is one word and says so.
