# 199. The cost is made visible by not offering the index

Date: 2026-08-25

## Status

Accepted. `PasUnicode.ElementEnd`, and the last of ADR-0193's three.

## Context

ADR-0193 named three things the text model left to a further increment: case
mapping, case folding and **grapheme-indexed slicing**. ADR-0196 did the first
two and restated the third with the objection attached:

> `for g in t` walks elements and a program wanting the third counts to three;
> an `ElementAt(t, i)` is O(n) and would read as though it were not, which is
> AP 6.4.15.9 NOTE's own objection to an integer index. If it lands it should
> be spelled so the cost is visible, and that is a design question rather than
> a table.

The specification is already decided about the *language* half. AP 6.4.15.9
refuses an indexed-variable, a substring-variable, `substr` and `index` over a
text-type, and NOTE 12 argues the refusal rather than apologising for it: three
sequences live in one value — bytes, scalar values, elements — so an integer
would have to choose silently which it names, and an index over elements cannot
be constant time over this representation. Nothing here proposes to reopen
that.

What was open is the library half, and the question it asks is narrow: **is
there a spelling under which the cost is visible?**

## Decision

**There is, and it is to answer a boundary rather than an element.**

    function ElementEnd(s: string; at: integer): integer;

The 1-based byte offset where the element beginning at `at` ends — which is
where the next one begins — or 0 at the end of the string and on bytes that are
not well-formed UTF-8. The element itself is `substr(s, at, ElementEnd(s, at) -
at)`, taken by the caller.

Three consequences follow from answering an offset, and each is the reason:

- **The walk is in the program.** A program that wants the third element writes
  the loop that reaches it, so an O(n) operation is n lines of loop rather than
  one call that looks like a subscript. No call of `ElementEnd` is itself O(n)
  in the elements before `at`.
- **There is no capacity to have an opinion about.** Returning the bytes would
  need a destination, and a destination needs a failure for an element that
  does not fit — a third answer beside "here it is" and "there are no more".
  The caller's own `substr` is where that error belongs, and it is the same
  error AP 6.4.15.9 already gives for a control-variable too small for an
  element.
- **A slice is a composition and not a routine.** Elements 2 to 4 are a nine-
  line procedure over `ElementEnd` — `tests/dialect/lib_unicode.pas` contains
  it — and writing those nine lines is the program stating what it is paying
  for.

**The operand is bytes, not a text**, as everything else in this module is
(ADR-0193). A text becomes bytes by assignment, and a slice cut at element
boundaries is **already in normal form**, so `ToText` back cannot fail for want
of normalisation. That is ADR-0192's property — walk a text, join the pieces,
get the original — used rather than restated.

**The element is validated, and the string is not.** `pas_text_next` advances
one byte over a byte it cannot decode, so that a program iterating a text whose
invariant is established still terminates; these are bytes the caller did not
write, so the wrapper checks the element it is about to name. Over the
*element* rather than over the whole string: validating from the start on every
call would make an n-element walk quadratic, and would answer a question the
caller did not ask.

## Consequences

**The text model is complete.** Nothing of AP 6.4.15 is left to a further
increment, and `doc/roadmap.md`'s row loses its "what is left".

**Three things `for g in t` cannot do are now writable**, and they are what
argued for the routine rather than convenience:

- two texts walked in **lockstep**, a for-statement having one operand and one
  control variable — `CommonPrefix` in the test is fourteen lines;
- a walk that **stops and resumes**, the offset being an ordinary integer the
  program keeps;
- a **range** out of the middle.

**One `pasx_` name and one exported function.** The split ADR-0193 established
holds: the segmentation rules stay in `pasrt_unicode.c` with the tables that
decide them, and the wrapper that speaks a NUL-terminated string is in
`pasrt.c`.

**Two mutations kill the test**: dropping the validation, so a walk over
ill-formed bytes reports an end where there is none; and answering the *scalar*
boundary instead of the element's, which makes a family emoji five elements
rather than one.

## What this does not do

**No `ElementAt`, and no `Slice`.** Both are three lines over this, both are
O(n), and both would read as though they were not — which is the whole of what
ADR-0196 said the increment had to avoid. A program writing the loop can see
what it costs; a program calling `Slice(t, 900, 3)` cannot.

**No backwards walk.** UAX #29's rules are stated forwards and a cluster's
extent depends on what precedes it, so an `ElementBefore` would be a scan from
the start of the string or a second reading of the rules. A program wanting the
last element walks to it.

**No random access, and no index that could be cached.** A program holding many
offsets into one text holds ordinary integers and must keep them consistent
with the bytes itself; nothing here ties an offset to a value.

**It does not change the language.** AP 6.4.15.9 is unaltered and this needs no
clause: the module operates on `string`, which every clause already admits.

## Alternatives rejected

**`function ElementAt(t: utf8; n: integer; var g: utf8): ErrorCode`.** The
obvious shape, and the one ADR-0193 and ADR-0196 each declined without naming
a replacement. It hides an O(n) walk behind something spelled like a subscript,
in a language where a subscript is O(1), and it would be reached for in a loop
— making an n-element traversal quadratic with nothing to warn anybody.

**Returning the element's bytes beside the offset**, as `NextScalar` returns
the scalar value beside it. It reads better at the call site and it costs a
third answer: an element that does not fit the destination is neither "here"
nor "no more". `NextScalar` escapes that because a scalar value is an integer
and every scalar value fits one.

**A cursor record** — `Start(t, c)`, `Next(c, var g): boolean`. It is the same
state as an offset and a string, with the state hidden in a record the program
cannot inspect and can copy by accident. The offset form is what the module
already uses for scalars, and a second idiom for the same shape would be a
second thing to learn.

**A language-level `t[i..j]`.** It contradicts AP 6.4.15.9, and NOTE 12 states
why: offering an O(n) access in the syntax every Pascal program already uses
for a string would guarantee it went unnoticed. The specification would have to
be amended against its own argument, and no use found here needs it.
