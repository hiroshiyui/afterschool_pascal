# ADR-0318: The borrow that may not release

## Status

Accepted.

## Context

ADR-0317 refused the two shapes in which one activation can release an owned
pointer while a borrow of what it owns is open. It landed with its own limit
written down: the refusal has no *workaround*. A program that wants to hand a
routine both an owner and a borrow of what it owns has to be restructured,
because there was nothing it could say to promise the routine would not release.

That limit met a second one, from the other end. `doc/roadmap.md`'s memory-safety
review counted every ordinary pointer type-definition outside the compiler and
found nine, not one of which could take the word `owned`. Five have a schema
domain, which AP 6.4.14.2 refuses. The other four — `JsonPtr`, `SMapPtr`,
`StrVecPtr`, `IVecPtr` — are refused for a different reason: every accessor in
`lib/` takes the handle by **value**, and AP 6.4.14.3 forbids that. The
conclusion recorded there was that the missing facility is a second borrow form,
"a lend that is not a variable parameter, Rust's `&T` where the `var` parameter
is its `&mut T`", and that until there was one, `owned ^T` would go on being
reachable only by code written for it from the start.

That conclusion was one step off, and the probe that found it is a single
program:

```
lend.pas:5:29: error: 'o' cannot be protected: own is not a protectable type
```

The lend already exists. §6.7.3.1's `protected` is exactly a variable parameter
that may be read and not written, and this compiler has had it since ADR-0046.
An owned pointer was excluded from it by one line of `Protectable`, which
implements §6.4.1 — and §6.4.1 states its own reason:

> a pointer *value* can be copied out and disposed of — so protecting the
> variable would protect nothing

**That reason is false for `owned ^T`, and for nothing else here.** AP 6.4.14.3
says the value cannot be copied; AP 6.4.14.6 makes `take` the one operation that
moves it, and requires a variable-access that is not threatened, which §6.5.1
already refuses for a protected one. The clause excludes this type by way of a
premise the dialect had already withdrawn.

A handle-type is the same argument already accepted. It is affine, uncopyable,
released by `release`, and it has been protectable all along — `take` of a
protected handle has been refused since ADR-0267, and CheckTake's comment says
so. It passes §6.4.1 only because `IsPointer` answers no about it. The exclusion
was by representation and not by the reason.

## Decision

**§6.4.1's exclusion of a pointer-type does not apply to an owned-pointer-type**
(AP 6.4.14.8). A formal parameter of an owned-pointer-type, or of a type
containing one, may be protected, and what that produces is a name for what a
variable owns that may be read through and through which nothing may be
released.

Two further rules make that true rather than approximately true.

**`dispose` threatens an owned pointer.** §6.9.4 does not list `dispose`, and
ADR-0317's own commentary gives the reason: for an ordinary pointer it reads the
variable and stores nothing through it. For an owned pointer it is AP 6.4.14.3's
release point, and a release empties the variable, which is §6.9.4 a)'s case —
CheckTake's sentence one procedure over. The other three release points were
threats already: `new` by §6.9.4 e), an assignment by a), and the move by a).

**A threat to an owned-typed designator is a threat to the variable that owns
it**, where every dereference between the two is of an owned-pointer-type; and a
with-binding reached through such a dereference stands for the designator that
reached it. This is the paragraph that makes the clause a statement about
everything a variable owns rather than about its first node, and it was not in
the first draft. A probe found the hole:

```pascal
procedure P(protected var o: Own; var n: Node);
begin dispose(o^.next); n.v := 999 end;
...
P(head, head^.next^)          { printed 999, exited 0 }
```

Shallow protection would have refused `dispose(o)` and admitted that — a borrow
able to release everything it was lent except the node it was handed. Four
spellings reach it (`dispose(o^.next)`, `o^.next := take(s)`, `take(o^.next)`,
and passing `o^.next` to an unprotected variable parameter), and two more inside
a `with`; all six root at a dereference rather than at a variable, so all six
answered nil to the question §6.5.1 asks. One rule in `ThreatSym` closes all
six, because every one of them funnels through `Threatened`.

**ADR-0317's rule a) is discharged where the owner's formal is protected.** That
is not an exception to it. AP 6.4.14.8 refuses every release point through a
protected owned pointer and §6.9.4 b) refuses handing it to a parameter that is
not itself protected, so the release ADR-0317 predicts cannot occur in the call
or in anything the call reaches. It is the workaround that record shipped
without.

## Consequences

