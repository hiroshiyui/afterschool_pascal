# ADR-0338: A bound belongs where the type is written down

Date: 2026-09-05

## Status

Accepted as a **design**, and nothing is implemented. It corrects increment B
of [ADR-0315](0315-methods-and-traits-without-inheritance.md), whose bound is
put where this project's own generic machinery cannot reach the case the
increment exists to serve. ADR-0315 stays `Proposed` for increments A and C and
gains a forward pointer here for B.

Read it as ADR-0315 was written to be read: a shape argued before any code
exists, with its costs measured. What is new is that the argument is now made
against **probes** rather than against a reading, and three of them contradict
the record they were run to confirm.

## Context

**ADR-0315's increment B does not reach its own payoff, and the payoff is the
whole of its justification.** The record's measurement is 14 routine-valued
parameters and 30 call sites threading `StrHash, StrEq` through
`lib/dialect/pascontainer.pas` and `lib/passort.pas`, and its answer is a bound
in the type-parameter slot:

    procedure MapPut(K: Hash + Eq; V: type; var m: Map(K, V); key: K; val: V);

**The container's parameter is a pointer, and a pointer determines nothing.**
`Determine` (`selfhost/apfront.pas:22253`) has exactly three arms — `nkNamed`
for a bare `T`, `nkSchema` for `S(…, T, …)` read against the actual's tuple,
and `nkArray` for `array of T`. There is no pointer arm and there cannot be
one: §6.7.3.1's parameter-form is a type-name, a schema-name or a type-inquiry,
so `var m: ^Map(K, V)` never reaches Sema as a denoter to read a tuple out of.
PasContainer's routines must take the pointer, because `MapPut` grows the map
with `new(m, bigger)`.

**Determined from the key instead, the bound binds the wrong thing.** With `K`
determined by the actual key, a string literal binds a type per literal
*length*: the probe reports *`packed array [1..2] of char` … argument 2 of this
call is what determined it*. That reproduces the failure `pascontainer.pas:213`
already records, and a trait does not fix it — `impl Hash for MapKey` is never
found for `MapPut(m, 'k3', 1)`, the type in hand not being `MapKey`.

**The orphan rule contradicts itself, and the commonest key falls through it.**
ADR-0315 §5 permits an impl in the component that declared the *trait*; its
*What this does not do* forbids `impl integer` outright. Both cannot stand.
Taking §5, PasContainer declares `Hash` and may therefore implement it for
`integer`. But `MapKey = string(20)` is declared by **nobody** — a type-name
denotes an existing type object (§6.4.1), so no component owns `string(20)`,
and `string(200)` is a third object again. Strings are what a map is keyed by
most of the time.

**And the record's spelling of the bound is ambiguous.** ADR-0315 writes
`procedure Sort(T: Ord; var v: Vec(T))`. The type-parameter slot's real grammar
puts the category *before* the word-symbol — `function Sum(Elem: numeric type;
a, b: Elem): Elem` — and the parser commits on exactly that juxtaposition
(`apfront.pas:4405`, `Check(tkIdent) and (PeekKind(1) = tkType)`). `T: Ord` is
byte-identical to an ordinary value parameter named `T` of type `Ord` and would
parse as one.

## Decision

**A bound is written where the type is written down, and that is the schema's
discriminant.**

    Map(K: Hash + Eq; V: type; cap: integer) = record … end;

    procedure MapPut(Ptr: type; var m: Ptr;
                     key: type of m^.slots[1].key;
                     val: type of m^.slots[1].val);

The client writes `type IntMap = ^Map(MapKey, integer)` and the bound is
checked **there**, once, against a type the client named. All 30 call sites are
unchanged and the two threaded parameters are gone. Nothing in `Determine`
changes and ADR-0304's inference is untouched, because nothing is being
inferred: the client wrote the type.

**The bound is also admitted on a routine's type parameter, spelled
`T: Ord type`.** That is where `lib/passort.pas` is served, and it is nearly
free once the machinery exists: the parser already commits on `ident` followed
by `type` and merely refuses the name, so the change is to let `CatOfName`'s
failure fall through to a trait lookup instead of bailing.

**`impl` names a type or a schema.** `impl Hash for string` is what serves
every `string(n)`, and without it increment B misses its commonest case. The
orphan rule is restated in the only form that is consistent: **an impl shall
stand in the component that declared the trait, or in the one that declared the
type.** The blanket refusal of `impl integer` is withdrawn — it contradicted
§5 and would have left every required type outside every trait.

