# 254. A generic activation need not write its types

Date: 2026-08-30

## Status

Accepted, 2026-08-30. *The degradation recorded under Consequences — a generic
whose parameter-form names a schema the caller cannot see infers nothing — was
closed by [ADR-0297](0297-the-library-uses-the-feature-it-asked-for.md), which
resolves the schema's name in the generic's own region; and it had never been
graceful, the next actual determining the type instead. The all-or-nothing
rule this record wrote was widened by
[ADR-0304](0304-a-prefix-of-the-type-arguments.md): an activation may write a
prefix of its type arguments, so the two forms below are the ends of a range.*

It answers the deferral
[ADR-0211](0211-a-routine-may-be-generic-over-a-type.md) recorded and
`doc/roadmap.md` has carried since — *generics have no inference*, with the
question that had to be settled first written into the row: **what happens
when two arguments imply different types**.

## Context

AP 6.7.3.10 gave a routine a type parameter, and every activation has had to
write it out: `Swap(integer, i, j)`, never `Swap(i, j)`. That was the
deliberate first increment, and the argument for stopping there was that
inference is a separate feature with an open question.

**What made it a demand rather than a wish** was reading the finished language
server as a reader would (`doc/roadmap.md`'s usability findings). `lib/`
carries one `…Or(r, whenBad)` accessor per result type — five of them are
genuinely `T ! ErrorCode -> T` — and the first reading of that was that a
routine generic over a fallible type *could not be written*. It can:
`tests/dialect/generic_fallible.pas` is the correction, and a schema is the
answer because §6.4.7 interns a production per tuple, so `Fallible(integer)`
written twice is one type.

That left the real cause, and it is this clause. `ValueOr(integer, a, 0)` is
wordier than `IntOr(a, 0)` at every one of about thirty call sites, so
collapsing five helpers into one generic would have made the callers worse to
make the library smaller. **The type is written at a call that could not have
meant anything else**, which is the whole of what the library was avoiding.

## Decision

An activation of a generic routine may omit its type arguments, and the types
are then determined from the other actual-parameters. AP 6.7.3.10.4 is the
clause; `tests/dialect/generic_infer.pas` and
`tests/spec/features/dialect_typeparam.feature` are what hold it.

**No spelling.** This is the third feature here to need none, after ADR-0184's
record at an `external` heading and ADR-0240's `writable`. Omission is not a
token in any position; it is a rule about what an existing position admits,
and a marker would have been a second place for the truth to live. CLAUDE.md's
first question — *does the feature need a spelling at all?* — answers itself
here.

**The count, and one tie-break.** A type parameter occupies a position in the
generic's formal-parameter-list and none in the produced routine's, so an
activation writing its types has `nFormals` actuals and an inferred one has
`nFormals - nTypes`; there is at least one type parameter, so the two numbers
are never the same and arity alone is never ambiguous.

The count alone is not enough, and **the case that says so was already in the
corpus**. `generic_errors.pas:27` is `P(integer)` against
`procedure P(T: type; var a: T)` — exactly `nFormals - nTypes` actuals — and
it is a call that forgot its second argument, not a call inferring its first.
The golden has said `'p' takes 1 argument(s), but 0 were given` since ADR-0211.
So the rule carries a further condition, and it is the one question that
cannot be wrong: **an actual that denotes a type cannot denote a value.** If
the actual standing where the first type parameter would stand names a type,
the activation is the written one, short an argument, and says what it always
said. `TypeArgument` is that question and has no side effects.

Dropping the tie-break fails `generic_errors` and nothing else, which is the
measurement rather than the argument.

**The first determining position binds, and there is no conflict to report.**
This is the answer to the question the roadmap had been carrying, and the
answer is that the question dissolves. A type parameter is determined by the
first actual-parameter that determines it and is never redetermined; every
later actual is then an ordinary actual of a formal that now has a type, and
§6.4.6 judges it exactly as it judges every other actual.

The case that decides this is in the corpus too. `ValueOr(st, 'none')` against
`function ValueOr(T: type; res: Fallible(T); whenBad: T): T` has `st` of type
`Fallible(string(8))` and `'none'` of a four-character string type. Under any
rule that let both positions speak, that is a conflict; under this one it is
an ordinary assignment-compatible actual, which is what it is. And a genuine
mismatch — `Swap(i, c)` — is refused by the message the language already had,
`var parameter 'b' is integer, but the argument is char`. **No new diagnostic
was needed for the conflict case, and that is the strongest evidence the rule
is the right one.**

One message is new, for a type parameter no actual determines:

    nothing in this call says what 't' of 'pick' is: write the type
    arguments, or pass an argument whose type determines it

`VecGet` and `MapGet` in `lib/dialect/pascontainer.pas` are the standing case
— their element type stands only in the result, and §6.7.1 makes a result type
a type-name and not an actual — which is why those two keep their type
arguments and why the roadmap's container row said they would.

**Three determining shapes and no more**, bounded by §6.7.3.1 rather than by a
convention: a type-name, a schema production read against the tuple, and
AP 6.7.3.9's slice read through its component. There is no pointer shape
because a parameter-form is a type-name, a schema-name or a type-inquiry, so
`var p: ^T` is a syntax error the parser refuses before inference could see
it — which was checked by writing the program rather than assumed.

**The tuple carries its types.** `numRec` gains a `ty: typePtr` beside
`value_`, filled at every site that appends a `typeId`. Without it a
production's arguments could not be read back: `ProduceFromSchema` says so
where it re-derives a type from the argument node instead — *"the tuple holds
an id and there is no registry to turn one back into a type"*. This does not
make `typeId` an identity, which ADR-0209 warns against: nothing compares
these types by id, `SameTuple` goes on comparing `value_`, and a reader gets a
pointer back and compares pointers, which is ADR-0017.

**An actual read by inference is not read again.** `CheckExpr` is not
idempotent — it writes a `use` line for every applied occurrence in it
(ADR-0246), so an editor would be told twice where a name is declared, and it
claims a frame slot for a nested call's result, so the frame would grow a slot
nothing reads. A node carries `nChecked`, set only by inference and read only
by `CheckArguments`, and only the actuals at determining positions are read at
all.

## Consequences

**Two latent defects went with it**, and both were in the walk this clause had
to rewrite. `InstantiateGeneric` matched actuals against parameter *groups*
rather than against formals, which is invisible while every generic in the
tree writes its type parameters first and one to a group:

- `procedure P(a, b: integer; T: type; x: T)` matched the type group against
  the second `integer` and reported *this argument must name a type* about an
  argument nobody meant as one. The call could not be written at all.
- `procedure P(T, U: type; …)` consumed one actual for the two names and gave
  both `T`'s type, so `U` was `T`. `lib_container.pas` catches the mutation
  that restores this, because `VecGet(Ptr: type; Elem: type; …)` would then
  have one type for both.

Both are pinned by `tests/dialect/generic_infer.pas`'s `Third` and `Show`, and
neither is a consequence of inference — inference is what made someone count
the same thing the language counts.

**Phase 2 reads the tuple and no longer reads the argument nodes.** ADR-0212's
husk (`a^.ntype := given`, so the type resolved in the caller's region
survives the scope switch) is gone, because an inferred activation has no
argument node in a type position and the tuple holds exactly the same
pointers. One carrier instead of two.

**A generic whose parameter-form names a schema the caller cannot see infers
nothing**, and the types must be written out. The schema is found by looking
its name up *at the call*, which is deliberate: comparing spellings instead
would let a same-named schema of the caller's own bind a type the callee never
meant. It is a graceful degradation rather than a wrong answer, and it is a
`doc/sop.md` §7 row rather than a fixed thing, because fixing it means
carrying the callee's region into the unifier.

**What this does not give.** Constraints — a body that adds its `T` values is
still refused at the instantiation for a type that cannot be added, and a
generic map keyed by anything but a string still waits on them. Inference and
constraints were one row in the roadmap and are now one row less.

**And the diagnostic row in `doc/sop.md` §7 gets worse before it gets
better.** *A generic's diagnostic names the generic and not the call that
asked for it* was already true; an inferred activation makes the call choose a
type nobody wrote, so a reader has one more step to work backwards through.
The row is restated rather than closed.
