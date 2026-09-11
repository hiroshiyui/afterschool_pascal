# ADR-0409: The trait object carries its answer

## Status

Accepted. Increment C2 of [ADR-0315](0315-methods-and-traits-without-inheritance.md),
completing [ADR-0408](0408-a-type-nothing-admits-is-not-refused.md), which
landed the *type* and accepted it nowhere. It supersedes that record's
three-increment staging: **there is no C3**, and why is below.

## Context

ADR-0408 shipped `dyn T` as a type the compiler knows completely and admits in
no position. What it argued for is the reason to finish it: this language has
§6.7.3.1's procedural *parameter* and no procedural *type*, so a vtable cannot
be built by hand, and the only heterogeneous collection expressible is a closed
variant record — which names every member type where the collection is
declared, so a library can never offer the facility to a program's own types.
That is ADR-0109's test failed: a program someone would write cannot be
written.

## Decision

**A trait object is a two-word heap variable — the implementation and the
storage — and an `owned` pointer to one is an ordinary one-word pointer.**

Everything else follows from that sentence and from one measurement.

### The representation, and the one that was rejected

Two shapes were on the table. ADR-0408's own working note assumed the first.

**A fat pointer**, where `owned ^D` is two words `{storage, implementation}` —
Rust's `Box<dyn Trait>`. Its cost is that `LlSize` of a *pointer* stops being a
constant, so every load, store, nil-test, comparison and parameter pass of an
owned pointer must ask whether its domain is a trait object. The note that
proposed it said the quiet part out loud: *every place that assumes an owned
pointer is one word has to be found, not assumed.* That is the class of change
this tree cannot make by construction and spends its gates refusing.

**A box**, where the two words are a heap variable the pointer points at. It
costs one allocation per trait object and one load per call, and it changes
**nothing** about how a pointer is represented. It is also what AP 6.7.11.2
says literally — *a value of a trait-object-type shall be two components* —
where under a fat pointer the value of `D` has no storage at all.

The box was chosen. What it cost in the compiler is the measure of the
argument: `IsMemory` gained one disjunct, **one cell moved in a 42 × 22
predicate table**, and no other predicate answer changed.

### The predicates, and refusal by construction working this time

`IsMemory` gains `IsDyn`; `IsStructured` stays false. **That is the file's own
shape** (ADR-0021), and it grants and refuses the right things with no list: a
value that lives in memory and may never be copied refuses assignment,
comparison, value parameters and function results, and admits a `var`
parameter — which is AP 6.7.11.1 b) for free.

What it does **not** refuse is a `dyn` variable, field or component, because a
`text` is all three and legal. ADR-0408's finding applies again and this time
it is written into the language: those are a positional rule, checked in one
place — every denoter that becomes storage passes through `ResolveType` — with
the two grants named. The domain of an owned pointer needs no grant at all:
§6.4.4 makes a domain a type-*identifier* looked up by name and never resolved
as a denoter, so the refusal cannot see it.

### Object safety, which the clause did not have and could not do without

A trait routine is reachable through a trait object when `Self` occurs exactly
once, as the type of a `var` or `protected var` **first** parameter.

**This was measured, not reasoned about.** With that spelling, `impl R for
Circle` and `impl R for integer` compile to `void @p2(ptr %link, ptr %a0)` and
`void @p4(ptr %link, ptr %a0)` — the same signature — so a table holds the
routine itself. With `p: Self` by value they are `ptr` and `i32`, a record
travelling by address and an integer not (ADR-0017), and every call through the
table would need an adapter emitted per (routine, implementation) pair.

`Self` elsewhere is refused for reasons that are not about the calling
convention: as a result type it is a value whose size the caller cannot know,
and in a second parameter it would need two trait objects to agree about a type
neither carries.

It is reported at `type D = dyn T;` — where the program asks for the facility —
and every heading in the way is named in one run, because a reader who fixed
one would otherwise be told about the next on the next run.

### The table

A `[2n+1 x ptr]` internal constant per **(trait, concrete type)** pair, from a
worklist drained after the last user function, exactly as `EmitOwnRels` drains
its own.

    slot 0        the release: `@ownrel` of the concrete domain
    1 + 2i        the code of trait routine i
    2 + 2i        its static link