**The library is the client, and it is now written.** Four of `PasList`'s ten
exported routines — `ListPeek`, `ListEmpty`, `ListLen`, `ListGet` — take
`protected var l: List`. Before this the module had one way to accept a chain
and it granted every caller the right to destroy it.

**The fourth warning found four on its first run, and it was not aimed at
them.** ADR-0272's bar for a new warning is that it finds something; this is the
same bar met by an *existing* warning when a type became protectable. `Len` and
`Sum` in `tests/dialect/owned.pas`, `Show` and `Len` in `take.pas`, and `Show`
in `examples/owned_list.pas` were all read-only traversals written before there
was a word for them. Taking the advice in `PasList` then exposed a caller —
`ShowAll` in `tests/dialect/lib_list.pas` — which is ADR-0283's fixed point
behaving as it says it does, and it closed at depth two.

**A comment that argued for keeping a check was paid.** `tests/dialect/take_errors.pas`
carried the sentence that an owned pointer is not a protectable type, so
`CheckTake`'s `Threatened` arm is reachable only in a program already refused for
another reason — and that the guard stays anyway, "because dropping a check
because today's type rules make it unreachable is how a permission comes to leak
later (ADR-0146)". It is now the ordinary way this is reported. The argument was
written before there was anything to keep the check for.

**Costs.** A protected owned pointer refuses list surgery through the borrow,
which is the point but is worth stating: a routine that restructures a chain
takes an unprotected `var`, and there is no third form between them. And the
word is not free to add later — an exported heading is an interface, so
protecting a library routine's parameter is a change every importer sees, though
in the permissive direction.

**Not a lifetime.** What a protected borrow says is that this activation will
not release what it was lent. What says the borrow cannot outlive the lending is
still ADR-0201's argument, that no value naming a variable parameter can be
formed. The two are separate and this record adds nothing to the second.

**`predicate-kinds` cannot see this change**, owned-ness being a flag on the
pointer kind rather than a kind of its own, so `--dump-predicates` asks
`Protectable` about a fresh pointer type whose `owns` is false and gets the
answer it always got. That is ADR-0194's known shape and not a new gap; the
cases are what pin it.

## What this does not do

**It does not close Annex C.12.** ADR-0317's undetected form is a release
reached through a further activation, and it is undetected for an *unprotected*
borrow exactly as it was. What this record adds is that a program which wants
the guarantee can now ask for it in one word, where before there was nothing to
say. The dynamic borrow flag is still the only thing that would make the
guarantee unconditional, and ADR-0317 has the design.

**It does not make `owned ^T` reachable from `lib/`'s existing containers.**
`JsonPtr`, `SMapPtr`, `StrVecPtr` and `IVecPtr` are value parameters and a
protected parameter is still a *variable* parameter, so adopting the safe
pointer there is still a rewrite of every accessor. What changed is that the
rewrite now has a destination: `protected var` rather than `var`, which is the
same permission the value parameter granted. The five schema-domain ones are
unaffected and remain AP 6.4.14.2's.

**It does not give a record a `Drop`**, and it does not touch the release walk's
recursion depth. Those are the other two rows of that roadmap section.

## Alternatives rejected

**Leave `Protectable` alone and add a new spelling** — a `lend` or `borrow`
parameter form. Rejected on the dialect's own rule (ADR-0140): the first question
is whether the feature needs a spelling at all, and three times now none has.
This is the fourth. §6.7.3.1's word is in the right position, means the right
thing, and is already checked; a second spelling would be a synonym for it with
a different name.

**Protect the identified variable as well** — make a protected owned pointer
refuse `o^.v := 1` too, which is what a constant-access does (§6.9.3.10).
Rejected because it answers a different question. The clause is about ownership,
and a store into a field releases nothing; a routine that must not modify what it
is shown has `protected` on a record parameter already, and conflating the two
would make the word mean "read-only" for one type and "not-releasable" for the
rest.

**Refuse `take(o^.next)` and the rest by writing a rule at each release point.**
This was the first implementation and it took four sites, then six when the
`with` forms were found, and it would have taken a seventh the next time a
release point was added. The rule in `ThreatSym` is one place because §6.9.4 is
one list, and a release point added later inherits it.

**Restrict the discharge of ADR-0317 to the direct case** — admit
`P(protected o, o^)` but not `P(protected o, o^.next^)`. Rejected as
unnecessary once the deep rule was in: with it, a protected `o` cannot release
anything reachable through owned dereferences, which is precisely the region a
borrow reached that way can name.
