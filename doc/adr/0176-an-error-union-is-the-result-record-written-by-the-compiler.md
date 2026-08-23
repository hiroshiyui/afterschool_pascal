# 176. An error union is the result record, written by the compiler

Date: 2026-08-24

## Status

**Accepted.** AP 6.4.13, and a row each to Annexes B and F.

Written as **Proposed** first, before the implementation, which is what
ADR-0001 asks for — and the implementation then changed two of its decisions.
Both changes are recorded in place, marked *revised*, rather than smoothed
over: the point of writing a record before the work is to be able to see what
the work taught.

This record is written before the decision, which is ADR-0001's rule — a record
written afterwards justifies rather than explains. Three choices in it are
genuinely open and are named at the end.

## Context

`doc/roadmap.md`'s borrowings table calls error unions **the biggest practical
gap**, and with `defer` landed (ADR-0175) they are the last of the two items
that "cover most of what daily practical development means" without settling
the memory-safety fork.

**What is already decided, and is not the gap.** ADR-0118 makes a variant
record's tag authoritative in the dialect: writing a field activates its arm,
reading an inactive one stops the program. ADR-0120 built the library's failure
reporting on exactly that, and ADR-0141 wrote down the rule for choosing
between the four shapes. The semantics are good and nothing here proposes to
change them. `tests/dialect/trap_result_unchecked.pas` is the property in one
program: a caller who does not look is stopped rather than handed a stale
value.

**What the gap actually is, measured.** ADR-0120 §3 says the shape "is a
convention, not a type, and it cannot be otherwise", because with no generics a
payload type is part of the layout. Six years of that convention is six
declarations. Surveyed on 2026-08-24, `lib/dialect/` holds:

- **six result records** — `PathResult`, `FdResult`, `CountResult`,
  `IntResult`, `RealResult`, `RunResult` — in five modules, answered by twelve
  exported routines. Thirty lines of declaration, byte-identical but for the
  payload, plus twenty-one lines of comment saying in four different sentences
  why they must be written six times, plus a seventh copy of the shape quoted
  as prose in `lib/dialect/README.md`.
- **three spellings of the error field**: `code` four times, `openCode` in
  `FdResult`, `reason` in `RunResult`. ADR-0141 fixed the *tag* at `ok` and
  said the payload carries each record's own name; nothing fixed the other
  side, and it drifted.
- **one outright collision**, which is the sharpest evidence here.
  `RunResult.code` is the *success* payload — a process exit status — while
  `r.code` in the four other records is the `ErrorCode`. Two of the library's
  own result records give the same field name opposite meanings, and a reader
  of `lib_process.pas` beside `lib_path.pas` has to know which.
- **second-order duplication**: four `XOr` bodies identical modulo names, two
  `ResultText` bodies, and two doc comments that are byte-identical.
  Neither convenience exists for `FdResult` or `RunResult` at all, because
  each has to be written by hand and nobody did.
- and at the call sites, **a renderer per record per program**:
  `tests/dialect/lib_io.pas` declares three of them — `said`, `got`, and an
  inline five-line early exit — for one test.

So the gap is not safety and not expressiveness. It is that **the language
makes the author write, and name, the same type six times**, and the naming has
already gone wrong once in a way a reader can be caught by.

## Decision (proposed)

**`T ! E` denotes the record ADR-0120 tells you to write, with the field names
fixed by the language.**

```pascal
type IntResult = integer ! ErrorCode;      { was five lines }

function ParseInt(s: string) = r: IntResult;
begin
  if bad then r := errSyntax                { the failing arm, by assignment }
  else r := n                               { the succeeding one }
end;

r := ParseInt(s);
if r.ok then writeln(r.val:1)
else writeln(ErrorText(r.cause))
```

### 1. It is a record type, and there is no new type kind

`T ! E` resolves to a `tyRecord` with a tag field `ok: boolean`, arm `true`
holding `val: T` and arm `false` holding `cause: E` — the record the library
declares today, built by Sema instead of by the author. A flag on the type says
it was written this way; nothing else is new.