**The order is the trait's headings and not the implementation's
declarations**, because that order is the only thing two concrete types reached
through one `dyn` have in common. `tests/dialect/dyn.pas` declares two of its
four implementations in a different order for no other reason than to be able
to tell the two apart — without that, the mutation that builds the table in
declaration order changes nothing.

**The link is in the table because a constant can hold it.** An implementation
belongs to the whole program or module and cannot be written inside a procedure
— the compiler already refused that — so its enclosing activation is a global.
This is ADR-0030's code-and-link pair, stored rather than passed.

### The coercion, and the hazard it was arranged around

`d := take(c)` is the one place a trait object comes into existence: the move is
the move the source spelled, and what the target gains beside the address is
the implementation.

The permission is granted **where the assignment is checked and not inside
`Assignable`**. That is ADR-0058's sentence — a permission granted in a shared
predicate leaks to every caller — which has cost this tree three defects and
the last of them a double free (ADR-0139, ADR-0143, ADR-0150). `Assignable` is
asked by the relational operators, so granting it there would make two trait
objects comparable, and what would be compared is two box addresses.

## The finding that removed an increment

**ADR-0408 staged the release slot as a third increment and that staging was
wrong.** Its reasoning was that C2 could refuse a concrete type that owns
something and add the slot later. It cannot: behind a `dyn` the emitter has no
type to resolve `@ownrelN` from, so without the slot there is nothing to call
for *any* concrete type, not merely for one that owns something — `owned ^D`
would leak every object it ever held, and the feature's whole point is a
collection that owns its elements.

The slot holds a function that already exists for every domain. It cost one
word, and the release of a type that owns something then works with nothing
written for it: `tests/dialect/dyn.pas` puts a stream inside a concrete type
and reads the file back, which is `take.pas`'s own way of observing a release
rather than assuming one.

**And it found a real defect while being written.** `dispose(d)` on an
`owned ^D` had its own arm, which disposed the box and left the concrete object
and everything it owned unreleased — `new=5 dispose=3` where the same program
without the `dispose` statement answered 5 and 5. A release written twice is
ADR-0388's *fact stated twice*, and the half nothing exercised was the wrong
one. The explicit dispose now calls the same `@ownrel` the end of a block does.

## What the specification had to be corrected about

Two entries in AP Annex E, both of them ADR-0408's clause text meeting the
thing being built (AP 5.5 c): the document is the current statement and a
record is the historical one).

- **E.13**: 6.7.11.2's NOTE put a trait object in ADR-0030's two-word company —
  the shapes that travel as separate arguments so nothing depends on how a
  structure is passed. Under the box they travel as one address, in both
  permitted positions.
- **E.14**: the clause required no object safety and could not have been
  implemented without it.

AP 6.7.11 also loses AP 5.6's `[not yet implemented]` marker, which it was the
first and only clause ever to carry. The triage rows move from
`not-implemented` to `testable` and `tests/spec/features/dialect_trait_objects.feature`
cites all six, which is the direction ADR-0195's gate refuses until the marker
is gone.

## What this does not do

**It does not make a trait object out of anything but an owned pointer.** There
is no borrowed trait object formed from a variable — no `dyn` made from `c^`
for a live `c` — because that value would refer to storage whose lifetime
nothing states, which is AP 6.7.11.1 NOTE 1 and ADR-0201's boundary unmoved.

**It does not compare, copy, or store one by value**, and those are refused by
`IsStructured` answering false rather than by any check written for them.

**It has no `verify/` rule and that is deliberate.** CLAUDE.md's bar is that a
rule must not restate the lowering: *the call goes to the routine the table
names* is the emitted code written twice, which is the nil-check's shape and
proves nothing. What holds this instead is the behavioural case under
`valgrind-corpus` and `sanitizers`, and the heap balance, which is the same
evidence AP 6.4.14's release has always had.

**It does not give a trait object to a task.** Both forms are refused already —
a task's formal is a value parameter, which 6.7.11.1 refuses, and a `var`
formal is refused by AP 6.7.8.1 — so `Transferable`'s answer for this kind is
unreachable and no rule was written for it.

**It does not add a second dispatch mechanism.** A bound (§6.7.3.10.5) still
chooses the implementation where the type is given and emits no table; the two
answer different questions and AP 6.7.11.3 NOTE 7 says which.