**Impl lookup follows `Base()`**, which is ADR-0018's rule said once more, so
`impl Ord for integer` covers every subrange of integer and `impl Ord for digit`
is an error at the heading.

**A trait is a symbol kind and not a type kind.** `skTrait`, with `skSchema` as
the exact precedent — a name that is not a type until applied, its payload on
the symbol record. Measured: `skTrait` moves 11 rows of
`tests/checks/partial_cases.txt`; a `tyTrait` moves 83 rows across that
catalogue and `predicate_kinds.txt`, forces a `--like` re-read of every type
predicate, and puts a zero-size type object in front of `EmitAssign` and
`IsMemory` — which is the pair of defects `doc/sop.md` §4a records from the last
two times a type kind was added. The bound rides on a new `grBound: symPtr`
field of `nkGroup` rather than a fifth `typeCat`, because `aptypes.pas` imports
nothing and so cannot look up an impl table.

## Consequences

**Three notes of AP 6.7.3.10.5 are narrowed, and one of them argues against
this feature by name.** NOTE 11 says *the set is closed … admitting an arbitrary
predicate would be admitting a second type system*. That claim is kept for
**categories** and is why a trait bound is a separate production rather than a
fifth category: a category names a group of operators the specification already
gives, and a trait names routines a *program* gives. The two are different in
kind and collapsing them really would be the conflation NOTE 11 refuses.

NOTE 12 says a formal-discriminant takes no category, *because there is no
activation for a refusal to be attributed to*. For a trait bound that reason
does not hold — the refusal is attributed to the type-denoter the client wrote —
so the note is narrowed to the categories whose diagnostic needs an activation.

NOTE 10 says the four spellings are recognised in that position and nowhere
else. A trait name joins them there, and the juxtaposition argument that makes
the position free is unchanged.

**CodeGen is untouched and no rule joins `verify/`.** `InstantiateGeneric`
already builds an ordinary routine symbol and hands it to `AppendInstDecl`, so
the emitted call is the direct call already emitted. The commit that implements
this carries `Model-unchanged:`. There is no new global, so `foreign-reserved`
is unmoved, and nothing new is emitted, so **the seed is not refreshed**.

**What the implementation will cost**, measured against `ae2e06c`, the `task`
increment: a new `nodeKind` moves 42 rows of `partial_cases.txt` and needs an
arm in every exhaustive dispatch; `skTrait` moves 11; roughly 12 to 18 new
diagnostics, each needing a golden or `diagnostic-coverage` fails; both coverage
ratchets move; and every declaration-part loop must learn to *stop* at the new
two-token pair, which is the half of the `task` change easiest to miss.

**No clause number is spelled here**, for ADR-0315's own reason:
`clause-citations` cannot tell a proposal from a claim, and a number written
before its clause exists is an entry in `nonexistent_clauses.txt` that somebody
must remember to remove. The trait-declaration follows the task-declarations
clause; the bound amends the category clause in place.

## What this does not do

**It does not build anything.** The three findings above were each a
contradiction of a record written without probes, and this one is written with
them; it should be read before it is implemented, which is why it lands alone.

**It does not decide increment A.** A is not a prerequisite for B — established
2026-09-05 against ADR-0315's Staging table, which asserts the dependency in one
sentence with no argument. `T: ordered type` compiles today, and a trait bound
is checked where a category is checked. A's own justification is 118 call-site
spellings that block no program, and it is judged separately.

**It does not admit multiple bounds.** `K: Hash + Eq` is written above because
it is what the container needs to say, and it is the one part of this design
that is not yet argued: it is a parser change, and whether two traits or one
combined trait is the better answer is left to the implementing record.

**It does not give a trait an associated type or constant**, does not admit
`dyn`, and adds no operator overloading — all three are ADR-0315's exclusions
and none is disturbed.

## Alternatives rejected

**The bound on the routine's type parameter alone**, which is ADR-0315's
design. Rejected because it cannot reach PasContainer, where the 30 call sites
are: a pointer parameter determines nothing, and determining from the key binds
a literal's own length-type. It is *kept as well as* the schema form, because it
is what serves `lib/passort.pas` and is nearly free.

**Making a trait a fifth `typeCat`.** Rejected on the measurement above and on
NOTE 11's argument, which is right: a category is a name for operators the
specification gives.

**Keeping `impl` restricted to a type-identifier**, as ADR-0315 has it.
Rejected because `string(n)` is declared by no component, so the commonest key
in the library could satisfy no trait.

**Building B and discovering this**, which is what would have happened. The
probes cost an afternoon; the design they refuted would have been found wrong
after the diagnostics, the goldens and the clause were written against it.
