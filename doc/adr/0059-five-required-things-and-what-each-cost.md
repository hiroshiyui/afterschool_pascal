# 59. Five required things, and what each cost

Date: 2026-08-12

## Status

Accepted.

## Context

ISO/IEC 10206:1991 adds a number of required identifiers and one operator that
ISO 7185 has not, each too small to be a feature and too separate to be part of
one. Five of them land together here:

| Clause | Thing |
| --- | --- |
| §6.4.2.2 d) | `maxchar` — the largest value of char-type |
| §6.7.5.7 | `halt` — "no further processing ... shall occur" |
| §6.7.6.3 | `card(x)` — the number of members of a set |
| §6.7.6.4 | `succ(x, k)` and `pred(x, k)` |
| §6.8.3.4 | `><` — the set symmetric difference |

ADR-0033 said every Extended Pascal feature gets a record even when it decides
nothing a later feature has to live with, so that the language's growth reads
end to end from `doc/adr/`. This is that record for a batch.

## Decision

**`><` is an adding-operator and one instruction.** §6.8.3.4 puts it beside the
`+` and `-` that are already union and difference on sets, and it lowers to
`xor` for the same reason those lower to `or` and `and not` (ADR-0028). It is
the one adding-operator with no numeric reading at all, which is the only line
Sema needed.

**The lexer decides which standard has it, not the parser.** Under ISO 7185 the
two characters can only be `>` followed by `<`, which no expression admits —
`a > <b` is not a program — so joining them there would turn one clear
diagnostic into a cascade. This is the same argument ADR-0036 made for a
non-decimal literal being consumed and then refused.

**`card` is a population count**, and §6.7.6.3's "it shall be an error if no
such value of integer-type exists" cannot arise: every set is one 256-bit word
(ADR-0028), so the answer is at most 256. It is gated on the standard where the
*call* is checked, beside the complex and string functions, because the name is
a required identifier and a valid ISO 7185 program may declare its own.

**`succ(x, k)` widens in i32 and range-checks.** The one-argument form tests
one end (`a = ordinalHi`) and steps; the two-argument form cannot, because
`ord(x) + k` may leave the type in *either* direction and by an arbitrary
amount. So the ordinal is widened to i32 first, the sum is compared against
both ends, and only then narrowed back — the arithmetic must not wrap before it
is looked at. §6.7.6.4 defines `pred(x, k)` as `succ(x, -(k))`, and this
subtracts rather than negating, which is the same thing without the
`-maxint..maxint` edge case negation would have.

They are the only required functions whose arity is not exactly one, so the
arity gate says so rather than being restructured.

**`halt` is a required procedure that takes no arguments**, which makes it the
one that must be answered *before* `emitStdProc` takes the address of its first
one. The runtime closes every open file and exits zero: a halt leaves every
block on the way out without running its epilogue, so those files are closed
through the open-file list instead — the same obligation ADR-0032's non-local
`goto` discharges, and through the same list, because "still open" and
"abandoned" are the same set once nothing further will run. §3.6's normal
termination is a zero status; a halt is not an error.

**`maxchar` is 255**, because a char is a byte (ADR-0021), and it is declared in
the outermost scope like `maxint` — where a program may shadow it — rather than
being a word-symbol.

## Consequences

`verify/` gained nothing and no existing lowering changed.

**Four of the five reserve nothing.** `maxchar`, `halt` and `card` are required
identifiers, so `tests/required_iso.pas` is a legal ISO 7185 program that
declares its own `halt` and `card` and uses `maxchar` as a variable name.
`><` reserves nothing either, for the lexical reason above.

**Two enumerators had to be placed to match, not to read well.** The AST dump
prints a builtin and a required procedure as their *ordinal*, so `Builtin::Card`
and `StdProc::Halt` must sit at the same index in both compilers. Each was
inserted where it read best in C++ and at a different point in Pascal, and
`difftest` reported it as a number one apart. That is the cheapest possible
form of that mistake and it happened twice in one change.

**The batch found no bugs**, which is worth recording because the four features
before it each found one. These are all *additions* — nothing existing computes
differently — and that is the difference.

### What this does not do

The remaining small items from the same list are not here: `minreal`,
`maxreal` and `epsreal` (§6.4.2.2 b)), the time procedures (§6.7.5.8), zero and
truncating field widths (§6.10.3.6), and set-member iteration.

The three real constants are the interesting omission. ADR-0025 carries a real
literal as its *source text* all the way into the IR, and the Pascal compiler
has no float to make one with — so a required real constant has to arrive as
interned text rather than as a value, which is a different mechanism from the
one `maxint` and `maxchar` use. That is a small piece of work and it is not
done; the same reasoning is why ADR-0054 refuses a real-valued
constant-expression.
