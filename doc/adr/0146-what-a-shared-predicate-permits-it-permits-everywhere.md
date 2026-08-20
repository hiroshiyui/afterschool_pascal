# ADR-0146: What a shared predicate permits, it permits everywhere

Date: 2026-08-21

## Status

Accepted. Closes the `doc/sop.md` §7 row opened by ADR-0139 and widened by
ADR-0143. Does not supersede either; both remain the record of what the
permission cost.

## Context

ADR-0058 wrote the sentence:

> A permission granted in a shared predicate leaks to every caller.

It has cost twice over one permission, and the second time the sentence was
already in `CLAUDE.md`.

AP §6.4.5 makes two slices compatible when their component types are the same,
so that one `array of T` parameter accepts either. `Assignable` is where
compatibility is decided, and sixteen routines ask it at 33 call sites.

- **ADR-0139.** The relational operators ask it, so `a[1..2] = a[3..4]` was
  accepted, reached CodeGen and emitted invalid IR. Fixed for the relational
  operators, and stopped there.
- **ADR-0143.** Assignment asks it too. `p := r` between two slice formals fell
  through to `tb^.kind = fb^.kind`, which is true for any two slices whatever
  their component types, and copied sixteen bytes of one array's contents over
  another's — at `-O0` and `-O2` alike, **exit 0**.

Both fixes were followed by a probe. ADR-0143's covered eighteen positions and
every one refused a slice — but that is a probe over the positions someone
thought of, four commits after the first probe over the positions someone
thought of. §7 recorded the shape:

> What would close it is mechanical: for each predicate a new type is taught to
> satisfy, enumerate its callers and require an answer per caller. Nothing does
> that, and the next extension of `Assignable` has nothing looking over its
> shoulder.

## Decision

**Sweep the positions the source contains, not the positions someone
remembers.**

`tests/checks/predicate_callers.py` derives both halves of the question and
asks the built compiler for the answer.

### The types come from the predicate's own refusal arms

`Assignable` opens with a run of arms that answer `false` for a type whatever
it is compared with:

```pascal
else if IsFile(toT) or IsFile(fromT) then
  Assignable := false
```

Each names a type that is **not a value**: ISO 7185 §6.8.2.2 gives a file no
assignment and §6.7.2.5 no relational operators, a procedural parameter is not
a value either, and AP §6.4.9 says the same of a slice. Those three arms are
read from the source. A fourth type added to that run with no wrapper here
fails the gate — which is the forward-looking half, and the one the next
extension of `Assignable` will meet.

### The positions come from the call sites

Every routine that calls `Assignable` is enumerated, **with its call count**,
and mapped to at least one position in the grammar that reaches it: an
assignment, a relational operand, an actual parameter, a set member, a set
value, a `for` statement's bounds and its `for..in` control variable, an array
index, a structured value's field, an array value's selector, a variant value's
tag, a `write` and a `read` argument to a non-text file, a `new` tuple, a
schema discriminant, an initial-state specifier, a `seek` position, an `unpack`
index, a case selector. Twenty-one positions over sixteen routines, and a
routine whose call count moves is a failure asking for a position rather than a
silent addition.

### The answer is a verdict, not a message

For each (position, type) pair the gate builds a whole program — one preamble,
one wrapper per type putting `u` and `v` in scope, one snippet per position —
and requires the compiler to **refuse** it. 63 pairs, and every one refuses.

Not "refuses with these words". The messages are `diagnostic-coverage`'s
business and the `.err` goldens'; a golden here would agree with whoever wrote
it, and what is being asserted is a safety property rather than a spelling. An
acceptance is an entry in `predicate_callers.txt` with an argument, and an
entry that starts being refused fails — `verify/`'s `KNOWN_GAP` rule again.

## Consequences

Two mutations, and the second is the one that matters.

**Remove `Assignable`'s slice arm** — ADR-0143's defect exactly. The gate fails
on the *source* half: the arm is gone and the wrapper for `slice` has nothing
to answer for.

**Move the arm one line down**, below `else if toT = fromT`, so two formals of
one slice type are assignable again. The source half stays satisfied — the arm
is still there, still spelled the same — and:

> all 625 tests pass, `tests/dialect/slice_assign.pas` included, and
> `predicate-callers` is the only thing that fails: *a slice is accepted in
> assignment*.

`slice_assign.pas` survives because its slices differ in component type, so the
arm still fires for them. The out-of-bounds write comes back for two slices of
the *same* type, which no case in the corpus writes.

### What it does not check

It does not judge whether the refusal happens **at** the call site. A guard
placed ahead of the predicate refuses the same program and passes this gate,
which is ADR-0143's second defect and stays in `doc/sop.md` §7.

Nor is every probe guaranteed to *reach* the call site it is named for. Some
are refused by a rule that fires first — a slice cannot be a `for` control
variable, because §6.8.3.9 wants one declared in the block and a slice is
necessarily a parameter; a discriminant actual must be ordinal before
`ProduceFromSchema` compares its type. Those programs are refused, which is the
whole of what is claimed. The claim is **"no program in this table is
accepted"**, and it is a safety property; it is not "every call site was
exercised", and the docstring says so rather than letting a reader assume the
stronger thing.

### Rejected: a catalogue of answers per caller

The first design had a human write, per (caller, type), what that caller does
and why. It was rejected for the reason the two defects share: an answer
written down is an answer that agrees with whoever wrote it. Compiling a
program and asking the compiler is the same move ADR-0144 made for
`foreign-reserved`, which had kept both halves of its own comparison and could
not fail.

### Rejected: extending it to every type `Assignable` decides about

An optional, a restricted type and a variable-string all reach `Assignable`
too, and all three are **values**. The leak this gate is about is a type that
is *not* a value being let into a value position, which is what the
unconditional-false arms mark. Widening the sweep to types that are supposed to
be assignable would turn a property into a table of expected messages, and the
table is what was rejected above.
