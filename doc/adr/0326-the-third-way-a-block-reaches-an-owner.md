# ADR-0326: The third way a block reaches an owner

Date: 2026-09-05

## Status

Accepted. Amends AP 6.4.14.9 with a paragraph and corrects its NOTE 1, which
claimed the requirement was exhaustive and was not. ADR-0319 is not superseded:
its rule is right and its enumeration is right, and what was wrong is the
inference drawn between them.

## Context

`doc/roadmap.md`'s first memory-safety row was struck on 2026-09-04 as *closed*,
and AP 6.4.14.9's NOTE 1 said so in the strongest available terms:

> There is no third way, and so no residue.

There is a third way. A review on 2026-09-05 probed the claim rather than
reading it, and this program compiles, prints a value read from disposed
storage, and exits 0:

```pascal
procedure Runner(var m: N; procedure k);       { names nothing of Holder's }
begin k; writeln('after the release: m.v = ', m.v:1) end;

procedure Holder;
var p: ON;
  procedure Killer; begin dispose(p) end;      { can name p }
begin new(p); p^.v := 7; Runner(p^, Killer) end;
```

The only diagnostic is the fourth warning, suggesting `protected var m` —
advice that does not help, protection stopping writes where this is a read.

**The enumeration NOTE 1 rests on is right and the inference is not.**
6.4.14.3 forbids copying an owned pointer, so its only names are the variable,
a variable parameter bound to it, and a component of what contains it. But
that is an enumeration of **names**, and the requirement is about **releases**.
A block does not have to name an owned variable to release it: it releases it
by activating a §6.7.3.4 procedural parameter that can. `Runner` names nothing
of `Holder`'s, so ADR-0319's `CanName` found nothing to refuse.

Both halves of the clause had it. The with-statement form is the same program
with the borrow bound by `with p^ do` instead of passed, and `Bare(Killer)`
inside the body.

The construct is not new: a procedural parameter is ADR-0030 and predates every
owned-pointer record here. What is new is that anything asks about it.

## Decision

**Neither activation-point shall have an actual-parameter corresponding to a
procedural or functional formal-parameter that denotes a block which can name
the owner.** `ProcActualReaching` asks it, of the actual and not of the formal
— a formal's heading says what a routine looks like and never which one
arrived.

**It needs no transitive requirement**, and that is a property of Pascal rather
than a simplification worth apologising for. A block obtains a routine in
exactly two ways: by being declared where it is in scope, which the existing
paragraph already asks about, or by being handed it, there being no
procedure-variable in this language. And the only activation-point where a
borrow is *formed* from its owner is one in a block that can name the owner. So
the routine and the borrow meet at a single activation-point, and that is the
one examined. A borrow passed onward travels with whatever the callee was
given, and the callee was given nothing that reaches the owner.

## Consequences

**The check runs after the arguments are checked, and that is a constraint and
not a preference.** `ProcActualSym` reads what `CheckProcArgument` resolved, so
the with-statement pass at the top of `CheckArguments` cannot ask it — it runs
before any actual has a symbol. The new pass is the last thing `CheckArguments`
does, and asking it early would have found nil for every routine and refused
nothing, silently, which is the shape of the defect this record is about.

**A procedural actual that resolved to nothing must not crash it.** §6.7.3.4's
own check reports the name; this pass then holds a nil symbol, and a question
about a routine there is no routine to ask is answered no.
`tests/dialect/owned_procparam_errors.pas` case 4 is that program, and it is
what reaches the guard — the branch ratchet named it, which is the gate doing
the job ADR-0274 built it for.

**It takes something away from working programs**, which is the cost and the
reason this is a decision. `Runner(p^, Killer)` compiles today and will not.
Nothing in this tree was affected: the whole corpus is green and the only
programs that had the shape are the two written to demonstrate it.

**The message names the routine and why it reaches**, reusing `WhyCanName` so
that the two forms of the clause report the same reason in the same words:
*this borrows what 'p' owns, and the routine it is given, 'killer' can name
'p', being declared inside 'holder'*.

## What this does not do

**It does not make the model sound.** What it closes is the way found by
probing, and the honest statement of the residue is now NOTE 1a's argument
rather than NOTE 1's assertion: the argument is that a routine reaches a block
only by scope or by being handed over, and both are asked. That argument can be
wrong the way the last one was, and the way to find out is to probe it again
rather than to re-read it.

**It does not add a flow analysis.** `Harmless(p^, Killer)` — a routine that
takes the pair and never activates `k` — is refused, deliberately. What is
claimed is that the routine *can* release, which is ADR-0277's boundary read
one construct over.

**It does not touch 6.4.14.7.** The release-while-borrowed rule is about a
release the same activation makes and is unchanged.

**It does not revisit `protected`.** A protected borrow is refused here too,
and must be: protection stops the callee writing through the borrow and says
nothing about a third party disposing what it names. That is why the warning
suggesting `protected` was no help in the program above.

## Alternatives rejected

**An interprocedural summary of what each routine releases.** ADR-0317
rejected it for 6.4.14.7 and the reason holds here: §6.13.2's module-heading
carries no such summary, so the answer would differ across a separate
translation boundary.

**Refuse a procedural parameter in any call that forms a borrow.** Simpler to
state, and it refuses `Runner(p^, Quiet)` — a routine that demonstrably cannot
reach the owner. The clause already has `CanName`; using it costs nothing and
keeps the rule about reachability rather than about shape.

**Leave it, and record it as a known gap.** It is a use-after-free reachable
from a program a person would write — a callback taking a borrow is an ordinary
shape — and the row above it in the roadmap claimed to have closed exactly this
class.
