# 178. `try` is propagation, and a required identifier

Date: 2026-08-24

## Status

Accepted. AP 6.8.9, an amendment to 6.9.3.11.3, a row in Annex B, C.10, E.10
and a row in Annex F.

## Context

ADR-0176 gave the dialect `T ! E` and closed on the one thing it does not have:
**propagation**. ADR-0177 then gave it `exit`, because propagation needs a way
out of a block that is not the end of it and neither standard has one.

So this record answers the two questions `doc/roadmap.md` said were open and
ADR-0177 did not touch:

1. what the enclosing function's result type must be for the cause to be
   assignable to it; and
2. whether a spelling exists that a conforming program could not have written
   in that position.

The first turned out to be already decided. The second is **no**, and that is
the finding: ADR-0176 sketched `try X` by ADR-0140's statement rule, and the
sketch does not survive contact with a *factor*.

## Decision

**`try(x)` yields the value of a fallible x where x succeeded; where it did
not, the cause is assigned to the enclosing function's result and that
activation terminates.**

```pascal
function readConfig(path: PathName): TextResult;
var body: string(4096);
begin
  body := try(PasFS.ReadAll(path));       { or leave, with the cause }
  readConfig := parse(body)
end;
```

### 1. It is a required function-identifier, because no position would serve

ADR-0140's rule is that a dialect construct is spelled where a conforming
program could not have written it, and ADR-0177 established the second shape
for when that fails: a required *identifier*, nobody's under a conformance
mode and shadowable by §6.1.3. `int64`, `argcount`/`argument` and `exit` are
the first three; `try` is the fourth, and the first for which the failure of
the position rule was **measured rather than assumed**.

ADR-0176 sketched the spelling as `defer`'s: "`try` followed by a token that
begins an expression is a construct no conforming program can write". That is
true of a *statement*-initial identifier, where the six tokens that may follow
one are `(`, `:=`, `[`, `.`, `^` and a terminator. It is false of a factor. A
factor may be a variable-access, so a conforming program that declares `try`
may write

    try (x)      try [x]      try + x      try - x      try.f      try^

and mean something by each. Only an operand beginning with an identifier, a
number, a character-string, `nil` or `not` would have been unambiguous — which
is not a rule about a construct but a rule about six of its operands, and a
diagnostic nobody could act on.

So the parentheses are not decoration; they are what makes the construct
writable at all. And a function-designator is what Pascal spells an operation
on a value as, which is the second reason to be content with it: `try(x)`
stands beside `ord(x)` and `succ(x)` rather than beside a punctuation mark.

### 2. The result requirement is *the assignment's*, and nothing new

The cause-type must be assignment-compatible with the enclosing function's
result-type. That is the whole of it, and it is not stated anywhere in the
implementation: Sema writes an assignment and hands it to
`CheckResultAssign` — ADR-0177's routine, the one place `f := e` and
`exit(e)` already agree.

Three things follow that would each have been a rule if the question had been
asked separately:

- where the result is a fallible-type, AP 6.4.13.3's shorthand picks the cause
  arm;
- where the result **is** the cause-type, the cause is assigned directly, so
  `function why: Reason` is a legal home for a `try`;
- where it is neither, the program is refused by the message any unassignable
  result is refused by — *cannot assign reason to a result of type colour*.

The enclosing function's result therefore does **not** have to be fallible,
which was the shape the question presumed. Roadmap question 1 dissolves rather
than being answered.

### 3. The husk is three nodes and a binding

ADR-0044's husk again. Sema writes what the construct means and CodeGen emits
it in order: the tag to test, the assignment to make where it is false, and
the value to yield where it is true.

The **binding** is the one mechanism a reading would not have predicted. All
three of those read the operand, and a function-designator written three times
is three calls — which is 6.8.9's NOTE 4 and the difference between this
construct and the expansion a reader writes for it. So the operand is
evaluated once into a frame slot holding its address, and that is a `with`
statement's binding: `AddHiddenVar(..., skVarParam, ...)` in Sema and
`EmitWith`'s three lines in CodeGen, both unchanged.

Everything downstream then needed nothing. A value-type that is a string, an
array or a record travels by address (ADR-0017), and what a `try` yields is a
*field of a record* — so `EmitString`, `EmitAddress` and whole-value
assignment each answer for it through the path they already had.

### 4. The lowering is `exit`'s branch, factored

`EmitLeaveBlock` is the three lines ADR-0177 wrote, now called from two places:
claim the epilogue's block number on first use and branch to it. The caller
opens what comes next, because the two want different things — an
exit-statement wants a fresh unreachable block for the statements after it, and
a `try` wants the block its value is read in.

**No CodeGen mechanism is new.** A branch in the middle of an expression is
what `and then` has emitted since ADR-0010, and a forward-referenced label is
what textual IR admits and an instruction list would not (ADR-0025).

### 5. A deferred statement may not contain one

6.9.3.11.3, for the exit-statement's reason: the deferred statement is emitted
in the block's runner as well, and the runner is not the activation a `try`
would leave.

It is asked of a **count of enclosing defer-statements** rather than by
`CheckDeferBody`'s walk, because that walk visits statements and this is an
expression — no walker here descends into one. Two mechanisms for one clause,
and the clause now says so in one place: 6.9.3.11.3 listed three items and its
own NOTE in 6.7.5.9 claimed four, so a processor reading only the numbered
requirements would have been right to allow an `exit` there. That is fixed
here — 6.9.3.11.3 lists all five and the two later clauses cite it rather than
the other way about — and it is Annex E.10, the first divergence recorded
there between two clauses of the specification rather than between it and a
standard. The mechanism deserves the sentence it gets there: a NOTE may cite,
and nothing checks that what it cites says what it claims.

