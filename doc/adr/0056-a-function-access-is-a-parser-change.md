# 56. A function-access is a parser change

Date: 2026-08-12

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.8.6 makes a *function-access* a family rather than a
single form:

> function-access = entire-function-access | component-function-access
>                 | substring-function-access .
> component-function-access = indexed-function-access | record-function-access .

So `mk(7, 8).y` reads a field of a result, `scale(10)[2]` a component, and
§6.8.6.4's `alloc(3)^` the variable a returned pointer identifies. ISO 7185
§6.6.2 made every result a simple type or a pointer, so there was nothing to
select from and only the last form could even be spelled — and that standard
does not offer it either. ADR-0055 gave results records, arrays and sets; this
clause is what that unlocked, and ADR-0055 listed it as work it was not doing.

The clause carries a NOTE that decides how much machinery the feature needs:

> A function-access is not equivalent to a variable-access. For example, a
> function-access may not be used as an actual variable parameter or as the
> record-variable in a with-statement.

## Decision

**The whole feature is in the parser.** A call in expression position may be
followed by selectors, under `--std=extended`; that is `Parser::afterCall`, and
nothing downstream is told which of the two things it walked.

Sema needed **nothing**, and CodeGen needed **nothing**. Both facts have the
same cause and it is ADR-0055's: a result that lives in memory travels in
storage the caller supplies, so a call in that position already *yields an
address*. `CodeGen::emitAddress` has had a `case NK::Call` since ADR-0052 built
`binding(f)` in a hidden frame slot — the comment above it names `binding`, and
the code was already general.

**§6.8.6's NOTE was already written, as `Sema::isDesignator`.** That predicate
answers "is this a variable-access", it has answered `false` for a call since
it was written, and every restriction the NOTE names is one of its twenty call
sites. So the refusals cost no code:

- an actual var parameter (§6.9.4 b)) — `isDesignator` says no;
- `read` into one (§6.10.3) — the same;
- an assignment's target, and a `with`'s record — these two are refused by the
  **grammar**, one level earlier. §6.8.2.2's target and §6.8.3.10's
  record-variable-list are variable-accesses, and §6.5.1's list of those does
  not include a record-function-access. There is no production to reach, so
  there is no rule to write.

**§6.8.6.4 is the exception, and it is a variable.** §6.5.1 lists a
function-identified-variable among the variable-accesses, because what a
pointer points at is a variable however the pointer was obtained. So
`alloc(3)^.x := 1` is legal, and a statement beginning with a name and an
argument list is no longer certainly a procedure-statement.

Telling the two apart needs a scan to the **matching** `)`, because the token
that decides is not a fixed distance away — the same bracket-depth walk
ADR-0054 added to `looksLikeSubrange`, and the second time this parser has
needed one. `Parser::callTakesCaret` is it, and the statement branch then hands
the work to `parsePrimary`, which already knows how to build a call and its
selectors.

`isDesignator` needed no change for this either: it answers `true` for *any*
dereference, whatever its base, and the comment saying why has been there since
ADR-0019.

## Consequences

The feature reserves nothing, adds no runtime error, adds no `verify/` rule,
and changes no lowering — the first Extended Pascal feature here to touch one
file and one function in each compiler.

**What the corpus had to be told, because nothing else would say it.** Five
programs, and three of them exist for a reason a green bar would not have
given:

- The ISO 7185 gate cannot be tested with a record result. The obvious program
  — `mk(7, 8).x` under `--std=iso7185` — dies at the *result type*, which
  §6.6.2 refuses, and the selector is never reached; it would pass whatever the
  parser did. `tests/funcaccess_iso.pas` returns a **pointer** instead, which
  §6.6.2 allows, so the `^` is the only thing in the program that ISO 7185
  refuses. This is exactly the fault ADR-0054 found in `constexpr_iso.pas`, met
  a second time and recognised before it landed rather than after.
- The **statement** form has its own gate and its own file
  (`funcaccess_iso_assign.pas`). A `callTakesCaret` that scanned regardless of
  the standard would accept `alloc(3)^.x := 1` under ISO 7185 — the parser
  would build the assignment and Sema, which is told nothing about
  function-accesses, would raise no objection. Nothing else anywhere would
  notice.
- The two grammar refusals cannot share a file, because the parser stops at its
  first error. `funcaccess_assign.pas` and `funcaccess_with.pas` are one
  statement each.

A nested argument list (`alloc(sqr(2))^.y := 7`) is in the corpus for the
matching-paren scan: a version stopping at the first `)` finds no `^` and turns
the statement into a procedure call.

### What this does not do

**§6.8.6.5's substring-function-access is not here.** `f(x)[i..j]` is deferred
with §6.5.6's substring *variables*, which this compiler does not have either —
ADR-0051 deferred them and they are still their own feature. When they land,
they land in both places, because `parseSelectors` is the one function that
would learn the syntax and it is now shared by variables and function-accesses
alike. That sharing is the argument for deferring rather than doing half of it
here.

**§6.8.6.2's abbreviated form is inherited, not implemented.** `a[i, j]` is
`a[i][j]` in `parseSelectors` already, and a function-access uses that loop
unchanged.

**§6.8.6.3's "it shall be an error to denote a component of a variant, unless
the variant is active" is not enforced**, and neither is the same rule for a
variable — ADR-0018 has never checked it. This feature does not widen the gap
and does not narrow it.
