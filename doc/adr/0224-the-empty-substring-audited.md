# 224. The empty substring, audited

Date: 2026-08-27

## Status

Accepted.

## Context

ADR-0219 amended §6.5.6's third error condition for the dialect and ADR-0220
fixed a defect turning on §6.1.9 and §6.4.3.3.2. Both rest on *readings*, and
no oracle here can contradict one: the goldens agree with whoever wrote them,
`tests/bsi/expected.tsv` records what this compiler does, `verify/` proves the
lowering matches a model of the lowering, and difftest's two front ends are one
author's reading twice.

Four independent readers were given the behaviour and not the reasoning, told
to prove the compiler wrong from the standards text. This records what they
settled, because a reading that has survived an adversarial check is a
different thing from one that has merely not been challenged, and the next
reader cannot tell them apart unless it is written down.

## Confirmed

**§6.5.6's error conditions are implemented exactly, disjunct for disjunct.**
The clause has two `It shall be an error` sentences, which Annex D splits as
D.16 and D.17. D.16 is a three-way disjunction asserted of *each* index-
expression, and the emitted `lo < 1 or hi > len or hi < lo` was shown
logically identical to it over both — neither wider nor narrower. Probed
exhaustively on a length-6 string, including `0 -1`, `-3 -4`, `9 8` and `1 7`.

**The check reads the value's length, not the type's capacity.** D.16 says
"greater than the length of the value of the string-variable". For a fixed
string the two coincide; for `s: string(20)` holding `'abc'`, `s[1..4]` traps.
Reading the capacity would have been a silent under-strictness no golden could
see.

**§6.7.6.7's `substr(s, i, 0)` yields the null-string**, verbatim: *"If the
value of j equals 0, the function shall yield the null-string"*. Its three
error conditions are `i <= 0`, `j < 0` and `i+j-1 > length(s)` — so
`substr(s, length(s)+1, 0)` is legal and does not trap, and it does not here.

**The two grammars really do differ, and this is the strongest single result.**
ISO/IEC 10206:1991 §6.1.9 is `character-string = "'" { string-element } "'"`;
ISO 7185 §6.1.7 is `character-string = "'" string-element { string-element }
"'"`. Zero elements is admitted by one and not the other, and each clause says
it a second time in prose — "other than a single" against "more than one".
**Corroborated by a corpus nobody here wrote**: BSI's `DEV024` and `DEV262` are
classified DEVIANCE, and their 1982 headers say why — *"The Pascal Standard
says that a character string is a sequence of characters enclosed by
apostrophes, consequently there is no NULL string"*.

**No fixed-string-type has capacity 0.** §6.4.3.3.2 makes the capacity the
largest value of a fixed-string-index-type whose smallest value is 1, and
§6.4.2.4 requires the smallest to be at most the largest — so `1..0` is not a
subrange-type and `packed array [1..0] of char` is not a type. `''` must
therefore possess the canonical-string-type, which is what the compiler gives
it.

**No over-strictness was found inside §6.5.6**, which was the primary target,
across roughly sixty probes over two readers. The equivalence above is why:
there is no gap for a legal program to fall into.

**The BSI suite agrees completely** — 221 CONFORM programs recompiled, 812/812
matching `expected.tsv`, zero differences. It has nothing to say about §6.5.6
itself: ISO 7185 has no substring notation, the word does not occur in the
standard, and every `[i..j]` in the suite is a set-constructor or an index
range. Worth stating plainly, because it means this reading rests on the clause
text and the probes alone.

## Corrected

**ADR-0219's NOTE 5 is too strong, and this is the reading that changes.** That
record says §6.5.6's capacity arithmetic "already yields 0 for the admitted
case — the clause's arithmetic needed nothing; only the prohibition was
removed", which invites the conclusion that the standard would have allowed the
empty substring had it noticed. It would not. §6.8.6.5 and §6.8.8.4 give the
substring-function-access and the substring-constant a *length* rather than a
capacity, and a length of 0 is an ordinary canonical-string value — so in those
two clauses nothing in the type system forces the rule, **and the standard
states it there anyway** (D.86, D.91, in D.16's own words). The rule is written
three times: once where it is forced and twice where it is not. It is a
decision of the standard, not an artefact of the arithmetic. The dialect is
overriding a deliberate rule rather than filling a hole, which is a larger
claim and the honest one.

**Two errors in the brief the readers were given**, recorded because a briefing
error can steer an audit and this one did not:

- It said the conformance modes "stop the program at run time" for `s[4..3]`.
  Only `--std=extended` does. ISO 7185 has no substring notation at all —
  §6.5.1 lists four alternatives and none is a substring-variable — so
  `--std=iso7185` refuses at the parser, `expected ']' after a subscript,
  found '..'`. That is correct behaviour and the brief described it wrongly.
- It cited "§3.1's definition of error". In ISO/IEC 10206:1991 §3.1 is
  *Dynamic-violation* and §3.2 is *Error*; §3.1 is the error definition in
  ISO 7185 only.

## Unsettled

**Whether the dialect is where this had to go.** §5.1 g) offers a compliant
processor two treatments of an error, and g) 2) — leave it undetected and say
so in an accompanying document — is one of them. So a processor that returned
the null-string for `s[i..i-1]` **under `--std=extended`**, with a line in
`doc/implementation-defined.md` §3, would on the face of it still comply.
Trapping is the better choice under §3.2's NOTE 2, *"Processors should attempt
the detection of as many errors as possible"* — but "the conformance modes had
to keep the trap" is a project policy (ADR-0014) and not something §5.1
requires. No document here may claim otherwise. Recorded in `doc/sop.md` §7.

