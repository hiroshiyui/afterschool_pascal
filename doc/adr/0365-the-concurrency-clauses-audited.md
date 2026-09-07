# ADR-0365: The concurrency clauses, audited

Date: 2026-09-08

## Status

Accepted. Fixes seven defects in AP 6.4.16, 6.7.8, 6.9.3.11 and 6.9.3.12 found
by an adversarial reading of the clauses: three over-strict, three
under-strict, and one that made the compiler emit a module LLVM refused.
Amends AP 6.7.8, 6.7.8.2 and 6.9.3.11.2 in `doc/afterschool-pascal-spec.md`.
Adds six `tests/` cases and ten scenarios. Adds no construct to the language:
every program it newly accepts was already meant to compile.

## Context

`langspec-audit` was run over the concurrency clauses — the newest surface
here, and the one whose records say most often that a limitation is *recorded
as a shape rather than an omission*. Four readers were launched into the
sandbox ADR-0228 builds, each given the behaviour and not the reasoning, three
to five clauses each, and told to hunt for a legal program wrongly refused.
The disclosure question was asked of a throwaway reader in the sandbox and of
one in the repository: the sandbox reader saw nothing, the repository reader
listed the git log, so the isolation ADR-0107 asked for still holds.

The audit's economics have changed since ADR-0105. Every clause in scope is
written down and clause-tagged, so a reader attacks a *claim* rather than
inferring one from behaviour. Three of the four readers reached the same
finding about a nested routine independently, and one of them reached it while
auditing a different clause, which is the shape of evidence a single reader
cannot produce.

## Decision

**A task's rule is asked of the owner chain, not of the owner.** AP 6.7.8.2
says a variable-access shall denote a variable declared "in that
task-declaration **or in a block within it**", and the check compared a
variable's owner with the task symbol. A procedure declared inside a task was
therefore refused its own parameter and its own local — so a task of any size,
which is to say any task with a helper, was unwritable. `OwnedByTask` walks
the owner chain instead.

**A nested task restores the rule; it does not clear it.** `taskBody` was set
on entering a task's body and set to nil on leaving one, so a task declared
inside a task cleared the rule for every statement of the *outer* body after
it. Two readers found it. It is saved and restored like `currentProc` beside
it.

**`input` and `output` are exempt.** Every write-parameter-list that names no
file denotes `output` (§6.10.3), and that spelling was never refused — so
refusing `writeln(output, x)` inside a task while admitting `writeln(x)` was a
rule about a spelling. Both required files are exempt by symbol identity.

**A task-declaration takes no directive.** AP 6.7.8 says so and named
`external` as the instance; `external` was refused and `forward` was accepted.

**A task-declaration belongs to a module-block.** The parser knew the
two-token spelling in a block's declaration-part and not in a module-block's,
so a worker declared in a library module was "expected `end` at the end of a
module block, found identifier" — a diagnostic naming nothing the programmer
did. Three readers reached it, one calling it the first finding of its report.
A module-*heading* is refused one, and says why: a task has a body, a heading
holds none, and what a module exports is the routine that spawns it.

**The join precedes the block's own deferred statements.** AP 6.9.3.12.1
requires every activation to be complete "before any variable of that block is
released", and its NOTE 2 names the block's deferred statements among the
things that must follow the join. But AP 6.9.3.11.2 a) executes an armed
statement when its statement-sequence completes, and for the block's own
statement-part that is *before* the epilogue where the join stood — so
`defer c := nil` closed a channel a spawned task was still sending on, and the
program died with the runtime error for sending on a closed channel. The join
is now emitted at the completion of that sequence as well. `pas_tasks_join`
empties the set as it joins, so the epilogue's call stands unchanged and is a
no-op; a block that does not both spawn and defer emits nothing new.

**6.4.6 c)'s conversion applies at a send and at a spawn's actual.** Sema
admits an integer where a channel's component or a task's formal is real, and
CodeGen stored the value at the *destination's* type. `send(c, 1)` on a
channel of real emitted `store double 1` and LLVM refused the module — a
program the front end accepted, failing in the assembler with a message about
a file nobody wrote. Both sites now call `ConvertFor`, which is what every
other assignable position already used.

## Consequences

A nested-sequence deferred release is *not* covered and that is deliberate,
written into AP 6.9.3.11.2 NOTE 4. A defer-statement in an inner
compound-statement is armed in that sequence and runs when it completes, which
is inside the block; a release written there is the release the program wrote
where it wrote it, which AP 6.4.16.4 already governs. Joining at every inner
sequence's completion would join at the end of each loop iteration and destroy
the construct.

Six of the seven defects were invisible to every oracle here, and the seventh
— the LLVM refusal — was invisible for the reason ADR-0067 gives: no corpus
program sent an integer on a channel of real. `procedure-coverage`,
`line-coverage`, `kind-exhaustive` and the stage-2/stage-3 fixed point were all
green throughout, because each asks whether the compiler still does what it
did.

The `--dump` goldens did not move, and neither did `verify/lowering.py`: the
model carries no rule about a channel send, a spawn's argument block or a
deferred statement, so the two CodeGen changes affect no theorem. The commit
says so in a `Model-unchanged:` trailer.

## Alternatives rejected

**Refusing a deferred release in a block that spawns.** It is the other way to
satisfy 6.9.3.12.1, and it refuses the program the clause was written to make
work — `defer` beside the action is the whole of ADR-0175's argument.

**Joining wherever an armed sequence completes.** Correct for every reading and
useless: a `defer` inside a loop body in a block that spawns would serialise
the loop.

**Reporting the module-block finding as unsettled.** Two readers rated it
over-strict and one leaned that way; ADR-0140's own test — an identifier where
a declaration-part expects a word-symbol is already a syntax error — holds in a
module-block word for word, and the clause never restricted itself to a block.

**Leaving `writeln(output, x)` refused as consistent.** It is consistent only
with itself: the implicit spelling writes the same variable and was never
refused, so the rule cost a spelling and bought nothing.

## What this does not do

It does not close AP 6.7.8.2's non-transitivity: a task may still reach a
global through a procedure declared outside it, which needs the call graph and
is `doc/sop.md` §7's row. It does not settle the four readings the audit
returned UNSETTLED — a `goto` out of a task's block hangs with no diagnostic,
a `send` arm on a closed channel raises its error only when the select's
rotation reaches that arm, `after` refuses an `int64`, and a trailing `;`
before a select's `end` is accepted. Each is in §7 and none takes a scenario,
because a scenario asserting one of two defensible readings would launder a
coin-flip into a citation.
