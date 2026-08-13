# 76. A read that took too much, and two brackets that were never provided

Date: 2026-08-13

## Status

Accepted.

## Context

ADR-0071's sweep of Annex A left two lists behind: about thirty constructs the
compiler accepted that no program in this corpus wrote, and the
implementation-defined choices of Annexes E and F, most of which had no
document. ADR-0073 wrote the document. This record is the other list.

Working through it meant asking, for each entry, not "does this compile" but
"what would notice if it stopped working" — which is ADR-0067's question, and
the one the counting lessons of ADR-0022 to ADR-0024 keep answering the same
way. Seven claims turned out to be checked by nothing. Two of them were not
merely unchecked but wrong.

## Decision

**A number read stops where §6.9.1 says it stops.** Clauses c) and d) do not
say "read a number". They say the sequence read "shall, and s ~ S(t.first)
shall not, form a signed-integer according to the syntax of 6.1.5" — the
longest prefix that *is* one and not a character more. §6.1.5 then makes both
halves of a real obligatory, `unsigned-real = digit-sequence '.'
fractional-part [ 'e' scale-factor ]` with `scale-factor = [ sign ]
digit-sequence`. So `1.` is the integer 1 followed by a point, `.5` is not a
number at all, and `2e+` is the integer 2 followed by two characters the
program has not read yet.

The reader took all three, and a file offers one character of lookahead
(ADR-0021) — which is one short of deciding any of them, because the point has
to be consumed before what follows it can be seen. `struct pas_file` therefore
gained a two-character give-back and `pas_fill` prefers it to the stream. Two
is the depth an over-read reaches, and the order matters: the sign has to come
back out before the character that followed it, so the give-back is a stack.
The `e` handed back is the one that was written, since §6.1.5 admits either
case and the program reads the character rather than its meaning.

**`(.` and `.)` are required.** §6.1.9 (ISO/IEC 10206:1991 §6.1.11, word for
word) has two sentences and they say different things:

> All processors that have the required characters in their character set
> shall provide both the reference representations and the alternative
> representations, and the corresponding tokens or separators shall not be
> distinguished. Provision of the reference representations, and of the
> alternative token @, shall be implementation-defined.

The second sentence carves out exactly two things — the reference tokens
themselves, and `@`. Every other alternative representation is a *shall*. This
compiler provided `(*` and `*)` and not `(.` and `.)`, and
`doc/implementation-defined.md` recorded the omission as a choice the clause
offers, which for these two it does not.

They are the same token as `[` and `]` rather than a second spelling: nothing
after the lexer is told which arrived, which is what "shall not be
distinguished" asks for and is why `a[2.)` is a legal subscript.

## Consequences

**Neither bracket is ambiguous, and the reason is worth writing down.** A `(`
begins a parenthesised expression, an argument list, an enumerated type or a
field-list, and no expression or identifier begins with a point. A bare `.` is
a field selector, a qualified name or the program terminator, and none of those
is followed by `)`. `..` is still taken first, so `(.1..3.)` is five tokens and
`3.` is not a real — both of which were already true of `[1..3]`. What is new
is only that the brackets are two characters each.

**The document's E.2 entry named a token the standard does not.** It listed a
double quote among §6.1.9's tokens, which comes from reading an extraction of
the PDF: the standard writes the pointer symbol as an up-arrow, and the arrow
arrives in the text layer as a quote. The same substitution appears throughout
that extraction — `new-pointer-type = '"' domain-type` is the giveaway — and it
is why the entry then answered a question about a character Pascal does not
have. ADR-0072's wrong-citation lesson with a new cause: not a clause read
carelessly but a clause read through a lossy rendering.

**Five of E.32 and E.33's six answers had no program.** Only `reset(input)`
did, from ADR-0073. The two answers that are "no effect" have to be pinned by
something that would notice a *quiet* one, which is §6.9.5's `page`: it writes
an implicit `writeln` only "if f.L is not empty", so a `rewrite(output)` that
cleared that flag would put a blank line into the output and a test without a
`page` would print exactly what a correct one prints.

**`maxreal` and `minreal` were pinned to thirteen digits.** ADR-0062 required a
test of the three required real constants to assert the property rather than
the characters, and `epsreal` has one — §6.4.2.2 b) defines it by subtraction,
which a program can perform. The other two are defined as the largest and
smallest values of the real-type, and Pascal offers no way to ask for the next
one. So the only handle is the printed text, and the default output rounds to
thirteen significant digits: a constant short by its last four digits satisfied
every inequality in that test and printed identically **in both compilers**, so
`difftest` and `irtest` agreed as readily as the goldens did. §6.10.3.4.1
derives the decimal places from the field width (ADR-0064), so asking for 26
characters asks for nineteen digits — past binary64's seventeen, and past any
truncation of the decimal text the two compilers carry.

**Two word-symbols had never been written as identifiers.** Eleven of §6.1.2's
thirteen extra word-symbols appear as ordinary names somewhere in the ISO 7185
corpus; `protected` and `bindable` did not, so moving either into the ISO
keyword table broke nothing. `protected` now sits where Extended Pascal puts
it — §6.7.3.1 writes a formal parameter as `[ protected ] identifier-list ':'
type`, so under that standard the same heading is the word-symbol followed by a
missing parameter name.

**The read bug is the one that would have bitten this project.** `7..9` read as
7 and swallowed a point, so a program reading input that looks like Pascal
source would have lost the `..`. Every `.in` file in the corpus held numbers
with nothing interesting after them, so no oracle could see it; the sign branch
was in the same position, reached only through §6.7.5.5's `readstr` and there
only for an integer and only for `-`.

### What this does not do

**It does not provide `@`.** §6.1.9 leaves that one alternative to the
implementation, and `torture.pas` has refused it since the lexer was ported.
The reference tokens `^`, `[` and `]` are provided, which the same sentence
also leaves open.

**It does not make `.5` read as a number.** §6.9.1's "it shall be an error if s
is empty" would permit leaving that undetected, so accepting it would conform
too — but the sequence `.5` forms no signed-number, and a processor that
attributed 0.5 to the variable would be inventing a syntax the standard's own
§6.1.5 does not have. It is refused, and `tests/trap_readreal.pas` is the
program that says so.

**It does not revisit the remaining unexercised forms.** The list ADR-0071 left
is shorter, not empty; what is written down here is what a probe reached, and
the sweep's own lesson is that a claim no test names is a claim nothing checks.
