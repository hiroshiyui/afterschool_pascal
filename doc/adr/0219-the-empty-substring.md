# 219. The empty substring

Date: 2026-08-27

## Status

Accepted.

## Context

`lib/dialect/pasparse.pas` had this defect, in shipped and pushed code, from
the day the module landed:

```
$ ParseInt(' ')
runtime error: substring: [2..1] is not within a string of length 1
```

The routine trims blanks the obvious way — `while (length(b) > 0) and
(b[1] = ' ') do b := b[2..length(b)]` — and on a string of exactly one space
that last step is `b[2..1]`. ISO/IEC 10206:1991 §6.5.6:

> It shall be an error if the string-variable of the substring-variable is
> undefined, or if the value of an index-expression in a substring-variable is
> less than 1 or greater than the length of the value of the string-variable of
> the substring-variable, **or if the value of the first index-expression is
> greater than the value of the second index-expression.**

So there is no empty substring, and the ordinary way to drop a string's first
or last character stops the program on a string of one. The compiler is right
and the clause is explicit; this was checked against the standard's own text
before anything was written down, which is ADR-0214's rule at the first
opportunity to break it again.

**The finding is not new; the second sighting is.** ADR-0218 recorded it from
`lib/dialect/paslsp.pas`, where the line ending a frame's headers is exactly
one character — a bare carriage return — so `line[1..length(line) - 1]` is
`line[1..0]` and the server stopped on every message it read. That entry closed
with: *"Whether the dialect should have `s[i..i-1] = ''` is undecided and wants
a second sighting; one site is an anecdote."* The second sighting arrived the
next day, in a module written a week earlier by the same hand, and it had
shipped.

Three sites in this tree, three different treatments:

| Site | Standard | What it does |
| --- | --- | --- |
| `lib/pastext.pas`'s `TrimStart`/`TrimEnd`/`TrimAll` | Extended Pascal | finds the bounds, then builds the result a character at a time — never takes a substring at all |
| `lib/dialect/paslsp.pas`'s `ReadHeaderLine` | dialect | writes the length-one case out as its own arm |
| `lib/dialect/pasparse.pas`'s `ParseInt` | dialect | gets it wrong |

Every gate here passed. `line-coverage` counts a statement and the statement
ran; `heap-balance` reads no output and there was no heap; `difftest` skips a
dialect source; the golden agreed with a compiler that was correct. What found
it was reading the sweep for the shape after ADR-0218 named it.

**And the tree already answers the question the other way, twice.**

- §6.7.6.7's required function `substr(s, i, 0)` yields the null-string. That
  is *Extended Pascal's own* answer, for an operation that differs from
  `s[i..j]` in nothing but spelling — and `runtime/pasrt.c`'s
  `pas_str_slice_check` has `count < 0` as its error, not `count < 1`.
- ADR-0125's slice `a[i..i-1]` is the empty slice, and
  `tests/dialect/lib_io.pas` writes `buf[1..0]` today. The comment on
  `pas_slice_check` gives the argument in the sentence this record is named
  after: *"a loop that consumes a slice down to nothing should not have to
  special-case its last step."*

So `s[i..i-1]` was the **only bracketed range in the dialect that could not be
empty**, and it is the one whose emptiness a writer reaches for most often,
because a string is the thing whose last character one drops.

§6.1.9 makes `''` a character-string in Extended Pascal and §6.4.3.3.1 names
the null-string, so the *value* has been in the language throughout. What was
missing was a way to compute one with `[..]`.

## Decision

**Under `--std=afterschool`, a substring of no characters is admissible.**
§6.5.6's error conditions become, in AP 6.5.6:

- the string-variable is undefined; or
- the first index-expression is less than 1; or
- the second index-expression is greater than the length; or
- **the second index-expression is less than one less than the first.**

That is the standard's condition widened by exactly one value. `s[4..3]` is the
null-string; `s[4..2]` is still an error, so a transposed pair of indices is
still reported. The far end moves with it: `s[length(s) + 1 .. length(s)]` is
admissible and `s[length(s) + 2 .. length(s) + 1]` is not.

§6.5.6's own capacity — "one plus the value of the second index-expression
minus the value of the first" — is **already 0** for the admitted case. The
clause's arithmetic needed nothing; only the prohibition was removed.

**The conformance modes are unchanged.** §6.5.6 states the error and ADR-0014
makes an ISO error condition trap, so `--std=iso7185` and `--std=extended` go
on trapping. `tests/extended/trap_substring.pas` is the case, and it now has an
entry in `tests/checks/containment_exceptions.txt`.

**There is no new spelling, so ADR-0140 is not engaged.** This is ADR-0184's
shape taken one step further: that record admitted a record type at a position
the dialect already held and spelled nothing; this one changes when using a
construct **ISO/IEC 10206:1991 itself provides** is an error, and spells nothing
either. `grep '\.\.'` still finds it, because the construct is §6.5.6's.

