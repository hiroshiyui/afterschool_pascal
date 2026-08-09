# 17. Structured types are identified by name, and every subscript is checked

Date: 2026-08-09

## Status

Accepted

## Context

Arrays and records are the second item in ADR-0004's dependency list, and they
are where the type system stops being a four-value enumeration. Three questions
had to be answered together, because the answer to each constrains the others.

**When are two structured types the same type?** ISO 7185 §6.4.5 says two types
are the same when one type-identifier denotes both, or when one identifier is
defined equal to the other. That is *name* equivalence. The alternative —
structural equivalence, where any two `array [1..3] of integer` are
interchangeable — is friendlier to write against and is what several later
languages chose. It is not what the standard says, and it would quietly accept
programs a conforming compiler rejects.

**What does a subscript cost?** §6.5.3.2 makes an index outside the array's
bounds an error. ADR-0014 already committed to trapping on ISO's error
conditions rather than letting them produce arbitrary values, so the question
was not whether to check but whether arrays would be the exception. They are the
one place where *not* checking turns a Pascal program into an arbitrary memory
write, which is the strongest case for the check rather than the weakest.

**How does a structured value reach a procedure?** A value parameter of ISO
Pascal is a copy. Copying at the call site, copying in the prologue, and not
copying at all (with a promise the callee will not write) are all
implementable; only the first two are correct.

## Decision

**Name equivalence, by pointer identity.** Every array or record *type-denoter*
in the source produces one `Type` object, and a type identifier names the one
its definition produced. `assignable` therefore compares structured types with
`==`. A group declaration shares one denoter in the AST as well as in the
source, so `a, b: array [1..3] of integer` makes a and b the same type — which
is exactly the rule §6.4.5 states, obtained by construction rather than by a
special case.

**The string types are the documented exception**, as they are in the standard:
packed arrays of char compare and assign by *length*, however they were written.
A string literal is given the type §6.4.3.2 says it has — `packed array [1..n]
of char` — rather than a type of its own, so assignment, comparison, `write`,
and parameter passing all work through the ordinary rules with no literal-shaped
hole in any of them.

**Every subscript is bounds-checked**, against both ends, before anything is
computed from it. The address is then `base + (i - lo)` with an unchecked
subtraction.

**A structured parameter always travels as an address.** A `var` parameter binds
to it; a value parameter is copied out of it by the callee's prologue, once, so
the callee may write to its copy freely. Copying in the callee rather than at
the call site means one copy per procedure rather than one per call site.

## Consequences

Two structurally identical anonymous types are not interchangeable, and the
diagnostic has to say so in a way that does not read as a compiler bug —
`cannot assign array [1..3] of integer to a variable of type vector`. Anonymous
types are spelled out in messages for that reason.

The ISO restriction that a parameter's type must be a type *identifier*
(§6.6.3.1) stops being an annoyance under this rule and starts being the point:
it is what guarantees a formal and an actual parameter are the same type rather
than two that merely look alike.

Bounds checking costs two comparisons and a branch per subscript. The branch is
perfectly predicted and the checks fold away wherever the optimiser can see the
index is in range; a `for` loop over an array's own bounds is the common case
and optimises to nothing. What it buys is that no Pascal program this compiler
produces can write outside an array.

The check has to come *before* the offset subtraction, and the ordering is not
merely defensive. `i - lo` is unchecked, and it is sound only because the check
has already established `lo <= i <= hi`; the rule
`accepted-index-selects-the-right-element` in `verify/rules.py` states exactly
that, and it is the array counterpart of `negation-cannot-overflow`.

**That rule found a real hole when it was first run.** It failed on an array
whose bounds span more than `maxint` values, where `i - lo` wraps however
carefully the bounds are checked. Sema now rejects such an array at compile
time, and the rule's precondition names that restriction — so the check in the
compiler and the assumption in the proof are the same statement written twice,
and neither can drift without the other failing. This is the second time the
solver has caught something the tests did not; see ADR-0013.

Records ignore `packed`. §6.4.3.1 leaves the representation to the
implementation, and the natural layout is what the ABI and the optimiser both
expect. `packed` on an *array* is honoured only in the sense that it selects the
string types; an array of char is dense either way.

Variant parts of a record are rejected with a diagnostic rather than parsed and
ignored. They need a tag of an enumerated or subrange type, which arrives with
`case` — the next item in the dependency list. Rejecting them keeps the eventual
implementation honest, since the self-hosted AST is exactly what will need them.

Functions still cannot return an array or a record. §6.6.2 restricts a result
type to a simple type, which is what lets the result travel in a register and be
read back with a load; lifting that restriction would mean a hidden result
parameter, and nothing in the bootstrap needs one.

## Notes for the port

The `with` statement's binding is a frame slot holding an address — the same
shape as a `var` parameter — so a `with` inside a recursive procedure binds the
record of the invocation it is running in, and the designator is evaluated once
as §6.8.3.10 requires. That reuse is deliberate: the Pascal-hosted compiler will
have one mechanism to re-implement rather than two.
