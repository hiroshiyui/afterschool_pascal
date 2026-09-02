# 297. The library uses the feature it asked for

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Closes the first open usability finding in
`doc/roadmap.md`'s "The program that would judge the language" — *the
dialect's error-handling constructs are unused by its largest client* — and
closes the `doc/sop.md` §7 row
[ADR-0254](0254-a-generic-activation-need-not-write-its-types.md) opened,
*a generic whose parameter-form names a schema the caller cannot see infers
nothing*.

## Context

The finding had already corrected itself once. It first said a routine generic
over a fallible type could not be written; `tests/dialect/generic_fallible.pas`
showed it could, and that the real cause of `lib/`'s four per-type accessors —
`IntOr`, `PathOr`, `CountOr`, `RealOr`, each `T ! ErrorCode → T` — was that
`ValueOr(integer, r, 0)` names a type the argument already knows. ADR-0254
landed inference on 2026-08-30 with that paragraph as its stated cause. Four
days later `grep -rn ValueOr lib lsp` still found nothing: the four helpers
stood, the twelve result types were still twelve separate `T ! ErrorCode`
denoters — which §6.4.1 makes twelve distinct types, so no one routine could
take them — and the measurement the finding asked for had not been retaken
with the feature present.

**The probe came first and cost more than minutes.** Before touching the
library, `tests/dialect/generic_fallible_import.pas` was written in the shape
the library would take: a schema `Fallible(T: type) = T ! Code` and a generic
`ValueOr(T: type; res: Fallible(T); whenBad: T): T` in one module, three
named productions — a scalar, a `string(8)` and a record — in a second, and a
program importing the generic by `only (ValueOr)`, so the schema's *name* is
not in scope at the call. That is `lsp/pasls.pas`'s own import style. It found
two compiler defects, and neither was the one ADR-0254 had predicted.

**A production reads its own discriminant when the argument is spelled like
it.** `ProduceFromSchema` declared the type-valued discriminant `T` into the
body's scope and *then* looked the argument node up to give it a type — so
`Box(T)` written where a `T` is in scope found the discriminant it had just
declared, a type with no type, and resolved the body over nil. Nothing
generic about it: `type T = char; Box(T: type) = record item: T end;
CB = Box(T)` stops the compiler on a nil dereference, and
`tests/dialect/schema_typearg_shadow.pas` is that program. What made it
invisible for a month is that only the **first** production of a tuple runs
this code, an interned one being found before it, and every case in the tree
had named its productions in a type-definition before any call. Every generic
whose type parameter shares the schema's spelling writes the collision —
`ValueOr(T: type; res: Fallible(T); …)` produces `Fallible(T)` with a `T` in
scope — and its instantiation came out with `falVal = nil`, which
`Assignable` reads as *an earlier error already reported* and answers yes to.
So `WhenBadFirst(0, st)`, a `Fallible(short)` handed to a formal produced for
`integer`, was accepted with exit 0, and the string-typed cases stopped the
compiler in CodeGen's `DynLength` instead.

**And ADR-0254's degradation was not graceful.** That record resolved the
schema a parameter-form names *at the call*, and said a caller that cannot
see the name would determine nothing through that formal and have to write
the types. What actually happened is that the *next* actual determined the
type parameter instead — `'none'` binding `T` to `packed array [1..4] of
char` — and the formal was produced for a type nobody meant. AP 6.7.3.10.4 b)
already said "that schema", meaning the one the parameter-form names, and a
parameter-form is written where the generic is.

## Decision

Two Sema changes, then the library.

1. **The discriminant's type is read off the tuple**, `tv^.ty`, which
   `numRec` has carried beside the id since ADR-0254; the argument node is not
   looked up again. The comment that said *there is no registry to turn an id
   back into a type* described the tree before that record.

2. **`Determine` resolves the schema's name in the generic's declaring
   region** — `genDeclTop`/`genDeclDepth`, the same scope `InstantiateGeneric`
   switches to for the body — and not at the call. ADR-0254's reason for a
   lookup over a comparison of spellings still holds and is now stronger: a
   same-named schema of the caller's own cannot bind a type the callee never
   meant, because the caller's scope is never consulted.

3. **`lib/dialect/paserror.pas` exports `Fallible(T: type) = T ! ErrorCode`
   and `ValueOr`.** All twelve result types in `lib/` are productions of it
   and keep their names — `IntResult = Fallible(integer)`, `PathResult =
   Fallible(PathName)`, and the other ten — so every existing caller compiles
   unchanged. The four per-type accessors are **retired outright**, not kept as
   wrappers: `IntOr`, `PathOr`, `CountOr` and `RealOr` are gone from their
   export lists, and every call site is `ValueOr(r, whenBad)`. `JsonIntegerOr`
   and its neighbours read a scalar out of a `JsonPtr` and `LookupOr` takes an
   environment default; neither is a fallible accessor and both stand.

## Evidence

**The cases.** `generic_fallible_import` is the cross-module probe, with the
string case defaulting to a *literal* so that the schema path and not the
default is what has to determine `T`. `schema_typearg_shadow` is the collision
with no generic in it. `generic_infer_errors` gains `WhenBadFirst('?', good)`,
refused in the words a mismatch has always had. `try_depth` is the question
the finding left open, below.