## Containment

This is the first time the dialect has relaxed an **error condition** the
standards state about a construct they have, so the containment argument is
worth writing out rather than asserting.

ISO 7185 §3.1, and ISO/IEC 10206:1991 in the same words:

> **error** — A violation by a program of the requirements of this
> International Standard that a processor is permitted to leave undetected.

A program that writes `s[i..i-1]` is therefore *erroneous*. It is not a program
Extended Pascal accepts; it is one Extended Pascal declares to be in violation,
and about which it explicitly permits a processor to say nothing. ADR-0117's
containment is a claim about the programs Extended Pascal **accepts**, and no
valid Extended Pascal program's meaning changes here.

`tests/checks/containment_exceptions.txt`'s own bar — *"not 'the two runs
differ' but 'they differ and the difference is not something Extended Pascal
accepts'"* — falls on exactly that word, which is why the entry is admissible
under a rule written before anyone had this case in mind.

Note that the standard's permission runs the *other* way from what is being
taken here: it permits leaving the error undetected, and this does more than
that — it assigns the construct a meaning. That is a dialect's business and not
a conformance mode's, which is the whole of why the two modes keep the trap.

## Consequences

**The mechanism is one flag.** `pas_str_substr_check` gained a fourth
parameter, `emptyok`, in the shape `pas_read_str`'s `isvar` already uses; the
condition is `hi < (emptyok ? lo - 1 : lo)`. The comment above it argued the
opposite for as long as the function has existed —

> The two conditions differ at exactly the empty case, which is why they cannot
> be one function however alike they look.

— and that was true of two *functions* with two messages, and false of the
condition. With the flag set it is `pas_slice_check`'s condition character for
character. The two stay separate functions because a substring is not a
sequence of components and the messages must not say it is.

**The rule is written twice in the compiler and both had to move.** CodeGen
emits the check; `EvalConstAccess` folds §6.8.8.4's substring-constant and
carries the same three disjuncts in Pascal. `const e = g[1..0]` is admitted
under the dialect and refused under both conformance modes, and the node built
is a length-zero `nkStr` — which needed nothing, §6.1.9's null-string being
already typed there.

**Two callers were rewritten, and that is the evidence.** `pasparse.pas`'s two
trim loops are now the obvious four lines, and `paslsp.pas`'s carriage-return
strip is one statement instead of three. What came out with them is worth more
than the lines: `pasparse.pas` had carried a comment reconstructing an
invariant — *the leading loop leaves `b` empty or beginning with a non-space,
so the trailing loop never sees a length of one* — which existed only to
explain why the guard was needed in one loop and not the other. A reader had to
verify that to trust the code. Nobody has to now.

**`tests/checks/heap_balance.txt` and `line_coverage.txt` are untouched**: no
heap, and the compiler gained two statements that the new cases run.

## Alternatives

**Leave the language alone and write the guard at every site.** What the
previous day chose, deliberately, and what the second sighting overturned. The
cost is not the two lines; it is that the guard is *invisible when missing* —
the program compiles, the corpus passes, and the failure needs an input that
trims down to exactly one character. `lib_result.pas` tested `''` and
`'   123   '` and neither reaches it.

**Relax it to `hi < lo`, admitting `s[4..2]` as well.** Simpler to state and
strictly worse: a transposed pair is a real defect and this is the only thing
that reports it. Every scenario in
`tests/spec/features/dialect_substring_empty.feature` passes under that
relaxation but one, which is why that one is there.

**Make `substr(s, i, 0)` the way to write it and leave `[..]` alone.** It is
already available and works today. It reads worse at every site that has an end
index rather than a count — `substr(b, 2, length(b) - 1)` for `b[2..length(b)]`
— and it is a *required function*, so it is the answer that says the notation
the language provides for this is the one that cannot do it.

**Give the dialect a separate spelling for the empty case.** ADR-0140's test is
whether a conforming program could have written the spelling in that position,
and a conforming program can write `s[i..j]` for any `i` and `j` — so any new
spelling would be a second way to say a thing §6.5.6 already says, which is
what ADR-0184's "does the feature need a spelling at all?" asks first.

## What this does not do

It says nothing about **`succ`, `pred` or a `for` loop over an empty range**,
which are separate clauses with their own answers. It does not make a substring
assignable where §6.5.6 does not, and `s[1..0] := ''` is still governed by the
fixed-string store: a capacity of 0 takes the null-string and nothing else.

And it does not touch §6.7.6.7. `substr(s, i, 0)` was already the null-string
and remains so; what changed is that the two constructs of one standard now
agree, which is the disagreement that argued for the change.
