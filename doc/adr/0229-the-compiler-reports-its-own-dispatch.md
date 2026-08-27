# 229. The compiler reports its own dispatch

Date: 2026-08-28

## Status

Accepted. Replaces the case half of `kind-exhaustive`'s source parsing
(ADR-0145); the if-chain half of ADR-0221 still reads the source.

## Context

A case-statement with no matching label **stops the program** (ISO 7185
§6.9.3.5, ADR-0018), so a constant left off one is a crash and not a wrong
answer. No other oracle here can see that: a missing arm is not a statement, so
`line-coverage` cannot; a crash writes nothing, so no golden holds it; and
`src/`'s counterpart is a `switch` with a `default`, so difftest has one side
falling over rather than a disagreement. It has shipped twice — `tyString`,
then `tyOptional`.

`tests/checks/kind_exhaustive.py` has asked the question since ADR-0145 by
**parsing Pascal with regular expressions**, and `doc/sop.md` §7 already calls
the source-parsing oracle the weaker of the two. `doc/roadmap.md`'s v3 chapter
proposed the replacement and named the pattern this project had already found
three times and not generalised: `--dump-limits` (ADR-0148),
`--dump-predicates` (ADR-0194) and `--dump-layout` (ADR-0185) all work one way
— the compiler answers a question about itself, a catalogue holds the answers,
and a gate compares the two.

What the parser could not know is exactly what the compiler knows for nothing:
which types are enumerations, how many constants each has, and what a
selector's type actually is. It recognised an enumeration constant by a
**naming convention** — two or three lower-case letters then a capital — and a
routine by a header regex.

## Decision

`--dump-dispatch`. The compiler compiles as usual and then writes every
case-statement in the **compiled program** whose selector is an enumeration:

```
case <routine>:<enumeration>:<n> names <N> of <M> [otherwise] at <line>:<col> [missing <c> ...]
unused <enumeration> <constant>
```

It is an ordinary flag and works on any program, as `--dump-layout` does;
pointing it at `selfhost/compiler.pas` is what produces the catalogue.

Four decisions inside it are worth recording.

**The record is claimed on the way in and filled on the way out.** A nested
case-statement inside an arm finishes before its enclosing one does, so
appending on the way out numbers the inner site first. The catalogue keys an
entry by source order — the order a reader of the file sees — so the slot is
linked before the arms are walked. This was found by the cross-check below,
not by reasoning: the two readers agreed on every site and every count and
disagreed on the ordinals.

**The count comes from the label ranges, not from the arms.** A label may be a
range and every constant in it is named. `seenHead` is the list the
overlap check already builds, so the count is of *distinct* constants by
construction and no arm can contribute twice.

**The dump names the missing constants, not only how many.** The catalogue's
failure message has always said which constants an arm leaves out, and a
replacement that could only count would have made the gate worse while making
it sounder.

**The unused pass walks the declared enumerations, not the sites.** An
enumeration that no case-statement mentions has every constant unnamed and
appears at no site to be found at. `stdKind` is exactly that — dispatched by
`HasExtended`'s `>=` — and a first version walking the sites reported
`spPack`/`spUnpack` and silently lost `stdKind`'s three. So the enumeration
type-definitions are collected beside `--dump-layout`'s record ones, in the one
place that has the name as written beside the type it resolved to.

## Consequences

**Two independent readers agreed exactly, which is the evidence.** Before the
Python was touched, its answer and the compiler's were compared over
`selfhost/compiler.pas`: **60 sites, the same routine, enumeration and ordinal
for every one, the same `N of M` for every one, and the same missing constants
named for every one** — and the same five unused constants as the catalogue
holds. A regex parser and a compiler front end reaching the same answer about
36 000 lines is a stronger statement about both than either could make alone.
The one disagreement was the ordinal permutation above, and the compiler was
the one that was wrong.

**The gate keeps its output byte for byte.** *59 case-statements over 12
enumerations; 36 name every constant and 23 argue for a subset. 37 tag-dispatch
if-chains, 37 of them arguing for a subset.* The 59-against-60 is not a
disagreement either: a site with an `otherwise` is excluded from the total,
because `otherwise` discharges coverage.

**It still fails in every direction**, checked one at a time: a count that is
wrong, an entry struck for a case that names a subset, an entry naming no case,
an `unused` entry for a constant something names — and the scenario the gate
exists for, a constant added to an enumeration, which fires twice, at the case
that does not name it and again as unused.

**85 lines of Pascal-parsing regex are gone**, and with them `cases()`,
`labels()`, and the `CASE`, `VARIANT`, `LABEL` and `FRAGMENT` patterns. What
remains reading the source is `enumerations()`, which the **if-chain** half
still needs — ADR-0221's other half is not replaced here, and `TAGTEST` still
hard-codes `^.kind`, so a chain over any other field or enumeration is still
invisible. That is the next increment, not this one, and `doc/sop.md` §7 says
so.

**The gate now needs a built compiler** and skips with 77 without one, as
`buffer-headroom` and `predicate-kinds` do. In `ctest` the compiler is built
from `compiler.pas` before the tests run, so a stale answer is not a practical
risk; it is named rather than assumed.

**The catalogue is matched case-insensitively.** The lexer case-folds
identifiers and the pool holds the folded spelling, so the compiler answers in
lower case while `partial_cases.txt` is written the way the source spells a
name. Folding the keys is what lets the file go on being readable; the written
spelling is used in the messages wherever an entry exists.

**An enumeration with no type-definition is reported at its sites and not in
the `unused` list.** `var q: (alpha, beta, gamma)` is a type-denoter and not a
type-definition, so it never reaches the declaration list the `unused` pass
walks; the site line still names it — as `?`, having no name to print — and
still says which constants the labels miss. `selfhost/compiler.pas` declares
every enumeration as a type-definition, so the catalogue is unaffected;
`tests/dumps/dispatch.pas` carries one anyway, because the shape is legal and a
reader should see what the dump does with it.

**The coverage ratchet found dead code in this change**, which is worth
recording as the instrument working rather than as a defect avoided. The
routine's name was taken through a guarded `if currentProc <> nil` with
`programSym` as the fallback; `line-coverage` reported the fallback unreached,
and the corpus case showed why — a case-statement can only stand in a
statement-part, every one of those is inside a block, and the *program's* block
has a symbol like any other. The guard is gone and the reason is in its place.

**What a dump does not do is judge an arm.** `tyOptional: StaticThroughout :=
true` names the constant and is wrong, and this reports it as covered. Moving
the oracle out of a Python parser and into the compiler makes it exact about
*which* constants are named; it does not make it a proof that naming them was
right. ADR-0194 says the same of `--dump-predicates`, and the roadmap said it
of this proposal before it was built.

## Alternatives rejected

**Teach the Python parser more shapes.** That is what ADR-0221 did, and the
result is 542 lines shaped like the last defect it was taught about. Each
lesson makes the next one harder to see.

**Have the gate parse the IR instead of the source.** The IR has no
case-statements in it — a case is lowered to comparisons and branches — so the
question cannot be asked there at all.

**Report every dispatch, including the if-chains, in one go.** The right end
state, and the roadmap says so. An if-chain has to be *recognised* rather than
read: an if whose condition compares a tag against a constant of its type, and
whose else-part is another such if. That is a real piece of work and belongs
with its own evidence, not appended to a change whose case half can be proved
by comparison against the incumbent.
