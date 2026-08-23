# 176. An error union is the result record, written by the compiler

Date: 2026-08-24

## Status

**Proposed.** Would add a clause of its own to AP 6.4 — the next one after the
handle-type — and a row each to Annexes B and F. The number is deliberately not
written down here: `clause-citations` reads any clause number in this tree as a
citation, and a proposal must not pin one the specification does not yet carry.

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

### 3. Assignment makes a value, from either side

Two arms in `Assignable`, the shape ADR-0123 used for `?T`:

- a `T` assigned to a `T ! E` makes it successful;
- an `E` assigned to it makes it failed;
- the same fallible type assigned to it copies, by identity as records already do.

**`T ! E` is refused where `T` and `E` are assignable to one another**, because
then a value would not say which arm it meant. `integer ! integer` and
`integer ! 1..5` are refused; `integer ! ErrorCode` is not. Refusal by
construction, and no rule about "which side wins".

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
  return**, and Pascal has none: a function runs to the end of its block and
  its value is whatever the result variable then holds. The sketch is in the
  next section; it is a separate decision and a separate record.
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
one. What it costs is the thing Pascal deliberately lacks — a second way out of
a block — and that is a decision on its own merits.

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
- **Cost estimate**: a token and a lexer arm, a parser branch in
  `ParseTypeDenoter`, a `ResolveFallible` building the record, one flag on
  `typeRec`, two arms in `Assignable`, one refusal in the assignment checker,
  a `WriteTypeName` arm, and the exhaustive no-op arms `kind-exhaustive` will
  name. No layout work, no new trap, no runtime routine, and no `verify/` rule
  — the same `Model-unchanged:` argument ADR-0123 made.
- **Gates it moves**: `kind-exhaustive` (one node kind), `annex-b` (a row and
  two cases), `containment_exceptions.txt` (one entry), the spec's clause table
  and triage, and `dialect-containment` not at all — `tests/extended/` cannot
  contain a `!`.
- **The specification is written after the probe, not before** (ADR-0135), so
  no clause is drafted here — which is also why this record cites none. A
  document that named the clause in advance would be a citation
  `clause-citations` could only call nonexistent, and it did, on the first
  draft of this file.

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

## Open, for the decision

1. **The field names.** `ok` / `val` / `cause`, given that `value` is reserved.
2. **Whether the record is the right substrate** — reusing `tyRecord` and
   ADR-0118, against a type of its own with `^`.
3. **Whether propagation is in scope now.** This record assumes not, and that
   assumption is what keeps it small.