## Consequences

- **What it completes.** Error handling. `T ! E` (ADR-0176) says what a
  failure is, `exit` (ADR-0177) is how a block is left, and this is the
  construct that connects them. The library's `XOr`/`ResultText` conveniences
  are what a caller reaches for *instead* of propagating; both now exist.
- **What it does not do.** No flow-sensitive narrowing — `if r.ok then r.val`
  still checks the tag at the read, as ADR-0176 and ADR-0123 both decline. No
  requirement that a caller propagate or check. No `catch`: there is nothing to
  catch, a cause being a value and not an exception, and 6.9.3.11's NOTE 4
  already says a deferred statement has nothing to report to. And **it does not
  detect a function whose only assignment to its result is a `try`'s** — Annex
  C.10, which is C.9 reached by the other door.
- **The redundant tag check is deliberate.** The two field reads carry
  ADR-0118's variant check, and neither can fire: each is emitted on the branch
  its own arm is active on. Suppressing them would put a second opinion about
  the tag beside the one the branch already is, and `-O2` folds them against
  the branch that dominates.
- **Gates it moves**: `kind-exhaustive` (one constant, five entries — and the
  interesting one is that `biTry` is deliberately left *out* of EmitCall's
  three fallback lists, whose bodies are `eq`, `undef` and a zero: an unnamed
  constant stops the compiler where it happened, a named one emits a fallback
  in silence), `annex-b` (a row and two cases), `containment_exceptions.txt`
  (a ninth), the spec's clause table and triage, and `predicate-callers` not at
  all, which is a decision and not an omission. `CheckTry` is not a caller of
  `Assignable`: it calls `CheckResultAssign`, whose position that gate already
  has. Adding a `try(u)` position would have *passed* — the five type spellings
  the gate offers are none of them fallible, so every probe would be refused by
  6.8.9.2 rather than by the predicate under test, which is the shape ADR-0177
  spent six lines removing from the gate rather than adding to it. And the
  refusal is proved rather than observed: 6.4.13.1 already refuses a
  fallible-type whose side contains a file or a handle, so no operand carrying
  one can reach the assignment at all.
- **`difftest` cannot see it**, `src/` being frozen at the conformance surface
  — but the *refusal* is on that surface and needed nothing, for ADR-0177's
  reason: the name is nobody's under a conformance mode, so both front ends
  already say *unknown function 'try'*.

## Mutation

Five, each a different line of the design, and each killing a different case.

- **The binding removed**, so each of the three husk reads addresses the
  operand itself: `try` prints `7 2` for the evaluated-once scenario — the
  operand called twice — and `dialect_try.feature`'s "the operand is evaluated
  once" fails. The behaviour cases stay green, which is why that scenario was
  written.
- **`EmitLeaveBlock` replaced by a branch to the continuation**, so a cause
  falls through instead of leaving. `try` **stops the program** — *variant: the
  tag selects another arm* — because the read of `val` is now on a path where
  the tag is false, which is the redundant check under Consequences turning out
  not to be redundant against this mutation. That was not the predicted kill
  and is the better one: a wrong answer would have needed the golden to notice
  it, and this needs nothing.
- **The assignment not emitted** (`EmitAssign(e^.clFail)` dropped): `try`
  answers `doubled 2x: value 0` where `cause 1` is right — the transfer works,
  the cause is lost, and the tag says the wrong thing about it. ADR-0177's
  second mutation met again one construct along.
- **The `deferDepth` refusal removed**: `try_errors` loses a diagnostic, and
  what it stops being is a compile-time error — the program then fails at the
  assembler with a branch to a label the runner does not define.
- **The dialect gate widened to `HasExtended`**: `try_refused` is *accepted*
  under `--std=extended`, which moves the conformance surface — the one thing
  ADR-0117 does not allow.

## Alternatives considered

- **`X?`, Rust's spelling.** A postfix `?` is a character neither standard
  admits, so it passes ADR-0140's position test where `try X` fails, and it is
  the terser construct. Rejected on two counts. It is **unshadowable**: a
  character taken is taken from every program, where a required identifier
  costs only a program that does not declare its own, and containment is the
  property this dialect is most careful about. And it is invisible: a
  single character at the end of a long line is where a Pascal reader does not
  look, and this construct is a *transfer of control*.
- **`try X`, ADR-0176's own sketch.** Refused by the operand analysis in §1.
  Recorded because it was written down as decided and was wrong, which is what
  a "next record, sketched" section is for.
- **A statement, `try f(x) else …`.** Rejected: it would be a second
  if-statement, and the whole value of this construct is that it is an
  *expression* — `a := try(f) + try(g)` is one line where the statement form is
  six.
- **Requiring the enclosing result to be a fallible-type.** Rejected once §2
  showed the assignment already decides it. It would have forbidden
  `function why: Reason`, which works and reads well.
- **Suppressing the two tag checks.** Rejected under Consequences.
- **A `catch` or an `otherwise` arm on the construct.** Rejected: a cause is a
  value, so what a caller does with one is an ordinary `if r.ok`. Adding a
  second way to write that is what ADR-0141's four shapes exist to avoid.