**Whether a multi-element character-string's type is right.** §6.1.9 says
unconditionally that a character-string of other than one element denotes a
value of the *canonical*-string-type; this compiler types `'hello'` as `packed
array [1..5] of char`, which is ISO 7185's rule. A reader tried four places to
distinguish the two readings — §6.4.5 d) compatibility, §6.4.6 f)'s
length-versus-capacity, §6.7.3.7.2's conformant arrays, and a `string`
schematic formal — and every one lands on the same observable behaviour. So it
is a labelling divergence that cannot presently be convicted, and a feature
able to observe a type's identity would turn it into a defect. Recorded.

**§6.7.3.2 and §6.7.3.7.2 contradict §6.4.3.3.3 for `p('')`.** The first two
require a formal to possess a type produced from `string` with the actual's
length as the tuple, or a fixed-string-type of that capacity; for `''` that
length is 0, and §6.4.3.3.3 and §6.4.2.4 say no such type exists. The compiler
resolves the two differently — the schematic formal accepts with capacity 0,
the conformant one refuses. Both are defensible readings of a hole in the
standard. No scenario may assert either, since the suite states what the
standard requires and this is what it does not.

## Found, and not fixed here

Three defects the audit turned up, none of them in the work it was auditing and
none blocking it. Each is its own change with its own test:

1. **UNDER-STRICT, and a real conformance defect.** §6.4.3.3.3 requires every
   tuple in `string`'s domain to have a component "greater than zero", and
   §6.4.8 makes it *"a dynamic-violation if the tuple is not in the domain of
   the schema"*. §3.1 permits a dynamic-violation to be left undetected "up to,
   but not beyond, execution of the declaration", and §5.1 f) NOTE 1 is
   explicit: *"Dynamic-violations, like all violations except errors, must be
   detected."* `procedure g(n: integer); var x: string(n)` called with 0
   produces a `string(0)` in silence, and with -1 is reported only incidentally
   by a later assignment. The static path is right — `var x: string(0)` is
   refused — so this is the dynamic discriminant path missing a check the
   static one has.
2. **OVER-STRICT.** A constant-definition may not be given a string-valued or
   string-compared expression. `doc/implementation-defined.md` recorded this
   for `substr` alone, with a reason that does not cover `('ab' = 'ab')` — a
   boolean — and that is false besides: `const c = ta[1: 'ab' + 'cd'; 2: 'xy']`
   is accepted and yields `abcd`, so the folder *can* produce a string
   constant. The document also claimed a diagnostic the compiler does not
   give, and no case pinned it. Both corrected in this change, with the cause
   now recorded as unknown rather than as something untrue, and
   `tests/extended/constexpr_errors.pas` extended to hold the four forms.
3. **OVER-STRICT, and the likeliest to bite.** Every real-valued
   constant-expression is refused, including §6.3.2's own worked examples
   `pi = 4 * arctan(1)` and `third = unity/3.0`. Already recorded in
   `doc/implementation-defined.md` §6 as a restriction; the audit adds that
   `trunc` and `round` yield *integers* and are refused too, in subrange-bound
   and case-constant position, which the recorded reason does not explain.

## On the readers' independence

**All four disclosed that the harness injected `CLAUDE.md` into their context
before they ran a command**, which is the limitation ADR-0107 registered and
which has not been fixed. Each said what it did about it; two deliberately
sought evidence the implementer could not have authored — the BSI DEVIANCE
headers — precisely because that is where anchoring would have mattered most,
and one noted that two of its findings cut *against* the injected framing. A
CONFIRMED verdict here therefore means "no independent oracle contradicts it",
not "an uninfluenced reader agreed". The disagreements remain the trustworthy
part.
