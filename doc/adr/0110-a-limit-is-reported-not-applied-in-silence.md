# ADR-0110: A limit is reported, not applied in silence

## Status

Accepted.

## Context

A security audit of the front end found three fixed limits that were reached in
silence, and the three failed in different ways:

- **`strMax = 255`, the longest identifier kept.** §6.1.3 makes every character
  of an identifier significant, so two names agreeing in their first 255
  characters and differing after are two names. `StrAppend` kept 255 and
  dropped the rest without a word, which made them one. A program could assign
  to one and read the other; a reader of the source saw two variables and the
  compiler saw one.
- **`strMax` again, the longest character-string kept.** §6.1.7 bounds a
  character-string not at all. `writeln` of a 300-character literal printed 255
  of them and said nothing, so the program's output did not match its source.
- **`maxBlockDepth = 1001`, the depth of Sema's scope stack.** The comment
  beside it said every block "is reached through a declaration the parser
  counted". `ParseBlock` did not count, so 1001 nested procedure declarations
  indexed `scopeMark` off its end. The array bounds check caught it — the
  compiler is a Pascal program and every subscript is checked — but what the
  user got was `array index out of bounds (0..1001)` on **stderr**, where this
  compiler's diagnostics go to stdout. A caller redirecting stderr saw a
  non-zero exit and no message at all.

None of the three was memory-unsafe. All 510 corpus sources, 195 generated
programs and 2 400 fuzz rounds are clean under AddressSanitizer and
UndefinedBehaviorSanitizer, before the fix and after. What they were is worse
in a different way: a compiler that quietly disagrees with its own input.

The other limits in this compiler already did the right thing, and say so:
`poolMax` and `tokMax` carry a comment reading "both fail loudly rather than
silently truncating". `strMax` was the third of that family and did the
opposite, which nothing had noticed because nothing had asked.

## Decision

**A limit this processor imposes is reported when it is reached.** Never
applied by truncating, dropping, or wrapping around; never left to a later pass
to trip over.

Concretely: over-long identifiers and character-strings are diagnosed, and
`ParseBlock` counts a level so that block nesting reaches the existing
`nesting is too deep` diagnostic rather than the scope stack's end.

**The limits are not raised.** `strMax` bounds a `packed array [1..strMax] of
char` that is frame storage in the lexer and in every routine holding a `str`,
so raising it multiplies stack use across the compiler for a case no real
program has. Reporting costs one comparison per token.

Every such limit is stated in `doc/implementation-defined.md` §6, which clause
5.1 c) requires and which had none of them.

## Consequences

**A program that compiled before may now be refused.** Anything with an
identifier or a literal over 255 characters, and anything nesting blocks past
the limit, was accepted and is now an error. That is the point — each of those
programs was being compiled into something other than what it said — but it is
a change to the accepted language and is called out in `CHANGELOG.md` rather
than left for someone to discover.

**A program's own block now costs one nesting level**, so 999 remain inside it
where 1000 did before. `tests/deep_chain.err` and `tests/deep_nesting.err` move
by one and two columns, and those goldens are regenerated in the same change.
The limit was always meant to bound the tree the later walkers descend, and a
block is one of its levels; the previous count was simply short.

**What this does not do.** It does not audit the remaining fixed arrays. Two
were checked here — `maxImports` and the twelve command-line arguments — and
both already report. The rest are bounded by construction or by a limit checked
elsewhere, and no sweep was made; a later one would be worth its own record.

It also does not make the *runtime*'s limits report. `pas_str_temp`'s ring
wraps in silence when several string values live at once, which
`runtime/pasrt.c` documents at the site and argues is unreachable from this
language. That argument is untested and is the obvious next thing to probe.

## Alternatives rejected

**Raise `strMax`.** Rejected for the frame cost above. It also only moves the
number: whatever it becomes, a program can exceed it, and then the question is
the same one.

**Make `StrAppend` itself report.** It is the generic string append and is used
for message construction as well as for tokens, where there is no source
position to attribute and no error to raise. The check belongs where the
scanner knows what it is scanning.

**Guard `scopeDepth` at its five increment sites instead of counting blocks.**
That would stop the trap without making the comment true, and would leave the
parser's own bound describing something other than the tree it builds. Counting
in `ParseBlock` fixes the measurement rather than adding a second one.
