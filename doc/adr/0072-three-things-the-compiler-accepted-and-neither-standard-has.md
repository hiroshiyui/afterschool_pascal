# 72. Three things the compiler accepted and neither standard has

Date: 2026-08-13

## Status

Accepted.

## Context

ADR-0071 swept Annex A for constructs the standard has and this compiler
refused. This record is the other direction: constructs *neither* standard has
and this compiler accepted, found the same way — by compiling a probe for a
clause rather than by a test failing.

Fifteen ISO 7185 restrictions were probed. Six were not enforced. Two of the
six are deliberate and stay (see below); three are closed here; and one was a
fault in the probing rather than in the compiler, which is worth recording
because it is the easiest mistake to make with this method.

**`writeln(5:0)` looked like a laxity and is not.** It compiles under
`--std=iso7185` and then traps, and §6.1 f) permits an error to be reported
either at preparation time or during execution. A probe that asks "does this
compile" asks the wrong question of an error condition; the question is whether
the program is *accepted*, and a program that stops is not. ADR-0064's claim —
that the bound is decided in the compiler, so the runtime is never told which
language it was compiled for — is intact.

## Decision

**Pascal has no empty argument list.** ISO 7185 §6.7.3 and ISO/IEC 10206:1991
§6.7.3 spell it identically:

    actual-parameter-list = '(' actual-parameter { ',' actual-parameter } ')'

and both require at least one. A parameterless call is the bare name, §6.8.2.2
making the reading of a function identifier a call of it, so `f` and `f()` are
not two spellings of one thing. This is refused in **both** standards, being
wrong in both.

Six copies of the argument loop each wrapped the list in `if
(!check(Tok::RParen))`, which is exactly the shape that permits the empty one.
Five are now one routine and `write` keeps its own — §6.10.3's write-parameter
is a value and an optional width rather than an actual-parameter, so the two
share the emptiness rule and nothing else. The five spellings that could be
written are `f()`, `p()`, `read()`, `readln()` and `writeln()`, and the last
three are the ones worth having a test for: their parameter list is optional to
begin with, so `readln` alone is legal and `readln()` is a different program.

`tests/extended/funcresult_bare.pas` had said in a comment that Pascal has no
empty argument list, while all six copies took one.

**A block's declaration parts have an order.** ISO 7185 §6.2.1 writes a block as
a fixed sequence of five optional parts — label, const, type, var, then
procedures and functions — each at most once and only after the ones before it.
ISO/IEC 10206:1991 §6.2.1 makes the same five a *repetition* in any order, which
§6.2.2.9 then needs.

This is checked in the parser, because the parser is where the written order is
visible, and against the **highest** part begun rather than the previous one, so
every misplaced part is reported and not merely the first of a descending run.
Two procedures in a row are one part and stay legal; that is the single
exception in the condition, and the grammar's own — the part is a list of
procedures rather than a part per procedure.

**A constant may not be selected from.** §6.8.8's constant-access belongs to
ISO/IEC 10206:1991. ISO 7185 §6.3 gives a constant no selectors — its
`unsigned-constant` is a number, a character-string, a constant-identifier or
`nil` — and §6.7.1 admits a `[`, a `.` or a `^` only after a variable-access.

It is refused in Sema and not in the parser, because a selector over a name is
a designator until the symbol says otherwise and the parser has no scope. "Ask
the symbol, not the syntax", for the fifth time.

**Two of §6.8.8's three forms are checked, not three.** §6.8.8.4's substring
needs a `..` inside a subscript, which the parser reads only under
`--std=extended`; no substring node exists under ISO 7185, so a call from that
arm could not fire in either standard. It was written for symmetry and deleted
for being unreachable.

## Consequences

**Three ISO programs in the corpus were themselves non-conforming**, which is
why the declaration-part order had gone unchecked without any test failing:
`stringconst.pas` wrote its types before its constants, `stringconst_errors.pas`
had two type parts, and `variants.pas` had two variable parts. All three are now
written the way §6.2.1 requires, and **both goldens are byte-identical after the
reordering** — the programs mean exactly what they meant, which is what makes
this a conformance fix rather than a behaviour change.

**The order check was lost by ADR-0069 and not by an original omission.** That
record found Sema imposing ISO 7185's fixed order on Extended Pascal and taught
it to read the parts in written order; it went one step further and stopped
checking the order at all. A change that correctly relaxes a rule for one
language can silently relax it for the other, and the corpus cannot object when
its own programs are the ones taking advantage.

**A wrong citation is invisible to every oracle a compiler has.**
`tests/stringconst.pas` indexed a string constant citing §6.5.3.2 — which is
about an array-*variable* — and the construct compiled, ran, printed the right
answer, and was agreed on by both compilers. Nothing a differential test, a
golden file, an SMT rule or a bootstrap fixed point can do will notice a
sentence. That gap is the one this project has no oracle for at all, and the
only defence is reading the clause.

**The deleted substring call is recorded rather than silently removed.** An arm
that no input reaches will be re-added by the next reader chasing symmetry, so
the reason it cannot fire is written where the call would have gone.

### What this does not do

**Two deviations remain, both deliberate.** An identifier may contain an
underscore, where §6.1.3 makes one `letter { letter | digit }`: it is how this
project spells a name that would otherwise collide with a word-symbol —
`label_`, `set_`, `packed_` — and how a test program takes the name of its
file. Enforcing it would rename thirteen identifiers in `selfhost/compiler.pas`
and the program headers of forty-three test programs for a lexical rule that
admits no ambiguity.

And **set compatibility ignores packing**. §6.4.5 c) makes two set-types
compatible only if both are `packed` or neither is; here only the base types are
compared. Every set is one 256-bit word whatever is written, so the check could
only reject programs that work — and the standard does not say what packing a
*set-constructor* has, so requiring agreement would make `s := [1]` succeed or
fail according to how `s` was declared. README carried this as "`packed` is
accepted on a `set`, where it has nothing to do", which describes accepting a
construct §6.4.3 makes perfectly legal; the deviation is the missing check, and
that is what it now says.

**`const q = nil` is refused under both standards, and should be legal under
one.** ISO 7185 §6.3's constant has no `nil` in it, so refusing it there is
right. ISO/IEC 10206:1991 §6.8.2 makes a constant-expression any nonvarying
expression and §6.7.1's factor includes `nil`, so that standard has it and this
compiler does not. It is a refusal rather than a laxity — ADR-0071's family,
not this one — and it is left for the corpus sweep that record's consequences
call for.
