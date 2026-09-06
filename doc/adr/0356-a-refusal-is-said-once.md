# ADR-0356: A refusal is said once

Date: 2026-09-07

## Status

Accepted. Closes the `doc/sop.md` §7 row ADR-0355 opened, and changes five
diagnostic goldens by removing lines from each; nothing else moves.

## Context

ADR-0355's client found no compiler defect and one diagnostic cascade, in
two shapes.

**A schema whose binding failed became `^integer`.** A type-valued
discriminant that fails its bound is reported by `SatisfiesBound`, at the
type, in one line that says which type, which discriminant and which trait.
`BoundSchema` then answers nil and the pointer-domain path turns nil into
`intType` — the placeholder every one of Sema's 113 error paths leaves, and
the right one for a value the program went on to use. For a schema it was
wrong in a way no node could say: `InstantiateGeneric` bound `Ptr` to the
pointer, re-read `MapInit`'s body against `^integer`, and reported `tag values
are only for a pointer to a record with a variant part` and six `cannot
select a field of a value of type integer`, all located in
`pascontainer.pas`, then `this activation is what asked for that
instantiation`. A client that also puts and gets read a hundred lines about
a library it had not opened, after the one line that was the diagnostic.

**A refused instantiation was an unknown function.** `InstantiateGeneric`
answers nil only after reporting — a category, a bound, a type nothing
determined — and `CheckCall` then fell through to the trait-keyed scope and
the required identifiers, found nothing of that name, and wrote `unknown
function 'bigger'` under the line that had just spelled `bigger`. Four
goldens carried that pair, fifteen times between them, since generics landed;
the procedure-statement path never had it, reading nil as done.

The general shape is `nErrType`'s (ADR-0306): an expression node can say its
type is the placeholder an error path left and the assignment check keeps
quiet on it. A *type* could not say so, and a failed binding is where the
difference was paid.

## Decision

**A type carries the fact that it was refused.** `typeRec.isErrType` is set
on the pointer type a failed schema binding produces — `nErrType`'s twin, a
flag on the record rather than a kind of its own, which is `isText`'s shape
and `owns`'s and moves no gate's denominator. `InstantiateGeneric` refuses a
tuple holding one **without a word**, in the position the categories and the
bounds are checked and before either, because a category asked of `^integer`
would be a second message about a program nobody wrote.

**`CheckCall` reads nil from `InstantiateGeneric` as reported.** The name was
found and the call is not unknown; the node takes the placeholder every
refusal below it leaves, and the fall-through to the trait scope and the
required identifiers is not taken. This is what the procedure-statement path
already did.

**The client's own direct uses of the placeholder are unchanged.** `new(m,
8)` and `m^.cap` written in the program that failed the bound still report
against `integer`, as they do for every placeholder in the tree — the
unknown-domain probe cascades the same way today. Silencing those is a policy
over 113 sites and a different decision; what this one closes is the *body
of a routine the program did not write* being checked against a type the
program was already told it could not have.

## Consequences

Five goldens lose lines and gain none:

| Golden | Lines removed | What they were |
| --- | --- | --- |
| `tests/dialect/lib_container_bad_key.err` | 7 | the library's faults and the activation line; **one line stays** |
| `tests/dialect/traits_bad_bound.err` | 2 | `unknown function 'bigger'` under each bound refusal |
| `tests/dialect/generic_constraint_errors.err` | 6 | the same, under six category refusals |
| `tests/dialect/generic_infer_errors.err` | 3 | the same, under three "nothing in this call says" |
| `selfhost/badsema/generics.err` | 4 | the same, under four refusals |

Each removed line was checked, mechanically, against the golden it left: it
names the function refused on the same source line, or it is located in the
library, or it is the activation line. No golden gained a line, and no
message was reworded.

**Two mutations, two cases.** Reverting the `isErrType` arm in
`InstantiateGeneric` puts seven lines back in `lib_container_bad_key`;
reverting the `refused` arm in `CheckCall` puts `unknown function 'bigger'`
back in `traits_bad_bound`. Both are catalogued.

**The flag is set in one place and read in one.** A second producer of a
refused type — a plain application `bad: Box(Line, 2)` produces one today
and reports nothing after it because no body is instantiated against a
variable — would set it there; a second reader would be a check that today
cascades on the placeholder and has been decided, above, to go on doing so.

## What this does not do

It does not add a type kind. `predicate-kinds` and `kind-exhaustive` read
the enumeration, and a kind for "erroneous" would be a constant every
dispatch had to name for a type no lowering can be asked about.

It does not silence a *heading*. `InstantiateHeading` is not reached for a
refused tuple, so `type of m^.slots[1].key` against `^integer` is never
resolved; if a later shape reaches it, the flag is where to look first.

## Alternatives considered

- **Silence every report whose subject is a placeholder.** The 113 sites,
  each a decision about whether the program's own next line deserves its
  own message; the unknown-domain probe says the tree's answer is yes.
- **Return a real `Map(WordText, integer)` and let the body fail on
  `Hash`.** Two lines instead of seven, still located in the library, still
  about a program nobody wrote.
- **Report the cascade and the activation line, as before.** ADR-0355
  recorded it rather than fixing it, so that the case naming the fix existed
  before the fix; it is the case this record's mutation kills.
