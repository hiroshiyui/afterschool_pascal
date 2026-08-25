# 198. The kind a new kind resembles is the question, and a person names it

Date: 2026-08-25

## Status

Accepted. `predicate_kinds.py --like`, and what is left of ADR-0194's
"what this does not do".

## Context

ADR-0194 built `predicate-kinds` and wrote its own limit into the record:

> It does not see a predicate's callers. Whether `IsMemory` is asked in the
> right places is `predicate-callers`'s question from the other end, and
> neither gate covers the middle: a call site that asks the *wrong predicate*
> — which is what all three defects actually were — is visible to neither.

That sentence was left as a thing to think about rather than a thing to build,
and it is worth thinking about because the three defects it names are the whole
of what the text model cost in correctness.

**The shape they share is sharper than "the wrong predicate".** In each one a
guard asked a predicate whose answer for the new kind is **right**:

- `IsMemory` was `IsStructured or IsOwned or IsVarString`. `IsVarString` is
  false of a text and correctly so — §6.4.3.3.3's rules do not apply to one.
- The code generator's comparison dispatch asked `IsStringOrChar`. A text is
  neither.
- `EmitAssign` selected the string store with `IsStringType`. A text is not a
  string-type; `IsStringType 1 of 22` is a correct row.

So no catalogue over *answers* can see any of them, and `predicate-kinds` is
satisfied by exactly the row that hides the defect. What was wrong was the
**question**: each of those guards means "does this take the string path?" and
spells it as "is this a string?", which were the same sentence until a second
kind shared the representation.

## Decision

**Given the kind a new kind resembles, the rest is mechanical.**

Every predicate true of the old kind and false of the new one is a guard the
new kind falls *out* of, and each of its call sites is a question: does this
site mean the kind, or the path? `--like OLD NEW` prints that set and every
call site under it.

For `--like tyString tyText` it is **three predicates over 42 call sites** —
`IsVarString`, `IsStringType`, `IsStringOrChar` — and all three defects are in
the list. Checked against the tree as it stood rather than asserted: at
`26501d7`, the commit before the kind existed, `IsMemory`'s body read
`IsStructured(t) or IsOwned(t) or IsVarString(t)`, so it appears under
`IsVarString`; the comparison dispatch is `IsStringOrChar` at what is now line
28324; and `EmitAssign`'s guard is `IsStringType` at what is now line 30269.

**What cannot be derived is `OLD`.** Nothing in the compiler says a text
resembles a string. The two share a representation and share none of their
rules — which is the distinction ADR-0191 had to invent `IsStringRep` and
`IsVarString` to make — so deriving the resemblance from the representation
would be right here and wrong for a kind that resembles another in its rules
instead. It is a fact about *why the kind was added*, and the person adding it
knows it on the day. That is the whole of what this asks for.

**It is a query, not a gate**, and the record says so where a reader will meet
it. There is no answer to check: the output is a list to read once. It is
registered as a `ctest` case anyway, because ADR-0103 found four documented
`--dump` flags that no case had ever passed and a documented mode with no case
behind it is the same shape.

## Consequences

**`predicate-kinds`'s failure message names it.** The moment the gate fires is
the moment a kind was added, which is exactly when this question is worth
asking, and a tool nobody is pointed at on the day is a tool nobody runs.

**`doc/sop.md` §7 gains a row rather than losing one.** The middle is narrowed
and not closed: `--like` puts the call sites in front of a reader and has no
opinion about any of them, so a reader who scrolls past 42 lines gets the
defect. What it removes is the excuse that nothing could have listed them.

**§4a's corollary stands.** *A gate asks a question somebody thought of; a
client asks the questions a program asks.* This is a better-aimed prompt, not a
client, and the library increment is still what found the third defect. The
paragraph is amended to say the prompt exists, not to withdraw the lesson.

**Twenty-one gates, still.** `predicate-kinds-like` is a case behind a
documented mode and is not counted as one — a gate here watches a claim in both
directions, and this watches nothing.

## What this does not do

**It does not know which call sites are wrong.** All 42 are printed and none is
judged. Judging one needs the question the guard was written to ask, which is
in the author's head and sometimes in a comment.

**It does not fire on its own.** Nothing detects that a kind was added except
`predicate-kinds`' own `of N` moving, and nothing forces the pair to be named.
A kind added by someone who does not run it is a kind this record did not help.

**It does not reach a guard that asks no predicate.** A `case t^.kind of` with
the new constant missing is `kind-exhaustive`'s (ADR-0124, ADR-0145), and a
guard testing a *flag* rather than a kind — `t^.hiDisc = nil`, `packed` — is
neither gate's and remains unswept.

## Alternatives rejected

**A standing gate over every pair of kinds.** Twenty-one kinds make 210 pairs
and almost all of them are meaningless — a file does not resemble a set — so
the output would be thousands of call sites with no reason to read any of them.
Meaning comes from the resemblance, and the resemblance is what a person
supplies.

**Deriving the resemblance from the representation.** `IsStringRep` is true of
exactly `tyString` and `tyText`, so for this case a tool could have found the
pair itself. It would be an accident: ADR-0191's whole point is that
representation and rules are two questions, and a kind sharing another's
*rules* — an ordinal beside an ordinal, an affine kind beside an affine one —
would resemble it with no shared representation to detect.

**Listing every call site where the new kind answers `no`.** That is the
general form and it is useless: 36 predicates over roughly 600 call sites, of
which a new kind is false of most. The pair is what cuts 600 down to 42.

**Making it a gate with a catalogue.** A `like_baseline.txt` would record which
call sites exist and fail when one moved, which is a large standing cost for a
question that is asked once per kind — and it would fire on every ordinary edit
to any of the 42 lines. The catalogue that *is* worth keeping is
`predicate_kinds.txt`, and it already exists.
