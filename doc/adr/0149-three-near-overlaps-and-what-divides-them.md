# ADR-0149: Three near-overlaps, and the ownership question that divides them

Date: 2026-08-21

## Status

Accepted. Answers what is left of `doc/roadmap.md` §5, whose sharpest instance
ADR-0141 answered. Changes no behaviour: it is a survey and a rule, and the one
thing it found that could be legislated is argued below and deliberately is
not.

## Context

`doc/roadmap.md` §5 says the dialect was **pulled, not designed**: every feature
was demanded by the foreign interface or by the library built on it, and nobody
has stepped back to ask whether the pieces form a language rather than a set of
local optima. ADR-0141 took the sharpest instance — the dialect had four ways
of saying *this may have failed*, not the two the entry claimed — and left the
rest:

> optionals against pointers, slices against strings and `int64` against
> `integer` are three more near-overlaps that have not been examined this way.

Each pair is two type-shapes that answer almost the same question. Each was
added for a reason that had nothing to do with the other member, so nothing
guaranteed the two would divide cleanly, and nothing had asked.

## Decision

**Each pair divides on ownership, and it divides the same way three times.**

| Pair | The owned shape | The other shape | What the other shape says |
| --- | --- | --- | --- |
| absence | `^T` | `?T` | there may be no value |
| sequences | `string(n)`, `packed array [1..n] of char` | `array of T` | the sequence belongs to the caller |
| numbers | `integer` | `int64` | the number came from outside |

In every pair the second member exists because something **outside the block**
had to be described: a foreign function may answer null (ADR-0123), a buffer
belongs to whoever lent it (ADR-0125), the kernel says `ssize_t` (ADR-0128).
The first member is what a program owns and computes with.

From which the rule for the author of a module:

**A boundary shape may be a parameter. It may not be a result.**

A parameter is the caller's ownership written down, and passing a slice is the
whole point of the form. A *result* has no owner, so a boundary shape there is
the boundary leaking into the interface — and the fix is always to convert at
the first opportunity: `o^` after a test, a whole-array assignment into a
string, `trunc` with an argument for why it cannot reject.

**The language already enforces two-thirds of it.** AP §6.7.3.9.2 makes a slice
a formal parameter's type and nothing else, so a slice result is a syntax
error; AP §6.4.2.6.5 makes no `int64` expression a constant, so it cannot reach
a constant-definition, a case-constant, an index or a bound. Only the optional
can be written as a result, and that is not an oversight — see below.

### The census

All 35 exported routines of `lib/dialect/`, which is the whole of the surface
either shape has:

- **Pointers: zero.** Not a pointer type, not a `new`, not a `dispose` in seven
  modules. Every `^` in the library — three of them — is an
  optional-value-access after a `= nil` test.
- **Optionals: three, one exported.** `Lookup: OptEnvText`; `OptPathName` and
  `OptSysText` are internal, each the shape a foreign `char *` arrives in and
  stops being a pointer at the call site.
- **Slices: three routines, all parameters, all bytes.** `ReadInto`,
  `WriteFrom`, `WriteAll` take `var buf: array of char`. No exported routine
  takes text that way: `WriteText` takes `IOLine` — a `string` — and copies it
  into a buffer of the module's own, because a string is not an array of char.
- **`int64`: zero exported routines mention it.** It appears on three `external`
  headings — `read`, `write`, `readlink` — and in the private `Counted`, which
  narrows with `trunc` and argues that the narrowing cannot fail because what
  `read` answers is bounded by the length it was given.

So the library was already written to the rule, three times, by three people's
worth of separate decisions. That is the evidence the rule is descriptive
rather than invented for this record.

### Pair 1: an optional is not a nullable pointer

They overlap in two spellings and in nothing else: both write absence `nil`,
and both write access `^`. What they answer is different — **a pointer says
where a value is, an optional says whether there is one** — and the two
questions come apart exactly where a program needs identity or lifetime, which
is what a pointer has and an optional has not.

`?T` contains its component, so it needs no `new`, has no `dispose`, cannot be
recursive (AP §6.4.11.1's NOTE: a type that were its own optional could have no
size) and takes a whole type-denoter rather than §6.4.4's type-identifier. A
pointer is the reverse of each. Nothing in the library needs identity or
lifetime — every value it hands back is a copy — which is why it holds no
pointer at all.

**The optional is also the only one of the three that is a reporting shape.**
ADR-0141 classifies it as the *absence is not a failure* arm, so it legitimately
appears as a result and the rule above admits it: what `Lookup` returns is a
`?string`, a value, not a foreign pointer wearing a flag.

### Pair 2: a slice is a view; a string is a value

Both are an address and a count, both are indexed from 1 (AP §6.7.3.9.4), and
both answer `length`. They divide on who owns the storage, and the division is
enforced at the actual: a `string(n)` is **refused** as a slice actual.

That refusal is load-bearing rather than a limitation. A variable-string has a
*current* length distinct from its capacity, and a slice carries one count —
so a slice of a variable-string would have to choose, and `length` would mean
the current length to the caller and the capacity to the callee, or the callee
could not write past the current length. Refusing it is what keeps `length`
meaning one thing on both sides.

