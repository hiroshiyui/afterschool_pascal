# 317. The other half of the borrow argument

Date: 2026-09-04

## Status

Accepted, 2026-09-04. Narrows a defect ADR-0201 left open without naming;
adds AP 6.4.14.7 and Annex C.12. ADR-0201 is not superseded — every sentence
in it is still true, and this record is about a sentence that is not in it.

## Context

ADR-0201 withdrew the ARC-or-borrowing fork by showing the language has no
escaping alias to govern. Its third probe found the one alias that does exist:

> `n` is a second name for what `o` owns, for the duration of the call — a
> borrow. And it **cannot escape**.

That is the whole of the safety argument, and it is one of two halves. Rust's
rule has both: a borrow may not outlive what it borrows, **and** what is
borrowed may not be released while the borrow is live. The second was never
stated here, and AP 6.4.14.3 gives an activation three ways to perform exactly
that release — `dispose`, `new`, and an assignment.

## What the probes found

**1. The hole is ADR-0201's own probe with one word changed.** That record
tested the classic hazard — two `var` parameters bound to one variable — and
pronounced it safe, because the operation it wrote there was `take`:

```pascal
procedure P(var o: op; var n: node);
begin dispose(o); n.v := 42; writeln('n.v = ', n.v) end;
...
new(q); q^.v := 1; P(q, q^)          { printed 42, exited 0 }
```

**2. Every oracle here agreed with it.** `heap-balance` reads `new=1
dispose=1 live=0`, and honestly: the count is right and the storage is gone.
A build under `AFTERSCHOOL_PASCAL_CFLAGS=-fsanitize=address` reports nothing.
The corpus case for the construct, `tests/dialect/owned_borrow.pas`, exercises
bump, read, move and self-move and never releases the owner during a borrow —
so the shape was not merely unchecked, it was untested, and the record that
introduced it says in as many words that the classic hazard is safe.

**3. It corrupts, rather than merely reading rubbish.** With an allocation in
between, the write through the stale borrow lands in an unrelated live
variable — `dispose(g)`, then `new(h); h^.v := 111`, then `n.v := 999`, and
`h^.v` reads **999**. `new` under a live borrow is the same defect by a second
door, 6.4.14.3's fourth release point rather than its fifth.

**4. There is a third borrow form and it needs no call at all.** A
with-statement's binding is a frame slot holding an address — the same shape
as a variable parameter, and `CheckWith` says so in a comment. So

```pascal
with q^ do begin dispose(q); v := 999 end
```

is the same defect inside one block, with no procedure in it.

**5. The double-release shape needed nothing, and that is what identifies the
rule.** `P(q, q)` disposing both parameters does not free twice: each of
6.4.14.3's release points **empties the variable it was given**, so the second
meets `dispose` of `nil` and Annex D's error. A second name that is a
*variable* is therefore already safe. What this clause is about is the second
name that is **not** a variable, which nothing empties — which is what a
borrow is.

## Decision

**AP 6.4.14.7: it shall be an error to release an owned pointer while a
variable it owns is bound to a variable formal-parameter or to a
with-statement's binding.** An *error* in §3.1's sense and not a violation,
because the general question is not answerable where the program is
translated; the clause then requires two occurrences to be detected and the
processor detects them.

**a) Two actual-parameters of one activation-point.** An actual reached
through a dereference of an owned-pointer-type, where another actual of the
same call denotes an entire-variable whose type contains that owned pointer,
and both correspond to variable formal-parameters. Three decisions inside it:

- **The unit is the entire-variable**, which is §6.9.4 h)'s own unit — a
  threat to a component is a threat to the variable containing it. So
  `P(r.p, r.q^)` for two owned fields of one record is refused although the
  two identify different variables. Comparing the access paths would need the
  value of a subscript, which is not a translation-time fact.
- **The owner is an entire-variable and not itself a borrow.** An actual
  reached through a dereference can release only what lies deeper than
  itself, so `Two(o^, o^)` binds two borrows and no owner and must go on
  compiling. That case is in the corpus for the same reason the refusals are.
- **A value parameter raises no question**: §6.7.3.2 attributes the actual's
  value to a variable of the activation before the body runs, and a value
  parameter cannot possess a type containing an owned pointer in any case.

