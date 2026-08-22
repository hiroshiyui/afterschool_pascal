# ADR-0167: The third audit found six defects in the parameter and constant clauses

Date: 2026-08-22

## Status

Accepted. The third run of `.claude/skills/langspec-audit/`; ADR-0101 and
ADR-0107 record the first, ADR-0162 the second.

## Context

The audit was aimed at ISO/IEC 10206:1991's **uncited** clauses, because that
standard sat at 6.2% scenario coverage against the dialect's 95.9% — 137
clauses no scenario named. An uncited clause the compiler implements is where
an unexamined reading hides: nothing has ever stated what the compiler thinks
it means, which is not the same as the reading being right.

Four readers, one group of clauses each, 366 compiled probes between them:

1. §6.7.3.1, §6.7.3.2, §6.7.3.3, §6.7.3.6 — parameters and congruity.
2. §6.7.1, §6.7.2, §6.7.3.4, §6.7.3.5 — procedure and function declarations,
   and procedural and functional parameters.
3. §6.7.5.6 and §6.7.6.8 — the binding procedures and the binding function.
4. §6.7.5.4, §6.7.5.5, §6.7.6.3, §6.7.6.4 — the transfer and ordinal
   functions.

The reports did not survive the session that produced them. **The probes did**,
and every verdict below was re-derived from a probe and the clause text rather
than taken from a reader — which is step 7 of the skill and turned out to be
load-bearing twice, in both directions.

## Decision

Six defects fixed, all in the conformance modes and none touching the dialect.

### 1. `round` is an equivalence, not a rounding mode (§6.6.6.3 / §6.7.6.3)

The clause defines round(x) as *equivalent to* `trunc(x+0.5)`, or
`trunc(x-0.5)` when x is negative. This emitted `llvm.round`. The two agree at
every halfway point — including all four of the clause's own examples — and
disagree wherever `x ± 0.5` is inexact, because the addition rounds:
`round(0.49999999999999994)` was 0 where the clause requires 1.

**The reader filed this UNSETTLED**, on the reading that the clause names a
rounding mode. It does not; it names a computation, and the word is
"equivalent". Re-reading it is what turned a coin-flip into a fix.

`verify/` is the part worth recording. It had a rule for round's *range* and
none for its *value*, so `lowering.py` modelled `llvm.round` faithfully and the
catalogue reported no known gaps while proving the compiler matched a model of
a mistake. `iso.py` gains `is_iso_round`, characterised rather than recomputed
in the house style of `is_iso_div`; reverting the model fails it with the
counterexample `1.9999999999999997779553950749686919152736663818359375*(2**-2)`
— which is 0.49999999999999994, found by z3 independently of the probe.

### 2. `succ(x, k)` added at the ordinal's width (§6.7.6.4, D.65)

The comment above the code already said what the clause requires — "the
arithmetic must not wrap before it is looked at" — and the addition was `i32`,
so `succ(maxint, 2)` wrapped to -maxint and the range check found it inside
every type. `succ(maxint)` reported, because a step of one compares before it
steps. One clause, two spellings, two answers, and the wrong one silent.

D.65 makes it an *error*, so §3.1 would have permitted documenting it instead.
That was the smaller change and the worse one: the detection was already there
and already paid for, and what was wrong was one width.

### 3. A result variable could be spelled like a parameter (§6.2.2.7)

`function f(n: integer) = n: integer` has two defining-points of `n` for one
region — §6.7.3.1 puts a parameter's in the formal-parameter-list and §6.7.2
puts a result-variable-specification's in the same list — which §6.2.2.7
forbids. Accepted, it meant a different program: the result variable won inside
the block, so the body wrote the result and the argument was unreadable. A
wrong answer and exit 0, which is the worst shape a conformance gap takes.

Not an Annex D error, so §5.1 e) requires the refusal.

### 4. A qualified name is a procedure-name (§6.7.3.4, §6.7.3.5)

§6.7.1 spells `procedure-name = [ imported-interface-identifier '.' ]
procedure-identifier`, so `call(i.p)` is one of exactly two forms §6.7.3.4
admits, and it was refused. Under `import i qualified` there was no workaround:
§6.11.3 puts the unqualified spelling out of scope, so a module imported that
way could have none of its procedures passed to anything.

### 5. Three required functions were nonvarying and refused (§6.8.2)