**One type is both, and it is the bridge the library uses.** A `packed array
[1..n] of char` is §6.4.3.2's fixed-string-type *and* binds to an `array of
char` formal — so `PathBuffer` is lent to `getcwd` as bytes and then becomes a
`PathName` in one assignment rather than 4096 concatenations. `pasfs.pas` says
so at the declaration; this record is where the general fact goes.

The bridge is one-directional and the asymmetry is worth knowing:
`a[i..j]` on that same packed array is §6.5.6's **substring**, not a slice, so
the whole array crosses and a part of it does not. On an unpacked `array [1..n]
of char` the same designator is a slice. One spelling, two meanings, and only
the base's type — packing included — tells them apart, which is the fact
ADR-0125 got for free from §6.5.6 having already paid for the grammar.

### Pair 3: `int64` is a boundary type and cannot spread

`integer` is ordinal; `int64` is numeric and deliberately not (AP §6.4.2.6.2).
That single decision is what keeps the pair from overlapping anywhere it would
matter: an `int64` cannot be a case-constant, an array index, a subrange bound,
a set's base, a `for` control-variable, or an operand of `succ`, `pred`, `ord`,
`odd`, `chr` or `in` — each refused by the rule that was already there, none by
a rule written for `int64`.

Widening `integer` → `int64` → `real` is implicit and exact; the one narrowing
is written, and it is `trunc` (AP §6.4.2.6.4), whose §6.7.6.3 error condition
does the checking. So a value that came from outside cannot reach an owned
position without the program saying where.

Probed rather than read: `i := n` for `n: int64` is refused, `i := trunc(n)` is
accepted, `const big = 9223372036854775806` is refused naming the remedy,
`1..maxint64` is refused as a subrange, and `for n := 1 to 3` is refused for an
`int64` control-variable.

## Consequences

`lib/dialect/README.md` gains the rule, beside ADR-0141's. It is the file the
author of the next module reads, and both rules are about the same thing from
two directions: ADR-0141 says what shape a routine's *answer* takes, and this
says which shapes may not be that answer at all.

`doc/roadmap.md` §5 is answered and its entry says what the survey found.

### What it found and did not fix: `?^T`

An optional of a pointer is accepted, and it has **two** absent values that are
not the same value:

```pascal
q := nil;
op := q;                 { present, and the value it holds is nil }
if op = nil then ...     { false }
if op^ = nil then ...    { true }
```

AP §6.4.11.2 refuses `?(?T)` — *one flag answers for a value; two would answer
for each other* — and an optional of a file, *a file is never a value, so there
is nothing to be absent*. Neither argument reaches a pointer, and this record
declines to extend them, for three reasons:

- **The redundancy is the program's, not the language's.** A pointer is nil
  only because something assigned nil. "No pointer was given" and "a pointer was
  given and it points nowhere" are two facts, and a program that distinguishes
  them is not confused.
- **The order is right and was probed.** `op^^` checks the optional first and
  traps *this optional has no value* before the nil check can be reached, so the
  two checks compose rather than shadowing one another.
- **Nothing needs it.** The library holds no pointer, and ADR-0123's conversion
  means no program here receives a foreign one. A rule refusing a construct
  nobody writes buys nothing and takes a spelling away.

What it *is* is a place where `nil` means two things in one expression, and
where a mistyped count of `^` changes which check traps. That belongs in
AP §6.4.11.2 as a NOTE and in `doc/sop.md` §7, which is where it now is —
stated rather than legislated, which is this dialect's habit for a hole it has
argued for (AP §6.4.3.4.5 is the other).

### And what a survey turns up that no oracle here had

**ADR-0150.** Pair 1 asks what an optional's component may be — the rule refuses
another optional and refuses a file — so a probe was written for the case
between them, `?record a: text end`, expecting a refusal because a record
holding a file is not a value either. It was accepted, and so was the plain
`z := y` under it: ISO 7185 §6.4.6 a) is two conditions and `Assignable` read
one. The copy is a memcpy of the file's own storage and the block then closed
one file twice, exit 134.

That is the argument for surveys of this shape, and it is worth more than the
rule this record states. Five oracles had looked at that program — the goldens
agreed with the compiler, difftest compared two front ends sharing one reading,
`verify/` models lowerings and not type rules, `predicate-callers` derived its
type list from the arms the defect had already excluded — and the sixth, BSI's
DEV102, had **said so**, in the one DEVIANCE row of 266 that was not `REJECTED`,
for as long as the catalogue had existed. A survey with a clause in front of it
is what read it.

### What it is not

Not a proof that the shapes are complete. `doc/roadmap.md` §5's larger claim —
that nothing speculative has landed and nobody has checked the pieces form a
language — is answered for the three pairs named and for the four reporting
shapes ADR-0141 named. It says nothing about the shapes not yet added, and the
memory-safety fork (§7) is untouched: every rule here is about a value the
program owns, and *owns* is exactly the word §7 has not defined.
