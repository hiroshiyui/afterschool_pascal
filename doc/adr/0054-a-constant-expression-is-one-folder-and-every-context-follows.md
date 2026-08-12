# 54. A constant-expression is one folder, and every context follows

Date: 2026-08-12

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.8.2:

```
constant-expression = expression .
```

"The expression of a constant-expression shall be nonvarying and shall not
contain a discriminant-identifier." Nonvarying is then defined *negatively* —
an expression is nonvarying if it does not contain a variable-identifier, a
schema-discriminant, a bound-identifier or a field-designator-identifier; a
type-name denoting a type that is not static; or a function-identifier the
program declares, or `eof` or `eoln`.

ISO 7185 §6.3 gives a constant-definition a `constant` — a signed literal or
the name of another constant — and §6.4.2.4 says the same of a subrange bound.
So this is a change of language, not an addition to one, which is the shape
every feature since ADR-0033 has had.

## Decision

**There is one folder and every constant position follows.** `evalConst`
already served the constant definition and `evalOrdinal` — a thin wrapper on it
— already served subrange bounds, array bounds, case labels, variant labels and
a schema's discriminants. Adding the rest of the expression grammar to that one
function opened all six at once; not one of the callers changed except to say
less (below).

That is the whole reason the feature is small. It is also why it is worth
recording: a constant-expression *looks* like it belongs in six places, and the
reason it belongs in one is a decision made long before this record, when
`evalOrdinal` was written as a wrapper rather than as six ad-hoc checks.

**Folding is gated on the standard, in the folder.** Everything ISO 7185
admits — a literal, a name, a sign, `not` — is folded under both; `Binary` and
`Call` are folded only under `--std=extended`. The ISO 7185 diagnostic is then
unchanged, because the expression still fails to fold and the caller still says
what it always said.

**Only the exactly computable is folded.** What that leaves out is stated
rather than silently refused:

- **A real-valued constant-expression is refused.** ADR-0025 carries a real
  literal as its *source text* all the way into the IR — LLVM's assembler is
  the `strtod` — so the Pascal-hosted compiler has no floating-point value to
  fold with and no way to print one back. Giving it one would mean writing a
  decimal-to-binary conversion in Pascal whose last bits agreed with C's, and
  the two compilers would emit different constants the day they did not. The
  refusal has its own message, which says why.
- **Set- and string-valued ones are refused**, because a `Symbol` has nowhere
  to keep the value. `const s = [1..3]` and `const t = 'ab' + 'cd'` are legal
  Extended Pascal and are not accepted here.
- **The required functions that fold are ISO 7185's ordinal-valued seven**:
  `abs`, `sqr`, `odd`, `ord`, `chr`, `succ`, `pred`. §6.8.2 c) excludes `eof`
  and `eoln` by name and NOTE 1 excludes the ones taking a variable; the
  transcendentals are excluded for the real-valued reason above. The boundary
  is therefore the standard's own, minus one stated limitation.

**An error found while folding is a diagnostic, and the vaguer message is
suppressed.** `maxint * 2` in a type declaration is not a value to store and
trap on later — it is a mistake the compiler can see. Failing to fold has two
unrelated causes, though, and they want different words: the expression is not
constant (which the *context* describes — "the bounds of a subrange must be
ordinal constants") or it is constant and wrong (which only the folder can
describe). `constReported_` is which, and without it the second is reported
twice, once precisely and once vaguely.

**`succ` tests the end before it steps.** At `maxint` the step itself would
overflow, and the Pascal-hosted folder has no wider type to compute in and
range-check afterwards. Both compilers therefore ask the bound first — which
is also what the emitted code does, so a folded `succ` and a computed one
cannot disagree.

## Consequences

**The subrange lookahead had to grow, and that is the one place the parser
changed.** `looksLikeSubrange` distinguished `1..9` from a type name by looking
exactly two tokens ahead, which is all ISO 7185's one-token bound needs. With a
constant-expression the `..` can be anywhere, so under `--std=extended` the
scan runs forward for a `..` at bracket depth zero before the denoter ends. The
ISO 7185 path is untouched and still exact.

Only the denoters beginning with a name, a literal or a sign reach that
function at all — `array`, `record`, `set`, `file` and `^` are each decided by
their first token — which is what bounds the scan's risk.

**`verify/` gained nothing**, for the eighth record running, and here the
reason is worth stating: constant folding is not a *lowering*. It produces no
instructions, and what it must agree with is the emitted arithmetic it
replaces — `mod` non-negative, `odd` by the low bit, overflow refused rather
than wrapped. Those are already proved for the emitted forms, and the folder is
written to the same words. A rule restating them for the compile-time path
would prove the model twice.

**Four of the mutations escaped the first corpus, and one of them was a
lesson about negative tests rather than about folding.** The standard gate,
the non-negative `mod`, `odd`'s low bit and the subrange scan's bracket depth
each survived a green suite. Three were ordinary gaps — no program folded a
`mod` or an `odd` with a negative operand, and none reached a `..` inside
brackets. The fourth was not: `tests/constexpr_iso.pas` *did* hold a constant
definition ISO 7185 must refuse, but a subrange in the same file made the
parser abort first, and the parser stops at its first error where Sema
accumulates. Sema's half of that program was never compared. Splitting it into
`tests/constexpr_iso_fold.pas` is the fix, and the general rule is that a
negative test mixing two passes only ever exercises the earlier one.

**The seventh mutation was equivalent, and it says something about writing a
compiler in its own language.** `mod`'s non-negative adjustment survived being
deleted from `selfhost/compiler.pas` — because that compiler is written in
Afterschool Pascal, whose `mod` already *is* §6.7.2.2's. The C++ folder needs
`((a % b) + b) % b` and the Pascal one needs nothing, so the two are not
translations of each other here, and no test could ever have distinguished the
two spellings. The redundant form was removed rather than kept: a line no
oracle can defend is a line the next reader cannot trust either way.

**A real constant-expression is the one place the two compilers' capabilities
differ**, and the resolution was to refuse in both rather than fold in one. The
same trade decided the shape of the real-literal range check a commit earlier:
one rule both lexers can apply beats an exact rule only one of them could.

## What this does not do

**Real, set and string constant-expressions**, as above.

**§6.8.2's own words are not enforced directly.** The standard defines
nonvarying by what an expression may not *contain*, and this implementation
decides by what it can *evaluate* — which accepts the same expressions and
rejects a few for a different reason. A function call the program declared is
refused because the folder has no case for it, not because §6.8.2 c) names it;
the diagnostic therefore says "not a compile-time constant" rather than naming
the clause. Where the two would differ is a program that is nonvarying and
still unfoldable here, which is exactly the real/set/string list above.