**b) A release under an open with-binding.** `new`, `dispose` and an
assignment, asked of an owned pointer through which an enclosing
with-statement's element was reached. The binding is recorded where the
element is still a designator — the body sees only the binding — on a stack
beside `withTop` and popped with it, which is `ActiveControl`'s shape one
construct over and for its reason: what the rule is about is a binding open
*here*, not a property of a symbol.

**What is not detected is written down rather than left to be found.** A
release the borrowing activation reaches indirectly — naming the owner as a
non-local, or being handed it by something other than the activation-point
that made the borrow — is Annex C.12.

## Consequences

**`doc/roadmap.md`'s memory-safety row narrows and does not close**, and it
now names the mechanism that would close it rather than the fact that
something is open.

**Three diagnostics, and the corpus reaches each.**
`tests/dialect/owned_borrow_errors.pas` carries eight refusals and five
programs that must go on compiling; `tests/dialect/owned_borrow_qualified.pas`
is the same rule asked of a variable a module holds, which is the only shape
whose walk to the entire-variable ends at a qualified field-designator.
`tests/spec/features/dialect_owned.feature` gains four scenarios against the
clause. Two mutations kill two different cases: neutering the pair test kills
`owned_borrow_errors`, neutering `ActiveOwnedBorrow` kills
`owned_borrow_qualified` as well.

**Two branch directions are unreachable and are argued at their sites** rather
than covered — `OwnedRoot`'s `nkVar` test, which §6.5.3.3 requires and which
only a function answering an owned pointer could falsify, and
`ActiveOwnedBorrow`'s nil guard, which stops a nil root matching the nil entry
an unowned `with` pushes. The branch ratchet moves by one for them.

**AP 6.4.14.6 had two NOTE 6** — ADR-0303 wrote one for the spawn position and
ADR-0307 added a second — and the later is renumbered. No normative text moves.

## What this does not do

**It does not close the aliasing question.** The indirect route above is open
and is now a clause of Annex C rather than an unexamined assumption. What it
takes is in *Alternatives*.

**It does not make `^T` safe**, and cannot. ADR-0019's hole is ISO Pascal's and
ADR-0117's containment keeps it.

**It does not check the escape direction.** That half is still *unformable*
rather than checked (ADR-0201), and `doc/sop.md` §7's row for it stands
unchanged: a future feature that lets a borrow be stored takes the property
away in silence, and this clause would not notice.

**It does not reach a task.** AP 6.7.8.2 lets a task name only its own
variables and every task a block spawned is joined before that block releases
anything (ADR-0268), so the construct that would break the single-thread
argument does not reach an owned pointer to begin with.

## Alternatives rejected

**Releasing only in the block that declares the pointer.** Sound under one
thread — a declaring block is suspended for the whole life of any borrow it
made — and it was rejected on a measurement rather than a feeling: all **ten**
of `PasList`'s exported routines take `var l: List` and **five** release
through it, so `lib/dialect/paslist.pas` could not be written. The module is
the one container here with no `Free` and it exists to demonstrate the type.

**A dynamic borrow flag** — a word beside every owned-pointer variable, set
across a call that borrows through it and tested at the three release points.
This is Rust's `RefCell` rather than its borrow checker, and it is the
candidate that is **sound and complete**: it needs no whole-program view and
survives separate compilation, where the static summary below does not. It is
not rejected on its merits — it is a lowering and a runtime change with a
`verify/` rule owing on it, and shipping it in the same increment as the
clause would have meant deciding the representation before the rule it
enforces had been written down. It is what closes Annex C.12.

**An interprocedural summary** — the set of non-local owned pointers each
routine may release, closed over the call graph, which is the fixed-point
shape ADR-0283's protected-parameter rule already has. It is sound in one
thread and keeps `PasList` whole. What it lacks is an answer for a routine
imported from another program-component: §6.13.2's module-heading carries no
summary, so either the linkage grows one — ADR-0245's shape — or every
cross-module borrow is refused conservatively, which is a permission withheld
too widely and the thing `doc/sop.md` §7 says nothing here watches for.

**Refusing the borrow instead of the release.** Refusing `o^` as an actual
variable parameter closes every form of this at once and takes `Bump(o^)` with
it — the construct ADR-0201 found and the only way a program reaches what an
owned pointer owns, `PasList`'s recursive traversals included.
ADR-0317's rule refuses eight programs; this would refuse the type's whole
usable surface.