**Two mutations, two different killers**, both in `tests/mutation/mutants/`.
Restoring the argument lookup fails `schema_typearg_shadow` and
`generic_infer_errors` and nothing else — `generic_fallible_import` survives
it, because with the schema resolved in the right region every production is
interned before the heading is built. Restoring the lookup at the call fails
`generic_fallible_import` alone, with the exact wrong-type refusal ADR-0254
said could not happen.

**The measurement, retaken.** `grep -c` over `lsp/pasls.pas`, before and
after:

| | before | after |
| --- | --- | --- |
| `IntOr(` | 18 | 0 |
| `PathOr(` | 1 | 0 |
| `ValueOr(` | 0 | 19 |
| `JsonIntegerOr(` | 8 | 8 |
| `LookupOr(` | 3 | 3 |
| `try(` | 0 | 0 |
| `T ! E` written | 0 | 0 |

Nineteen accessor calls became nineteen `ValueOr` calls, the import of
`PasParse` lost a name, the server is two lines longer for the comment
saying why, and the `try` column did not move — which is the answer, not the
gap.

**Call sites moved: 27** — 19 in the server, 8 in four test cases — and 0
in `lib/` itself, none of the modules having called its own accessor.

**No place in the server was converted to `try`, and there is none.** `try`
propagates by leaving the enclosing function with the cause (AP 6.8.9), which
is right for a program that may fail and wrong for one that must answer every
request: a language server has no request whose failure should abort the
routine rather than produce a response, and every fallible value it receives
is defaulted where it is read. That is the finding the ratio had been
carrying all along. There are two shapes — propagate and default — and a
server is entirely the second, so `ValueOr` *is* the construct for it and
nineteen-to-zero is the right ratio for this program and not a deficit.

**`try` at depth, with evidence.** `tests/dialect/try_depth.pas` is four
fallible routines across two modules, each one line, each propagating with
`try`, a failure originating at the bottom and another at the top, and a
program recovering twice — once by asking `r.ok`, once with `ValueOr`. It
compiled and matched its golden at the first run. Honestly:

- It reads well. `r := 10 * try(ReadDigit(s[1])) + try(ReadDigit(s[2]))`
  says what it does, a cause crosses four levels without being named at any
  of them, and the top-level recovery is three lines. Nothing about it got
  worse with depth, which is what the finding asked.
- What a reader has to know is that `try` is a *function that leaves the
  block*: nothing at the call site says so, and `sum := try(SumPairs(a, b))`
  followed by an `if` reads as a call and a test until one knows the rule.
  That is the price of a spelling that reserves no word, and it is the one
  place the construct is less obvious than an `if`.
- Every level's result type has to be a fallible type or its cause, so a
  module in the chain names a production of its own — `IntResult =
  Fallible(integer)` twice, once in `PasParse` and once in `DepthLow`. The
  first draft reached for PasError's `IntResult` and there is none; §6.7.1
  makes a result-type a type-name, so the production must be named
  somewhere, and 6.4.7 then makes the two names one type. Awkward for a
  minute and then right.

## What is not done

**No wrapper was kept.** Retiring the four accessors broke nothing that a
one-line edit did not fix, so none survives; a wrapper would be a second
spelling of one routine and the thing this record removes.

**`ParseIntOr` in `lib/pastext.pas` is untouched.** It takes a `TextLine` and
parses it, which is not an accessor over a result; and `lib/pastext.pas` is
one of the portable modules and imports nothing from `lib/dialect/`.

**The language did not change and the specification did not.** AP 6.7.3.10.4
b) said "that schema" and the compiler now does what it says; the shadowing
defect had no clause disagreeing with it, only a reading order in one routine.

**A finding about the roadmap, not the compiler.** The entry's own row in
"Writing a daily program" — *the library has not caught up with the
language's inference* — was the same fact written a second time, in a second
chapter, four days after the feature landed. Both are closed here.

## Consequences

- **A probe of a library shape is a probe of the compiler**, and this one
  found two defects that four cases, three ADRs and a green suite had not.
  The collision is the sharper lesson: it is the *natural* spelling — a
  generic over `Fallible(T)` calls its parameter `T` because the schema does —
  and every case in the tree had avoided it by accident of declaration order.
  `doc/sop.md` §4a's sentence stands: the library increment of a feature is
  the cheapest enumerator of its surface, and it should not have waited four
  days.
- **`doc/sop.md` §7 loses a row.** *A generic whose parameter-form names a
  schema the caller cannot see* is closed by decision 2, and the row's own
  sentence — *what would fix it is carrying the callee's region into the
  unifier* — turned out to be two assignments and their restoration.
- **A library module's result type is a production now**, and a new one is
  `X = Fallible(T)`; a module writing `T ! ErrorCode` again would declare a
  type `ValueOr` cannot take. `lib/dialect/README.md` says so.
- **The four-days gap is the register's finding**, met a third time in this
  chapter: a feature landed *because* of a finding and the finding's entry
  went on saying the feature was absent. The entry moves to `doc/history.md`
  with this record beside it.
