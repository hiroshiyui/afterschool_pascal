# 192. Joining and walking a text are inverses, and that is the test

Date: 2026-08-25

## Status

Accepted. AP 6.4.15.7 and the iteration of 6.4.15.9, and the third of
ADR-0189's four increments. **AP 6.4.15 is now implemented in full**, and AP
5.6's list of clauses stated ahead of the processor is empty.

## Context

ADR-0189 staged concatenation and iteration together, on the grounds that "`+`
must renormalise at the join, and the canonical-text-type that a concatenation
yields is the same device iteration's element type wants". The first half was
right and the second was wrong in an interesting way: iteration needs no
canonical type at all, because the control variable is a text the program
declared and the element is stored into it.

What the two do share is the property this record is named for, and it is the
only real question either of them raises.

## Decision

**Concatenation returns a text value in the arena, and iteration cuts one up
without normalising. Joining the pieces back together gives the original, and
that is what is tested.**

**`+` cannot return a length the compiler computes.** §6.8.3.6 says a string
concatenation's length "shall be equal to the sum of the length of a and the
length of b", so `pas_str_concat` returns bytes and the emitter adds two
numbers. Normal form is not preserved by joining: where the left operand ends
in a base character and the right begins with a combining mark the two compose
across the join, and the result is *shorter* than the sum. So
`pas_text_concat` returns a pointer to a text **value** in the arena — a length
word and the bytes, the representation a text variable already has — and the
emitter reads it with the same two `getelementptr`s it uses for a variable.

That the result is shorter and not longer is what makes one pass enough:
composition removes code points and never adds any, so `la + lb` bounds the
result and nothing has to be sized twice.

**The result type is a text with no capacity**, as `canonStringType` is a
variable-string with none. What `+` yields must fit any target, so it carries
no capacity to exceed and 6.4.15.5's store is where the fit is checked. It
required no new machinery anywhere else: `length`, `write`, comparison and
assignment all ask `IsText`, and a capacity-less text answers yes.

**Iteration does not normalise, and must not.** `pas_text_take` copies the
element into the control variable and checks the fit, where `pas_text_store`
would validate and normalise through the string arena. The arena is released
once per *statement* (ADR-0111), so an iteration that allocated would grow it
once per element and a long text would exhaust it — the ring that wrapped in
silence, found by a security audit's follow-up probe and not by any gate.

Not normalising is sound because **a grapheme cluster boundary is also a
boundary of normal form**: every character that composes onto what precedes it
is `Extend` or `SpacingMark`, and UAX #29's GB9 and GB9a make neither of those
a boundary, so a boundary never falls between a base character and a mark that
would have composed with it.

**That argument is a reading, so it is tested rather than trusted.**
`tests/dialect/text_join.pas` walks a text, joins the elements back together
and requires the result to equal the original. If a boundary could split a
normalisation segment, the pieces would not be in normal form, rejoining them
would renormalise, and the comparison would fail. This is the one place in the
text model where correctness rests on an argument rather than on Unicode's own
conformance files, and a property test is the nearest thing to an oracle
available for it.

**The operand is evaluated once and outlives the loop.** `for g in a + b` is
the case that matters: the concatenation took arena storage, the loop walks
it, and the loop body must therefore not release the arena. It does not — the
release is the enclosing statement's, and the pair is a pair of SSA values
defined before the loop, so it dominates every block.

**Iteration is told from set-member-iteration by the operand's type**, which is
ADR-0140's rule and reserves nothing: `for v in s` over a set goes on meaning
exactly what §6.9.3.9.3 says. The control variable is checked against the
operand rather than against §6.9.3.9.1's "shall possess an ordinal-type",
which required the iteration-clause to be typed *before* the control variable
is judged — it was typed after, and the check fired on every text.

## Consequences

**AP 6.4.15 is implemented in full and AP 5.6's list is empty.** That
sub-clause was written three days ago so a design could be written down before
it was built, and it has now done its whole job once: it held the text model
through two increments, refused a scenario claiming the feature worked, and is
now empty. An empty list is the state it expects to be in.

**Two more runtime entry points**, `pas_text_concat` and `pas_text_take`, plus
`pas_text_boundary` — an `int` wrapper over `pasrt_unicode.c`'s `long long`
`pas_text_next`. The width matters: the emitted code speaks i32 because every
length in this compiler is one, and passing an i32 where a `long long` is
declared is an ABI mismatch the IR verifier does not catch. Every `pas_text_*`
entry point is an int wrapper for that reason.

**`t + s` is refused where `t := s` is admitted**, which is the same asymmetry
comparison already had and for the same reason: an assignment normalises, so
the text is right afterwards, while a join or a comparison against unnormalised
bytes would need a conversion the operator cannot report on.

## What this does not do

**No `PasUnicode`.** The scalar view, the byte count, case mapping, case
folding and grapheme-indexed slicing are increment 4's, and so is the fallible
conversion a program needs when it must handle ill-formed input without
stopping.

**No reverse iteration and no element at a position.** Both would want a
`pas_text_prev`, and neither has a client. `for g in t` walks forwards and
that is the whole of what 6.4.15.9 gives.

**Iteration does not admit a string or a character-string operand.** Only a
text. A character-string would have to be normalised first, which is an arena
allocation before a loop and would be fine, but nothing asked for it and the
program can assign to a text in one line.

**The control variable is not protected from the body beyond what §6.8.3.9
already does.** A text control variable is threatened by the same rules as any
other, through the same `Threatened` walk.

## Alternatives rejected

**Returning a length from `pas_text_concat` through an out-parameter.** It
would need somewhere to put the `int`, and an `alloca` for it inside a loop is
ADR-0102's defect exactly. A global would have worked and is what
`pas_str_at` already is, but a length word in front of the bytes costs the same
and gives the result the shape everything else already reads.

**Normalising in `pas_text_take`.** Correct and slow, and worse than slow: it
allocates from the arena, so a loop over a long text exhausts it. The
correctness of not doing it is the property test above.

**Making iteration an arm of `EmitForIn`.** Nothing is shared. A set walks its
base type's ordinals and tests a bit in a 256-bit word; this walks byte offsets
and asks the runtime where an element ends. The one thing they share is the
frame slot Sema hands the statement, and it holds a different kind of number in
each.

**Relaxing §6.9.3.9.1's ordinal requirement** rather than adding a second
iteration beside it. It reads as the smaller change and is the larger one: an
ordinal control variable is what the set form's whole lowering is built on, and
"ordinal, or a text when the operand is a text" is two rules written as one.
