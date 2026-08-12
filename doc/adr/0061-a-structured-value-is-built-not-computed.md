# 61. A structured value is built, not computed

Date: 2026-08-12

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.8.7 adds the structured-value-constructor: a primary
that denotes a value of a named array or record type, written as the type's
name and a bracketed list of what its components are.

>     structured-value-constructor = structured-value-type-name
>                                    '[' component-values ']' .
>     array-value = '[' [ array-value-element-list ] [ ';' ]
>                   [ array-value-completer [ ';' ] ] ']' .
>     array-value-element = case-constant-list ':' component-value .
>     array-value-completer = 'otherwise' component-value .
>     record-value = '[' field-list-value ']' .
>     field-value = field-identifier { ',' field-identifier } ':'
>                   component-value .
>     variant-part-value = 'case' [ tag-field-identifier ':' ]
>                          constant-tag-value 'of' '[' field-list-value ']' .

Three of those productions were already in this compiler under other names.
A case-constant-list is what a case statement and a variant part read
(ADR-0035). A field-list-value corresponds to a field-list, and an arm's
field-list is a field-list like any other (ADR-0026). A component-value is an
expression assigned to a component, which is what `emitStore` already is.

What is genuinely new is the shape of the thing being denoted. ADR-0017 gives
an array and a record no register form: a value of one exists only as storage,
and every expression yielding one until now was a designator, so the storage
already existed and was somebody else's.

## Decision

**A structured value is built rather than computed.** `emitStructValue` takes
the address the value is to occupy and stores each component into it; the
expression's value is that address. There is no intermediate, no aggregate
`load`, and no assembly step — which makes the whole of CodeGen for this
feature a walk of the same two shapes Sema walked.

Where the storage comes from is decided per position:

- At the top of an expression it is **the hidden frame slot ADR-0055 gives a
  memory-living function result**, per call site. `Call::resultSlot` was
  already that mechanism, and `StructValueExpr::resultSlot` is a second user
  of it rather than a second mechanism.
- A **nested** component-value builds directly into the component it is for,
  so it never has a slot. That is not an optimisation: it is what makes
  `mat[1: vec[otherwise 7]]` one store per component instead of a build and a
  copy.
- **An assignment builds into its destination.** `emitStore` takes the
  constructor branch before the whole-variable copy, which is also what makes
  §6.6's initial-state form work at all — a variable's prologue has no result
  slot to lend, because the variable itself is the storage the value was
  always going to occupy.

**The completer is filled in first and the elements written over it.**
§6.8.7.2 b) gives the completer "each component of the array-value that is not
mapped to by an array-value-element", and computing that complement would need
a set of the index type. Filling every component and then overwriting the
named ones is the same answer, because Sema has already established that the
elements' ranges are disjoint.

**A component-value is emitted once however many components it is for.**
`vec[1..4: bump]` calls `bump` once and copies; so does `pt[x, y: f(3)]`. The
standard does not say, but evaluating a function call once per component is
the reading a program would notice, and one evaluation is the one a reader
expects from a single expression.

**One node covers both forms, and Sema decides which.** `[a: 1]` is an
array-value when `a` is a constant of the index-type and a record-value when
it is a field-identifier, so the parser cannot know: it reads every selector as
an expression and Sema either folds it with `evalLabelRange` or reads it as a
bare name, according to the type the name resolved to. `ValueElem` carries the
unresolved selectors in `labels` and whichever of `values` and `fieldIndex`
the answer called for.

**Telling a value from a subscript is the third bracket-depth scan in this
parser**, after ADR-0054's `looksLikeSubrange` and ADR-0056's
`callTakesCaret`. A subscript list holds index-expressions, and an
index-expression contains no `:`, no `;`, and neither of the words `case` and
`otherwise` at the depth the bracket opened; an empty `[]` counts too, since a
subscript list may not be empty. No types are consulted, which is what lets
this sit in `parsePrimary` beside the call forms.

**The completeness rule is the whole of Sema.** §6.8.7.2's NOTE and §6.8.7.3's
NOTE 2 both say every component is specified exactly once, so each form does
the same three things: resolve the selectors, check each component-value
against the type it lands in, and ask what was left out. For an array that is
a count against the index type's extent, exact because the ranges are known
disjoint; for a record it is a flag per field, with the tag field excluded
because §6.8.7.3 gives its value to the `case`.