That is the whole reason to prefer this over a type of its own. Everything a
result record already does — whole-value copy, a value parameter, a function
result, a field, an array component, `LlSize`, `PutLlType`, `WriteTypeName`,
the ADR-0118 trap — is inherited rather than re-implemented. The optional
(ADR-0123) needed about fifteen sites with real behaviour and two new
procedures because `?T` is a layout the compiler had never emitted. This is a
denoter and two assignment rules.

### 2. The field names, and why not `value`

`ok`, `val`, `cause`. `ok` is ADR-0141's, already universal. `cause` is new and
collides with nothing, and is deliberately *not* `code`: reusing that spelling
would leave `RunResult`'s collision in place with the language's authority
behind it.

**The payload cannot be called `value`** — probed, not assumed: `value` is a
word-symbol of ISO/IEC 10206:1991 §6.1.2 and cannot be a field name, which is
the same fact that forced `selfhost/compiler.pas` to rename a field of its own
(ADR-0082). `val` is the nearest spelling that is free.

### 3. Assignment makes a value, from either side [revised]

Two arms in `Assignable`, the shape ADR-0123 used for `?T`:

- a `T` assigned to a `T ! E` makes it successful;
- an `E` assigned to it makes it failed;
- the same fallible type assigned to it copies, by identity as records already do.

**Revised in implementation.** The proposal refused `T ! E` outright where `T`
and `E` are assignable to one another. What is implemented refuses the
*assignment* instead: `integer ! 1..5` is a declarable type — it is an
ordinary errno-shaped result — and what it cannot take is the shorthand, so
`r := 3` is refused where it is written and `r.val := 3` and `r.cause := 3`
say which arm they mean.

Two things pushed it there. The narrower refusal forbids nothing that works,
which is the better shape whenever the *construction* is not the thing that
fails. And `predicate-callers` (ADR-0146) found the other half: the
declaration-time test made `ResolveFallible` a caller of `Assignable`, and
that gate requires every caller to have a position it can sweep — a
type-denoter is not a position expressible in a probe that puts a type in as a
*variable*, so the honest way to answer the gate was to move the question to
where a value actually is. A gate asking "has this caller been considered at
all?" answered a design question.

### 4. The tag may not be assigned

Probed on the current compiler: a program may write `r.ok := false` today, and
ADR-0118 honours it — the arm changes and the later read of the payload traps.
That is correct for a record the program declared, where the tag means whatever
the program uses it for. For a fallible-type it is a hole: `r.ok := true`
claims a value that was never written, and the next `r.val` reads storage
rather than trapping.

So assignment to `ok` of a fallible-type is **refused**, with a message naming
the two assignments that do exist. Writing `r.val` or `r.cause` directly stays
legal and stays equivalent to assigning the whole thing.

### 5. Not interned, and a heading cannot spell one

