# 277. A statement after one that leaves

Date: 2026-08-31

## Status

Accepted, 2026-08-31.

## Context

ADR-0272 built the category *this compiles and is probably wrong* and shipped
one warning in it: a local variable declared and never used. It closed with a
list of four more that were sayable and unsaid, and `doc/roadmap.md` carried
that list. One of the four is **a statement written after an unconditional
`goto` or `exit`** — dead code the compiler emits, the linker keeps and nothing
ever runs.

The list is not four equal items. An unused *import* is not obviously a
mistake here: §6.2.3.6 commences a supplying module before the program-block,
so importing purely for a `to begin do` part is meaningful, and a warning would
need to know better than the programmer. A `var` parameter never written
through and a function result assigned on one path and not another are both
questions about what a *body* does over all its paths. This one is the smallest
of the four, and the only one that is a property of a statement-sequence rather
than of a routine — which is why it was taken first.

The corpus said in advance that it would be quiet. Sweeping the 779 tracked
`.pas` files found **five** dead statements in four files, and every one of them
is deliberate: `tests/goto.pas`, `tests/dialect/exit.pas`,
`tests/extended/required.pas` and `tests/dialect/components/exit_counter.pas`
each exist in part to prove that what follows a transfer does not run. The
compiler's own three program-components have none.

## Decision

`Transfers(s)` answers whether control reaches what is written after `s`, and
it is true for five statements: ISO/IEC 10206:1991 §6.9.2.4's `goto`, §6.7.5.7's
`halt`, and the dialect's AP 6.7.5.9 `exit`, AP 6.7.5.10 `break` and
AP 6.7.5.11 `continue`. A labelled statement is looked *through* — `1: exit` is
still an exit.

`WarnUnreachable(first)` walks a statement-sequence and writes
`this statement cannot be reached` at the first statement of every run that
follows one. It is a **statement-sequence** question and nothing smaller:
§6.9.2.1 gives a statement-sequence to a compound-statement, a
repeat-statement and §6.9.3.5's case-statement-completer, and nowhere else, so
the arm of an if and the body of a while are single statements with nothing
after them to be unreachable. There are four call sites for those three shapes,
because a block's statement-part is a compound-statement that `CheckBlock`
walks itself rather than through `CheckStmt`'s own arm for one — which the
first probe found by reporting the dead statement inside a `repeat` and neither
of the two at the top of a block.

**It is deliberately not a flow analysis.** An `if` whose two arms both leave,
and a `case` every arm of which does, make what follows unreachable just as
surely; answering that is a lattice over the whole statement tree. What is
claimed here is the *unconditional* transfer, which is one node kind and one
field, and the roadmap asked for exactly that.

Three rules beyond the main one, and none of them is visible from a single dead
statement:

- **A labelled statement is reachable**, however it was arrived at, so a run
  ends at one. §6.9.1 b) lets a `goto` reach a label at the top level of the
  sequence containing it, so `goto 2; x; 1: y` says what it means.
- **A run is reported once.** Naming every statement in it is a paragraph about
  a single mistake.
- **The empty statement is never named.** §6.9.2.1 lets a statement be empty
  and a doubled separator writes one, so `exit; ;` puts an empty statement
  exactly where a dead one would stand. Reporting it would be a complaint about
  punctuation. The `;` before an `end` is *not* this shape — the parser leaves
  nothing behind for it at all.

The guards are ADR-0272's, unchanged: `warnOn`, `not errorSeen`, and
`curFile = mainFile`.

## Consequences

`tests/dialect/unreachable.pas` is the case, and it is written so that each of
those rules has a shape only it can produce. Seven mutations of the mechanism
were made and each is killed by a named case: `goto` not transferring fails
`goto`, `exit` not transferring fails `exit`, `halt` not transferring fails
`required`, and `break`/`continue`, the label rule, the once-per-run rule and
the empty-statement rule each fail `unreachable`.

**Two of them were not killed by the first version of the case**, and the
reason is worth carrying. A label ending a run and a run being reported once
are *the same observation* unless a second run follows the label: with only one
run per sequence, dropping the label rule changes nothing, because the
report had already been used up. The case now writes two runs either side of a
label in one sequence. And the empty statement had to be written `exit; ;`
rather than as the `;` before an `end`, the parser producing a node only for
the first.

**Three new sidecars, and that is the gate working.** `tests/goto.warn`,
`tests/dialect/exit.warn` and `tests/extended/required.warn` say that those
programs are warned about, which is ADR-0272's rule that a case *without* a
`.warn` must produce none.

**And it closed a hole ADR-0272 left open.** Every warning is guarded by
`warnOn`, which every `--dump` flag clears, because a dump has a reader parsing
a fixed grammar; ADR-0272 learned that from `--dump-dispatch` and then pinned
it nowhere. No source under `tests/dumps/` warned at all, so **dropping the
guard from either warning left all 790 cases green**. `tests/dumps/warnings.pas`
declares a local nothing names and writes a statement after an `exit`, and its
golden now fails for either.

The two new decisions the code adds are both **fully covered in both
directions**, and getting there changed the code twice. `Transfers` had a
`s <> nil` test that no compiling program can take — the only caller refuses to
run once anything has been reported, so the tree it walks is one the parser
finished — and `CheckBlock` would have asked `b^.blBody <> nil` a second time,
which has been an untaken direction since long before this warning. Both were
restructured away rather than argued for, so `branch_coverage.txt`'s
`uncovered` holds at 853 with 30 more directions instrumented.

`Transfers` is a partial if-chain over `nodeKind` and takes an entry in
`tests/checks/partial_cases.txt`: the trailing `else` is the answer and not a
fall-through, an assignment, a compound, an if, a loop, a `with`, a `case` and
a `defer` all continuing to the next statement.

Three of ADR-0272's four remain: the unused import that would need to know
better, the `var` parameter never written through, and the function result
assigned on one path and not another.
