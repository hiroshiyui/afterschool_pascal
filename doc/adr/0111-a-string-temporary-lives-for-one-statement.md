# ADR-0111: A string temporary lives for one statement

## Status

Accepted.

## Context

ADR-0110 ended with a note that it had not made the *runtime*'s limits report,
and named one: `pas_str_temp`'s arena wrapped in silence when several string
values were live at once. The comment at the site argued no program could
reach it — a variable-string cannot be a value parameter, and `write` consumes
its arguments in turn — and recorded that the argument was untested.

It is false. A relational operator holds two string values at once:

```pascal
type big = string(600000);
var a, b: big;
...
if a + a = b + b then writeln('equal') else writeln('differ')
```

With `a` and `b` 262 145 characters long and differing in every character, the
two concatenations are 524 290 bytes each and the arena is 1 048 576. The
second wrapped to offset 0 and was written over the first, both pointers
reached `pas_str_cmp_pad` as the same address, and the program printed `equal`
with exit status 0. `tests/extended/str_arena_overflow.pas` is that program.

A wrap is *only* reachable at exhaustion, so there is no repair that keeps the
answer: whatever is done, this program must stop rather than compute. The
question is what happens to the programs that were relying on the wrap being
harmless, which is every program that concatenates in a loop —
`for i := 1 to 200000 do s := a + a` allocates four megabytes through a
one-megabyte arena and works today only because the space is silently reused.

Reporting exhaustion without a way to reclaim would refuse those, which is a
worse trade than the defect. So the arena needs a release, and nothing in
`runtime/pasrt.c` can supply one: a pointer into the arena is indistinguishable
from any other, and the runtime never learns that a value is finished with.

## Decision

**The arena is a stack whose boundary is a statement, and the generated code
says where the boundary is.**

`pas_str_at` becomes an exported `int`, named `@pas_str_at = external global
i32` in the emitted module. Each function's prologue reads it into an SSA value
— which therefore dominates every block, and is not an `alloca` (ADR-0102) —
and CodeGen stores that value back:

- at the end of every statement whose emission took arena storage, and
- after a `while` or `repeat` condition that took any, which is the one
  expression a statement evaluates more than once and which the statement's own
  release, running after the loop, would come too late for.

`pas_str_temp` then reports both ways of running out: a single value larger than
the arena, which it already did, and more live at once than the arena holds,
which is the wrap.

**Which statements need a release is answered by counting, not by a predicate.**
`EmitString` increments `strTemps` at each of its three arms that allocate —
concatenation, a char given an address (§6.4.3.3.1), and §6.7.6.9's `date` and
`time` — and `EmitStmt` compares the counter before and after. A predicate over
the tree would be a second opinion about what the emitter emits, free to drift
from it; the counter is the emitter's own answer.

**The release goes after the statement, not before it.** The emitter is
sequential and cannot return to put a mark in front of a statement it has not
yet read (ADR-0025). Placing it afterwards is what makes the counter usable at
all, and it is safe because every statement leaves a block open behind it —
`EmitGoto` starts a fresh one precisely so that what follows a `goto` has
somewhere to live.

**The shared datum is a global rather than a mark/release pair of calls.** The
prologue read is emitted in *every* function, because the prologue is written
before the body that would say whether it is needed. As a load from a global
with no reader it is deleted outright: `tests/hello.pas` mentions `@pas_str_at`
in its IR and its `-O2` object references it zero times. Two calls could not
have been, and would have cost an extra call per activation in every program
whether or not it ever concatenated.

## Consequences

**A program that computed a wrong answer now stops.** Anything holding string
temporaries summing past 1 MB in one statement is refused at run time with
`more string values are live at once than the string arena holds`. That is a
change to what an already-valid program does and is called out in
`CHANGELOG.md`; the answer it used to give was not one.

**The limit is stated.** `doc/implementation-defined.md` §6 carries it, which
clause 5.1 c) requires and which it did not before.

**Every function's prologue gains a load.** Free at `-O1` and above where
unused, one instruction per activation at `-O0`. The whole corpus at `-O0` runs
in the time it did.

**Nothing in `verify/` models this.** The proofs are about arithmetic,
conversion and comparison lowering; storage for string values is not among
them, and no rule was added, so the commit carries `Model-unchanged:`.

**What this does not do.** It does not bound the arena by anything but the
statement. A single statement can still be written that needs more than 1 MB
and it will still stop — correctly now, but stopping all the same, and the
number is this implementation's rather than either standard's.

It also leaves one gap nothing checks: a *new* arena producer added to the
runtime and emitted from somewhere other than `EmitString` would allocate
without incrementing `strTemps`, and the statement holding it would write no
release. Nothing fails if that happens. `doc/sop.md` §7 records it.

## Alternatives rejected

**Report on exhaustion and add no release.** One line, and it applies ADR-0110's
rule exactly — but with nothing reclaiming, an ordinary concatenation loop
exhausts the arena after a few thousand iterations. It converts a rare wrong
answer into a common refusal.

**Grow the arena, or grow it on demand.** Moves the number without answering the
question, which is the reason ADR-0110 gave for not raising `strMax`. Growing on
demand additionally has to keep already-issued pointers valid, so it is a block
chain that never frees — an unbounded leak in place of a bounded one.

**Reference-count the values.** A string value is deliberately a pointer and a
length and nothing else (ADR-0051), which is what makes `substr` and `trim` copy
nothing. A count would be a third word and would have to travel everywhere the
other two do.

**Release at the top of each statement instead of the end.** Equivalent in what
it frees, and it is where `--coverage` puts its counter, so the placement is
known good. It cannot be driven by the counter, though: at the top of a
statement the emitter has not yet seen what the statement contains. It would
need the predicate this decision rejects.

**Bracket only leaf statements and let structured ones inherit.** An `if` whose
condition concatenates, in a loop whose body does not, would then keep an
iteration's worth of arena per iteration. Every statement that took storage
releases it, including the structured ones.
