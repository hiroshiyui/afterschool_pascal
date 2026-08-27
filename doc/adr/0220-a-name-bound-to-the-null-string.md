# 220. A name bound to the null-string

Date: 2026-08-27

## Status

Accepted.

## Context

```pascal
program p(output);
const e = '';
begin writeln('[', e, ']') end.
```

Compiled with `--std=extended` at `-O0`, this prints the whole of the runtime's
message table:

```
[HEAP_BALANCE^@ a file that is not open^@reading from^@runtime error: %s
^@integer overflow in pow^@seeking to^@ …
```

Both halves of the program are old and both were right. §6.1.9 spells a
character-string with *zero or more* string-elements, so `''` denotes the
null-string §6.4.3.3.1 names — that is the one thing the two standards'
lexis disagrees about, and the compiler has had the branch for it since the
Extended Pascal work. §6.3's string constant is ADR-0068, found by probing
after three documents had called ISO 7185 complete. Nothing had put them
together.

**The defect is a representation mismatch, and it is one node kind wide.** A
string value is a pointer and a length (ADR-0051), and `EmitString` has one arm
per shape of value. The arm for a literal reads:

> A literal is its own characters and its own length, whatever type it was
> given — and the null-string is *why* this comes first: `''` has the canonical
> type, which would otherwise be read as a length in front of characters that
> are not there.

The guard was written, the reason was written down, and the test is
`e^.kind = nkStr`. A *constant* reaches the code generator as a designator, so
the arm saw `''` and not `e`, and `e` fell through to the arm the comment
warns about — `IsStringRep`, which loads four bytes from in front of a global
that holds characters alone.

The null-string is the only string constant this can happen to, and that is
worth stating because it is what made the case rare: a constant of a nonzero
literal possesses a fixed-string-type, whose length §6.4.3.3.2 makes equal to
its capacity, so it needs no length word. §6.4.3.3.2 gives no fixed-string-type
a capacity of zero, so `''` alone gets the canonical type.

## Decision

`StringConstOf(e)` answers with the literal a name is bound to, or nil. It is
asked in `EmitString` immediately before the arm it corrects, and the value it
yields is emitted the way the literal arm emits one: the address of the
characters, and the literal's own length.

Both spellings of a constant-access are asked — a bare name, and §6.11.3's
qualified one — because an imported null-string is the same value arriving by
another route, and `EmitAddress` already answers for both.

**It stands before `IsStringRep` rather than beside the literal arm**, so its
reach is exactly the arm that was wrong. A constant of a nonzero literal goes
on falling to the last arm as it always has.

## Consequences

**The case needs `-O0`, and that is the finding rather than an inconvenience.**
`tests/extended/const_nullstring.opt` says so. At `-O2` the load is out of
bounds of a one-byte global, LLVM is entitled to reason about it, and it folds
to zero — the right answer by accident. The corpus compiles at `-O2`.

This is ADR-0102's shape exactly, and ADR-0102's own sentence covers it without
alteration: *a defect in storage is invisible there, LLVM being free to hoist an
alloca whose address does not escape*. Here it is free to fold a load rather
than hoist a store, and the conclusion is the same. Those two cases and this one
are the whole of what `foo.opt` is for.

**The case exercises every shape.** `EmitString` is one procedure and the wrong
arm was reachable from all of them, so `const_nullstring.pas` writes the value,
assigns it, takes its `length`, concatenates it on either side, compares it and
passes it to `index`. Six paths, one arm.

**Nothing about `''` as a literal changes**, and nothing about the dialect. This
is a conformance defect in `--std=extended`; ISO 7185's grammar has one string-
element before the repetition, so `''` is refused there and the mode cannot
reach this at all.

## How it was found

Writing `tests/dialect/substring_empty.pas` for ADR-0219, whose `const none =
g[1..0]` folds to a length-zero literal bound to a name and takes the same path.
`selfhost/irtest.sh` links at `-O0` where `tools/pascalcc` defaults to `-O2`,
so the case passed under `ctest` and failed under `irtest` — two harnesses
disagreeing about one program, which is the only reason anybody looked.

That is worth recording as a property of the harnesses rather than as luck.
`doc/sop.md` §7 already carries the row that the corpus is compiled at one
optimisation level; what it did not say is that **one oracle here already
compiles it at another**, and that this is the second defect found by the two
disagreeing. It is not a designed check — `irtest.sh` links at `-O0` because
nothing made it do otherwise — and it should not be relied on as one, since it
covers only the golden corpus and reports as "output differs" rather than as an
optimisation-level finding.

## Alternatives

**Give the null-string a length-prefixed global.** It would make the value's
representation match its type everywhere rather than at the one place that
reads it, which is the more principled repair. It is also a change to
`AddGlobal`, which every string literal in every module goes through, to serve
one value that has no characters — and the arm above it already establishes
that a literal answers with its own length whatever its type. This follows that
decision rather than reversing it.

**Give `''` a fixed-string-type of capacity 0.** §6.4.3.3.2 makes a
fixed-string-type's index-type a subrange with a smallest value of 1, so a
capacity of 0 is `1..0` — an empty subrange, which §6.4.2.4 refuses. There is
no such type to give it.

**Refuse a constant-definition naming the null-string.** §6.3 admits any string
constant and the value is a value of the language; refusing it would be a
deviation with nothing behind it but this defect.