Two written `integer ! ErrorCode` are two types, exactly as two `?integer` are
(ADR-0123 §5: "a wrapper type invites one exception to name equivalence, and
one rule is better than two"). A module therefore declares its result type once
and exports it — which is what every module does today, so nothing about a
caller changes.

Nothing has to enforce that: §6.7.2 already requires a function's result-type
to be a **type-identifier**, so `function f: integer ! ErrorCode` is refused by
the grammar of the contained standard and the author is pushed to the named
declaration by a rule that predates the dialect. Probed.

### 6. The spelling reserves nothing

`!` is a character neither standard admits in any position — probed, along with
nine others — so the dialect can take it exactly as ADR-0123 took `?`, gated on
`langStd = stdAfterschool` in the lexer. Under both conformance modes the
answer is *unexpected character '!'*, which is a lexical refusal that predates
the dialect and costs `src/` nothing: Annex B gains a row identical in shape to
the optional's, with two `defer`-style refusal cases.

Written **payload first**. `integer ! ErrorCode` reads as "an integer, or a
failure described by an ErrorCode", and the payload is both what the caller
wants and what the type is named for in every existing module (`IntResult`,
`PathResult`). Zig writes the error first; that is noted below rather than
followed.

## What this deliberately does not do

- **No propagation.** This is the half worth being loudest about, because it is
  the half a Zig or Rust reader will expect. `try f(x)` needs an **early
  return**, which neither *standard* has: a function runs to the end of its
  block and its value is whatever the result variable then holds. That is a
  weaker obstacle than the first draft of this record claimed — see the next
  section. It is a separate decision and a separate record, but not a blocked
  one.
- **No flow-sensitive narrowing.** `if r.ok then r.val` still checks the tag at
  the read, exactly as `if o <> nil then o^` still checks the flag. `doc/sop.md`
  §7 and Annex C.3 already carry that for the optional and would carry it here.
- **No static requirement to check.** Nothing makes a caller test `r.ok` before
  reading `r.val`; the run-time trap is the answer, as it is today. Requiring it
  is dataflow analysis, which this compiler has none of anywhere.
- **No generics.** This is one shape with a language-known meaning, not a type
  parameter system. `PasVector` still holds integers and ADR-0116 still stands.
- **Nothing about `?T`.** ADR-0141's four shapes and its two questions are
  unchanged; what changes is only how the third arm is *spelled*.

## The next record, sketched

`try` would be spelled by ADR-0140's statement-and-factor lookahead, as `defer`
is: `try` followed by a token that begins an expression is a construct no
conforming program can write, while `try;`, `try(x)` and `try := 3` stay
whatever a program that declared the name meant by them.

Its meaning can be written in the contained standard's own terms: **`try X`
yields `X.val` where `X` succeeded, and otherwise assigns the enclosing
function's result variable the cause and behaves as a goto-statement to the end
of that function's statement-part.** The enclosing function's result must be a
fallible-type whose error side accepts this one's.

That framing is why it is worth doing *after* ADR-0175 rather than before: a
goto to the end of a block already closes the block's files and handles and runs
what it deferred, so propagation inherits a correct exit instead of inventing
one.

**And the obstacle is smaller than "Pascal has no early return" makes it
sound.** Neither *standard* has one. Every widely used Pascal does: Turbo
Pascal has had `Exit` since the 1980s, Delphi and Free Pascal have `Exit` and
`Exit(value)`, and `Break` and `Continue` beside them. So an early exit is not
foreign to Pascal — it is foreign to the two documents this project implements,
which is a different claim and a much weaker one for a *dialect* to be bound
by (ADR-0109, ADR-0117). What the dialect actually owes is containment: an
early exit must not change what a conforming program means, and spelled by
ADR-0140's rule it cannot.

That reopens the design rather than settling it, and it reopens it wider than
`try`. The honest sequence is probably **`exit` first and `try` second**: an
early exit is the more conventional feature, every Pascal programmer already
knows it, it is useful to programs that never touch a fallible-type, and once
it exists `try X` is sugar over `if not X.ok then begin r := X.cause; exit end`
rather than a construct that has to invent its own way out of a block. Doing
`try` first would be building the sugar before the thing it is sugar for.

## Consequences

- **The library loses six declarations and gains uniform names.** Thirty lines
  of record become six one-line type definitions; `r.num`, `r.path`, `r.fd`,
  `r.count` become `r.val`, and `r.code`, `r.openCode`, `r.reason` become
  `r.cause`. `RunResult`'s collision disappears by construction. The migration
  touches five modules and seven test programs and is mechanical.
- **`XOr` and `ResultText` become writable once — but not in Pascal.** A
  required function over `T ! E` could serve every payload type, which no
  library routine can. That is a follow-on and not part of this record; it is
  named because it is the second thing the survey found and the reason two of
  the six records have no conveniences at all.
- **Cost, as built**: a token and a lexer arm, a parser postfix in
  `ParseTypeDenoter`, `ResolveFallible` building the record, one flag and two
  type pointers on `typeRec`, one arm in `Assignable`, `AsFallibleArm` in
  Sema, a refusal in `Threatened`, a `WriteTypeName` arm, and the exhaustive
  no-op arms. **No CodeGen change at all** — which was the estimate's whole
  bet and it held: no layout work, no new trap, no runtime routine, and no
  `verify/` rule.
- **Gates it moves**: `kind-exhaustive` (one node kind), `annex-b` (a row and
  two cases), `containment_exceptions.txt` (one entry), the spec's clause table
  and triage, and `dialect-containment` not at all — `tests/extended/` cannot
  contain a `!`.
- **The specification is written after the probe, not before** (ADR-0135), so
  no clause is drafted here — which is also why this record cites none. A
  document that named the clause in advance would be a citation
  `clause-citations` could only call nonexistent, and it did, on the first
  draft of this file.

## Mutation

Four, three different cases. The arm rewrite dropped from §6.8.2.2's path:
`fallible` fails to compile at all, the compiler reaching a nil where a record
field should be. The tag's refusal in `Threatened` disabled: `fallible_errors`
loses two diagnostics, the assignment *and* the `read`. `!` removed from
`LooksLikeSubrange`'s terminator set: `fallible_errors` loses the nested-type
refusal, `integer ! 1..5` having scanned as one subrange. The cause arm never
chosen in `AsFallibleArm`: `fallible` no longer compiles, an `ErrorCode` being
offered to the `val` field.

## Alternatives considered

- **A type of its own, paralleling `?T` with `^` access.** Rejected on the
  reading rather than the cost: an optional has exactly *one* thing to read, so
  an operator suffices; a fallible has three — the tag, the value and the cause
  — and three readings want three names. It would also give up ADR-0118's trap
  and re-implement it.
- **A blessed error type in the language**, so that `!T` needs no second
  operand. Rejected: the only candidate is `lib/dialect/paserror.pas`'s
  `ErrorCode`, and putting a six-constant library enumeration into the language
  would make one module unremovable. The coherence ADR-0141 asks for is a
  *library* rule and stays one.
- **`E ! T`, Zig's order.** Rejected: Zig's order exists because `!T` with an
  inferred error set is its common case, and there is no inference here.
- **`?T of E`** — an optional that says why. Rejected because it invites `^`
  and hides that the two are different questions (ADR-0141's second question is
  exactly "can the value be missing for a reason the caller could act on?").
- **Structural identity, so `integer ! ErrorCode` is one type wherever
  written.** Rejected for ADR-0123 §5's reason, unchanged.
- **Restricting `E` to an ordinal type.** Considered and not adopted: a variant
  record holds anything, the clash rule in §3 is what actually has to be
  refused, and an arbitrary narrowing would have to be widened later.
- **Doing nothing.** The convention works and is tested. What it does not do is
  scale: the seventh module pays the same thirty lines, and the naming has
  already gone wrong once without any oracle noticing — `lib/dialect/README.md`
  says so itself: "a new module returning a result record with a tag spelled
  `success` would compile, link and pass every test in this repository."

## What the implementation found

Four things a reading would not have, each now a case:

- **Assigning to a function's own identifier is a different path.** §6.8.2.2's
  `f := 1` never reaches the ordinary assignment checker, so the arm rewrite
  was absent there: Sema accepted it, nothing wrapped it, and CodeGen emitted
  a store of an integer into a record. A segfault at run time with the whole
  suite green.
- **The rewrite must not re-check its base.** Handing the new `f.val` to
  `CheckExpr` re-read `f`, and §6.8.2.2 makes *reading* a function identifier
  a recursive call — the program looped until the stack ran out. The field is
  the language's own and cannot be missing, so it is resolved directly.
- **`LooksLikeSubrange` had to learn the token.** It scans forward for a `..`
  to tell `base - 9 .. base + 1` from a type name, and stops at the tokens
  that end a denoter. `!` was not one, so `integer ! 1..5` scanned as a single
  subrange whose lower bound was `integer`, and the diagnostic was about a
  `..` that was never missing.
- **The tag needed §6.9.4 and not the assignment.** Refusing `r.ok := true`
  where the assignment is checked would have left `read(r.ok)` setting the tag
  with no arm written. `Threatened` is the predicate the clause's six threat
  sites already go through, and a refusal there reaches all of them — the
  shared-predicate lesson of ADR-0146 used the way round that pays.

## Consequences of the migration

`lib/dialect/` loses six record declarations for six one-line type
definitions, and the field names become the same in every module. The
collision this record cited as its sharpest evidence — `RunResult.code` being
a *success* payload where `r.code` elsewhere is the `ErrorCode` — is gone by
construction rather than by a convention someone must remember.

## Still open

**Propagation**, and beneath it whether the dialect gets `exit`. ADR-0175's
record carries the argument: an early exit is what every popular Pascal has
and neither standard does, and `try X` is sugar over it rather than a
construct that has to invent its own way out of a block.
