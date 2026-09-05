# ADR-0340: Four things a trait heading cannot do

Date: 2026-09-05

## Status

Accepted. Follows [ADR-0339](0339-a-trait-heading-names-one-type-and-one-scope.md),
which follows [ADR-0338](0338-a-bound-belongs-where-the-type-is-written-down.md),
which corrects increment B of
[ADR-0315](0315-methods-and-traits-without-inheritance.md). Each of those
narrowed the one before it. This one narrows ADR-0339 and ADR-0315 together,
and it is the first of the four written from a **working implementation**
rather than from a reading or a probe.

The implementation is on the `traits-b` branch, where a trait, an
implementation and a dispatching call compile and run. It does not pass its
gates and is not for merging; what is settled here is what building it found.

## Context

**Three records described this construct before anyone had built it, and the
compiler disagreed with all three.** ADR-0338 was written because probing beat
reading; this record exists because building beat probing. That is the pattern
worth naming before the findings, because it is the third turn of the same
wheel and the next feature should expect a fourth.

All four findings are constraints on **what a trait heading can say**, which is
why they are one record.

## The four

### 1. A trait heading cannot name its receiver `self`

ADR-0315 writes the receiver as `self: Self` and every record since has copied
it. It does not compile:

    'self' is already used in this block, so declaring it here would give one
    name two meanings

§6.1.2 makes case insignificant, so the parameter name `self` and the type name
`Self` are **one identifier**. Rust has both only because it is case-sensitive.

The design survives untouched — ADR-0315 says in terms that `self` is not a
keyword but a parameter name a program may call anything — and every written
example does not. The receiver takes another name: `function Compare(p: Self;
q: Self): integer`.

### 2. A trait heading's routines cannot live in the block's scope

ADR-0339 decided that a trait's routine names are ordinary exported names and
that a collision between two *traits* is answered by §6.11's `qualified`. That
holds and is unchanged. What it did not consider is two implementations of
**one** trait: `impl Ord for Point` and `impl Ord for Line` each define
`Compare`, and declaring either in the block they stand in makes the second a
redeclaration.

So a trait's routines are declared in the **implementation's own scope** and
reached through a trait-keyed lookup, consulted only after an ordinary lookup
has failed — which is §6.2.2.11's rule and the placement `LookupBuiltin`
already sits behind, so a program that declares its own routine of the name
goes on meaning what it meant.

**This is not increment A's per-type scope**, and the distinction is what keeps
A out of B's way: the key is the *trait*, the selection is by the first
actual's type, and no method table or receiver syntax is involved.

The selecting type must be known one step *before* `CheckArguments`, and
checking the actual there would check it twice and report a bad one twice. A
designator's type is a fact about its declaration, so it is read without
checking the expression, and the answer is nil wherever it cannot be — falling
through to the ordinary `unknown function`, which is the right message for a
call that can select nothing.

### 3. A trait heading cannot be resolved once

A trait keeps its headings' syntax and resolves them per implementation with
`Self` bound — ADR-0338's decision, and correct. But **sharing the parsed nodes
does not work**: resolution annotates them, so the second implementation of a
trait reads the first's types and reports a field of the wrong record —
`'a' is not a field of point`.

The mechanism that answers it already existed and ADR-0338 cites it for the
neighbouring case. AP 6.7.3.5 re-reads a generic's body **from the token
stream** rather than copying its tree, because a copy is a second statement of
every node's shape and free to drift, and re-reading tokens is parsing, so it
cannot disagree with parsing. A trait heading records its token position and is
re-parsed once per implementation, with `Self` bound to that implementation's
type.

### 4. A trait heading cannot take a `protected var` receiver and serve a subrange

ADR-0315 asserts both halves of this and they are incompatible. Its Rust
mapping makes `&self` a `protected var` parameter; its Consequences say
`impl Ord for integer` covers every subrange, which is ADR-0018's rule said
once more.

**Selection does follow `Base()`** — that half works, and a `1..9` selects the
implementation written for `integer`. Then §6.6.3.3 refuses the call:

    var parameter 'p' is integer, but the argument is digit

A var parameter binds to a variable and requires an actual of the *same* type,
not an assignment-compatible one. With a **value** receiver all four cases pass
— `Point`, `Line`, `integer` and a subrange of integer.

## Decision

**The receiver is written with a name of the implementer's choosing**, and no
example in this tree spells it `self`.

**A trait's routines are declared in their implementation's scope** and reached
by a trait-keyed selection on the first actual's type, after the ordinary
lookup.

**A trait heading is re-parsed per implementation**, by token position, as a
generic body is.

**`Base()` selection is kept, and the receiver's mode is the program's
choice.** A trait whose receiver is `protected var` is simply not usable at a
subrange, and the diagnostic says exactly why. This is *not* patched: refusing
`Base()` selection for a var receiver would make one rule two, and copying a
subrange into a value receiver silently would defeat the reason a program wrote
`protected var`. What changes is the advice — **a trait meant to serve
subranges takes its receiver by value** — and `Ord` and `Hash`, the two this
feature exists for, both should.

## Consequences

**ADR-0315's `&self` mapping is narrowed rather than withdrawn.** `protected
var self: T` is still what `&self` means and is still right for a large record;
what it cannot also be is the receiver of a trait a subrange implements. The
three-row table in ADR-0315 §2 should be read with that caveat.

**A large record and a subrange cannot both be served cheaply by one trait.**
The value receiver copies, which is what `protected var` exists to avoid. No
program here has yet wanted both from one trait, so this is recorded rather
than solved; the shape that would solve it is a receiver whose mode is chosen
per implementation, and that is a second dispatch axis nobody has asked for.

**The trait-keyed scope means a trait's routines are reachable only through a
call whose first actual is a designator.** A literal, a function result or an
expression selects nothing and gets `unknown function`. That is a real limit
and it is the price of not checking an argument twice; it costs nothing the
motivating cases want, `Compare(a, b)` and `Hash(key)` both passing designators.

## What this does not do

**It does not revisit ADR-0339's answer for two traits.** `qualified` still
answers a collision between traits; this record is about two implementations of
one trait, which is a different question with a different answer.

**It does not settle procedure-call dispatch.** Only function calls select an
implementation so far. A trait declaring a procedure is parsed and checked and
cannot yet be called, and closing that is implementation rather than design.

**It does not touch the bound**, which is ADR-0338's and remains the payoff and
the largest thing unbuilt.

## Alternatives rejected

**Spelling the implementing type something other than `Self`** — `T`, or the
trait's own name — so that a receiver may be called `self`. Rejected: it trades
a name every reader of another language knows for one they do not, to keep a
spelling that is only conventional, and §6.1.3 lets a program shadow `Self`
anyway.

**Declaring a trait's routines in the block with a mangled name.** Rejected
because the mangling would be a second naming scheme visible in every
diagnostic and in `--dump-symbols`, and because the trait-keyed lookup is the
thing that has to exist regardless.

**Copying the trait's heading tree per implementation** rather than re-parsing.
Rejected on AP 6.7.3.5's own argument, which this project has already paid to
learn once.

**Refusing `Base()` selection where the receiver is a var parameter**, so that
finding 4 becomes a clean refusal at the impl. Rejected: it makes one rule two,
and the failure it prevents already reports itself precisely at the call.
