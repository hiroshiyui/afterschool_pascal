# ADR-0145: Every enumeration, not only the type kinds

Date: 2026-08-21

## Status

Accepted. Extends ADR-0124, which built this gate for one enumeration and left
eleven; closes the `doc/sop.md` §7 row that has carried them since.

## Context

ADR-0124's argument was that a Pascal case-statement with no matching label
**stops the program** (ADR-0018), so a constant left off one is a compiler
crash rather than a wrong answer — invisible to every other oracle here,
because a missing arm is not a statement for `line-coverage` to count, a crash
writes nothing for a golden to hold, and `src/`'s counterpart is a `switch`
with a `default`, so difftest has one side falling over rather than a
disagreement.

It shipped twice in one routine. `StaticThroughout` named fifteen of sixteen
type kinds and omitted `tyString`; ADR-0123 added `tyOptional` and it crashed
again, with all 578 cases, difftest, irtest, verify, `llc` and the BSI suite
green.

The gate ADR-0124 wrote reads `typeKind` and nothing else. §7 has said since:

> The **other** enumerations are still swept by hand. They are less exposed in
> practice: the parser and both walkers enumerate the node kinds in long label
> lists, and this compiler rejects a duplicate label at build time, which is
> what caught two of them during ADR-0123. That is an accident of how those
> lists are written and not a check. Extending the gate is cheap and is not
> done.

`compiler.pas` has **twelve** such enumerations — `tokenKind` (79 constants),
`ctxKind` (78), `nodeKind` (59), `builtinKind` (40), `binaryOp` (20),
`stdProcKind` (19), `typeKind` (19), `symKind` (12), `labelWhat` (4),
`fileBinding` (4), `unaryOp` (3), `stdKind` (3) — and 54 case-statements over
them.

## Decision

**Read every enumeration, and require a case-statement over one to name every
constant or to argue for the subset.**

Both halves of the question come from the source. An enumeration is any
`name = (c1, c2, ...)` whose every constant is a lowercase tag and a capital —
this compiler's own convention, and what lets a label name its enumeration
without a symbol table. A case-statement is `case <expr> of`, with its labels
collected at its **own** nesting depth so a nested case is not credited to the
one containing it, and with a **variant part** excluded: `case kind: nodeKind
of` is not a statement, and §6.4.3.3 already requires its labels to be exactly
the tag-type's values (ADR-0096), which is the stronger check.

A case-statement with an `otherwise` is total by construction (§6.9.3.5) and is
required to name nothing.

### The catalogue is a pair of numbers

23 of the 54 name a subset on purpose, and each is one line of
`tests/checks/partial_cases.txt`:

```
EmitStdProc:stdProcKind:1 names 17 of 19
```

keyed by routine, enumeration and which case in that routine — line numbers
churn and a key must not. **The denominator is what pays.** When a constant is
added to an enumeration, every partial case over it becomes `17 of 20` and
fails, which is precisely the moment `tyString` and then `tyOptional` needed a
reader and did not get one. A case that names every constant needs no entry and
is simply required to go on naming every one.

A second entry form, `enumeration:CONSTANT unused`, records a constant no
case-statement names at all. There are five, and they are not an oversight:
`stdKind`'s three are **ordered rather than dispatched** — ADR-0117's
containment *is* that order, and every one of the forty sites asking "does this
mode have Extended Pascal?" goes through `HasExtended(s)`, which is
`s >= stdExtended`. A case-statement over the standard is the thing that
predicate exists to prevent. `spPack` and `spUnpack` are compared with `=`,
because the difference between them is a direction and not a dispatch.

The bar for an entry is `unreachable_diagnostics.txt`'s: not "I could not make
it crash" but "no program can reach this arm", naming the guard.

## Consequences

It fails in five directions — an exhaustive case that stops being exhaustive, a
partial case with no entry, an entry whose case is now exhaustive or gone, an
entry whose numerator or denominator moved, and a constant nothing names.

Three mutations, each killed, and the third is the one no gate could see
before:

| Mutation | What fails |
| --- | --- |
| `StaticThroughout` loses its `tyOptional` arm — the historical bug | `names 18 of 19 ... missing tyOptional` |
| `typeKind` gains a constant | every case over it, by name |
| `stdProcKind` gains a constant | `partial_cases.txt:113 says ... names 17 of 19; it names 17 of 20 — the enumeration grew and this case did not` |

It found one omission on its first run, and it is small: `WriteOperator`'s
catch-all list means to name every token kind and had lost `tkRestricted`. It
is unreachable — `DumpTokens` routes exactly 25 operator tokens to it and
writes `restricted` itself, §6.4.2.5's spelling being one character too long
for `kwLit` — so nothing could have crashed. The label is added anyway, which
turns "a reader can see it cannot happen" into an invariant the gate holds.

### What it does not do

It does not judge whether an arm is **right**, or whether a subset is the right
subset. `tyOptional: StaticThroughout := true` satisfies this gate and is
wrong. The claim is that every constant was considered somewhere, which turns a
crash into a review — the same claim ADR-0124 made, over twelve enumerations
instead of one.

It also reads the *source* rather than asking the built compiler, which is the
weaker of the two oracles this repository has and is a row of its own in
`doc/sop.md` §7. There is no alternative here: a crash on a case-statement is
not a question a program can be written to ask, since the arm that is missing
is the one no program reaches.

### Rejected: requiring every case-statement to be total

The rule "no case-statement without an `otherwise` may name a subset" is
mechanical and needs no catalogue. It was rejected because 23 of the 54 here are
partial for good reasons that would have to be written as `otherwise` arms doing
nothing, and an `otherwise` that does nothing is exactly the C `default:` that
made this class of defect invisible to difftest in the first place. The
catalogue keeps the crash, and adds a reader.