**A variant-part-value recurses into `checkRecordValue` and
`emitRecordValue`**, keyed by the same variant path `Field::variant` already
uses (ADR-0026). A variant part inside a variant part therefore costs nothing
in either pass, and `fieldsAt`/`armsAt`/`tagFieldAt`/`tagTypeAt` moved onto
`Type` so that Sema and CodeGen ask one set of functions rather than two.

## Consequences

`verify/` gained nothing and no existing lowering changed. A component store
is `emitStore`, so a subrange component is range-checked, a string component
padded, and a `real` component converted, all by code that was already there
and none of it written twice.

**§6.6's initial-state form arrived with it, and retires ADR-0048's stated
deferral.** §6.6 NOTE 4 makes an initial-state-specifier's component-value "an
assignment-compatible expression, an array-value, or a record-value", so the
one edit was `parseExpr` becoming `parseComponentValue` in `parseTypeExpr` —
which is what makes NOTE 3's own example, `array [1..8] of char value
[1..8: '*']`, mean eight stars rather than a set. `nonvarying` learned the
node in the same change, because the rule that an initial state may not read a
variable has to reach the component-values.

**A constructor is not a designator, and needed no rule saying so.**
`isDesignator` answers false for it, so it cannot be an actual var parameter,
a `read` target, an assignment's target or a `with`'s record — the four
restrictions ADR-0056 found already written. The one place a rule *was* needed
is the opposite direction: a structured *value* parameter is a copy and had
required a designator to copy from, so `checkArguments` learned that a
constructor is a third thing with storage, beside a designator and a string
literal.

**A field-identifier and an arm's field-list-value are given types they did
not ask for.** Neither is an expression that anything evaluates, but ADR-0008
says every node leaves Sema with a type, and a dump that printed `?` for them
was the first sign that the invariant had a hole. The field's own type and the
record's type are the honest answers.

**The AST dump is where the two compilers meet on this.** An element prints
how many selectors it had, and after Sema the folded ranges of an array-value
or the field numbers of a record-value — so the dump says which of the two
forms the type turned out to name, which is the one decision this feature
makes that no output would otherwise show.

**`tokMax` in `selfhost/compiler.pas` went from 110000 to 130000.** The
feature's own source pushed the compiler past its token limit while compiling
itself; the constant fails loudly rather than truncating, which is why this is
a line in a decision record rather than a mystery.

### What this does not do

**§6.8.7.4's set-value is not implemented**, and the boundary is a decision
rather than a shortfall. `sieve[2, 3, 5, 7]` and `a[2, 3]` are the same tokens,
so the form could only be told from a subscript by the symbol — in Sema, as
ADR-0053 tells a qualified name from a field selection. But the reason not to
is that this whole mechanism is about *storage*: a set is a value (ADR-0028),
it is assigned with a store and passed in a register, and it needs none of
what an array or a record needs. Set types are also structurally compatible
(§6.4.6), so `[2, 3, 5, 7]` already denotes the same value everywhere an
expression may appear; the named form's only irreplaceable use is a
constant-definition, which is deferred below in any case. The empty `t[]` does
reach Sema, and is refused there with the words every unstructured type gets.

**§6.8.8's constant-accesses and structured constants are not implemented.**
`const c = t[1: 1; 2: 2]` needs a constant that has an address, which is a
different mechanism from anything `evalConst` does — that folder answers with
a number, and ADR-0054 already refuses real-, set- and string-valued
constant-expressions for the same kind of reason. Saying so costs one line in
each compiler and a program in the corpus: the C++ folder falls through to
"not a compile-time constant", and the Pascal one is a `case` over the node
kind, so a kind it has no arm for **traps at run time**. That is the shape of
mistake this port makes, and the only oracle that can see it is a program that
writes one.

**A dynamically bounded array cannot be constructed** (ADR-0040, ADR-0041).
"Every component is specified" is not a question a compiler can answer about a
type whose extent arrives at run time, and it is refused with its own words
rather than half-checked. The check looked unreachable and is not: a
constructor names a type-name, and no *named* type has a dynamic extent
(ADR-0055's argument), but §6.2.3.2 lets a **variable declaration** compute its
discriminants — so `var d: vector(k) value [1..k: 0]` is the one program that
reaches it, through the initial-state form rather than through an expression.
A mutation deleting the check survived until that program was written.

**§6.8.7.3's rule that the fields of a field-value have one type is checked by
identity**, so two fields of alike-but-distinct types are refused. That is
ADR-0017's name equivalence applied where §6.8.7.3 NOTE 1 says the
component-value has a single type, and it is stricter than the clause only in
cases the clause does not describe.
