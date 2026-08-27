# 230. The if-chain half moves to the compiler too

Date: 2026-08-28

## Status

Accepted. Completes what ADR-0229 began and narrows ADR-0221, whose "three
enumerations qualify" sentence is superseded by its own selection criterion —
see Decision. `tests/checks/kind_exhaustive.py` now
reads no Pascal at all.

## Context

ADR-0229 moved the **case-statement** half of `kind-exhaustive` onto
`--dump-dispatch` and left the **if-chain** half (ADR-0221) reading the source,
saying so rather than striking the row in `doc/sop.md` §7. What remained was a
regular expression, `TAGTEST`, matching the literal text `^.kind` — so a chain
dispatching on any other field, or on a record rather than through a pointer,
was invisible to it.

A chain is the *opposite* failure from a case-statement. A constant left off a
case stops the program (ADR-0018); a constant left off a chain takes the
trailing `else` in silence, which is what ADR-0220 cost.

## Decision

The compiler finds the chains, and the gate selects among them by a fact the
compiler reports.

**A chain is a shape, not a node.** There is no if-chain in the tree — only an
if whose else-part is another if. So Sema records *every* if-statement, with
its else-part, and separately every **tag test**: a comparison of an
enumeration-valued expression against a constant of its own type, keyed by the
if whose condition held it. A head is then an if that is no other if's
else-part, and the chain is what the else-parts reach from it. Recording every
if rather than only those holding a tag test is what makes
`if a then … else if e^.kind = nkVar then …` come out as one chain: its head
dispatches on nothing.

**A condition is one expression however it is spelled.** The collector walks
through `and`, `or`, `and then`, `or else` and `not`, so
`if (e^.kind = nkStr) and IsChar(t)` yields one test and
`if (a^.kind = nkVar) or (a^.kind = nkField)` yields two. Exactly one side of a
comparison must be an enumeration constant: `nkVar = nkStr` compares two
constants and dispatches on nothing.

**The dump reports the field each chain reads, and that is what selects a
tag dispatch.** `chain <routine>:<enum>:<n> on <field> names N of M`. The gate's
`TAG_FIELD` is `kind`, so `e^.kind = nkVar` is a value asked for its own kind
and `t = tkSemi` is a lookahead asking whether a token happens to be a
semicolon. ADR-0221 chose that scope by matching `^.kind` in the text and so
selected it *by accident*; this keeps the scope and states it. The compiler
reports all 70 chains it finds, over seven enumerations; the gate holds the 42
reading a tag to account.

**ADR-0221 gives two criteria and they disagree; this follows the stated one.**
It says a chain is selected "by the shape of its conditions and by nothing
else: `<expr>^.kind = c`, a value asked for its own tag" — and then, four lines
later, "three enumerations qualify today: `nodeKind`, `symKind`, `typeKind`".
Selecting by the field admits one chain that list excludes:
`LexIdentOrKeyword`, which reads `tok[tokCount].kind = tkAnd` to join
ADR-0038's `and then`. That is a stored token asked its own kind, not a
`Check(tkOf)` lookahead, so it satisfies the criterion; it failed the list only
because the regex required a *pointer* dereference and a record field is not
one. The list was a description of what the old reader could see, written down
as though it were the rule. The criterion is kept and the list is not, which is
the kind of thing this migration exists to expose. It costs one catalogue entry
and the entry says why the other 76 token kinds have nothing to do there.

That split was put to the author as a choice — hold all 70, or keep the scope
and report the rest — and keeping the scope was chosen. The 28 it leaves are
parser lookahead ladders and dispatches on `clBuiltin`, `bnOp` and `pcStd`;
demanding a catalogue argument for each would have added 33 entries mostly
saying "a lookahead deciding between N shapes", which dilutes a catalogue the
way a restated `verify/` rule dilutes "no known gaps".

**The dump also reports the declared enumerations and their sizes**, so it
describes its own denominator and the gate needs no other source of truth about
what an enumeration is.

## Consequences

**The regex found 38 chains; the compiler finds 42 reading a tag, and misses
none of the 38.** The three extra on enumerations the regex was already looking
at are the interesting ones — `CheckArguments`, `CheckForeignHeading` and
`ResolvePendingPointers`, each a real dispatch on `symKind` that the text match
did not see, because the arms read `.kind` of a record or sit further apart
than its eight-line window. So the replacement is not merely broader in scope;
it is more accurate *within* the old scope.

**Five new catalogue entries**, each with its own argument: the lexer's
`and then`/`or else` join (ADR-0038), the pointer-domain resolution, the two
variable-parameter faults, the `external` heading's two refusals, and — fairly
— the walker this record adds, whose own chain over `nodeKind` names the two
node kinds a condition can be built out of.

**`kind_exhaustive.py` is 542 lines and now 384**, and reads no Pascal:
`cases`, `labels`, `chains`, `enumerations`, `strip`, `word`, and the `CASE`,
`VARIANT`, `LABEL`, `FRAGMENT`, `CHAIN_IF`, `CHAIN_ELIF`, `THEN`, `TAGTEST`,
`CONST`, `ENUM` and `HEADER` patterns are all gone. `SOURCE` survives as the
path handed to the compiler. `doc/sop.md` §7's row about gates that read the
compiler's source now names only `reserved_words.py`.

**The gate's output is unchanged but for the chain count**, 37 becoming 42, and
it still fails in both directions on a chain: a count that moved, and an entry
naming no chain.

**The coverage ratchet found two gaps in the corpus, not in the compiler**, and
both were closed rather than accepted: no case had two chains over one
enumeration in one routine, so the ordinal counter was never exercised, and
none put a tag test under `not`. `tests/dumps/dispatch.pas` has both now.

**What is still not judged is whether an arm is right.** The dump is exact
about which constants a chain names; it says nothing about whether naming them
was correct, and a bare `else` still catches what nobody considered. That limit
is ADR-0124's, ADR-0194's and ADR-0229's, and no dump lifts it.

**A chain naming one constant of a type is not reported.** One test is a
question, not a dispatch — the rule the regex had, kept deliberately, because
two is the smallest thing a reader could have got wrong by leaving a third off.

## Alternatives rejected

**Hold all 70 chains to account.** The philosophically consistent option: the
catalogue is exactly where "this chain is not meant to be exhaustive" belongs.
Rejected on the author's decision, and the cost is real — 33 further entries,
most of them one reason repeated.

**Select the tag dispatches by the enumeration rather than by the field.** It
would have given roughly the same set today and for the wrong reason: what
makes a chain a dispatch is that it asks a value for its own kind, not which
enumeration the value belongs to. `tokenKind` appears on both sides of the
line — `tok.kind = tkAnd` is a tag test and `t = tkSemi` is not.

**Keep recognising chains in the gate, and take only the enumerations from the
compiler.** Half a migration. The regex's blind spots are in the chain
recognition itself, which is what the three missed `symKind` chains show.