§6.8.2's exclusion for required functions reaches only a function declared by
the program and `eof`/`eoln`; NOTE 1 adds `empty`, `position` and
`LastPosition` and gives the reason. So `succ(x,k)`, `pred(x,k)` and `length`
belong in a constant-expression, and a constant-expression is what a bound is —
`packed array [1..length(greeting)] of char` did not compile.

Eight remain refused and are a **restriction**, not this rule: a real constant
is carried here as the text that was written and never converted to a number,
so `trunc` and `round` need a conversion and the six real-valued ones a
formatter besides. They now say which, because "the expression is not constant"
is a complaint about the program and this is not one.

### 6. A `string` value parameter takes an expression (§6.7.3.2)

The clause gives the required schema `string` its own paragraph as a **value**
parameter: the actual is an expression "having an underlying-type that is a
string-type or the char-type", and the formal possesses the type produced "with
the tuple having that length as its component". Both halves were wrong. A
literal, a char, a constant, a concatenation and a function result were all
refused — **including §6.11.6's own Example 10**, `record event('event-module
initialization')` — and the formal was given the actual *variable's* capacity
rather than the value's length.

The fix is small because the two shapes already coincided: a schematic formal
travels as an address and one discriminant, and `EmitString` already builds an
address and a length for any string expression. The callee's prologue builds
the string object instead of copying one, and the discriminant it stores is the
length, so the second half arrives with the first.

## Consequences

Two of the refused programs are the standard's **own worked examples** —
§6.11.6's Example 10 and §6.7.6.8's `bindfile`. That is the strongest evidence
this audit produced and it points at the cheapest fix and the most expensive
one. Probing the examples an ISO standard prints is worth doing directly and
was not, in three audits.

**Three programs that compile today change behaviour**, and CHANGELOG spells
each out: `round(x)` where `x ± 0.5` is inexact, `succ(x, k)` at the top of the
integer type, and an over-long assignment into a `string` value formal.

**A finding was corrected in each direction.** One UNSETTLED verdict was a
defect (§6.6.6.3); one "gap" that would have been documented was a fix worth
making (D.65). Neither would have been caught by merging on the strength of a
verdict being returned.

## What is not done

**Reader C's five findings, which have one root cause and are not a bug fix.**
Bindability here is read off the *root symbol* of a designator — the message
even names the container — and the standard makes it a property of the
type-denoter (§6.4.3.4 for a field, and the same wording for an array
component), so `bind(r.log, b)` and `bind(pool[i], b)` are refused for a
bindable field and a bindable element. §6.7.3.3 is worse: "the formal-parameter
... shall possess the bindability that is possessed by the actual-parameter",
NOTE 1 making it "determined **dynamically**", and §6.7.5.6 and §6.7.6.8 both
making the file case a *dynamic-violation*. So a conforming processor carries a
bindability word with every `var` file parameter and checks it at run time —
the seventh entry in the list of things that travel as two words — and
§6.7.6.8's own `bindfile` example is refused until it does.

`bind` on a non-file bindable variable is a third, and it is a feature rather
than a fix: the clause's "otherwise, the variable shall possess the bindability
that is bindable" presupposes a non-file, and what it means to bind an integer
to an external entity is implementation-defined and undesigned here.

These are on `doc/roadmap.md`, not in this change. A record for them is owed
before any of it is written.

**§6.7.3.2's same-length error is unreported.** "It shall be an error if the
values ... do not all have the same length" for the actuals of one parameter
form naming `string`; the lengths are run-time values, unlike every other tuple
in a parameter form, so the sibling §6.7.3.3 check reports before the program
runs and this one cannot. `doc/implementation-defined.md` §3 carries it.

**Two gate blind spots were found and one is new.** `difftest` never passes
`--import`, so a case with a `.components` sidecar is compared as two identical
*rejections* about an interface neither front end has heard of — ADR-0034's
failure mode one harness along, and how finding 4 could have been wrong in both
implementations without the oracle noticing. And `model-drift` is scoped to a
**range**: this push changed `verify/lowering.py` in two commits, which
satisfies the gate for the four others, two of which touch CodeGen and are
unmodelled for good reasons nobody had to write down. Both are in
`doc/sop.md` §7.

**Nine scenarios** were added, under §6.2.2.7, §6.8.2 and §6.7.3.2, all three
of which were in `pending.txt`. §6.7.3.4's qualified form has none and cannot:
`tests/spec/run.py` compiles a single program and cannot ask for a second
component, which is the limit already recorded for §6.11 and §6.13.1. Writing a
scenario for the unqualified form instead would file a citation under a
requirement it does not check.
