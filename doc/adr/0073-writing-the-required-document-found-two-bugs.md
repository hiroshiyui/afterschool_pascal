# 73. Writing the required document found two bugs

Date: 2026-08-13

## Status

Accepted.

## Context

ISO 7185 clause 5.1 d) and ISO/IEC 10206:1991 clause 5.1 d) and j) require a
complying processor to be **accompanied by a document** defining every
implementation-defined feature and describing its treatment of every
implementation-dependent one. Clause 5.1 f) 1) requires a separate section
naming each error the processor does not report, and 5.1 g) requires the
extensions to be described. None of that existed. Neither did a statement of
the compliance level, which 5.1 a) and b) make the first thing a reader needs.

The two standards list their features again in informative annexes: ISO 7185
has eighteen implementation-defined and ten implementation-dependent, ISO/IEC
10206:1991 thirty-four and eighteen. Answering all of them meant compiling a
probe for each rather than reading the source and inferring — which is what
ADR-0067 asks for, and what turned up the two defects this record is named
for.

## Decision

`doc/implementation-defined.md` is that document. It states the compliance
level, answers every annex entry of both standards with the entry numbers
cross-referenced, names the twelve errors that go unreported, describes the one
extension, and lists the restrictions.

**A comment may end with the other delimiter.** §6.1.8 of both standards writes
the production as an opening delimiter that is either a brace or a star-paren,
a commentary, and a closing delimiter that is again either — and NOTE 1 says in
as many words that a comment may commence with one and end with the other. This
lexer had two loops, one per pair, so a comment had to close with the delimiter
that opened it and both mixed forms were rejected as unterminated. One loop
serves both openings now, because which delimiter closes a commentary does not
depend on which one opened it.

**`reset(input)` no longer discards a fetched lookahead.** §6.11.4.2 makes the
effect implementation-defined, and the standard input cannot be repositioned —
but what the runtime did was worse than not rewinding: it cleared the buffer
variable. ADR-0021 makes `f^` one character that the *stream* has already
consumed, so clearing it destroyed a character nothing could read again. A
`reset` between a peek and a read silently skipped one. The definition now is
that `reset(input)` leaves the file exactly as it is, which is the only effect
available that does not lose input.

## Consequences

**The lexer fix immediately found a latent ambiguity in this compiler's own
source.** `selfhost/compiler.pas` carried the comment

```
{ set-constructor = '[' (member (',' member)*)? ']', ... }
```

whose regular expression contains `*)`. Under the corrected rule that closes
the comment, and the rest became tokens. The compiler could not compile itself
until the comment was rewritten — the sort of failure that only appears when a
rule is corrected, and the reason this ADR exists rather than the change being
a one-line fix.

**`selfhost/torture.pas` asserted the rule was the other way.** It said, in
comments, that a brace inside a star-paren comment "does not end it" and that a
star-paren inside a braced one "does not end it either". Both claims are false
and both were written down as though tested — the lexical torture file, whose
whole purpose is to carry the corner cases a valid program never reaches, was
carrying the *bug*. That is worth more than the fix: a wrong claim in a test is
indistinguishable from a right one to every oracle here, exactly as ADR-0072's
wrong ISO citation was.

**Neither bug was reachable by any oracle.** A comment is invisible to every
stage after the lexer, so the token dumps `difftest.sh` compares agree whatever
a comment does — the two compilers were wrong in the same way and said so
identically. And the lookahead fill is lazy, so `reset(input)` only loses a
character in a program that has touched `input^` first; no program in the
corpus applied `reset`, `rewrite` or `extend` to a standard file at all.

**The consequence for how this corpus is written**: because either delimiter
closes a commentary, neither pair can quote the other's characters, so a
grammar production cannot be written inside a Pascal comment. Every production
mentioned in a test is now described in words. Three test files had to be
rewritten for this while the rule was being fixed, which is a fair measure of
how easy the mistake is.

**What the document is worth beyond compliance** is the list of answers no test
pins. Writing it required naming, for each entry, what would change if the
answer changed — and several had nothing behind them at all: the whole of
E.32 and E.33, module parameters other than `input`/`output`, the refusal of
`"` and `@`, and the last four digits of `maxreal` and `minreal`, which no
golden file anywhere shows to more than thirteen significant digits.

### What this does not do

**The document is not generated and cannot be checked automatically.** It is
prose that describes behaviour, so it can drift from the compiler exactly as
a comment can. What limits that is the tests written beside it —
`tests/comments.pas`, `tests/resetinput.pas`, `tests/textfile_chars.pas`,
`tests/packedset.pas`, `tests/transcendental.pas` and
`tests/extended/module_importlist.pas` — each of which pins an answer the
document states.

**`maxreal` and `minreal` are still unpinned to the last digits.** A test that
printed them to seventeen significant digits would fix that, and would be a
test of the runtime's real formatting as much as of the constants; it is not
written here.
